const $ = (selector) => document.querySelector(selector);

const state = {
  health: null,
  cases: [],
  comparison: null,
  summary: null,
};

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  if (!response.ok) {
    let detail = `Request failed (${response.status})`;
    try {
      const payload = await response.json();
      detail = payload.detail || detail;
    } catch (_) {
      // Preserve the safe generic error.
    }
    throw new Error(detail);
  }
  return response.json();
}

function humanize(value) {
  return String(value || "")
    .replaceAll("_", " ")
    .replaceAll(".", " › ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function signed(value, suffix = "") {
  if (value === null || value === undefined) return "Unavailable";
  const number = Number(value);
  return `${number > 0 ? "+" : ""}${number.toLocaleString()}${suffix}`;
}

function costLabel(cost) {
  if (cost.availability !== "AVAILABLE" || cost.amount === null) {
    return { value: "Unavailable", detail: cost.reason || "Pricing not configured" };
  }
  return {
    value: `${escapeHtml(cost.currency)} ${Number(cost.amount).toFixed(6)}`,
    detail: "Estimated variable model cost",
  };
}

function setModeBanner() {
  const comparison = state.health.comparison;
  const banner = $("#mode-banner");
  if (comparison.execution_mode === "SIMULATED_LOCAL") {
    banner.className = "mode-banner simulation";
    banner.innerHTML = `<strong>Local comparison preview</strong><span>${escapeHtml(comparison.note)} Token and latency values below are visibly marked as simulated estimates.</span>`;
  } else {
    banner.className = "mode-banner live";
    banner.innerHTML = "<strong>Live Foundry comparison</strong><span>Provider telemetry is being captured by the application backend.</span>";
  }
}

function renderDeltaGrid(result) {
  const evalDelta = result.deltas.required_evidence_found;
  const cost = result.deltas.estimated_model_cost;
  const cards = [
    ["Total tokens", signed(result.deltas.total_tokens), "Combined compiler + Manufacturing usage"],
    ["Model calls", signed(result.deltas.model_calls), "All continuation calls must be included live"],
    ["Tool calls", signed(result.deltas.tool_calls), "Same approved read-only tool plane"],
    ["End-to-end latency", signed(result.deltas.end_to_end_ms, " ms"), "Enhanced compile through validated decision"],
    ["Expected evidence", signed(evalDelta), "Additional expected source records found"],
    ["Valid citations", signed(result.deltas.valid_citations), "Additional resolvable authorized citations"],
    ["Estimated model cost", cost === null ? "Unavailable" : signed(Number(cost).toFixed(6)), "Deployment pricing is not configured"],
  ];
  $("#delta-grid").innerHTML = cards.map(([label, value, detail]) => `
    <article class="delta-card">
      <span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong><small>${escapeHtml(detail)}</small>
    </article>
  `).join("");
}

function stageBreakdown(arm) {
  const maxTokens = Math.max(...arm.metrics.stages.map((stage) => stage.total_tokens || 0), 1);
  return arm.metrics.stages.map((stage, index) => {
    const width = Math.max(6, Math.round(((stage.total_tokens || 0) / maxTokens) * 100));
    return `
      <div class="stage-row">
        <div><span class="stage-color stage-${index + 1}"></span><strong>${escapeHtml(stage.label)}</strong><small>${stage.model_calls} model · ${stage.tool_calls} tools</small></div>
        <div class="stage-bar"><span class="stage-${index + 1}" style="width:${width}%"></span></div>
        <b>${stage.total_tokens === null ? "—" : stage.total_tokens.toLocaleString()} tok</b>
      </div>
    `;
  }).join("");
}

function findingsBlock(findings) {
  const groups = [
    ["Missing", findings.missing],
    ["Stale", findings.stale],
    ["Conflicts", findings.conflicts],
  ];
  return groups.map(([label, items]) => `
    <div class="finding-group ${items.length ? "has-finding" : "clear"}">
      <span>${escapeHtml(label)}</span>
      ${items.length
        ? items.map((item) => `<p>${escapeHtml(humanize(item))}</p>`).join("")
        : "<p>None detected</p>"}
    </div>
  `).join("");
}

function evidenceList(arm) {
  return arm.evidence.map((item) => `
    <li>
      <span class="evidence-class">${escapeHtml(humanize(item.evidence_class))}</span>
      <div><strong>${escapeHtml(item.title)}</strong><small>${escapeHtml(item.source_record_id)} · ${escapeHtml(humanize(item.authority))}</small></div>
    </li>
  `).join("");
}

function timeline(arm) {
  return arm.tool_timeline.map((item) => `
    <li>
      <span class="timeline-order">${item.order}</span>
      <div><strong>${escapeHtml(humanize(item.tool_name))}</strong><small>${escapeHtml(humanize(item.stage))}</small></div>
      <span class="tool-status ${item.status.toLowerCase()}">${escapeHtml(humanize(item.status))}</span>
      <b>${item.returned_count} rec · ${item.elapsed_ms} ms</b>
    </li>
  `).join("");
}

function contextPacket(packet) {
  if (!packet) return "";
  return `
    <section class="packet-summary-card">
      <div><span>ContextPacket</span><strong>${escapeHtml(packet.status)}</strong></div>
      <dl>
        <div><dt>Evidence</dt><dd>${packet.evidence_items}</dd></div>
        <div><dt>Classes</dt><dd>${packet.evidence_classes}</dd></div>
        <div><dt>Stale</dt><dd>${packet.stale_records}</dd></div>
        <div><dt>Conflicts</dt><dd>${packet.conflicts}</dd></div>
      </dl>
    </section>
  `;
}

function findingCountSummary(findings) {
  const counts = [
    `${findings.missing.length} missing`,
    `${findings.stale.length} stale`,
    `${findings.conflicts.length} conflict${findings.conflicts.length === 1 ? "" : "s"}`,
  ];
  return counts.join(" · ");
}

function evidenceClassTags(arm) {
  const classes = [...new Set(arm.evidence.map((item) => item.evidence_class))];
  return classes.map((item) => `<span>${escapeHtml(humanize(item))}</span>`).join("");
}

function activityStep(number, title, detail, extra = "") {
  return `
    <li>
      <span class="activity-step-number">${number}</span>
      <div><strong>${escapeHtml(title)}</strong><p>${escapeHtml(detail)}</p>${extra}</div>
    </li>
  `;
}

function renderAgentActivity(result) {
  const direct = result.baseline;
  const enhanced = result.hexacontext;
  const packet = enhanced.context_packet_summary;
  const caseLabel = state.cases.find((item) => item.lot_id === result.controls.lot_id)?.label
    || result.controls.lot_id;
  const shared = `${caseLabel} · ${result.controls.actor_label}`;
  const controls = `Same snapshot, Decision Profile, Manufacturing Agent contract, business rules, and tool plane.`;
  const directTags = `<div class="activity-tags">${evidenceClassTags(direct)}</div>`;
  const enhancedTags = `<div class="activity-tags">${evidenceClassTags(enhanced)}</div>`;
  const packetDetail = packet
    ? `${packet.status} packet · ${packet.evidence_items} evidence items across ${packet.evidence_classes} classes · ${packet.missing_classes.length} missing · ${packet.stale_records} stale · ${packet.conflicts} conflicts.`
    : "No ContextPacket was produced.";

  $("#agent-activity").innerHTML = `
    <div class="activity-shared">
      <span>Shared starting point</span>
      <div><strong>${escapeHtml(shared)}</strong><small>${escapeHtml(controls)}</small></div>
    </div>
    <article class="activity-lane direct-activity">
      <header>
        <div><span>A · Foundry Direct</span><h3>Manufacturing Agent gathers context and decides</h3></div>
        <b>One agent</b>
      </header>
      <ol>
        ${activityStep(1, "Receives the controlled request", `The lot, actor, snapshot, and ${result.controls.decision_profile_id} profile are fixed by the backend.`)}
        ${activityStep(2, "Retrieves and evaluates authorized evidence", `The Manufacturing path runs ${direct.metrics.tool_calls} approved tool operations and receives ${direct.metrics.returned_records} source-backed records.`, directTags)}
        ${activityStep(3, `Returns ${direct.decision.disposition}`, `${direct.decision.summary} It provides ${direct.decision.citations.length} citations and reports ${findingCountSummary(direct.findings)}.`)}
      </ol>
      <div class="activity-boundary"><span>Direct handoff</span><strong>Authorized evidence → ManufacturingDecision</strong></div>
    </article>
    <article class="activity-lane enhanced-activity">
      <header>
        <div><span>B · With HexaContext</span><h3>HexaContext prepares context; Manufacturing decides</h3></div>
        <b>Two agents</b>
      </header>
      <ol>
        ${activityStep(1, "HexaContext compiles the evidence", `It runs ${enhanced.metrics.tool_calls} approved tool operations and organizes ${enhanced.metrics.returned_records} authorized records for this decision.`, enhancedTags)}
        ${activityStep(2, "Builds the ContextPacket", packetDetail)}
        ${activityStep(3, `The same Manufacturing Agent returns ${enhanced.decision.disposition}`, `It reasons over the packet, provides ${enhanced.decision.citations.length} citations, and reports ${findingCountSummary(enhanced.findings)}.`)}
      </ol>
      <div class="activity-boundary"><span>Enhanced handoff</span><strong>Authorized evidence → ContextPacket → ManufacturingDecision</strong></div>
    </article>
    <p class="activity-note"><strong>What changed:</strong> the enhanced path adds context compilation and a typed packet. <strong>What did not:</strong> the request, permissions, source snapshot, tools, decision rules, and Manufacturing Agent contract.</p>
  `;
}

function renderArm(target, arm, evaluation) {
  const cost = costLabel(arm.metrics.estimated_model_cost);
  const correctness = evaluation
    ? `<span class="correctness ${evaluation.disposition_correct ? "correct" : "incorrect"}">${evaluation.disposition_correct ? "Matches hidden answer" : "Does not match hidden answer"}</span>`
    : '<span class="correctness neutral">Human review required</span>';
  target.innerHTML = `
    <header class="arm-header">
      <div><p>${escapeHtml(arm.label)}</p><h3 class="decision ${arm.decision.disposition.toLowerCase()}">${escapeHtml(arm.decision.disposition)}</h3></div>
      <div class="arm-state"><span>${escapeHtml(arm.status)}</span>${correctness}</div>
    </header>
    <div class="arm-body">
      <p class="decision-summary">${escapeHtml(arm.decision.summary)}</p>
      ${contextPacket(arm.context_packet_summary)}
      <div class="metric-cards">
        <div><span>Expected sources</span><strong>${evaluation ? `${evaluation.required_evidence_found}/${evaluation.required_evidence_total}` : "—"}</strong></div>
        <div><span>Valid citations</span><strong>${evaluation ? `${evaluation.valid_citations}/${evaluation.citation_count}` : "—"}</strong></div>
        <div><span>Model calls</span><strong>${arm.metrics.model_calls}</strong></div>
        <div><span>Tool calls</span><strong>${arm.metrics.tool_calls}</strong></div>
        <div><span>Total tokens</span><strong>${arm.metrics.total_tokens?.toLocaleString() ?? "Unavailable"}</strong></div>
        <div><span>End-to-end</span><strong>${arm.metrics.end_to_end_ms} ms</strong></div>
      </div>
      <section class="stage-section">
        <div class="mini-heading"><strong>Where the overhead occurs</strong><span>${escapeHtml(humanize(arm.metrics.metric_source))}</span></div>
        ${stageBreakdown(arm)}
      </section>
      <section class="findings-grid">${findingsBlock(arm.findings)}</section>
      <section class="cost-card">
        <div><span>Estimated variable model cost</span><strong>${cost.value}</strong></div>
        <p>${escapeHtml(cost.detail)}</p>
      </section>
      <details>
        <summary>Evidence and citations <span>${arm.evidence.length}</span></summary>
        <ul class="evidence-list">${evidenceList(arm)}</ul>
      </details>
      <details>
        <summary>Tool timeline <span>${arm.tool_timeline.length}</span></summary>
        <ol class="timeline-list">${timeline(arm)}</ol>
      </details>
      <details>
        <summary>Technical metrics</summary>
        <dl class="technical-list">
          <div><dt>Input tokens</dt><dd>${arm.metrics.input_tokens?.toLocaleString() ?? "Unavailable"}</dd></div>
          <div><dt>Output tokens</dt><dd>${arm.metrics.output_tokens?.toLocaleString() ?? "Unavailable"}</dd></div>
          <div><dt>Foundry request time</dt><dd>${arm.metrics.foundry_request_ms} ms</dd></div>
          <div><dt>Retrieval time</dt><dd>${arm.metrics.supabase_retrieval_ms} ms</dd></div>
          <div><dt>Returned records</dt><dd>${arm.metrics.returned_records}</dd></div>
          <div><dt>Retries</dt><dd>${arm.metrics.retries}</dd></div>
        </dl>
      </details>
    </div>
  `;
}

function determineVerdict(result) {
  const baseline = result.evaluation.baseline;
  const enhanced = result.evaluation.hexacontext;
  if (!baseline || !enhanced) {
    return ["Quality not automatically scored", "The cost and process comparison is available, but this request requires human review."];
  }
  const qualityGain = Number(enhanced.disposition_correct) - Number(baseline.disposition_correct)
    + enhanced.required_evidence_found - baseline.required_evidence_found
    + enhanced.valid_citations - baseline.valid_citations;
  if (qualityGain > 0) {
    return ["HexaContext improved this controlled result", `The enhanced path added ${signed(result.deltas.total_tokens)} tokens and ${signed(result.deltas.end_to_end_ms, " ms")} while improving measured quality.`];
  }
  if (qualityGain < 0) {
    return ["HexaContext regressed this controlled result", "The enhanced path added overhead and reduced one or more scored quality measures."];
  }
  return ["No measured quality lift in this run", `Both arms reached the same scored quality. HexaContext added ${signed(result.deltas.total_tokens)} tokens, ${signed(result.deltas.model_calls)} model call, and ${signed(result.deltas.end_to_end_ms, " ms")} in this preview.`];
}

function renderEvaluator(result) {
  const evaluation = result.evaluation;
  if (evaluation.status !== "SCORED") {
    $("#evaluator-panel").innerHTML = `<div><p class="eyebrow">Evaluator</p><h2>Not automatically scored — human review required</h2></div>`;
    return;
  }
  const row = (label, left, right, danger = false) => `
    <div class="eval-row ${danger ? "danger" : ""}"><span>${escapeHtml(label)}</span><b>${escapeHtml(left)}</b><b>${escapeHtml(right)}</b></div>
  `;
  const base = evaluation.baseline;
  const hexa = evaluation.hexacontext;
  $("#evaluator-panel").innerHTML = `
    <div class="evaluator-heading">
      <div><p class="eyebrow">Hidden evaluator</p><h2>Quality and safety check</h2><p>${escapeHtml(evaluation.note)}</p></div>
      <div class="eval-column-labels"><span></span><strong>Direct</strong><strong>HexaContext</strong></div>
    </div>
    <div class="eval-table">
      ${row("Correct disposition", base.disposition_correct ? "Yes" : "No", hexa.disposition_correct ? "Yes" : "No")}
      ${row("Critical false PASS", base.critical_false_pass ? "Yes" : "No", hexa.critical_false_pass ? "Yes" : "No", base.critical_false_pass || hexa.critical_false_pass)}
      ${row("Expected evidence recall", `${base.required_evidence_found}/${base.required_evidence_total}`, `${hexa.required_evidence_found}/${hexa.required_evidence_total}`)}
      ${row("Valid citations", `${base.valid_citations}/${base.citation_count}`, `${hexa.valid_citations}/${hexa.citation_count}`)}
      ${row("Missing evidence detection", base.missing_evidence_detected ? "Correct" : "Missed", hexa.missing_evidence_detected ? "Correct" : "Missed")}
      ${row("Stale evidence detection", base.stale_evidence_detected ? "Correct" : "Missed", hexa.stale_evidence_detected ? "Correct" : "Missed")}
      ${row("Conflict detection", base.conflicts_detected ? "Correct" : "Missed", hexa.conflicts_detected ? "Correct" : "Missed")}
      ${row("Unauthorized leakage", String(base.unauthorized_leakage), String(hexa.unauthorized_leakage), base.unauthorized_leakage > 0 || hexa.unauthorized_leakage > 0)}
    </div>
  `;
}

function renderComparison(result) {
  state.comparison = result;
  $("#empty-state").classList.add("hidden");
  $("#comparison-result").classList.remove("hidden");
  $("#actor-label").textContent = result.controls.actor_label;
  $("#snapshot-label").textContent = result.controls.snapshot_id;
  $("#profile-label").textContent = `${result.controls.decision_profile_id} · v${result.controls.decision_profile_version}`;
  const [verdict, detail] = determineVerdict(result);
  $("#run-verdict").textContent = verdict;
  $("#run-verdict-detail").textContent = detail;
  $("#run-id").innerHTML = `<span>Comparison run</span><strong>${escapeHtml(result.comparison_run_id.slice(0, 8))}</strong><small>${escapeHtml(result.controls.execution_mode.replaceAll("_", " "))}</small>`;
  renderAgentActivity(result);
  renderDeltaGrid(result);
  renderArm($("#baseline-card"), result.baseline, result.evaluation.baseline);
  renderArm($("#hexacontext-card"), result.hexacontext, result.evaluation.hexacontext);
  renderEvaluator(result);
}

async function runComparison() {
  const button = $("#run-button");
  button.disabled = true;
  button.querySelector("span").textContent = "Running both arms…";
  try {
    const result = await api("/api/comparisons", {
      method: "POST",
      body: JSON.stringify({
        task: "Assess manufacturing lot disposition readiness",
        lot_id: $("#case-select").value,
        decision_profile_id: "manufacturing_lot_disposition_v1",
        hexacontext_mode: "hydrate",
      }),
    });
    renderComparison(result);
  } catch (error) {
    $("#empty-state").classList.remove("hidden");
    $("#empty-state").innerHTML = `<span class="empty-icon error" aria-hidden="true">!</span><div><h2>Comparison did not complete</h2><p>${escapeHtml(error.message)} No simulated fallback was substituted for a failed request.</p></div>`;
  } finally {
    button.disabled = false;
    button.querySelector("span").textContent = "Run comparison";
  }
}

function aggregateRow(label, direct, hexa, delta) {
  return `<tr><th>${escapeHtml(label)}</th><td>${escapeHtml(direct)}</td><td>${escapeHtml(hexa)}</td><td>${escapeHtml(delta)}</td></tr>`;
}

function renderSummary(summary) {
  state.summary = summary;
  $("#attempted-cases").textContent = summary.attempted_cases;
  $("#paired-cases").textContent = summary.paired_complete_cases;
  $("#quality-delta").textContent = signed(summary.hexacontext.correct - summary.baseline.correct);
  $("#token-delta").textContent = signed(summary.deltas.total_tokens);
  $("#aggregate-mode").textContent = humanize(summary.execution_mode);
  $("#aggregate-dataset").textContent = `v${summary.dataset_version}`;
  $("#aggregate-snapshot").textContent = summary.snapshot_id;
  const costDirect = summary.baseline.estimated_model_cost ?? "Unavailable";
  const costHexa = summary.hexacontext.estimated_model_cost ?? "Unavailable";
  $("#aggregate-body").innerHTML = [
    aggregateRow("Correct disposition", `${summary.baseline.correct}/${summary.attempted_cases}`, `${summary.hexacontext.correct}/${summary.attempted_cases}`, signed(summary.hexacontext.correct - summary.baseline.correct)),
    aggregateRow("Critical false PASS", summary.baseline.critical_false_passes, summary.hexacontext.critical_false_passes, signed(summary.hexacontext.critical_false_passes - summary.baseline.critical_false_passes)),
    aggregateRow("Mean evidence recall", `${Math.round(summary.baseline.mean_required_evidence_recall * 100)}%`, `${Math.round(summary.hexacontext.mean_required_evidence_recall * 100)}%`, signed(Math.round((summary.hexacontext.mean_required_evidence_recall - summary.baseline.mean_required_evidence_recall) * 100), " pp")),
    aggregateRow("Valid citations", summary.baseline.valid_citations, summary.hexacontext.valid_citations, signed(summary.deltas.valid_citations)),
    aggregateRow("Unauthorized leakage", summary.baseline.unauthorized_leakage, summary.hexacontext.unauthorized_leakage, signed(summary.hexacontext.unauthorized_leakage - summary.baseline.unauthorized_leakage)),
    aggregateRow("Total tokens", summary.baseline.total_tokens.toLocaleString(), summary.hexacontext.total_tokens.toLocaleString(), signed(summary.deltas.total_tokens)),
    aggregateRow("Model calls", summary.baseline.total_model_calls, summary.hexacontext.total_model_calls, signed(summary.deltas.model_calls)),
    aggregateRow("Tool calls", summary.baseline.total_tool_calls, summary.hexacontext.total_tool_calls, signed(summary.deltas.tool_calls)),
    aggregateRow("Median end-to-end", `${summary.baseline.median_end_to_end_ms} ms`, `${summary.hexacontext.median_end_to_end_ms} ms`, signed(summary.deltas.end_to_end_ms, " ms")),
    aggregateRow("Estimated model cost", costDirect, costHexa, "Unavailable"),
  ].join("");
  const equalQuality = summary.baseline.correct === summary.hexacontext.correct
    && summary.baseline.mean_required_evidence_recall === summary.hexacontext.mean_required_evidence_recall;
  $("#aggregate-verdict").textContent = equalQuality
    ? "Equal measured quality, higher enhanced-path overhead"
    : "The two architectures produced different measured outcomes";
  $("#aggregate-note").textContent = summary.note;
}

async function init() {
  try {
    const [health, cases, summary] = await Promise.all([
      api("/api/health"),
      api("/api/comparison-cases"),
      api("/api/evaluations/summary"),
    ]);
    state.health = health;
    state.cases = cases;
    setModeBanner();
    $("#case-select").innerHTML = cases.map((item) => `<option value="${escapeHtml(item.lot_id)}">${escapeHtml(item.label)}</option>`).join("");
    $("#case-select").value = cases.find((item) => item.lot_id.endsWith("009"))?.lot_id || cases[0].lot_id;
    renderSummary(summary);
    await runComparison();
  } catch (error) {
    $("#mode-banner").className = "mode-banner error";
    $("#mode-banner").innerHTML = `<strong>Evaluation unavailable</strong><span>${escapeHtml(error.message)}</span>`;
  }
}

$("#run-button").addEventListener("click", runComparison);
document.querySelectorAll("nav a").forEach((link) => {
  link.addEventListener("click", () => {
    document.querySelectorAll("nav a").forEach((item) => item.classList.remove("active"));
    link.classList.add("active");
  });
});

init();
