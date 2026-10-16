# Steal a Slime

A collect-and-steal tycoon for Roblox. Why this game: see [RESEARCH.md](RESEARCH.md).

Buy slimes off the conveyor, they earn cash every second and grow bigger (even offline), raid other bases to steal theirs, shield your own, rebirth for permanent multipliers.

## Files

```
StealASlime.rbxl          Ready-to-open place file (built from src/ with Rojo)
default.project.json      Rojo project
src/shared/Config.luau    ALL tuning: prices, slimes, rarities, timers, pass/product IDs
src/shared/Util.luau      Number formatting, growth stage math
src/server/Main.server.luau            Startup, join/leave, offline earnings, daily streak
src/server/Services/MapBuilder.luau    Builds the map from code (belt, 8 bases)
src/server/Services/PlotService.luau   Bases, pens, income, collecting, shield, rebirth
src/server/Services/ConveyorService.luau  Belt spawns, buying, Slime Rain events
src/server/Services/StealService.luau  Raiding and carrying slimes home
src/server/Services/MonetizationService.luau  Game passes + dev products (ProcessReceipt)
src/server/Services/DataService.luau   DataStore saving
src/client/Hud.client.luau             All UI
```

## 1. Test it in Studio (10 minutes)

1. Install Roblox Studio and sign in with your Roblox account.
2. Open `StealASlime.rbxl` (File > Open from File).
3. **Home > Game Settings > Security:** turn on *Enable Studio Access to API Services* so saving works in tests. (Studio asks you to publish first; you can do step 2.1 below, then come back.)
4. Press **Play**. Buy a Goop off the belt (hold E), stand on the green pad to collect, try the red shield button.
5. To test raiding: **Test > Clients and Servers > 2 Players > Start**.
6. To try the paid features without paying: set `Config.StudioOwnsAllPasses = true` in `ReplicatedStorage > Shared > Config`. Set it back to `false` before publishing.

## 2. Publish (needs your account; I can't do this part)

1. **File > Publish to Roblox**. Name: *Steal a Slime*. Genre: Simulation. Description: see below.
2. **Game Settings > Places > Max players: 8** (there are 8 bases).
3. Fill the experience questionnaire in Creator Hub (maturity: Minimal) so it shows to all ages.
4. Make it **Public** in Creator Hub > your experience > Configure.

Suggested description: *Buy slimes, grow them into giants, and STEAL the best ones from other players! Lock your base before thieves strike. Slime Rain every 15 minutes: rare slimes x5!*

## 3. Turn on monetization

Creator Hub > your experience > **Monetization**:

- **Passes**: create these four, then paste each ID into `Config.GamePasses`:
  2x Cash (199), VIP (299), Extra Pens (149), Auto Collect (99).
- **Developer Products**: create these six, paste IDs into `Config.Products`:
  Small Cash (25), Big Cash (99), Huge Cash (399), Shield 5 min (39), Grow Boost (49), Server Slime Rain (199).
- Prices in Roblox must match `price` in Config (Config's price is only what the shop button shows).
- Republish (File > Publish to Roblox) after pasting IDs.
- Also turn on **Private Servers** (Monetization > Private servers, e.g. 100 R$/month) and Premium Payouts happen automatically.

Need icons? Any square 512x512 image works; a screenshot of a glowing slime is fine to start.

## 4. Getting players (the hard part)

New games get almost no traffic by default. In order of cost:

1. **Free:** post short clips of steals/rare drops on TikTok/YouTube Shorts (this is how Steal a Brainrot blew up). Tell friends; first players matter for the algorithm's retention signal.
2. **Sponsored ads in Creator Hub** (Ads Manager): start with ~1,000-2,000 R$ ($10-25) to get first data. Watch Day-1 retention in Creator Hub Analytics; aim for 15%+ before spending more.
3. **Update weekly**: a new slime or event each week. Games that stop updating drop fast.

## 5. Numbers to watch (Creator Hub > Analytics)

| Metric | Healthy target |
|---|---|
| Day-1 retention | 15%+ |
| Day-7 retention | 5%+ |
| Avg session | 15+ min |
| Payer conversion | 1.5-3% |
| ARPDAU | 1-3 R$ |

Tuning knobs, all in `Config.luau`: slime prices/income (pace), `GrowthStages` (how often players return), `RebirthCost`, `SpawnInterval`, rarity weights.

## Rebuilding after code edits

With [Rojo](https://rojo.space): `rojo build default.project.json -o StealASlime.rbxl`, or `rojo serve` + the Rojo Studio plugin to live-sync.
