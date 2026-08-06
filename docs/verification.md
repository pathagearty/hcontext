# Verification Report

> **Scope:** this report verifies the current deterministic local harness. It is not evidence that either planned Foundry agent has run. Live-agent verification must be added after the implementation in [`foundry/setup-checklist.md`](foundry/setup-checklist.md) succeeds.

## Automated checks

Executed from the repository root:

```bash
python3 data/generate.py
python3 -m compileall -q backend data tests
node --check frontend/app.js
python3 -m unittest discover -s tests -v
```

Results:

- synthetic generator wrote 12 cases successfully;
- Python syntax compilation passed;
- frontend JavaScript syntax check passed;
- 11 engine/API tests passed;
- no test warnings remain.

## Live server/API check

The FastAPI application was started on `127.0.0.1:8010` and queried over HTTP.

Observed health response:

- status: `ok`;
- dataset: `hexacontext-manufacturing-demo-v1`;
- synthetic: `true`;
- case count: `12`;
- mock provider: configured and locally exercised;
- Foundry: not configured, not live-tested;
- Bedrock: not configured, not live-tested.

Observed sample packet for `HX-LOT-1002` in hybrid mode:

- disposition: `HOLD`;
- authorized evidence sources: `6`;
- routes: exact lookup, bounded relationship traversal, document search and authorized evidence fusion;
- explanation source: deterministic mock.

## Live evaluation result

| Mode | Correct | Agreement | Critical false passes | Over-escalations |
|---|---:|---:|---:|---:|
| Exact | 7/12 | 58.33% | 0 | 2 |
| Graph + exact | 11/12 | 91.67% | 1 | 0 |
| Search + exact | 7/12 | 58.33% | 0 | 2 |
| Hybrid | 12/12 | 100% | 0 | 0 |

These are results on designed synthetic fixtures, not production performance claims.

## Browser functional/layout QA

Verified in a browser at a 1280×577 viewport:

- all navigation, thesis, workspace, evaluation, architecture and validity sections loaded;
- the 12-case inbox populated;
- selected-lot metadata populated correctly;
- the relationship SVG rendered with lot, supplier, part, equipment and policy nodes;
- authorized evidence cards populated;
- evaluation values matched the live API;
- a hybrid packet compiled in the UI and displayed its disposition, explanation, routes, seven checks and human action;
- page width had no horizontal overflow (`scrollWidth == clientWidth`);
- scenario and inbox descriptions intentionally use ellipsis with full text retained in the data/title where applicable;
- browser console reported no JavaScript errors.

The screenshot/vision helper timed out in the local browser environment, so visual QA was completed through browser rendering, accessibility snapshot, computed layout dimensions, populated DOM content and an actual UI compile interaction rather than an exported screenshot.

## Safety/failure checks

Verified:

- restricted synthetic evidence is absent from the detail UI/API;
- restricted evidence is excluded before policy/model use and the exclusion count is traced;
- an unconfigured Foundry request returns `503`;
- no mock/fixture fallback is substituted for a failed live provider;
- hybrid policy output matches every v1 answer-key case;
- mutable business facts are retrieved evidence, not model weights.

## Remaining verification gates

- live Azure Foundry endpoint/authentication/network/trace;
- live AWS Bedrock access/model/trace if required;
- evaluator approval of manufacturing rules and answer keys;
- one approved source-system adapter contract;
- production identity, tenant isolation, persistence, OPA and audit controls.
