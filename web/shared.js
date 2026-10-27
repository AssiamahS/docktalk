// Shared between the door board (app.js) and the driver check-in page (checkin.js).
// The check-in text is the "wire format": the driver's phone sends it by SMS to the dock phone,
// the dock manager pastes it into the board. No server, nothing to host, works today.
(function (g) {
  const KEY = "docktalk.v1";
  const FIELDS = [
    ["name", "Driver"], ["phone", "Cell"], ["carrier", "Carrier"], ["ref", "Ref"],
    ["trailer", "Trailer"], ["kind", "Type"], ["appt", "Appt"], ["arrivedAt", "Arrived"], ["notes", "Notes"]
  ];

  function encodeCheckin(v) {
    const lines = ["DOCKTALK CHECKIN"];
    for (const [k, label] of FIELDS) {
      let val = v[k];
      if (k === "kind") val = val === "outbound" ? "Outbound" : "Inbound";
      if (val) lines.push(`${label}: ${String(val).replace(/\s+/g, " ").trim()}`);
    }
    return lines.join("\n");
  }

  function parseCheckins(text) {
    const out = [];
    const blocks = String(text || "").split(/DOCKTALK\s+CHECKIN/i).slice(1);
    for (const b of blocks) {
      const v = {};
      for (const raw of b.split(/\n/)) {
        const m = raw.match(/^\s*([A-Za-z]+)\s*:\s*(.*)$/);
        if (!m) continue;
        const f = FIELDS.find(([, label]) => label.toLowerCase() === m[1].toLowerCase());
        if (f) v[f[0]] = m[2].trim();
      }
      if (!v.name) continue;
      v.kind = /out|pick/i.test(v.kind || "") ? "outbound" : "inbound";
      const t = Date.parse(v.arrivedAt || "");
      v.arrivedAt = Number.isFinite(t) ? new Date(t).toISOString() : new Date().toISOString();
      out.push(v);
    }
    return out;
  }

  function smsHref(number, body) {
    const n = String(number || "").replace(/[^\d+]/g, "");
    const ios = /iPhone|iPad|iPod|Macintosh/.test(navigator.userAgent);
    return `sms:${n}${ios ? "&" : "?"}body=${encodeURIComponent(body)}`;
  }

  function load() {
    try { return JSON.parse(localStorage.getItem(KEY)) || null; } catch { return null; }
  }
  function save(state) {
    try { localStorage.setItem(KEY, JSON.stringify(state)); return true; } catch { return false; }
  }
  function uid() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 7); }

  g.DockShared = { encodeCheckin, parseCheckins, smsHref, load, save, uid, KEY };
})(window);
