# Cross-Computer Foundry Implementation Handoff

## Purpose

This is the operating handoff for continuing HexaContext when code can be edited on this computer but the private Microsoft Foundry endpoints can be reached only from the other computer. It distinguishes verified external facts, repository-tested behavior and work that still needs live validation.

Read this first, followed by:

1. [`../handoff-context-packet.md`](../handoff-context-packet.md)
2. [`../supabase-synthetic-dataset-v1.md`](../supabase-synthetic-dataset-v1.md)
3. [`implementation-agent-prompt-evaluation-ui.md`](implementation-agent-prompt-evaluation-ui.md)
4. [`README.md`](README.md)
5. [`manufacturing-agent.md`](manufacturing-agent.md)
6. [`hexacontext-agent.md`](hexacontext-agent.md)
7. [`tool-contracts.md`](tool-contracts.md)
8. [`orchestration-and-evaluation.md`](orchestration-and-evaluation.md)

## Product boundary

HexaContext is an additive context and assurance layer. For a task-specific Decision Profile, it supplies a downstream Manufacturing Readiness Agent with minimum sufficient, authorized, current and source-backed evidence.

The Manufacturing Agent may recommend `PASS`, `HOLD` or `ESCALATE` for human review. HexaContext must not make that recommendation. A qualified human retains release, rejection, deviation and remediation authority.

## Verified on the Foundry-connected computer

As of 2026-08-06:

| Item | Verified result |
|---|---|
| Azure CLI identity | Signed in to the approved tenant/subscription |
| Token audience | `az account get-access-token --resource https://ai.azure.com` succeeded |
| Manufacturing saved-agent endpoint | Returned HTTP 200 and a response ID |
| HexaContext saved-agent endpoint | Returned HTTP 200 and a response ID |
| Endpoint shape | Distinct per-agent `/responses` endpoints embedding their matching agent IDs |
| Required query parameter | `api-version=2025-05-15-preview` |
| Required saved-agent model | `gpt-5` for both existing endpoints |

A 20-token response ending as `incomplete` proved invocation only. It did not validate structured output, tools, policy behavior or comparison quality.

Do not use `gpt-5.6-luna` with these endpoints. A different model requires deliberately creating/versioning both agent definitions and re-running the connection and evaluation gates as a new experimental condition.

## Implemented and tested in this repository

The original deterministic harness remains intact. The following cross-computer foundation is now implemented:

- `.env.local` is ignored by Git and explicitly loaded from the repository root;
- environment variables override `.env.local` for Azure deployment;
- both agent ID/endpoint/model triples are validated before a live client can be constructed;
- endpoint validation requires HTTPS, a `/responses` path and a matching embedded agent ID;
- `api-version` is added/replaced without discarding other endpoint query parameters;
- Azure CLI authentication is used locally and managed identity can be selected in Azure;
- bearer tokens are acquired at runtime for `https://ai.azure.com/.default` and are never stored in configuration;
- the direct Responses client supports optional strict JSON Schema output and tool payloads;
- only `429`, `500`, `502`, `503`, `504` and transport failures receive bounded retries;
- errors omit provider response content and credentials; log helpers exclude prompts, evidence, outputs and secrets;
- response ID, status, usage, timing, attempt count and retry metadata are returned as typed metadata;
- `/api/health` reports configuration booleans/issues without invoking Foundry or exposing configured values;
- expected dispositions are stored in a separate evaluator-only fixture and are absent from runtime lot models and APIs.
- the normalized Supabase v1 schema, private evaluator schema, RLS/indexes and seven read-only RPC operations are versioned as four migrations;
- deterministic generation produces 179 runtime rows and 124 hidden evaluator rows across 15 primary cases plus one cross-tenant shadow lot;
- runtime and evaluator seeds are separate, and the deployed snapshot is pinned as `hx-mfg-v1-snapshot-001` at `2026-08-01T12:00:00Z`;
- v1 remains the immutable control snapshot; the primary live dataset is now `hx-mfg-v2-snapshot-001` at the same pinned time;
- v2 adds 2,000 lots and 40,295 normalized runtime rows across work orders, operations, equipment usage, BOMs, component consumption, material certificates and engineering changes;
- all 50 v2 Alpha cases have approved private expected results, path-aware evidence rubrics and an 8 `PASS` / 16 `HOLD` / 26 `ESCALATE` distribution;
- eight additional subject-bound RPCs expose multi-hop evidence without arbitrary SQL, bringing the runtime tool plane to 15 operations;
- a service-role-only evaluator RPC and private run ledger support UI scoring, trace review and fine-tuning curation without granting either agent answer-key access;
- the deployed database measured 58 MB after v2 seeding and fits comfortably within the current 500 MB Supabase Free database allowance;
- every exposed runtime table has forced RLS, `anon` has no read/execute access and `private_eval` has no `anon`/`authenticated` grants;
- tenant/scopes come only from signed `app_metadata`; remote tests confirmed alpha/beta isolation, restricted-scope exclusion and no `user_metadata` override;
- native note full-text search and all seven read-only database operations were exercised against the linked Supabase project;
- `backend/supabase_gateway.py` preserves the approved user JWT, binds the subject/snapshot/time server-side and rejects the service/secret key as an evidence-query identity;
- a clean local `supabase db reset`, 61 repository tests, both database test suites, schema lint, remote schema diff and remote database advisors all pass.

This is still not a live three-agent comparison. The source/tool and saved-endpoint foundations exist, but they are not yet connected to a Foundry function-call loop. A real approved Supabase Auth user JWT must also be provisioned and exercised through the remote Data API before claiming full browser/backend/Auth/RLS integration. A local deterministic comparison API and Decision Packet contract now exist; live packet validation and Foundry orchestration do not. Read [`../handoff-context-packet.md`](../handoff-context-packet.md) for the controlling current architecture and implementation plan.

## Local configuration

On each computer:

```text
copy .env.example to .env.local
populate only through the approved local secret/configuration process
never commit .env.local
```

Required for the verified saved-agent route:

```dotenv
FOUNDRY_ENABLED=true
FOUNDRY_API_VERSION=2025-05-15-preview
FOUNDRY_PROJECT_ENDPOINT=
FOUNDRY_MANUFACTURING_AGENT_ID=
FOUNDRY_MANUFACTURING_AGENT_ENDPOINT=
FOUNDRY_MANUFACTURING_MODEL=gpt-5
FOUNDRY_HEXACONTEXT_AGENT_ID=
FOUNDRY_HEXACONTEXT_AGENT_ENDPOINT=
FOUNDRY_HEXACONTEXT_MODEL=gpt-5
FOUNDRY_AUTH_MODE=auto
```

`FOUNDRY_AUTH_MODE=auto` selects Azure CLI on a normal developer computer and managed identity when common Azure identity environment markers are present. Set it explicitly to `azure_cli` or `managed_identity` if the host cannot be detected. A user-assigned identity can be selected with `FOUNDRY_MANAGED_IDENTITY_CLIENT_ID`.

Never store a bearer token in this file. Never send `SUPABASE_SECRET_KEY`, Application Insights connection strings, database keys, bearer tokens or private endpoint values to browser code, prompts, tool outputs, logs or Git.

The Supabase configuration additionally uses:

```dotenv
SUPABASE_PROJECT_REF=
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SECRET_KEY=
SUPABASE_JWKS_URL=
SUPABASE_SNAPSHOT_ID=hx-mfg-v2-snapshot-001
SUPABASE_AS_OF_TIME=2026-08-01T12:00:00Z
EVALUATOR_UI_TOKEN=
```

`SUPABASE_SECRET_KEY` is limited to migrations, trusted seeding and evaluator/admin work. Normal evidence queries use the publishable key plus an approved user access token whose `app_metadata` contains the tenant and scopes. Neither key enters Foundry or browser code.

`EVALUATOR_UI_TOKEN` is a separate operator credential for the post-run rubric endpoint. Do not embed it in a browser bundle or give it to either agent. See [`../supabase-context-benchmark-v2.md`](../supabase-context-benchmark-v2.md) for the complete scoring-plane boundary and v2 verification instructions.

## Safe live smoke test on the other computer

After installing the repository requirements and completing `az login`, run from the repository root:

```powershell
python -m scripts.foundry_smoke
```

The script invokes both configured roles and prints only sanitized status metadata. The request:

1. acquire a token for `https://ai.azure.com`;
2. call each saved endpoint with its own matching model;
3. retain existing endpoint query parameters while setting the configured API version;
4. use a normal output budget such as 1800 for structured-output evaluation;
5. report only HTTP status, response-ID presence, run status, timing and retry count.

Do not print the URL, token, request headers, response content, restricted tool output or hidden reasoning.

A successful response proves only reachability, authentication and execution. Locking an agent for evaluation additionally requires prompt/tool/schema/version equivalence and valid outputs.

## Two-computer development loop

Use this computer as the source of truth for code and tests:

1. make small changes here;
2. run all offline tests with fake Foundry transports;
3. commit/push only through the approved repository process;
4. pull the exact commit on the Foundry-connected computer;
5. run the narrow live smoke check there;
6. return only sanitized observations: commit SHA, agent role, HTTP status, response-ID presence, status, error code, timing and retry count;
7. reproduce any failure with a fake transport test here before changing production code.

Do not transfer source patches manually from the Foundry-connected computer unless unavoidable. Prefer recording a failing contract as sanitized input/output metadata, then implementing and testing it here.

## Next implementation order

1. Pull this exact repository state onto the Foundry-connected computer and regenerate the Supabase artifacts to confirm the manifest hash.
2. Confirm the saved agent definitions exactly match the Git prompts, schemas, tools and `gpt-5` model configuration.
3. Provision approved short-lived Supabase Auth demo identities with tenant/scopes in `app_metadata`, then live-test the backend gateway through the Data API; never substitute the secret key.
4. Define the remaining comparison/request and ContextPacket runtime Pydantic schemas.
5. Determine whether saved agents already contain the seven tool definitions; otherwise implement the Responses function-call execution loop over `SupabaseToolGateway`.
6. Implement and validate the direct Manufacturing baseline.
7. Implement HexaContext hydrate, validate the ContextPacket, then call the unchanged Manufacturing Agent with broad tools disabled.
8. Run the hidden evaluator through a trusted server/admin path that is separate from both agents.
9. Add fair comparison persistence/API, side-by-side UI and tracing.
10. Remove legacy Azure explanation/Bedrock adapters only after the live comparison path is covered.

## Non-negotiable comparison controls

Every recorded comparison locks the normalized task, lot, actor/scopes, immutable snapshot, as-of time, profile/version, Manufacturing model/agent/prompt/schema, tool contract/implementation, timeout/retries and evaluation-set version.

No requested live run may fall back to mock output. Preserve one-arm failures visibly.

Initial release gates include:

```text
unauthorized evidence leakage: 0
critical false PASS: 0
schema validity after normal retries: 100%
citation IDs within allowed evidence: 100%
false COMPLETE packets with missing mandatory evidence: 0
required evidence-class recall: >= 95%
tool argument/schema validity: >= 99%
explicit injected system/tool failures: 100%
```

Also run a deterministic profile-planner ablation. If deterministic planning matches the HexaContext agent, prefer the simpler implementation.

## Open decisions

- Are the two saved agents already configured with the exact shared custom tools?
- What saved agent version corresponds to each endpoint?
- Who owns and provisions the approved Supabase Auth demo identities and token-refresh path?
- Who approves the manufacturing Decision Profile and hidden answer keys?
- Which App Insights resource, retention window and access controls are approved?
- When, if ever, should the experiment switch from saved endpoints to Git-defined ephemeral agents?
