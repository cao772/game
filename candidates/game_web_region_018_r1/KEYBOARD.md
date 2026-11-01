# Complete keyboard-only synthetic workflow (planned; NOT_RUN)

1. Focus initial UI with **Tab**. Use native selection keys (for example up/down with the A/B/C OptionButton) and confirm a synthetic scene; selection changes reset that scene's local undo.
2. Continue **Tab** to the visible direction Buttons. Activate them using native **Enter/Space** to move P without relying on pointer or color. Read the textual current coordinate and row map after each movement. If a wall blocks movement, P remains fixed; the recovery text directs you to undo or preview return-to-S.
3. **Tab** to “预览到 T 路线” and activate. The current marker stays in place; every route cell displays ':' in the row-by-row alternative, not only as a blue overlay. For C, the message says T cannot be reached. Activate “预览返回 S” to obtain a recovery route.
4. **Tab** to “1. 重新核对可达与遮挡”. The reported claim and local observation appear in separate text lines. **Tab** to “2. 明确更正本地记录”. This updates an in-memory correction **only after Inspect**.
5. **Tab** to “撤销最近移动或更正” to reverse the most recent successful mutating action. Reinspect before any next correction. “清除路线预览” removes only the visual/text route, not the recorded claim. “重置本场景” restores the initial synthetic fixture claim and clears history.
6. **Shift+Tab** returns to text size and motion controls. Available text sizes are 100/125/150%; motion Off/Slow/Normal, default Off. Decorative player border changes only; factual text and the characters `# . : S T P` remain fixed.
7. Optional map-input path: activate “焦点转到网格” using native keyboard, press non-repeated WASD/arrows to move one passable tile, press **Escape** to release map focus. Map-focused controls must not steal focus from buttons.
8. Alt+Tab/native blur while a movement key is down: on return, movement remains gated until all movement keys are released. Do not assume that restoring window focus equals permission to move or to commit correction.

**Important limitations:** This is a proposed Godot-native focus design, not a verified assistive technology or platform compatibility report. No test was run. Exact behavior of OptionButton keyboard selection, key repeat, offscreen controls, window focus, Chinese glyph fallback and screen-reader announcements still require actual GUI/accessibility verification.
