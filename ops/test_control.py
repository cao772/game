import copy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from control import conversation, plan, reserve, atomic_json, ledger_lock


class DispatchTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 10, 25, 5, tzinfo=timezone.utc)
        self.chat = '00000000-0000-0000-0000-000000000001'
        self.task = dict(id='T1', version='r1', status='queued', url='https://chatgpt.com/c/'+self.chat,
                         inputs_ready=True, input_sha256='a'*64, write_paths=['candidates/T1/'])
        self.ledger = dict(target_active=10, trial_ceiling=10, tasks=[self.task])
        self.resource = dict(utc=self.now.isoformat(), cpuAverage=30, freeMemoryMinGiB=12, diskFreeGiB=80)
        self.browser = dict(available=True, checked_at=self.now.isoformat(), quota_ok=True,
                            chats={self.chat: dict(observed_at=self.now.isoformat(), state='idle', draft='',
                                                   project_verified=True, model_high_verified=True)})

    def result(self):
        return plan(self.ledger, self.resource, self.browser, self.now)

    def test_ready_and_url_normalization(self):
        self.assertEqual(self.result()['ready'], ['T1'])
        self.assertEqual(conversation('https://chatgpt.com/g/project/c/'+self.chat), self.chat)
        self.assertIsNone(conversation('https://example.com/c/'+self.chat))

    def test_weekend_boundaries(self):
        for date, expected in [('2026-10-23T15:59:59+00:00','rest'), ('2026-10-23T16:00:00+00:00','work'),
                               ('2026-10-25T15:59:59+00:00','work'), ('2026-10-25T16:00:00+00:00','rest')]:
            self.assertEqual(plan(self.ledger, self.resource, self.browser, datetime.fromisoformat(date))['time_gate'], expected)

    def test_continuous_schedule_allows_weekday_with_all_other_gates(self):
        self.now = datetime(2026, 10, 26, 5, tzinfo=timezone.utc)
        self.ledger['schedule_mode'] = 'continuous'
        self.resource['utc'] = self.now.isoformat()
        self.browser['checked_at'] = self.now.isoformat()
        self.browser['chats'][self.chat]['observed_at'] = self.now.isoformat()
        self.assertEqual(self.result()['time_gate'], 'work')
        self.assertEqual(self.result()['ready'], ['T1'])
        self.browser['available'] = False
        self.assertFalse(self.result()['ready'])
        self.assertIn('browser_unavailable_or_stale', self.result()['global_blockers'])

    def test_invalid_schedule_mode_rejected(self):
        self.ledger['schedule_mode'] = 'daily_typo'
        with self.assertRaises(ValueError):
            self.result()

    def test_unknown_stale_future_and_bool_resource(self):
        for value in [None, float('nan'), float('inf'), -1, True]:
            self.resource['cpuAverage'] = value
            self.assertFalse(self.result()['ready'])
        for offset in [-301, 1]:
            self.resource.update(cpuAverage=30, utc=(self.now+timedelta(seconds=offset)).isoformat())
            self.assertFalse(self.result()['ready'])

    def test_resource_pressure(self):
        for ram, cpu, disk in [(3,30,80), (7,30,80), (12,90,80), (12,30,9), (12,30,19)]:
            self.resource.update(cpuAverage=cpu,freeMemoryMinGiB=ram,diskFreeGiB=disk)
            self.assertFalse(self.result()['ready'])

    def test_no_browser_is_unknown_not_zero(self):
        self.browser['available'] = False
        self.assertIsNone(self.result()['currently_generating'])
        self.assertFalse(self.result()['ready'])

    def test_stale_or_missing_chat_observation(self):
        self.browser['chats'][self.chat]['observed_at'] = (self.now-timedelta(seconds=121)).isoformat()
        self.assertFalse(self.result()['ready'])
        self.assertIsNone(self.result()['currently_generating'])
        self.browser['chats'] = {}
        self.assertIsNone(self.result()['currently_generating'])

    def test_draft_and_owner_protected(self):
        self.browser['chats'][self.chat]['draft'] = 'unsent user text'
        self.assertFalse(self.result()['ready'])
        self.browser['chats'][self.chat]['draft'] = ''
        self.ledger['tasks'].insert(0, dict(id='OLD',url=self.task['url'],status='waiting_decision'))
        self.assertFalse(self.result()['ready'])

    def test_send_pending_never_repeated(self):
        self.task['status'] = 'dispatch_pending'
        self.assertFalse(self.result()['ready'])
        self.task.update(status='queued', dispatch_key='prior')
        self.assertFalse(self.result()['ready'])

    def test_independent_archive_does_not_block_dependency(self):
        self.task['depends_on']=['DEP']
        self.assertFalse(self.result()['ready'])
        self.ledger['tasks'].insert(0,dict(id='DEP',status='archive_pending',technical_status='passed'))
        self.assertEqual(self.result()['ready'],['T1'])
        self.ledger['tasks'][0]['technical_status']='failed'
        self.assertFalse(self.result()['ready'])

    def test_duplicate_task_ids_fail_closed(self):
        self.ledger['tasks'].append(copy.deepcopy(self.task))
        with self.assertRaises(ValueError): self.result()

    def test_two_queued_same_chat_cannot_both_send(self):
        other=copy.deepcopy(self.task);other.update(id='T2',write_paths=['other/'])
        self.ledger['tasks'].append(other)
        self.assertEqual(self.result()['registered_chats'],1)
        self.assertEqual(self.result()['ready'],['T1'])

    def test_write_conflict_and_unknown_busy_scope(self):
        for writable in [[], ['candidates/']]:
            self.ledger['tasks']=[self.task,dict(id='OTHER',status='running',write_paths=writable)]
            self.assertFalse(self.result()['ready'])
        self.ledger['tasks'][1]['write_paths']=['independent/']
        self.assertEqual(self.result()['ready'],['T1'])

    def test_review_backpressure(self):
        self.ledger['max_review_backlog']=1
        self.ledger['tasks'].append(dict(id='REVIEW',status='review',url=self.task['url'][:-1]+'2'))
        self.assertIn('review_backlog',self.result()['global_blockers'])

    def test_capacity_full(self):
        self.ledger['target_active']=1
        self.ledger['tasks'].append(dict(id='BUSY',status='running',write_paths=['other/']))
        self.assertFalse(self.result()['ready'])
        self.assertIn('capacity_full',self.result()['blocked'][0]['reasons'])

    def test_candidate_owner_gate(self):
        self.task['owner_gate']=True
        self.assertFalse(self.result()['ready'])
        self.assertIn('owner_decision_required',self.result()['blocked'][0]['reasons'])

    def test_paths_reject_escapes(self):
        for value in [['../escape'],['C:/outside'],['/absolute'],['.'],['']]:
            self.task['write_paths']=value
            self.assertFalse(self.result()['ready'])

    def test_local_reservation_is_durable_and_not_a_send(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            atomic_json(root/'tasks.json',self.ledger)
            atomic_json(root/'logs/latest-resource.json',self.resource)
            atomic_json(root/'browser-state.json',self.browser)
            with patch('control.datetime') as mock:
                mock.now.return_value=self.now
                mock.fromisoformat.side_effect=datetime.fromisoformat
                result=reserve(root,'T1')
                self.assertFalse(result['sent'])
                with self.assertRaises(ValueError): reserve(root,'T1')
            saved=json.loads((root/'tasks.json').read_text(encoding='utf-8'))
            self.assertEqual(saved['tasks'][0]['status'],'dispatch_pending')
            self.assertEqual(len(saved['tasks'][0]['dispatch_key']),64)

    def test_os_lock_rejects_overlap_and_releases(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'lock'
            with ledger_lock(path):
                with self.assertRaises(OSError):
                    with ledger_lock(path): pass
            with ledger_lock(path): pass


if __name__ == '__main__':
    unittest.main()
