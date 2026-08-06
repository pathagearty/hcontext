const state = {
  lots: [],
  selectedLotId: null,
  selectedLot: null,
  health: null,
};

const $ = (selector) => document.querySelector(selector);
const escapeHtml = (value) => String(value ?? "")
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;")
  .replaceAll("'", "&#039;");

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  if (!response.ok) {
    let detail = `Request failed (${response.status})`;
    try { detail = (await response.json()).detail || detail; } catch (_) { /* no-op */ }
    throw new Error(detail);
  }
  return response.json();
}

function providerLabel(name) {
  return {
    mock: "Deterministic mock",
    azure_foundry: "Azure Foundry",
    aws_bedrock: "AWS Bedrock",
  }[name] || name;
}

function modeLabel(name) {
  return {
    exact: "Exact only",
    graph: "Graph + exact",
    search: "Search + exact",
    hybrid: "Hybrid",
  }[name] || name;
}

function updateRuntimeStatus() {
  const provider = $("#provider").value;
  const status = $("#runtime-status");
  const config = state.health?.providers?.[provider];
  if (config?.configured) {
    status.className = "runtime-status";
    status.innerHTML = `<span></span>${provider === "mock" ? "Local ready" : "Configured · untested"}`;
  } else {
    status.className = "runtime-status error";
    status.innerHTML = `<span></span>Not configured`;
  }
}

async function loadHealth() {
  state.health = await api("/api/health");
  $("#case-count").textContent = state.health.case_count;
  updateRuntimeStatus();
}

function renderLotList() {
  $("#lot-total").textContent = state.lots.length;
  $("#lot-list").innerHTML = state.lots.map((lot) => `
    <button class="lot-item ${lot.lot_id === state.selectedLotId ? "active" : ""}" data-lot-id="${escapeHtml(lot.lot_id)}">
      <strong>${escapeHtml(lot.lot_id)}</strong>
      <span>${escapeHtml(lot.scenario)}</span>
      <small><b>${escapeHtml(lot.part_id)}</b><em>${escapeHtml(lot.supplier_id)}</em></small>
    </button>
  `).join("");
  document.querySelectorAll(".lot-item").forEach((button) => {
    button.addEventListener("click", () => selectLot(button.dataset.lotId));
  });
}

function graphNodeType(id, lot) {
  if (id === lot.lot_id) return "Active lot";
  if (id.startsWith("HX-SUP")) return "Supplier";
  if (id.startsWith("HX-PART")) return "Part";
  if (id.startsWith("HX-EQP")) return "Equipment";
  if (id.startsWith("HX-POLICY")) return "Policy";
  return "Entity";
}

function renderGraph(lot) {
  const positions = {
    [lot.lot_id]: [350, 105],
    [lot.supplier_id]: [95, 48],
    [lot.part_id]: [95, 168],
    [lot.machine_id]: [605, 48],
    "HX-POLICY-LOT-001": [605, 168],
  };
  const nodes = [...new Set(lot.relationships.flatMap((edge) => [edge.from, edge.to]))];
  const edges = lot.relationships.map((edge) => {
    const from = positions[edge.from];
    const to = positions[edge.to];
    if (!from || !to) return "";
    const mx = (from[0] + to[0]) / 2;
    const my = (from[1] + to[1]) / 2 - 5;
    return `<line class="graph-line active" x1="${from[0]}" y1="${from[1]}" x2="${to[0]}" y2="${to[1]}" />
      <text class="graph-edge-label" x="${mx}" y="${my}">${escapeHtml(edge.type.replaceAll("_", " "))}</text>`;
  }).join("");
  const renderedNodes = nodes.map((id) => {
    const [x, y] = positions[id] || [350, 105];
    const primary = id === lot.lot_id ? "primary" : "";
    return `<g class="graph-node ${primary}" transform="translate(${x - 66}, ${y - 23})">
      <rect width="132" height="46"></rect>
      <text x="66" y="19">${escapeHtml(id)}</text>
      <text class="node-type" x="66" y="33">${escapeHtml(graphNodeType(id, lot))}</text>
    </g>`;
  }).join("");
  $("#context-graph").innerHTML = `<svg viewBox="0 0 700 220" role="img" aria-label="Bounded context relationships">${edges}${renderedNodes}</svg>`;
}

function renderEvidence(lot) {
  const icon = {
    inspection: "IN", certificate: "CO", equipment_calibration: "EQ",
    supplier_history: "SP", revision_control: "RV", deviation: "DV", narrative_note: "NT",
  };
  $("#evidence-count").textContent = `${lot.evidence.length} sources`;
  $("#evidence-list").innerHTML = lot.evidence.map((item) => `
    <article class="evidence-item">
      <span class="evidence-icon">${icon[item.evidence_type] || "EV"}</span>
      <div><strong>${escapeHtml(item.title)}</strong><p>${escapeHtml(item.source_system)} · ${escapeHtml(item.summary)}</p></div>
      <small>${escapeHtml(item.retrieval_scope)}</small>
    </article>
  `).join("");
}

function resetPacket() {
  $("#packet-empty").classList.remove("hidden");
  $("#packet-result").classList.add("hidden");
  $("#packet-result").innerHTML = "";
}

async function selectLot(lotId) {
  state.selectedLotId = lotId;
  renderLotList();
  state.selectedLot = await api(`/api/lots/${encodeURIComponent(lotId)}`);
  const lot = state.selectedLot;
  $("#lot-title").textContent = lot.lot_id;
  $("#scenario-pill").textContent = lot.scenario;
  $("#scenario-pill").title = lot.scenario;
  $("#lot-metadata").innerHTML = [
    ["Part", `${lot.part_id} · Rev ${lot.part_revision}`],
    ["Supplier", lot.supplier_id],
    ["Material", lot.material],
    ["Quantity", lot.quantity.toLocaleString()],
  ].map(([label, value]) => `<div><span>${escapeHtml(label)}</span><strong title="${escapeHtml(value)}">${escapeHtml(value)}</strong></div>`).join("");
  renderGraph(lot);
  renderEvidence(lot);
  resetPacket();
}

function renderPacket(packet) {
  const missing = packet.missing_information.length
    ? `<div class="packet-block"><h4>Missing information</h4>${packet.missing_information.map((item) => `<div class="check-item unknown"><span class="check-dot"></span><div><p>${escapeHtml(item)}</p></div></div>`).join("")}</div>`
    : "";
  const conflicts = packet.conflicts.length
    ? `<div class="packet-block"><h4>Conflicts</h4>${packet.conflicts.map((item) => `<div class="check-item fail"><span class="check-dot"></span><div><p>${escapeHtml(item)}</p></div></div>`).join("")}</div>`
    : "";
  const checks = packet.policy_checks.map((check) => `
    <div class="check-item ${escapeHtml(check.status)}">
      <span class="check-dot"></span>
      <div><strong>${escapeHtml(check.label)}</strong><p>${escapeHtml(check.reason)}</p></div>
    </div>
  `).join("");
  const routes = packet.retrieval_trace.routes.map((route) => `<span class="trace-chip">${escapeHtml(route.replaceAll("_", " "))}</span>`).join("");
  $("#packet-result").innerHTML = `
    <div class="disposition-header ${escapeHtml(packet.disposition)}"><span>Deterministic profile result</span><strong>${escapeHtml(packet.disposition)}</strong></div>
    <p class="packet-summary">${escapeHtml(packet.summary)}</p>
    <div class="trace-row">${routes}</div>
    <div class="packet-block"><h4>Policy and assurance checks</h4>${checks}</div>
    ${missing}${conflicts}
    <div class="packet-block"><h4>Required human action</h4><div class="human-action">${escapeHtml(packet.human_action)}</div></div>
    <p class="provider-note">Explanation: ${escapeHtml(providerLabel(packet.explanation_source))} · Authorized evidence: ${packet.retrieval_trace.authorized_count} · Excluded: ${packet.retrieval_trace.excluded_unauthorized_count} · Context characters: ${packet.context_characters}</p>
  `;
  $("#packet-empty").classList.add("hidden");
  $("#packet-result").classList.remove("hidden");
}

async function compilePacket() {
  const button = $("#compile-button");
  if (!state.selectedLotId) return;
  button.disabled = true;
  button.textContent = "Compiling authorized context…";
  try {
    const packet = await api("/api/compile", {
      method: "POST",
      body: JSON.stringify({
        lot_id: state.selectedLotId,
        retrieval_mode: $("#retrieval-mode").value,
        provider: $("#provider").value,
      }),
    });
    renderPacket(packet);
  } catch (error) {
    $("#packet-empty").classList.add("hidden");
    $("#packet-result").classList.remove("hidden");
    $("#packet-result").innerHTML = `<div class="error-card"><strong>Packet not compiled.</strong><br>${escapeHtml(error.message)}<br><br>No fixture fallback was substituted.</div>`;
  } finally {
    button.disabled = false;
    button.textContent = "Compile governed packet";
  }
}

async function loadEvaluation() {
  const report = await api("/api/evaluation");
  $("#evaluation-body").innerHTML = report.rows.map((row) => {
    const pct = Math.round(row.accuracy * 100);
    return `<tr>
      <td><strong>${escapeHtml(modeLabel(row.mode))}</strong></td>
      <td class="score-cell"><b>${pct}%</b><div class="score-bar"><span style="width:${pct}%"></span></div></td>
      <td>${row.correct}/${row.total}</td><td>${row.critical_false_passes}</td><td>${row.over_escalations}</td>
    </tr>`;
  }).join("");
  $("#evaluation-note").textContent = report.note;
  const hybrid = report.rows.find((row) => row.mode === "hybrid");
  $("#hybrid-score").textContent = `${Math.round(hybrid.accuracy * 100)}%`;
}

async function init() {
  try {
    await loadHealth();
    state.lots = await api("/api/lots");
    renderLotList();
    await selectLot(state.lots[0].lot_id);
    await loadEvaluation();
  } catch (error) {
    $("#runtime-status").className = "runtime-status error";
    $("#runtime-status").innerHTML = `<span></span>${escapeHtml(error.message)}`;
  }
}

$("#provider").addEventListener("change", updateRuntimeStatus);
$("#retrieval-mode").addEventListener("change", resetPacket);
$("#compile-button").addEventListener("click", compilePacket);

document.querySelectorAll("nav a").forEach((link) => {
  link.addEventListener("click", () => {
    document.querySelectorAll("nav a").forEach((item) => item.classList.remove("active"));
    link.classList.add("active");
  });
});

init();
