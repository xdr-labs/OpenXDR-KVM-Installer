# Installer Safety and Compatibility Invariants

These are product rules independent of any AI provider or editor.

## Stability and execution
- Treat STEP identity/order, defaults, UI/log semantics, state paths, and config keys as compatibility contracts.
- Changes must be minimal and behavior-preserving unless the owner explicitly revises the contract.
- Preserve strict shell execution, re-runnability, and the existing DONE/FAILED/CANCELED meanings.
- Auto execution resumes through the existing state model and stops on failure or cancellation.
- Cancel/ESC is user cancellation, not failure, and must not incorrectly advance completion state.

## Destructive safety
- DRY_RUN=1 must never perform destructive or system-changing commands.
- Provisioning/destructive STEPs require a clear impact summary and explicit user confirmation.
- Full Configuration Validation is read-only; blocking FAIL results prevent deployment.
- State/config files are long-term compatibility surfaces; do not silently rename/restructure them.

## Network, image, and UX boundaries
- Host-management addresses and VM-internal NAT addresses remain distinct.
- DP, Sensor, and AIO topology assumptions remain installer-specific.
- Image acquisition and image consumption STEPs remain separated; deployment must not silently change an earlier image-source decision.
- Preserve whiptail menu semantics, STEP navigation, cancellation behavior, operator-focused English output, and uniform log/result conventions.
- Any behavior change must identify affected STEPs and evidence backward compatibility.
