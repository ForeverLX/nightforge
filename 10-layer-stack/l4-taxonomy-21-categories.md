# L4 Failure Taxonomy — 21-Category AgentEval Standard

**Date:** 2026-08-10
**Status:** Expanded from 6 → 21 categories
**Reference:** AgentEval/AHE research (2604.25850), Harness-Bench (2605.27922v1)

---

## Category Definition

| # | Category | Description | Detection Method | Data Source |
|---|----------|-------------|-----------------|-------------|
| 1 | **planning** | Planning loops, infinite retries, goal drift | Retry count > threshold, same tool called repeatedly | Session logs, tool call history |
| 2 | **reasoning** | Logical errors, incorrect deductions | Output contradiction analysis, LLM-as-judge | Agent output, model responses |
| 3 | **memory** | Context loss, memory corruption | State inconsistency detection, context mismatch | Session state, message history |
| 4 | **context_window** | Overflow, truncation, compression loss | Token count vs model limit, compression events | Token usage data, model config |
| 5 | **hallucination** | Fabricated facts, false tool results | Grounding verification, tool result validation | Tool outputs, agent claims |
| 6 | **tool_selection** | Wrong tool chosen, tool misuse | Tool-task fit analysis, tool call patterns | Tool call logs |
| 7 | **routing** | Wrong model/agent for task | Routing decision audit, model-task mismatch | Routing decisions, task outcomes |
| 8 | **rate_limit** | Provider throttling | HTTP 429 detection | API responses |
| 9 | **cost** | Budget overrun, unexpected spending | Cost tracking, per-task cost analysis | Cost data, budget config |
| 10 | **latency** | Timeout, slow response | Response time monitoring, p95 latency | Timing data |
| 11 | **security** | Injection, prompt leakage | Security scanning, input validation | Security tools, input logs |
| 12 | **authz_escalation** | Privilege escalation attempt | Permission boundary check | Permission logs |
| 13 | **deadlock** | Agent stuck, no progress | Progress monitoring, heartbeat detection | Session state, timestamps |
| 14 | **data_loss** | Information lost during processing | State comparison, information loss monitoring | Before/after state |
| 15 | **tool_error** | Tool execution failure | Exit code / error detection | Tool output, exit codes |
| 16 | **model_error** | Model API failure | HTTP status / error body | API responses |
| 17 | **config_error** | Configuration misparse | Schema validation | Config files |
| 18 | **workflow_error** | Process flow disruption | State machine monitoring | Workflow state |
| 19 | **auth_error** | Authentication failure | Credential validation | Auth responses |
| 20 | **resource_error** | OOM, disk full, VRAM exhaustion | System resource monitoring | System metrics |
| 21 | **timeout** | Network/tool/model timeout | Timeout detection | Timing data |

---

## Mapping: Old Categories → New

| Old Category | Mapped To | Notes |
|-------------|-----------|-------|
| tool_error | tool_error (#15) | Direct mapping |
| api_error | model_error (#16) | Renamed for consistency |
| timeout | timeout (#21) | Direct mapping |
| auth_error | auth_error (#19) | Direct mapping |
| stop_reason_error | workflow_error (#18) | Renamed, broader scope |
| unknown | unknown (filtered out) | No longer a category |

## New Categories (Need Additional Data Sources)

| Category | Current Data Support | Gap |
|----------|---------------------|-----|
| planning | Partial (retry counts from session logs) | Need loop detection logic |
| reasoning | None | Need LLM-as-judge integration |
| memory | None | Need state comparison |
| context_window | Partial (token usage in cost data) | Need token limit mapping |
| hallucination | None | Need grounding verification |
| tool_selection | None | Need tool-task fit analysis |
| routing | Partial (routing decisions logged) | Need outcome correlation |
| cost | Partial (cost data exists) | Need budget threshold alerts |
| latency | Partial (timing in session logs) | Need p95 monitoring |
| security | None | Need security scanner integration |
| authz_escalation | None | Need permission boundary checks |
| deadlock | Partial (heartbeat in session logs) | Need progress monitoring |
| data_loss | None | Need state comparison |
| resource_error | None | Need system resource monitoring |

---

## Priority Implementation Order

### P0 (Immediate — data available)
1. tool_error (#15) — already implemented
2. model_error (#16) — already implemented
3. timeout (#21) — already implemented
4. auth_error (#19) — already implemented
5. workflow_error (#18) — already implemented
6. rate_limit (#8) — add HTTP 429 detection
7. cost (#9) — add budget threshold alerts

### P1 (This week — partial data)
8. planning (#1) — add retry loop detection
9. context_window (#4) — add token limit monitoring
10. routing (#7) — add routing decision audit
11. latency (#10) — add p95 latency monitoring
12. deadlock (#13) — add progress monitoring

### P2 (Next week — needs new data sources)
13. tool_selection (#6) — add tool-task fit analysis
14. reasoning (#2) — add LLM-as-judge
15. memory (#3) — add state comparison
16. hallucination (#5) — add grounding verification
17. security (#11) — add security scanner integration
18. authz_escalation (#12) — add permission checks
19. data_loss (#14) — add state comparison
20. resource_error (#20) — add system resource monitoring
