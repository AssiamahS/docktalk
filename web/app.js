// DockTalk door board. Vanilla JS, state in localStorage on this device.
(function () {
  const S = window.DockShared;
  const $ = (id) => document.getElementById(id);
  const STATUSES = [
    ["waiting", "Waiting in yard"],
    ["door", "At door"],
    ["loading", "Loading / unloading"],
    ["done", "Done today"]
  ];
  const NEXT = { waiting: "door", door: "loading", loading: "done" };
  const NEXT_LABEL = { waiting: "Send to door", door: "Start loading", loading: "Mark done" };
  const STAMP = { door: "doorAt", loading: "loadingAt", done: "doneAt" };

  let state = S.load() || seed();
  let selected = null;
  let editingId = null;

  function seed() {
    const now = Date.now(), m = 60000;
    const at = (mins) => new Date(now - mins * m).toISOString();
    return {
      settings: { site: "Main DC", doors: 8, free: 120, rate: 60, phone: "" },
      visits: [
        { id: S.uid(), name: "Marcus T.", phone: "", carrier: "Ridgeline Freight", ref: "PO 44817", trailer: "53R-2210", kind: "inbound", appt: "", notes: "Demo row - delete anytime", status: "loading", door: 3, arrivedAt: at(134), doorAt: at(96), loadingAt: at(88) },
        { id: S.uid(), name: "Dana K.", phone: "", carrier: "Blue Mile Logistics", ref: "LD 90213", trailer: "TRL 7781", kind: "outbound", appt: "", notes: "Demo row", status: "door", door: 5, arrivedAt: at(52), doorAt: at(9) },
        { id: S.uid(), name: "Luis R.", phone: "", carrier: "Owner-op", ref: "BOL 3321", trailer: "", kind: "inbound", appt: "", notes: "Demo row", status: "waiting", door: null, arrivedAt: at(23) }
      ]
    };
  }
  const persist = () => { if (!S.save(state)) toast("Storage blocked - data will not survive reload"); };

  // ---------- time + risk ----------
  const mins = (from, to) => Math.max(0, Math.round(((to ? Date.parse(to) : Date.now()) - Date.parse(from)) / 60000));
  const fmt = (m) => (m < 60 ? `${m}m` : `${Math.floor(m / 60)}h${String(m % 60).padStart(2, "0")}`);
  const clock = (iso) => (iso ? new Date(iso).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }) : "-");
  function dwell(v) { return mins(v.arrivedAt, v.doneAt); }
  function risk(v) {
    const d = dwell(v), free = +state.settings.free || 120;
    if (d >= free) return "r-stop";
    if (d >= free - 30) return "r-warn";
    return "r-ok";
  }
  function detentionCost(v) {
    const over = dwell(v) - (+state.settings.free || 120);
    return over > 0 ? Math.ceil(over / 60) * (+state.settings.rate || 0) : 0;
  }
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  // ---------- render ----------
  function render() {
    $("siteName").textContent = state.settings.site || "Site";
    document.title = `DockTalk Door Board`;
    const active = state.visits.filter((v) => v.status !== "done");
    const atDoor = active.filter((v) => v.door);
    const allDwell = state.visits.map(dwell);
    $("sOn").textContent = active.length;
    $("sDoor").textContent = `${atDoor.length}/${state.settings.doors}`;
    $("sAvg").textContent = fmt(allDwell.length ? Math.round(allDwell.reduce((a, b) => a + b, 0) / allDwell.length) : 0);
    const atRisk = active.filter((v) => risk(v) !== "r-ok").length;
    $("sDet").textContent = atRisk;
    $("sDetWrap").classList.toggle("alert", atRisk > 0);
    renderList();
    renderDetail();
  }

  function card(v) {
    const r = v.status === "done" ? "" : risk(v);
    return `<button class="card ${r} ${v.status === "done" ? "done" : ""} ${selected === v.id ? "sel" : ""}" data-id="${v.id}">
      <div class="door-tag ${v.door ? "on" : ""}"><small>DOOR</small>${v.door || "--"}</div>
      <div style="min-width:0"><div class="who">${esc(v.name)}</div>
        <div class="meta">${esc([v.carrier, v.ref, v.kind === "outbound" ? "PICKUP" : "DROP"].filter(Boolean).join(" · "))}</div></div>
      <div class="dwell">${fmt(dwell(v))}<small>${v.status === "done" ? "total" : "dwell"}</small></div>
    </button>`;
  }

  function renderList() {
    const html = STATUSES.map(([key, label]) => {
      const rows = state.visits.filter((v) => v.status === key).sort((a, b) => Date.parse(a.arrivedAt) - Date.parse(b.arrivedAt));
      return `<div class="lane"><h3>${label} <span class="n">${rows.length}</span></h3>
        ${rows.length ? rows.map(card).join("") : `<div class="empty">${key === "waiting" ? "No trucks waiting. Tape the Gate QR at the shack." : "None"}</div>`}</div>`;
    }).join("");
    const quick = `<div class="quick"><button class="btn sm" data-act="doors">Door board</button><button class="btn sm" data-act="qr">Gate QR</button><button class="btn sm" data-act="import">Paste texts</button></div>`;
    $("listPane").innerHTML = quick + html;
  }

  function doorGrid() {
    const n = Math.max(1, +state.settings.doors || 8);
    let cells = "";
    for (let d = 1; d <= n; d++) {
      const v = state.visits.find((x) => x.door === d && x.status !== "done");
      cells += v
        ? `<button class="door busy ${risk(v)}" data-id="${v.id}"><div class="num">${d}</div><div class="occ">${esc(v.name)}<small>${v.status === "loading" ? "loading" : "at door"} · ${fmt(dwell(v))}</small></div></button>`
        : `<button class="door free" data-free="${d}"><div class="num">${d}</div><div class="occ">Open</div></button>`;
    }
    const waiting = state.visits.filter((v) => v.status === "waiting").length;
    return `<div class="doors-head"><h2>Door board</h2><span class="pill">${waiting} waiting</span></div><div class="doors">${cells}</div>
      <p class="hint" style="margin-top:14px">Tap an open door to assign the longest-waiting truck. Red = past ${state.settings.free} min free time.</p>`;
  }

  function renderDetail() {
    const v = state.visits.find((x) => x.id === selected);
    const pane = $("detailPane");
    if (selected === "__doors") { pane.innerHTML = `<button class="btn ghost sm back" data-act="back">&larr; Trucks</button>` + doorGrid(); document.body.classList.add("show-detail"); return; }
    if (!v) { pane.innerHTML = doorGrid(); document.body.classList.remove("show-detail"); return; }
    const r = v.status === "done" ? "" : risk(v);
    const cost = detentionCost(v);
    const taken = new Set(state.visits.filter((x) => x.status !== "done" && x.door && x.id !== v.id).map((x) => x.door));
    let picks = "";
    for (let d = 1; d <= (+state.settings.doors || 8); d++) picks += `<button data-door="${d}" class="${v.door === d ? "mine" : taken.has(d) ? "taken" : ""}" ${taken.has(d) ? "disabled" : ""}>${d}</button>`;
    const statusLabel = STATUSES.find(([k]) => k === v.status)[1];
    pane.innerHTML = `
      <button class="btn ghost sm back" data-act="back">&larr; Board</button>
      <div class="det-head">
        <div class="bigdoor ${v.door ? "on" : ""}"><div><small>DOOR</small>${v.door || "--"}</div></div>
        <div style="min-width:0"><h2>${esc(v.name)}</h2>
          <div style="margin-top:6px;display:flex;gap:6px;flex-wrap:wrap"><span class="pill">${statusLabel}</span>
          ${r ? `<span class="pill ${r}">${r === "r-stop" ? "Detention" : r === "r-warn" ? "Near free-time limit" : "On time"}</span>` : ""}</div></div>
      </div>
      <div class="facts">
        <div><div class="k">Dwell</div><div class="v">${fmt(dwell(v))}</div></div>
        <div><div class="k">Est. detention</div><div class="v">${cost ? "$" + cost : "$0"}</div></div>
        <div><div class="k">Carrier</div><div class="v">${esc(v.carrier) || "-"}</div></div>
        <div><div class="k">PO / Load</div><div class="v">${esc(v.ref) || "-"}</div></div>
        <div><div class="k">Trailer</div><div class="v">${esc(v.trailer) || "-"}</div></div>
        <div><div class="k">Type / appt</div><div class="v">${v.kind === "outbound" ? "Pickup" : "Drop"}${v.appt ? " · " + esc(v.appt) : ""}</div></div>
      </div>
      <div class="actions">
        ${NEXT[v.status] ? `<button class="btn sig" data-act="next">${NEXT_LABEL[v.status]}</button>` : ""}
        ${v.phone ? `<a class="btn" href="${S.smsHref(v.phone, doorMsg(v))}">Text driver${v.door ? " door " + v.door : ""}</a><a class="btn ghost" href="tel:${esc(v.phone)}">Call</a>` : `<span class="hint">No cell on file - add one to text the door.</span>`}
        <button class="btn ghost" data-act="edit">Edit</button>
        <button class="btn ghost danger" data-act="del">Delete</button>
      </div>
      ${v.status !== "done" ? `<div class="section-k">Assign door</div><div class="door-pick">${picks}</div>` : ""}
      <div class="section-k">Timeline</div>
      <ul class="timeline">
        <li class="hit">Checked in <span>${clock(v.arrivedAt)}</span></li>
        <li class="${v.doorAt ? "hit" : ""}">At door <span>${clock(v.doorAt)}</span></li>
        <li class="${v.loadingAt ? "hit" : ""}">Loading started <span>${clock(v.loadingAt)}</span></li>
        <li class="${v.doneAt ? "hit" : ""}">Released <span>${clock(v.doneAt)}</span></li>
      </ul>
      ${v.notes ? `<div class="section-k">Notes</div><p>${esc(v.notes)}</p>` : ""}`;
    document.body.classList.add("show-detail");
  }

  function doorMsg(v) {
    const site = state.settings.site || "the dock";
    if (v.door) return `${site}: ${v.name.split(" ")[0]}, back into DOOR ${v.door} now. Ref ${v.ref || ""}. Reply here if you can't. - DockTalk`;
    return `${site}: ${v.name.split(" ")[0]}, you're checked in (${clock(v.arrivedAt)}). We'll text your door. Stay with your truck.`;
  }

  // ---------- mutations ----------
  function setDoor(v, d) {
    v.door = d;
    if (v.status === "waiting") { v.status = "door"; v.doorAt = new Date().toISOString(); }
    persist(); render();
    toast(`Door ${d} -> ${v.name}${v.phone ? ". Tap Text driver." : ""}`);
  }
  function advance(v) {
    const n = NEXT[v.status];
    if (!n) return;
    if (n === "door" && !v.door) {
      const d = firstFreeDoor();
      if (!d) return toast("All doors busy");
      v.door = d;
    }
    v.status = n; v[STAMP[n]] = new Date().toISOString();
    persist(); render();
  }
  function firstFreeDoor() {
    const taken = new Set(state.visits.filter((x) => x.status !== "done" && x.door).map((x) => x.door));
    for (let d = 1; d <= (+state.settings.doors || 8); d++) if (!taken.has(d)) return d;
    return null;
  }
  function addVisit(data) {
    const v = { id: S.uid(), status: "waiting", door: null, arrivedAt: new Date().toISOString(), ...data };
    state.visits.push(v); persist(); return v;
  }

  // ---------- events ----------
  document.addEventListener("click", (e) => {
    const t = e.target.closest("[data-id],[data-free],[data-door],[data-act]");
    if (!t) return;
    const v = state.visits.find((x) => x.id === selected);
    if (t.dataset.id) { selected = t.dataset.id; render(); window.scrollTo(0, 0); return; }
    if (t.dataset.free) {
      const w = state.visits.filter((x) => x.status === "waiting").sort((a, b) => Date.parse(a.arrivedAt) - Date.parse(b.arrivedAt))[0];
      if (!w) return toast("Nobody waiting");
      selected = w.id; setDoor(w, +t.dataset.free); return;
    }
    if (t.dataset.door && v) { setDoor(v, +t.dataset.door); return; }
    const act = t.dataset.act;
    if (act === "back") { selected = null; render(); }
    if (act === "doors") { selected = "__doors"; render(); window.scrollTo(0, 0); }
    if (act === "qr") $("btnQR").click();
    if (act === "import") $("btnImport").click();
    if (act === "next" && v) advance(v);
    if (act === "edit" && v) openVisit(v);
    if (act === "del" && v && confirm(`Delete ${v.name}?`)) { state.visits = state.visits.filter((x) => x.id !== v.id); selected = null; persist(); render(); }
  });

  function openVisit(v) {
    editingId = v ? v.id : null;
    const f = $("formVisit");
    f.reset();
    $("visitTitle").textContent = v ? "Edit truck" : "Check in truck";
    if (v) {
      for (const k of ["name", "phone", "carrier", "ref", "trailer", "appt", "notes"]) f.elements[k].value = v[k] || "";
      f.elements.kind.value = v.kind || "inbound";
    }
    $("dlgVisit").showModal();
  }
  $("dlgVisit").addEventListener("close", () => {
    if ($("dlgVisit").returnValue !== "ok") return;
    const f = $("formVisit");
    const data = {};
    for (const k of ["name", "phone", "carrier", "ref", "trailer", "appt", "notes", "kind"]) data[k] = f.elements[k].value.trim();
    if (!data.name) return;
    if (editingId) Object.assign(state.visits.find((x) => x.id === editingId), data), persist();
    else selected = addVisit(data).id;
    render();
  });
  $("btnAdd").onclick = $("fab").onclick = () => openVisit(null);

  $("btnImport").onclick = () => { $("importText").value = ""; $("dlgImport").showModal(); };
  $("dlgImport").addEventListener("close", () => {
    if ($("dlgImport").returnValue !== "ok") return;
    const rows = S.parseCheckins($("importText").value);
    rows.forEach(addVisit);
    toast(rows.length ? `Added ${rows.length} truck${rows.length > 1 ? "s" : ""}` : "No DOCKTALK CHECKIN text found");
    render();
  });

  function checkinUrl() {
    const u = new URL("checkin.html", location.href);
    u.search = "";
    if (state.settings.site) u.searchParams.set("site", state.settings.site);
    if (state.settings.phone) u.searchParams.set("to", state.settings.phone);
    return u.toString();
  }
  $("btnQR").onclick = () => {
    const url = checkinUrl();
    $("qrUrl").textContent = url;
    $("qrOpen").href = url;
    const box = $("qrBox");
    if (window.qrcode) {
      const q = window.qrcode(0, "M"); q.addData(url); q.make();
      box.innerHTML = q.createSvgTag({ cellSize: 6, margin: 2, scalable: true });
    } else box.innerHTML = `<p class="hint" style="color:#333">QR library offline - print the link below.</p>`;
    if (!state.settings.phone) toast("Set the dock phone in settings so drivers' texts reach you");
    $("dlgQR").showModal();
  };
  $("qrClose").onclick = () => $("dlgQR").close();
  $("qrPrint").onclick = () => window.print();
  $("qrCopy").onclick = async () => { try { await navigator.clipboard.writeText(checkinUrl()); toast("Link copied"); } catch { toast("Copy blocked - long-press the link"); } };

  $("btnMenu").onclick = () => {
    const f = $("formSettings"), s = state.settings;
    f.elements.site.value = s.site; f.elements.doors.value = s.doors; f.elements.free.value = s.free; f.elements.rate.value = s.rate; f.elements.phone.value = s.phone;
    $("dlgSettings").showModal();
  };
  $("dlgSettings").addEventListener("close", () => {
    if ($("dlgSettings").returnValue !== "ok") return;
    const f = $("formSettings");
    state.settings = {
      site: f.elements.site.value.trim() || "Main DC",
      doors: Math.min(60, Math.max(1, +f.elements.doors.value || 8)),
      free: Math.max(15, +f.elements.free.value || 120),
      rate: Math.max(0, +f.elements.rate.value || 0),
      phone: f.elements.phone.value.trim()
    };
    persist(); render();
  });
  $("btnClearDone").onclick = () => {
    const n = state.visits.filter((v) => v.status === "done").length;
    if (n && confirm(`Remove ${n} finished visit(s)? Export CSV first if you need detention proof.`)) { state.visits = state.visits.filter((v) => v.status !== "done"); persist(); render(); }
  };
  $("btnCSV").onclick = () => {
    const cols = ["name", "phone", "carrier", "ref", "trailer", "kind", "appt", "door", "status", "arrivedAt", "doorAt", "loadingAt", "doneAt"];
    const rows = state.visits.map((v) => [...cols.map((c) => v[c] ?? ""), dwell(v), detentionCost(v)]);
    const csv = [[...cols, "dwellMinutes", "estDetentionUSD"], ...rows].map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(",")).join("\n");
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
    a.download = `docktalk-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
  };

  // sync if the driver kiosk tab (same device) adds a check-in
  window.addEventListener("storage", (e) => { if (e.key === S.KEY) { state = S.load() || state; render(); } });

  let tt;
  function toast(msg) { const el = $("toast"); el.textContent = msg; el.classList.add("on"); clearTimeout(tt); tt = setTimeout(() => el.classList.remove("on"), 2600); }

  persist();
  render();
  setInterval(render, 30000);
  if ("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js").catch(() => {});
})();
