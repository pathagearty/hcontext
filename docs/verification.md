# Verification Report

> **Scope:** this report verifies the deterministic harness, the local two-arm comparison preview, the offline Foundry client/configuration foundation, and the local plus deployed Supabase source/tool substrate. It is not evidence that either saved Foundry agent has run from this computer. Live-agent verification must be performed on the Foundry-connected computer using [`foundry/cross-computer-implementation-handoff.md`](foundry/cross-computer-implementation-handoff.md).

## Automated checks

Executed from the repository root:

```bash
python3 data/generate.py
python3 data/generate_supabase_v1.py
python3 -m compileall -q backend data scripts tests
node --check frontend/app.js
python3 -m unittest discover -s tests -v
supabase db reset --local
supabase test db supabase/tests/dataset_v1_test.sql --local
supabase test db supabase/tests/dataset_v1_test.sql --linked
supabase db lint --local --level warning
supabase db advisors --linked --type all --level warn
```

Results:

- synthetic generator wrote 12 runtime-safe cases and a separate evaluator-only answer-key fixture;
- Python syntax compilation passed;
- frontend JavaScript syntax check passed;
- 57 engine, API, UI-contract, comparison, telemetry, pricing, settings, Foundry-client, Supabase-generator and Supabase-gateway tests passed;
- one upstream Starlette `TestClient` deprecation warning is emitted under the local Python 3.14 environment; it does not affect the test result.

## Local comparison preview verification

The primary browser experience now runs one synchronous, deterministic comparison through:

```text
same server-owned request, actor, profile and snapshot
  -> Foundry Direct contract preview
  -> HexaContext compile + Manufacturing contract preview
  -> private evaluator after both results exist
  -> side-by-side result and aggregate Evaluation Lab
```

Verified through the API and UI:

- all 15 neutral case labels are available without scenario or expected-answer labels;
- `POST /api/comparisons` returns a completed run and `GET /api/comparisons/{id}` retrieves it;
- the browser cannot choose actor, tenant, scopes, models, snapshot or hidden expected outcomes;
- both arms receive the same authorized runtime evidence;
- the enhanced total includes HexaContext compilation plus Manufacturing reasoning;
- missing, stale and conflicting evidence cases render and score correctly;
- input, output and total usage normalize without converting missing values to zero;
- the deliberately unconfigured pricing catalog produces `Unavailable`, not an invented price;
- restricted and cross-tenant records do not appear in arm results or the DOM;
- aggregate execution completed 15/15 paired cases with 15/15 correct dispositions in both arms, zero critical false passes and zero unauthorized leakage;
- aggregate preview usage was 2,568 direct tokens versus 5,341 enhanced-path tokens, with 15 versus 30 model calls and the same 105 tool calls;
- median simulated end-to-end latency was 41 ms direct versus 54 ms enhanced;
- the UI explicitly labels execution `SIMULATED_LOCAL` and labels token/latency values as simulated estimates;
- the local banner states that neither Foundry nor the remote Supabase Data API is invoked in preview mode;
- desktop/laptop browser checks completed without console errors, page errors, overlap or clipping;
- selecting another case and clicking **Run comparison** updated the decision, evidence gaps and telemetry.
- the result includes a per-path walkthrough that distinguishes Manufacturing-owned retrieval/decision work from HexaContext compilation, ContextPacket handoff and the same Manufacturing decision contract.

This local result demonstrates the comparison contract and presentation, not a HexaContext model-performance benefit. Because both arms receive the same complete authorized evidence, the current preview honestly reports equal measured designed-case quality and higher enhanced-path overhead.

## Supabase source/tool verification

The fixed v1 generator produced:

- snapshot: `hx-mfg-v1-snapshot-001` at `2026-08-01T12:00:00Z`;
- manifest: `4a69bc05efbb8e72d2f0e98d3417324f49c9be3c98ef42818c73efeff1a8a3d9`;
- runtime: 179 rows, including 15 primary lots and one cross-tenant shadow lot;
- hidden evaluator: 124 rows, including 15 case expectations and 109 expected-evidence rows;
- distribution: 4 `PASS`, 5 `HOLD`, 6 `ESCALATE`.

Verified locally from a clean database reset and again against the linked remote project:

- all four migration versions match local and remote history;
- zero prohibited answer-bearing runtime columns;
- all 15 exposed runtime tables have forced RLS;
- `anon` has no runtime-table or RPC access;
- `private_eval` has no `anon`/`authenticated` schema or table grants;
- alpha quality/general claims see 15 lots and two authorized notes;
- the same alpha claims cannot see the restricted HR note or beta shadow records;
- elevated alpha claims including `restricted_hr` see all three alpha notes;
- beta claims see only one lot and its failed inspection;
- putting beta/scopes in `user_metadata` does not override alpha `app_metadata`;
- missing supplier history, stale-window history and closed-deviation checks return successful zero-item results;
- case 10 returns both simultaneously active revisions;
- cases 09 and 15 return their authorized narrative conflicts through subject-bounded full-text search;
- all seven read-only operations return the expected remote happy-path result counts;
- Supabase schema lint and linked security/performance advisors report no issues.

The backend gateway tests verify that the subject lot, snapshot and pinned time are server-owned, actor tenant/scopes are absent from tool arguments, the publishable key is paired with the approved user bearer token, the service/secret key is rejected as an evidence identity, and source failures are not converted into missing evidence. A real approved Supabase Auth user JWT has not yet been provisioned; remote RLS verification used the actual `authenticated` role with the intended JWT claim shape.

The Foundry client suite verifies:

- repository-root `.env.local` loading with environment override precedence;
- matching HTTPS agent ID/endpoint/model configuration;
- query-string-safe `api-version` replacement;
- runtime bearer authentication without stored tokens;
- strict JSON Schema request construction;
- no retry for `400`/`401`;
- bounded, recorded retry for `429` and transient `5xx` responses;
- typed/redacted token, HTTP and response-protocol failures;
- log summaries that omit prompts, evidence, outputs and credentials.

## Live server/API check

The FastAPI application was started on `127.0.0.1:8010` and queried over HTTP.

Observed health response:

- status: `ok`;
- dataset: `hexacontext-manufacturing-demo-v1`;
- synthetic: `true`;
- case count: `12`;
- mock provider: configured and locally exercised;
- saved-agent Foundry configuration: disabled locally, not live-tested on this computer;
- comparison preview: available as `SIMULATED_LOCAL`, with Foundry live execution false;
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
- expected dispositions are absent from the runtime fixture and public APIs;
- answer keys are read only by evaluator code from a separate fixture;
- an unconfigured Foundry request returns `503`;
- no mock/fixture fallback is substituted for a failed live provider;
- hybrid policy output matches every v1 answer-key case;
- mutable business facts are retrieved evidence, not model weights.

## Remaining verification gates

- sanitized live saved-agent smoke test on the Foundry-connected computer;
- saved prompt/tool/schema/model/agent-version equivalence check;
- live Azure Foundry endpoint/authentication/network/tool/trace behavior;
- live AWS Bedrock access/model/trace if required;
- evaluator approval of manufacturing rules and answer keys;
- approved Supabase Auth demo identities and an end-to-end user-JWT Data API gateway test;
- Foundry function-call execution over the seven implemented Supabase operations;
- provider-reported token and live backend latency reconciliation in both comparison arms;
- approved versioned model pricing, or an explicit capacity-billing policy that keeps per-run cost unavailable;
- durable, actor-authorized comparison history if the preview becomes a shared multi-user tool;
- production identity, tenant isolation, persistence, OPA and audit controls.
