# Full User E2E Contract

Run at least one complete operator mission on the exact release candidate through the actual OpenXDR KVM Installer whiptail workflow CLI/TUI.

1. Start the real entry point in a disposable or lab-safe environment.
2. Complete the primary read-only or DRY_RUN workflow from entry through result.
3. Verify prompts/help/output and any resulting state/log evidence match the documented behavior.
4. Exercise cancellation/exit safely where it is part of the user flow.
5. Record candidate SHA, environment, commands/menu path, outcome, and evidence.

Mock-only, import-only, syntax-only, or direct-function tests are not Full User E2E.

## Engineering System User Acceptance v2 — mandatory execution semantics

- **ChatGPT itself is the executor and final auditor.** ChatGPT directly assumes the applicable real User/Operator/Admin persona and performs complete missions through the actual supported public product surface. Coding agents, alternate models, wrappers, scripted scenario replays, CI jobs, and automated test harnesses are supplemental evidence only.
- Run **mission-first, black-box, and real-effect** E2E. The persona starts without source/test/manual answer-key knowledge, follows public discovery and user-visible guidance, performs the real supported state transition/action, and verifies the real user-visible outcome, traffic, persisted/effective state, rendered behavior, or external effect applicable to the product.
- Begin from a known clean or explicitly namespaced run state and bind evidence to the exact candidate. Previous-run state must not accidentally satisfy the new run.
- Exercise realistic mistakes and recovery where applicable: invalid/blank input, wrong context/role, cancellation/back, stale or duplicate references/actions, unavailable dependency, interruption/retry, and failure recovery. Recovery must be discoverable through the public product surface or bounded test-environment recovery, not hidden implementation knowledge.
- Repeat stateful/high-risk workflows across meaningful starting-state/order/retry/concurrency variants when one success could hide stale-state, idempotency, race, or recovery defects. Exercise concurrency, failure/recovery, and function-under-load when they are part of the product claim/risk surface; do not invent irrelevant load requirements.
- **A finding is not a stop condition.** Record it and continue every safe independent mission. Do not repair product/source/contract during the frozen run. After safe execution is exhausted, freeze findings, batch-remediate, and rerun invalidated Full User E2E from the beginning on the new candidate.
- For CLI products, ChatGPT directly uses the actual supported public CLI/TUI; parser/unit tests, direct internal APIs, and scripted replay cannot substitute.
- Retain machine-readable mission/findings ledgers and derive the summary from them. Release PASS requires 100% applicable mission/real-effect coverage, zero mandatory FAIL/PARTIAL/BLOCKED, zero unresolved blocking finding, and cleanup/orphan truth for run-owned state.
- The final clean Full User E2E and final clean Surface Reconciliation must bind to the **same exact HEAD**. If E2E remediation changes the public surface/contract, rerun Surface Reconciliation. Only after ChatGPT directly executes and finally audits both clean gates may the authoritative release Work Packet record terminal product-quality closure and freeze that exact HEAD as the candidate.
- If the product supports an AI-assisted public user path, rerun the same applicable mission from an equivalent starting state and require semantically equivalent supported outcome.
