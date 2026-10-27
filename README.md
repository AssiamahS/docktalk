# DockTalk

Dock door + yard check-in board for small warehouses, cross-docks and 3PLs.

- **Live board:** https://assiamahs.github.io/docktalk/
- **Driver check-in (what the gate QR opens):** https://assiamahs.github.io/docktalk/checkin.html
- **Pricing / Start:** https://assiamahs.github.io/docktalk/sales.html

Drivers scan a QR at the guard shack and check in from their own phone (no app, no login). The check-in goes
to the dock phone as a structured text; the dock manager pastes it onto the board (or runs the check-in page in
kiosk mode on the same tablet: `checkin.html?kiosk=1`). The board shows every truck as **waiting / at door /
loading / done** with dwell timers that turn amber 30 min before free time runs out and red when detention
starts, an estimated detention dollar figure, a door grid, and one-tap "back into DOOR 5" texts. CSV export
gives timestamped check-in / door / release times for detention disputes.

## The business case

| | |
|---|---|
| **Buyer** | Owner / ops manager / dock lead at a 4-30 door warehouse, cross-dock, cold store or small 3PL that runs the yard off a whiteboard and a ringing phone. Not big DCs - they already run Opendock / C3 / FourKites. |
| **Pain** | Drivers call the office to ask "which door?", nobody can prove arrival times, and detention gets billed at $50-$80/hr after 2 free hours. |
| **Price** | **$49 per site / month**, unlimited doors and drivers. 30-day pilot, pay once it works at your dock. |
| **Why that price** | One avoided detention hour a month pays for it. Cheapest comparable tools: Loading Calendar ~$99/mo flat, DockSync from ~GBP 79/mo; Trac Ahead from ~$500/mo; Opendock / DataDocks are quote-only. |

### Evidence

- ATRI (via TruckNews / DAT): detention cost the for-hire industry about **$15B in 2023**; drivers were detained at **39% of stops** (56% for reefer), with about 10% of stops over 2 hours. https://www.trucknews.com/transportation/truck-driver-detention-costs-industry-15-billion-in-2023-atri , https://www.dat.com/blog/trucker-detention-is-still-a-15-billion-problem
- TruckersReport forums: drivers say receivers refuse to sign in/out times, so detention gets eaten. The timestamped check-in text and the CSV fix exactly this. https://www.thetruckersreport.com/truckingindustryforum/threads/detention-shipper-wait-pay.303134/ , https://www.thetruckersreport.com/truckingindustryforum/threads/what-does-your-carrier-contract-say-about-detention-pay-disputes.2537804/
- Competitor pricing: Loading Calendar $99/mo, DockSync GBP 79/mo starter with QR check-in, Trac Ahead from $500/mo. https://www.capterra.com/p/10049943/DockSync/ , https://www.capterra.com/p/10010959/Loading-Calendar/alternatives/ , https://www.softwareadvice.com/dock-scheduling/trac-ahead-profile
- Opendock's own QR driver check-in shows the workflow is standard at big DCs; small sites can't justify enterprise quotes. https://blog.opendock.com/driver-check-in
- Indie Hackers founders building with Claude: first customers come from narrow communities and personal outreach, not launches; untargeted cold email gets close to zero replies. https://www.indiehackers.com/post/i-built-a-saas-that-got-0-paying-customers-at-launch-distribution-was-the-real-problem-all-along-4b4ff41e74 , https://aimaker.substack.com/p/claude-code-ai-sales-agent

### First-dollar plan (24h)

1. Set `PAY_URL` (below) to a Stripe / Square / PayPal payment link for $49/mo, and `CONTACT` to your email or cell.
2. Walk in / call 10 local warehouses, cold stores and cross-docks (Google Maps "warehouse", "cold storage",
   "3PL" within 20 miles). Ask for the shipping/receiving lead, show the board on your phone, offer to tape up
   the gate QR today.
3. Post the outreach message in r/logistics, r/supplychain, r/warehouseworkers and LinkedIn warehouse-ops
   groups; DM ops managers who post about detention or yard chaos.
4. Close one pilot at $49, set it up the same day (print QR, set door count + dock phone).

## Set PAY_URL / CONTACT

Edit `web/config.js`:

```js
window.DOCKTALK_CONFIG = {
  PAY_URL: "https://buy.stripe.com/xxxxxxxx",   // "" = show request-access form instead
  CONTACT: "you@example.com",                    // email -> mailto, phone -> sms
  PRICE: "$49",
  PRICE_UNIT: "per site / month"
};
```

Commit and push; the `pages` workflow redeploys in about a minute.

## Repo layout

- `web/` - the product today. Vanilla HTML/CSS/JS, no build step, localStorage, installable PWA. Two panes at
  >= 700px wide (iPhone Duo inner display, iPad, desktop), single pane below.
- `ios/` - native SwiftUI app (XcodeGen, iOS 26.0+, `com.assiamah.docktalk`). `NavigationSplitView` collapses to
  a stack when folded and shows a real detail pane (door board / truck) when unfolded; selection in
  `@SceneStorage`, settings in `@AppStorage`, visits in SwiftData. On-device only.
- `.github/workflows/pages.yml` - deploys `web/` to GitHub Pages.
- `.github/workflows/ios.yml` - unsigned simulator build on the `xcode-27` runner image (iOS 27.1 SDK, so the app
  fills the iPhone Duo inner display instead of letterboxing).

Build the iOS app on a Mac with Xcode 27:

```sh
cd ios && xcodegen generate && open DockTalk.xcodeproj
```
