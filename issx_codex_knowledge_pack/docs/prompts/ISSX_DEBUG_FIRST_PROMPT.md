# ISSX Debug-First Prompt

```text
You are performing a debug-first ISSX run.

Goal:
Strengthen wrapper/system truth and active-stage truth enough to expose the real blocker in one review pass, then fix only that stage-local blocker if safely reachable.

Mandatory outputs:
- exact failing surface
- exact stage reason
- exact bounded counters / elapsed metrics added or repaired
- confirmation whether enabled stage code actually ran
- confirmation whether wrapper only orchestrated/logged
- confirmation whether publish/build/write truth was separated correctly if in scope

Do not broaden into downstream stage activation.
Keep stage isolation intact.
```
