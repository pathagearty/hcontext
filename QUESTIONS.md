# Open Questions

These questions do not block the local synthetic MVP unless marked **build gate**, but they do block stronger business or production claims.

## Business and workflow

1. **Build gate:** Who is the named workflow owner and primary reviewer for the first real HexaContext decision profile?
2. Is manufacturing lot disposition the preferred stakeholder demonstration, or only a neutral proving domain before a different profile is selected?
3. Which existing agent/workflow will call HexaContext first?
4. What is the current baseline: active-record lookup, manual multi-system investigation, RAG/search, an existing context service, or Workfabric?
5. Which failure is frequent and consequential enough to justify this layer: missed relationships, stale context, conflicting evidence, authorization risk, model cost, or review time?
6. Who would fund or own the additive layer: the agent platform team, quality/digital operations, an industry solution group, or a delivery engagement?
7. What demo decision will leadership make: `go`, `extend`, `merge`, `stop`, or `continue discovery`?

## Internal overlap and positioning

8. **Build gate:** What exact capability does Workfabric or another approved internal substrate already provide for identity, source connectors, graph, memory, policy and agent integration?
9. Is the reusable Hexaware asset intended to be the substrate itself, or the decision-profile compiler, policy/evaluation pack and integration pattern on top of that substrate?
10. Which existing AgentVerse/Sovereign AI Mesh/Foundry seam is missing today?
11. Are there reusable industry profiles already owned by another team?

## Manufacturing profile

12. **Build gate:** Which qualified manufacturing/quality evaluator will approve the rule semantics and golden cases?
13. Is the synthetic "three consecutive supplier failures → HOLD" rule representative, or should it be replaced before stakeholder demonstration?
14. What are the actual authoritative sources for inspection, supplier quality, PLM revision, equipment calibration and deviations?
15. What is the source-of-truth and freshness hierarchy when records conflict?
16. Which actions can be automated, and which require quality authority/signature?
17. Should a missing connected source always escalate, or are some criteria optional by part/site/risk class?

## Data, privacy and authorization

18. Which tenant, site, role, purpose-of-use and source permissions must be present in a real `ContextRequest`?
19. Should the system reveal that a restricted record exists while hiding its content, or reveal nothing about it?
20. What data-retention and audit requirements apply to requests, source excerpts, model explanations and reviewer corrections?
21. Can one approved sandbox or synthetic source-system contract be provided for the next phase?

## Foundry and AWS

22. **Integration gate:** Which Microsoft Foundry tenant/subscription/project, region and project endpoint are approved?
23. **Integration gate:** Which deployment will power the Manufacturing Agent, and which approved smaller deployments should be evaluated for the HexaContext Agent?
24. Does the selected model/runtime support the required strict structured output, custom/OpenAPI tools, tool-choice controls and tracing?
25. Must the two definitions remain Git-defined ephemeral agents for the MVP, or must versioned prompt agents also be created/published in the Foundry portal?
26. Which approved Entra developer identity and production managed identity/RBAC scopes should be used?
27. Which Application Insights/Foundry observability resource and retention policy are approved?
28. What latency, token, cost and tool-call budgets apply to each comparison arm?
29. **Integration gate:** Which AWS account/region, Bedrock model ID and role should be used if portability verification is required?
30. Is Bedrock a required live alternate for this internship, or an architecture-portability adapter only?

## Retrieval and persistence

31. Is a dedicated Supabase/PostgreSQL project approved for Sneha's PoC, and who owns provisioning/cost/region?
32. Which evaluator-approved queries need multi-hop graph traversal rather than indexed PostgreSQL joins/search?
33. Is FalkorDB an approved component for the target environment, or should the graph interface remain vendor-neutral?
34. Which semantic query classes, if any, justify embeddings/`pgvector`?
35. Which must-happen rules should be promoted from Python to OPA/Rego?
36. Is API-first/OpenAPI function integration sufficient, or does a target agent require MCP tool discovery?

## Learning and profile model

37. What exact task would a profile-specific smaller model perform better/cheaper than prompting a managed model?
38. What labeled data exists for that task, and who owns correction quality?
39. Which trace-derived patterns may propose profile changes, and who approves promotion?
40. What benchmark would justify fine-tuning rather than prompts, deterministic code or retrieval improvements?

## Demo logistics

41. What is Sneha's target internal demo date?
42. Is a neutral internal visual design acceptable, or should the UI follow a Hexaware/Tensai design system?
43. Who will attend, and is the primary audience business leadership, manufacturing SMEs, AI platform engineering, or all three?
44. Should the demo run only locally, or must it be packaged for a work laptop/container?
