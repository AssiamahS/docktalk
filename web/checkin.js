// Driver check-in. Two modes:
//  - phone mode (default, from the gate QR): composes an SMS to the dock phone (?to=) with a
//    DOCKTALK CHECKIN text the manager pastes into the board. The text thread doubles as the
//    driver's timestamped arrival record for detention claims.
//  - kiosk mode (?kiosk=1, a tablet at the shack on the same device as the board): writes straight to the board.
(function () {
  const S = window.DockShared;
  const p = new URLSearchParams(location.search);
  const site = p.get("site") || "";
  const to = p.get("to") || "";
  const kiosk = p.get("kiosk") === "1";
  const $ = (id) => document.getElementById(id);
  $("siteName").textContent = site;
  if (site) document.title = `Check in - ${site}`;
  try { const last = JSON.parse(localStorage.getItem("docktalk.driver") || "{}"); for (const k of ["name", "phone", "carrier"]) if (last[k]) $(k).value = last[k]; } catch {}
  if (kiosk) $("note").textContent = "Kiosk mode: goes straight onto the door board.";
  else if (!to) $("note").textContent = "This link has no dock phone set - your message app will open so you can pick who to send it to.";

  $("f").addEventListener("submit", (e) => {
    e.preventDefault();
    const f = e.target, v = {};
    for (const k of ["name", "phone", "carrier", "ref", "trailer", "appt", "notes"]) v[k] = f.elements[k].value.trim();
    v.kind = f.elements.kind.value;
    v.arrivedAt = new Date().toISOString();
    try { localStorage.setItem("docktalk.driver", JSON.stringify({ name: v.name, phone: v.phone, carrier: v.carrier })); } catch {}
    if (kiosk) {
      const st = S.load() || { settings: { site: site || "Main DC", doors: 8, free: 120, rate: 60, phone: "" }, visits: [] };
      st.visits.push({ id: S.uid(), status: "waiting", door: null, ...v });
      S.save(st);
    } else {
      location.href = S.smsHref(to, S.encodeCheckin(v));
    }
    $("doneTime").textContent = "Arrived " + new Date(v.arrivedAt).toLocaleString();
    f.hidden = true; $("done").hidden = false;
  });
  $("again").onclick = () => { $("f").reset(); $("f").hidden = false; $("done").hidden = true; };
})();
