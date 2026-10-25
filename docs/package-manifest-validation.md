# Source packaging candidate

GAME-WEB-PACK-001 r2 is an independent Python 3.12+ standard-library tool. It packages explicit Godot source directories with a whitelist, SHA256 manifest, reproducible ZIP ordering/timestamps, link and traversal rejection, and no-overwrite publication.

```sh
python tools/package_manifest_candidate.py --self-test
python tools/package_manifest_candidate.py --source ./candidate-project --output ./artifacts/candidate.zip
```

The output parent must exist; the output must be new and outside the source tree. Only the root project.godot is an entry file. Assets and unknown extensions are skipped, so this is not an exported playable build. Filename filtering is not a content-privacy or license review.

The r2 pipeline consistently passes the canonical source root to scanning, relative-path construction and copying, fixing a Windows short/long-path comparison failure in r1. It retains the original six tests and adds a canonical-root regression.

Validation: all seven self-tests passed on Windows with Python 3.14.3, exit 0, with DeprecationWarning treated as an error. The file and directory symlink test ran without a skip. Source SHA256: 989bd5bb066d0599f2f25f9bdd7e538bafe567b3eac29830932005732a2a3cf3.

Not yet independently verified: Python 3.12, real Windows 8.3 aliases, junction-specific fixtures, packaging during hostile concurrent mutation, or a complete game release. Publication requires filesystem hard-link support. The source remains a candidate pending review; no shared game interface or release approval is implied.
