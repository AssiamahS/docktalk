// Start CTA: PAY_URL set -> checkout button. Empty -> request-access form composed to CONTACT.
(function () {
  const C = window.DOCKTALK_CONFIG || {};
  const $ = (id) => document.getElementById(id);
  if (C.PRICE) $("price").textContent = C.PRICE;
  if (C.PRICE_UNIT) $("unit").textContent = C.PRICE_UNIT;
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const box = $("ctaBox");
  if (C.PAY_URL) {
    box.innerHTML = `<h2 style="margin-bottom:10px">Start today</h2>
      <a class="btn sig cta" href="${esc(C.PAY_URL)}" rel="noopener">Start - ${esc(C.PRICE || "$49")}/mo</a>
      <p class="hint">Secure checkout. You'll get a setup call link right after payment.</p>`;
    return;
  }
  box.innerHTML = `<form id="req"><h2 style="margin-bottom:6px">Request a pilot</h2>
    <p class="hint">We set you up same day. Pay after you've seen it work at your dock.</p>
    <label for="rName">Name</label><input id="rName" required autocomplete="name">
    <label for="rCo">Warehouse / company + city</label><input id="rCo" required autocomplete="organization">
    <div class="row2"><div><label for="rDoors">Dock doors</label><input id="rDoors" type="number" min="1" inputmode="numeric"></div>
    <div><label for="rTrucks">Trucks / day</label><input id="rTrucks" type="number" min="1" inputmode="numeric"></div></div>
    <label for="rReach">Best phone or email</label><input id="rReach" required>
    <button class="btn sig cta" style="margin-top:14px">Start</button>
    <p class="hint" id="rOut"></p></form>`;
  $("req").addEventListener("submit", (e) => {
    e.preventDefault();
    const body = `DockTalk pilot request\nName: ${$("rName").value}\nSite: ${$("rCo").value}\nDoors: ${$("rDoors").value}\nTrucks/day: ${$("rTrucks").value}\nReach me: ${$("rReach").value}`;
    const c = (C.CONTACT || "").trim();
    if (c.includes("@")) location.href = `mailto:${c}?subject=${encodeURIComponent("DockTalk pilot request")}&body=${encodeURIComponent(body)}`;
    else if (c.replace(/\D/g, "").length >= 7) {
      const ios = /iPhone|iPad|iPod|Macintosh/.test(navigator.userAgent);
      location.href = `sms:${c.replace(/[^\d+]/g, "")}${ios ? "&" : "?"}body=${encodeURIComponent(body)}`;
    } else {
      $("rOut").innerHTML = `Copy this and send it to the person who shared this page:<br><span class="mono" style="white-space:pre-wrap">${esc(body)}</span>`;
      return;
    }
    $("rOut").textContent = "Opening your mail / messages app...";
  });
})();
