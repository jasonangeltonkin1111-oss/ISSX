# ISSX MQL5 API Verification Prompt

```text
Use the extracted MQL5 docs under knowledge/extracted_mql5_docs/ to verify every MT5/MQL5 API touched by this patch.

For each touched API, confirm:
- correct function name
- correct signature
- correct enum/type usage
- correct lifecycle constraints
- correct path/sandbox rules if file IO is involved
- correct chart-object usage if UI/HUD is involved

If local docs are missing for an API, state that coverage is degraded and avoid inventing behavior.
```
