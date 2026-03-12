# Old EAS telemetry/logging findings

## Scope reviewed
- `Old EAS/EA1_MarketCore.mq5`
- `Old EAS/ISSX.mq5`
- `Old EAS/issx_runtime.mqh`

## Observed patterns
- Logging was mostly direct `Print(...)` and ad-hoc debug JSON status fields, not a centralized telemetry API.
- Timing was tracked with per-cycle elapsed counters (microsecond/tick-based deltas) and persisted into debug/status payloads.
- Error reporting was string-based (`last_error`, publish error fields, degraded reasons) and typically coupled to publish/debug objects.
- Runtime diagnostics were captured by writing aggregate debug snapshots (stage status + weak link reasons), rather than an in-memory ring buffer.
- Progress diagnostics existed as manual counters (hydration cursor/processed/total, publish attempts, queue/service counters) emitted in logs and debug payload fields.

## Useful patterns adopted
- Keep diagnostics lightweight and append-only from stage flow.
- Preserve explicit stage reason strings for forensic traceability.
- Preserve cycle-level elapsed timing and progress counters as first-class telemetry fields.

## Limitations in Old EAS
- No single authority module for checkpoints/events.
- No bounded in-memory recent-event ring with overwrite policy.
- Diagnostics tightly coupled to persistence/debug projection flows.
