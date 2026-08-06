# Stakeholder Demo Script

> **Demo status:** the primary UI is a deterministic local comparison preview. It is visibly labeled `SIMULATED_LOCAL`; it does not invoke the saved Foundry agents or claim actual billed cost. Use it to validate the evaluation experience and metric contract before live integration.

Target length: **5–7 minutes**.

## 1. Frame the question — 45 seconds

Open the app and lead with the question shown in the hero:

> Does HexaContext improve evidence and decision quality enough to justify its extra work?

Point out the local-preview banner. The product is designed to show a negative, neutral or positive result honestly—not to make HexaContext look better by default.

## 2. Freeze the comparison controls — 45 seconds

Show the selected manufacturing lot, actor, immutable snapshot and Decision Profile. Explain that the backend owns these controls and runs the same request, permissions, evidence snapshot and Manufacturing decision rules in both arms.

The browser exposes neutral lot labels before scoring and does not receive the private scenario label or expected answer.

## 3. Run the comparison — 90 seconds

Leave `Manufacturing lot 009` selected and click **Run comparison**.

Walk through the pipeline:

```text
Foundry Direct contract preview
  -> Manufacturing reasoning

With HexaContext contract preview
  -> context compilation
  -> ContextPacket
  -> the same Manufacturing reasoning
```

Then lead with the run conclusion. In the current local preview, both arms make the same correct decision and find the same evidence, while the enhanced path uses one additional model call and more tokens/latency.

That is an intentional, useful result: the UI does not manufacture a HexaContext advantage.

## 4. Show what each path did — 90 seconds

Use the **What each path did** section as the basic product demo before discussing scores.

On the direct side, explain that the Manufacturing Agent owns both jobs: it receives the controlled request, gathers authorized evidence through the approved tool contracts, applies the readiness profile and returns a decision with citations.

On the enhanced side, explain the division of responsibility: HexaContext gathers, checks and packages the evidence into a typed `ContextPacket`; the same Manufacturing Agent then owns the manufacturing decision.

Point to the live record/tool counts, evidence classes, packet completeness, findings, decision and citation count. Close with the boundary shown beneath the lanes:

- what changed is the additional context-compilation and packet handoff;
- what stayed fixed is the request, actor, permissions, snapshot, tools, profile, business rules and Manufacturing Agent contract.

## 5. Inspect quality and overhead — 90 seconds

Compare the two equal-weight result cards:

- decision and hidden-answer correctness;
- required-evidence coverage and valid citations;
- missing, stale and conflicting evidence;
- model calls, tool calls, tokens and end-to-end latency;
- the HexaContext `ContextPacket` summary;
- expandable evidence, tool timeline and technical metrics.

Point out that enhanced totals include both HexaContext compilation and downstream Manufacturing reasoning. Cost is shown as **Unavailable** because no approved versioned model rates are configured; the app does not invent a per-query Supabase cost.

## 6. Show a missing-evidence case — 60 seconds

Select `Manufacturing lot 011` and click **Run comparison**.

Both arms should `ESCALATE`, identify `Supplier Part Family History` as missing, and match the private expected disposition. The result demonstrates that absence remains unknown rather than being converted into a pass.

## 7. Review the hidden evaluator — 45 seconds

Show that scoring appears only after both arm results exist. It checks:

- correct disposition and critical false PASS;
- required-evidence recall and citation validity;
- missing, stale and conflict detection;
- restricted and cross-tenant leakage.

For a future free-form request without an answer key, the correct state is `Not automatically scored — human review required`; the app must never fabricate correctness.

## 8. Read the 15-case aggregate — 60 seconds

Scroll to **All 15 controlled cases**. The current local preview reports equal designed-case quality and higher enhanced-path overhead. This is the decision-useful takeaway from the implemented preview, not a failure of the demo.

State the claim boundary clearly:

> These are deterministic executions against designed synthetic data. A live Foundry comparison is required before claiming model-quality lift, production accuracy, customer ROI or actual per-run billed cost.

## 9. Close with the next validation gate — 30 seconds

The next step is deliberately narrow: on the approved Foundry-connected computer, connect both saved agents to the same read-only Supabase tool plane, replace simulated usage with provider-reported usage and backend timing, and reconcile estimated model cost with Azure billing later.

## Anticipated questions

### Why does HexaContext not win in this preview?

Both arms receive the same complete authorized evidence. Giving the baseline less data would invalidate the comparison. HexaContext must earn a measurable advantage during live agent execution through better planning, selection, validation or packaging.

### Are the token and latency numbers real?

They are deterministic preview estimates and are labeled that way. The live path will sum provider usage across every Foundry continuation and measure each model/tool stage in the backend.

### Is estimated model cost the Azure bill?

No. Standard token pricing can support an immediate estimate after approved rates are configured. Azure Cost Management remains the delayed billing source of truth, and capacity-based deployments may not have a meaningful per-run token cost.

### Why is there no Supabase query cost?

One small query does not have a defensible exact project cost. The UI reports tool-call count, returned records, latency, errors and authorization exclusions; database infrastructure cost remains separate.

### Does `PASS` release a lot?

No. It means ready for authorized human review. A qualified reviewer retains release, rejection, deviation and remediation authority.
