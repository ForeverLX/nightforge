/* Nightforge Dashboard — Main SPA Logic */

// ---- State ----
let state = { services: [], tasks: [], ports: [], health: null, analysis: [] };
let charts = {};
let sse = null;

// ---- Init ----
document.addEventListener("DOMContentLoaded", () => {
  setupNav();
  fetchAll();
  connectSSE();
  setupLogs();
});

// ---- Navigation ----
function setupNav() {
  document.querySelectorAll("#navList .nav-link").forEach(link => {
    link.addEventListener("click", e => {
      e.preventDefault();
      const section = link.dataset.section;
      switchSection(section);

      // load logs dropdown on first visit
      if (section === "logs" && document.getElementById("logFileSelect").options.length <= 1) {
        fetchLogFiles();
      }
    });
  });
}

function switchSection(name) {
  document.querySelectorAll(".section-content").forEach(s => s.classList.add("d-none"));
  const target = document.getElementById("section-" + name);
  if (target) target.classList.remove("d-none");

  document.querySelectorAll("#navList .nav-link").forEach(l => l.classList.remove("active"));
  const link = document.querySelector(`[data-section="${name}"]`);
  if (link) link.classList.add("active");
}

// ---- Data Fetching ----
async function fetchAll() {
  try {
    const [svc, tsk, prt, hlth, anl] = await Promise.all([
      fetch("/api/v1/services").then(r => r.json()).catch(() => []),
      fetch("/api/v1/tasks").then(r => r.json()).catch(() => []),
      fetch("/api/v1/ports").then(r => r.json()).catch(() => []),
      fetch("/api/v1/health").then(r => r.json()).catch(() => null),
      fetch("/api/v1/analysis").then(r => r.json()).catch(() => []),
    ]);

    state.services = Array.isArray(svc) ? svc : (svc.services || []);
    state.tasks    = Array.isArray(tsk) ? tsk : (tsk.tasks || []);
    state.ports    = Array.isArray(prt) ? prt : (prt.ports || []);
    state.health   = hlth ? (hlth.health || hlth) : null;
    state.analysis = Array.isArray(anl) ? anl : (anl.analysis || []);

    renderAll();
  } catch (err) {
    console.error("fetchAll:", err);
  }
}

function renderAll() {
  renderOverview();
  renderTasks();
  renderPorts();
  renderAnalysis();
  renderApiUsage();
}

// ---- SSE ----
function connectSSE() {
  if (sse) sse.close();
  sse = new EventSource("/api/v1/events");

  sse.onopen = () => setConnection(true);
  sse.onerror = () => {
    setConnection(false);
    sse.close();
    setTimeout(connectSSE, 5000);
  };

  sse.addEventListener("update", e => {
    try {
      const data = JSON.parse(e.data);
      if (data.services) state.services = data.services;
      if (data.tasks)    state.tasks    = data.tasks;
      if (data.ports)    state.ports    = data.ports;
      if (data.health)   state.health   = data.health;
      if (data.analysis) state.analysis = data.analysis;
      renderAll();
    } catch (err) {
      console.error("SSE parse:", err);
    }
  });

  // catch-all for bare "message" events
  sse.onmessage = e => {
    try {
      const data = JSON.parse(e.data);
      if (data.type === "update" || data.services || data.tasks || data.ports || data.health) {
        if (data.services) state.services = data.services;
        if (data.tasks)    state.tasks    = data.tasks;
        if (data.ports)    state.ports    = data.ports;
        if (data.health)   state.health   = data.health;
        if (data.analysis) state.analysis = data.analysis;
        renderAll();
      }
    } catch (_) { /* ignore */ }
  };
}

function setConnection(live) {
  const dot = document.getElementById("connectionDot");
  const label = document.getElementById("connectionLabel");
  if (dot) {
    dot.className = "status-dot " + (live ? "live" : "dead");
  }
  if (label) {
    label.textContent = live ? "live" : "disconnected";
  }
}

// ---- Overview ----
function renderOverview() {
  renderServiceCards();
  renderBonsaiStatus();
  renderCpuLoad();
  renderGpuMem();
  renderCharts();
  renderOverviewTaskTable();
}

function renderServiceCards() {
  const container = document.getElementById("serviceCards");
  if (!container) return;

  if (!state.services.length) {
    container.innerHTML = '<div class="col-12 text-muted">No services registered.</div>';
    return;
  }

  container.innerHTML = state.services.map(s => {
    const up = s.status === "UP";
    const cls = up ? "badge-up" : "badge-down";
    const label = up ? "UP" : "DOWN";
    return `<div class="col-xl-3 col-lg-4 col-md-6">
      <div class="card h-100">
        <div class="card-body">
          <h6 class="fw-bold">${esc(s.name)}</h6>
          <div class="d-flex justify-content-between align-items-center">
            <small class="text-muted">Port ${esc(String(s.port))}</small>
            <span class="service-pill ${cls}">${label}</span>
          </div>
        </div>
      </div>
    </div>`;
  }).join("");
}

function renderBonsaiStatus() {
  const el = document.getElementById("bonsaiStatus");
  if (!el) return;
  const bonsai = state.services.find(s => s.name && s.name.toLowerCase().includes("bonsai"));
  if (bonsai) {
    const up = bonsai.status === "UP";
    el.innerHTML = `<span class="fw-bold">${esc(bonsai.name)}</span>
      <span class="service-pill ms-2 ${up ? "badge-up" : "badge-down"}">${up ? "UP" : "DOWN"}</span>
      <br><small class="text-muted">Port ${esc(String(bonsai.port))}</small>`;
  } else {
    el.innerHTML = '<span class="text-muted">No Bonsai service found.</span>';
  }
}

function renderCpuLoad() {
  const el = document.getElementById("cpuLoad");
  if (!el || !state.health) return;
  const load = state.health.load || [];
  el.innerHTML = `<div class="fs-4 fw-bold">${load.map(n => n.toFixed(2)).join(" / ")}</div>
    <small class="text-muted">1 min / 5 min / 15 min</small>`;
}

function renderGpuMem() {
  const el = document.getElementById("gpuMem");
  if (!el || !state.health) return;
  const used = state.health.gpu_mem || 0;
  const total = state.health.gpu_total || 0;
  const pct = total ? ((used / total) * 100).toFixed(1) : "?";
  el.innerHTML = `<div class="fs-4 fw-bold">${pct}%</div>
    <small class="text-muted">${used} MB / ${total} MB</small>`;
}

function renderOverviewTaskTable() {
  const tbody = document.querySelector("#overviewTaskTable tbody");
  if (!tbody) return;
  if (!state.tasks.length) {
    tbody.innerHTML = '<tr><td colspan="3" class="text-muted">No tasks.</td></tr>';
    return;
  }
  tbody.innerHTML = state.tasks.slice(0, 5).map(t => taskRow(t)).join("");
}

// ---- Tasks ----
function renderTasks() {
  const tbody = document.getElementById("taskTableBody");
  if (!tbody) return;
  if (!state.tasks.length) {
    tbody.innerHTML = '<tr><td colspan="3" class="text-muted">No tasks.</td></tr>';
    return;
  }
  tbody.innerHTML = state.tasks.map(t => taskRow(t)).join("");
}

function taskRow(t) {
  const status = t.status || "";
  let cls = "badge-ok";
  if (/err|fail|down/i.test(status)) cls = "badge-err";
  else if (/warn/i.test(status)) cls = "badge-warn";
  return `<tr>
    <td>${esc(t.name)}</td>
    <td><span class="service-pill ${cls}">${esc(status)}</span></td>
    <td><small class="text-muted">${esc(t.last_run || "")}</small></td>
  </tr>`;
}

// ---- Ports ----
function renderPorts() {
  const tbody = document.getElementById("portTableBody");
  if (!tbody) return;
  if (!state.ports.length) {
    tbody.innerHTML = '<tr><td colspan="3" class="text-muted">No ports.</td></tr>';
    return;
  }
  tbody.innerHTML = state.ports.map(p => `<tr>
    <td><code>${esc(String(p.port))}</code></td>
    <td>${esc(p.service || "")}</td>
    <td>${esc(p.process || "")}</td>
  </tr>`).join("");
}

// ---- Analysis ----
function renderAnalysis() {
  const container = document.getElementById("analysisCards");
  if (!container) return;
  if (!state.analysis.length) {
    container.innerHTML = '<div class="col-12 text-muted">No analysis available.</div>';
    return;
  }
  container.innerHTML = state.analysis.map(a => `<div class="col-lg-6 mb-3">
    <div class="card h-100">
      <div class="card-header">${esc(a.source || "analysis")}</div>
      <div class="card-body"><p class="mb-0" style="white-space:pre-wrap">${esc(a.text || "")}</p></div>
    </div>
  </div>`).join("");
}

// ---- Logs ----
function setupLogs() {
  const refreshBtn = document.getElementById("logRefreshBtn");
  const select = document.getElementById("logFileSelect");
  if (refreshBtn) refreshBtn.addEventListener("click", loadLogContent);
  if (select) select.addEventListener("change", loadLogContent);
}

async function fetchLogFiles() {
  const select = document.getElementById("logFileSelect");
  try {
    const res = await fetch("/api/v1/logs");
    const data = await res.json();
    const files = data.files || data || [];
    select.innerHTML = '<option value="">-- select log --</option>' +
      files.map(f => `<option value="${esc(f)}">${esc(f)}</option>`).join("");
  } catch (err) {
    console.error("fetchLogFiles:", err);
  }
}

async function loadLogContent() {
  const select = document.getElementById("logFileSelect");
  const pre = document.getElementById("logContent");
  if (!select || !pre) return;
  const file = select.value;
  if (!file) { pre.textContent = "Select a log file."; return; }
  pre.textContent = "Loading...";
  try {
    const res = await fetch("/api/v1/logs/" + encodeURIComponent(file));
    const data = await res.json();
    pre.textContent = data.lines ? data.lines.join("\n") : (data.content || JSON.stringify(data, null, 2));
  } catch (err) {
    pre.textContent = "Failed to load log: " + err.message;
  }
}

// ---- API Usage ----
function renderApiUsage() {
  const tbody = document.getElementById("apiUsageBody");
  if (!tbody) return;

  // placeholder data until API usage tracker is built
  const rows = state.tasks
    .filter(t => t.name && /usage|token|api/i.test(t.name))
    .map(t => `<tr>
      <td>—</td>
      <td>—</td>
      <td>—</td>
      <td><small class="text-muted">${esc(t.last_run || "")}</small></td>
    </tr>`);

  if (rows.length === 0) {
    rows.push('<tr><td colspan="4" class="text-muted">API usage tracker coming soon.</td></tr>');
  }

  tbody.innerHTML = rows.join("");
}

// ---- Charts ----
function renderCharts() {
  if (!state.health) return;
  const h = state.health;

  renderDoughnut("chartDiskRoot", "Root (/)", h.disk_root_pct || 0, ["#58a6ff", "#30363d"]);
  renderDoughnut("chartDiskHome", "Home (/home)", h.disk_home_pct || 0, ["#3fb950", "#30363d"]);
  renderDoughnut("chartMemory", "Memory", h.mem_pct || 0, ["#f0883e", "#30363d"]);
}

function renderDoughnut(canvasId, label, pct, colors) {
  const canvas = document.getElementById(canvasId);
  if (!canvas) return;

  if (charts[canvasId]) charts[canvasId].destroy();

  const ctx = canvas.getContext("2d");
  charts[canvasId] = new Chart(ctx, {
    type: "doughnut",
    data: {
      labels: ["Used", "Free"],
      datasets: [{
        data: [pct, Math.max(0, 100 - pct)],
        backgroundColor: colors,
        borderColor: "#0d1117",
        borderWidth: 2,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      cutout: "65%",
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { label: ctx => ctx.raw + "%" } },
      },
    },
    plugins: [{
      id: "centerText",
      afterDraw(chart) {
        const { ctx, chartArea: { width, height, top, left } } = chart;
        ctx.save();
        ctx.fillStyle = "#e6edf3";
        ctx.font = "bold 18px -apple-system, sans-serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(pct + "%", left + width / 2, top + height / 2);
        ctx.restore();
      },
    }],
  });
}

// ---- Helpers ----
function esc(s) {
  if (s == null) return "";
  const div = document.createElement("div");
  div.textContent = String(s);
  return div.innerHTML;
}
