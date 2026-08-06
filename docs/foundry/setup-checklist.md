# Foundry Setup and Transfer Checklist

## Status

This checklist is for the approved work environment. It does not assert that the required Foundry models, roles, connections, quotas or network routes are already available.

Do not paste credentials into Git, Markdown, Telegram or model prompts.

## 1. Confirm ownership and environment

- [ ] Confirm Azure tenant and subscription.
- [ ] Confirm the Microsoft Foundry hub/project or create an approved project.
- [ ] Record non-secret project name, region and owner in the deployment runbook.
- [ ] Confirm dev/test separation; do not begin in a production project.
- [ ] Confirm cost owner, quotas and budget alerts.
- [ ] Confirm data classification: initial corpus must be synthetic, public or explicitly approved.
- [ ] Confirm whether Application Insights/Foundry observability is approved.
- [ ] Confirm the developer has the documented `Azure AI Developer` role or equivalent and any required data-source roles.
- [ ] Confirm the application identity has only the least-privilege read roles needed by the tools.

Microsoft's current tool guidance lists a Foundry project, a model deployment in that project, the Azure AI Developer role/equivalent and required tool connections as prerequisites.

## 2. Choose the agent definition pattern

### Initial MVP — current decision

- [x] Use the two verified saved per-agent Responses endpoints for the first connection path.
- [ ] Export/reconcile each saved definition's exact prompt, tools, schema, model, ID and version with Git.
- [ ] Record prompt hashes and agent-definition versions.
- [ ] Treat Playground experiments as temporary until copied into Git.

The verified saved endpoint contract is:

```text
POST {FOUNDRY_*_AGENT_ENDPOINT}?api-version=2025-05-15-preview
model: gpt-5
```

Git-defined ephemeral agents remain a later option through the project endpoint. Record the route used on every comparison and never compare silently different definitions.

### Later option

- [ ] After evaluation passes, decide whether to save/publish versioned prompt agents or package the same code as hosted agents.
- [ ] Use stable published endpoints only after prompt/tool/model versions are controlled.

## 3. Deploy/select models

- [ ] Inventory models available in the chosen Foundry project/region.
- [ ] Confirm structured-output, tool-calling and required context-window support.
- [ ] Select the Manufacturing Agent model.
- [ ] Select at least one smaller candidate for HexaContext.
- [ ] Confirm rate limits and quotas for concurrent comparison runs.
- [ ] Record deployment names and approval status—never deployment keys.
- [ ] Verify content-filter configuration and version.

Environment variable names:

```bash
FOUNDRY_PROJECT_ENDPOINT=
FOUNDRY_MANUFACTURING_AGENT_ID=
FOUNDRY_MANUFACTURING_AGENT_ENDPOINT=
FOUNDRY_MANUFACTURING_MODEL=gpt-5
FOUNDRY_HEXACONTEXT_AGENT_ID=
FOUNDRY_HEXACONTEXT_AGENT_ENDPOINT=
FOUNDRY_HEXACONTEXT_MODEL=gpt-5
APPLICATIONINSIGHTS_CONNECTION_STRING=
```

`APPLICATIONINSIGHTS_CONNECTION_STRING` is sensitive configuration and must be stored in an approved secret/configuration system, not committed.

Do not hard-code exact model names until target-project availability is verified.

## 4. Local developer authentication

Preferred initial approach:

```bash
az login
az account show
```

Use `AzureCliCredential` or the current recommended Entra credential path from the official quickstart. Do not place access tokens in `.env` or source code.

- [ ] Verify the signed-in tenant/subscription.
- [ ] Verify project access with a harmless model listing/hello call.
- [ ] Verify the backend—not the browser—can reach the project endpoint.
- [ ] Record only success/failure, identity type and role scope; never log tokens.

For Azure-hosted deployment, prefer managed identity where supported and approved. Assign least-privilege RBAC at the narrowest practical scope.

## 5. Python packages

The current direct saved-agent foundation uses:

```bash
python3 -m pip install -r requirements.txt
```

- [x] Add `azure-identity` and `pydantic-settings` to project requirements.
- [x] Keep the HTTP transport fakeable so unit tests require no live secrets.
- [ ] Pin exact tested versions or generate a lock file if the work environment requires it.
- [ ] Generate/update a lock file if the work environment requires it.
- [ ] Run vulnerability/license checks required by the organization.
- [ ] Do not replace the current local mock path until the Foundry path passes tests.

## 6. Implement the shared tool gateway

- [x] Implement the seven [`tool-contracts.md`](tool-contracts.md) operations as security-invoker PostgreSQL functions plus a typed backend gateway.
- [x] Bind subject, snapshot and time server-side; derive tenant/scopes only from the approved user JWT.
- [x] Implement immutable snapshot/as-of behavior.
- [x] Implement hard result, relationship-depth and query-size limits.
- [x] Add source ID/version/timestamp/authority/content hash.
- [x] Distinguish successful no-match from source/system failure.
- [x] Exclude unauthorized data through RLS before model invocation.
- [x] Mark retrieved note text as untrusted evidence and preserve the prompt-injection test record as data.
- [x] Verify `anon` has no access and authenticated actors receive no write grants or policies.
- [ ] Provision approved Supabase Auth identities and exercise the gateway end to end with real short-lived user JWTs.
- [ ] Publish the narrow operations to the saved Foundry agents and implement the function-call execution loop.
- [ ] Use the same implementation for baseline and HexaContext arms.

Suggested initial physical layer:

```text
Supabase/PostgreSQL
  structured synthetic records
  source metadata
  immutable comparison snapshots
  evaluation/run records

Approved document/search layer
  versioned synthetic notes
  bounded search

Optional bounded graph projection
  only after relational baseline and graph lift are measured
```

The dedicated `hexacontext` Supabase project now contains the versioned runtime schema, 15 cases plus one shadow lot, RLS, full-text search and separately seeded private answer key from [`../supabase-synthetic-dataset-v1.md`](../supabase-synthetic-dataset-v1.md). The pre-tagged JSON `signals` were not copied into Supabase.

## 7. Implement the agents

### Manufacturing Agent

- [ ] Copy the exact system prompt from [`manufacturing-agent.md`](manufacturing-agent.md).
- [ ] Attach read-only tools in baseline mode.
- [ ] Set strict ManufacturingDecision schema.
- [ ] Configure `tool_choice` for baseline and enhanced conditions.
- [ ] Add deterministic citation, authorization and disposition validation.
- [ ] Confirm the same definition/model is used in both arms.

### HexaContext Agent

- [ ] Copy the exact system prompt from [`hexacontext-agent.md`](hexacontext-agent.md).
- [ ] Attach the same tool plane in hydrate mode.
- [ ] Set strict ContextPacket/RetrievalPlan schema.
- [ ] Enforce budgets outside the model.
- [ ] Validate every plan/packet.
- [ ] Prohibit manufacturing disposition fields.

Use structured runtime inputs for configuration values such as profile/mode where appropriate, but never treat prompt variables as authorization enforcement.

## 8. Implement comparison orchestration

- [ ] Add `POST /api/comparisons`.
- [ ] Pin actor, profile and immutable snapshot.
- [ ] Run baseline and context compilation independently.
- [ ] Pass validated ContextPacket into the same Manufacturing Agent.
- [ ] Disable broad tools in the enhanced Manufacturing call for the initial condition.
- [ ] Record full end-to-end latency for each arm.
- [ ] Preserve per-arm failures; no mock substitution.
- [ ] Store run controls and versions.

See [`orchestration-and-evaluation.md`](orchestration-and-evaluation.md).

## 9. Enable tracing and observability

- [ ] Connect the approved Foundry/Application Insights observability resource.
- [ ] Trace orchestrator, model calls, tool calls, validation and evaluation.
- [ ] Correlate spans with `comparison_run_id`.
- [ ] Record tool names/arguments after redaction, latency and result counts.
- [ ] Record model/deployment, agent/prompt/schema/tool/profile/snapshot versions.
- [ ] Record provider token usage where available.
- [ ] Do not log credentials, restricted evidence or hidden chain-of-thought.
- [ ] Define retention and access controls before non-synthetic data is considered.

## 10. Build evaluations

- [ ] Preserve the current 12-case set as smoke tests.
- [x] Separate local answer keys from runtime/public fixture data.
- [ ] Add deterministic evidence/citation/authorization/freshness/conflict evaluators.
- [ ] Use Foundry agent evaluators where available and approved.
- [ ] Label preview evaluators as non-release-authoritative.
- [ ] Add adversarial/tool-failure cases.
- [ ] Expand the release set with qualified manufacturing review.
- [ ] Define thresholds before inspecting final comparison results.
- [ ] Run evaluation in CI after Foundry connectivity is available, with secrets supplied by the approved CI secret store.

## 11. Model-selection test for HexaContext

For each approved smaller candidate:

- [ ] Run the identical held-out ContextRequest set.
- [ ] Measure required evidence recall.
- [ ] Measure tool selection/input accuracy.
- [ ] Measure false-complete packets.
- [ ] Verify zero authorization leakage.
- [ ] Measure conflict/freshness preservation.
- [ ] Measure schema validity, latency and total cost.
- [ ] Select only after thresholds are met.

The first MVP uses prompting. Fine-tuning begins only after approved, rights-cleared, reviewer-labeled trace data exists and a measured need remains.

## 12. UI update

- [ ] Replace the single retrieval-mode comparison as the primary experience with `Foundry Direct` vs `With HexaContext`.
- [ ] Retain exact/graph/search/hybrid as an Evaluation Lab/ablation view.
- [ ] Add request composer and HexaContext mode selector.
- [ ] Show source coverage, citations, missing/conflicting/stale evidence.
- [ ] Show tool timeline, context size, model/tool calls and end-to-end latency.
- [ ] Show provider/model/prompt/snapshot versions in an expandable trace section.
- [ ] Clearly label synthetic data and live vs mock mode.
- [ ] Never show hidden answer keys before a run is locked.

## 13. Security review before live demo

- [ ] No secrets in Git history.
- [ ] No credentials in browser bundles.
- [ ] All tools are read-only.
- [ ] Actor permissions enforced server-side.
- [ ] Unauthorized distractor test passes.
- [ ] Prompt-injection test passes.
- [ ] Error messages do not expose internal endpoints or stack traces.
- [ ] Logs/traces are redacted.
- [ ] Foundry connections and RBAC reviewed.
- [ ] Synthetic-only banner visible.
- [ ] Human authority boundary visible.

## 14. Git transfer checklist

Before pushing:

```bash
git status --short
git diff --check
python3 -m unittest discover -s tests -v
```

Also:

- [ ] Ensure `.env`, keys, tokens, connection strings and local database passwords are ignored.
- [ ] Scan tracked text for secret patterns.
- [ ] Confirm generated data is synthetic and intended for Git.
- [ ] Confirm all Markdown links resolve locally.
- [ ] Include the commit SHA in the work-computer handoff note.
- [ ] Do not commit organization-specific private endpoints unless approved.
- [ ] Do not push until Patrick reviews the target GitHub organization/repository visibility.

## 15. Live acceptance sequence

1. Health/configuration check.
2. One harmless Foundry call per model.
3. One tool call through authenticated backend.
4. Manufacturing Agent direct control case.
5. HexaContext ContextPacket generation.
6. Manufacturing Agent packet consumption.
7. One complete comparison run.
8. Trace verification.
9. Hidden-evaluator run.
10. Failure and authorization tests.
11. Stakeholder demo rehearsal.

## Open decisions before implementation

- Target Azure tenant/subscription/project and region.
- Exact available models/deployment names.
- Whether the initial tool backend uses Supabase/PostgreSQL, Azure AI Search or a local approved service.
- Whether hydrate or guide is the first HexaContext condition; recommendation: hydrate first, guide second.
- Approved manufacturing profile owner/evaluator.
- Data/log retention and access policy.
- GitHub destination and repository visibility.
- Whether prompt agents must also be created in the Foundry portal for stakeholder visibility.

## Official references

- [Foundry Agent Service overview](https://learn.microsoft.com/en-us/azure/foundry/agents/overview)
- [Responses API quickstart](https://learn.microsoft.com/en-us/azure/foundry/agents/quickstarts/responses-api)
- [Structured inputs](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/structured-inputs)
- [Tool best practices](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/tool-best-practice)
- [Development lifecycle](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/development-lifecycle)
- [Agent evaluators](https://learn.microsoft.com/en-us/azure/foundry/concepts/evaluation-evaluators/agent-evaluators)
