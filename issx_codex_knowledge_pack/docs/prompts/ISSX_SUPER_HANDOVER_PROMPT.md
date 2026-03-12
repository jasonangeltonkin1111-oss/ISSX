# ISSX Super Handover Prompt

```text
We are continuing work on ISSX, a modular MetaTrader 5 / MQL5 system.

Start by reading:
- AGENTS.md
- docs/ISSX_FOUNDATION_TASK_BOARD_v1.4.md
- docs/ISSX_CODEX_OPERATING_RULES.md
- docs/ISSX_MANUAL_CHECKLIST.md
- docs/prompts/ISSX_MQL5_API_VERIFICATION_PROMPT.md

Use the local documentation here:
- knowledge/extracted_mql5_docs/
- knowledge/raw/mql5.chm

Mission:
Get the ISSX foundation pipeline working truthfully and safely using the board's exact priority order.

Current board status summary:
- EA1 cadence = done
- EA1 determinism = done
- EA1 super-debug = done
- EA1 publish/projection truth = wip
- EA1 HUD truth = wip
- EA1 foundation-proven = wip
- EA2 onward = pending

Working rules:
- one main task only
- one active stage focus only
- no architecture redesign
- no speculative cleanup
- wrapper orchestrates/logs only
- stage engines own business logic
- persistence owns writes
- HUD is read-only projection only
- version bump +1 on successful task and sync all versioned files

When you respond, first identify:
1. current best next task
2. primary files to inspect
3. related modules required
4. likely failure modes
5. exact success criteria from the board

Then perform the task and report using the required headings.
```
