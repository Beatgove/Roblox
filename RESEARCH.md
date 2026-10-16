# Roblox research: what's winning in October 2026, and why

## 1. Most played right now

Live concurrent players (CCU), snapshot 16 Oct 2026, from [livecounts.nl](https://livecounts.nl/roblox-charts/):

| # | Game | Genre | Playing now |
|---|---|---|---|
| 1 | Steal An Egg | Collect + steal tycoon | 1,530,599 |
| 2 | Brookhaven RP | Open roleplay | 472,565 |
| 3 | Adopt Me! | Pet roleplay / trading | 385,652 |
| 4 | Murder Mystery 2 | Social deduction | 253,717 |
| 5 | 99 Nights in the Forest | Co-op survival | 248,898 |
| 6 | Blox Fruits | Action RPG / trading | 223,315 |
| 7 | RIVALS | Competitive shooter | 205,188 |
| 8 | Jujutsu Shenanigans | Anime fighting | 151,269 |
| 9 | Break and Steal an Egg | Collect + steal tycoon | 139,944 |
| 10 | Dandy's World | Survival horror | 134,210 |
| 11 | Steal a Brainrot | Collect + steal tycoon | 110,047 |
| 12 | +1 Speed Keyboard Escape | Incremental obby | 90,699 |
| 14 | Fisch | Collection sim | 78,937 |
| 16 | Fish It! | Collection sim | 74,390 |
| 20 | Dress To Impress | Fashion roleplay | 69,498 |

Two months earlier (20 Aug 2026, [StudioKrew](https://studiokrew.com/blog/top-roblox-games-august-2026/)) the top 10 also had Animal Hospital, +1 Speed Monkey Escape and Grow a Garden 2. Rankings churn fast; counts swing 2 to 3x within a day.

**Most active ever:** Steal a Brainrot peaked at 25.4M CCU (Oct 2025) and Grow a Garden passed 20M; their joint "admin war" event set the platform record of 47.4M concurrent ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot)). Long-run giants by visits remain Brookhaven, Adopt Me!, Blox Fruits, MM2 and RIVALS (17.5B visits).

## 2. Patterns behind the winners

1. **Collect → passive income → steal** is the dominant 2025-26 formula (Steal a Brainrot, Steal An Egg, Grow a Garden). Buy units off a conveyor, they earn money while you're away, other players can raid your base, you defend with a timed lock. Theft creates drama, clips and revenge sessions.
2. **Tiny, readable core loop.** Every top new game shows a satisfying cycle in under 10 minutes. +1 Speed games are one mechanic plus rebirth.
3. **Rarity ladders + rebirth.** Common → Secret tiers give a chase; rebirth resets for a permanent multiplier, so progress never caps.
4. **Real-time timers as reasons to return.** Crops growing, eggs hatching, offline earnings. This matters because discovery now weights **return rate** (24h/72h) over CCU or session length ([RoWatcher](https://rowatcher.com/news/what-the-roblox-algorithm-actually-rewards-in-2026-not-ccu), [Roblox DevForum](https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441)).
5. **Scheduled live events** ("admin abuse", limited spawns) create CCU spikes and FOMO.
6. **Social first.** Small servers (Steal An Egg caps at 7 so each theft is personal), trading economies (Adopt Me!, Blox Fruits, MM2).
7. **Speed beats polish.** Grow a Garden's first version was built in about 3 days by a 16-year-old. 28% of the top 100 games by hours launched in the last 90 days ([IBTimes](https://www.ibtimes.co.uk/roblox-top-creators-devex-payouts-2026-1819403)).
8. **Fast decay without updates.** Grow a Garden 2 fell 66% in a month. Weekly content drops are required.

## 3. The money

- **DevEx:** $0.0038 per earned Robux (30,000 R$ = $114), min 30,000 R$ to cash out, age 13+, tax form required. US-verified 18+ purchases pay $0.0054 ([Roblox docs](https://create.roblox.com/docs/en-us/production/monetization/developer-exchange.md)).
- **Roblox fee:** creator keeps ~70% of game pass / dev product sales ([creation.dev](https://www.creation.dev/learn/how-to-price-game-passes-roblox)).
- **Sweet-spot prices:** 49 to 199 R$ for volume; multipliers 99 to 249; VIP bundles 199 to 499; whale items 1,000+.
- **Other streams:** Premium Payouts (automatic, based on Premium members' playtime), private servers, and Rewarded Video ads (needs 100K+ DAU, so later) ([DevForum](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678)).
- **Reality check:** $1.7B paid out in 12 months, but the top 10 creators took 39%, and the **median payout across 42,000 creators was about $1,500**. Most games make nothing; a hit makes millions. Expect to iterate on several releases.

Rough math: 1 Robux of player spend ≈ $0.0027 to us after fee and DevEx. A game with 1,000 daily players and a typical 2% paying ~150 R$/day ≈ 3,000 R$/day ≈ **$8/day ≈ $240/month**. At 10,000 DAU ≈ $2,400/month.

## 4. Recommended concept: **Steal a Slime**

A collect-and-steal tycoon (the #1 formula right now) with a growth twist for return rate.

- **Loop:** Slimes slide down a central conveyor with rarities (Common → Secret). Buy one with cash, carry it to your base, it earns cash per second. Raid other bases, grab a slime, run it home. Hit your base button to lock it for 60s.
- **Twist (return hook):** Slimes **grow** in real time, including while offline, raising their income. Coming back the next day means fatter slimes and an offline earnings pop-up.
- **Rebirth:** reset cash and slimes for a permanent +50% income multiplier and one more pen slot.
- **Events:** a server-wide "Slime Rain" every 15 minutes with boosted rare spawns (a built-in mini "admin abuse").
- **Why buildable fast:** simple primitive art (glowing coloured blobs look good), no animation rigs, all systems in code.

## 5. Monetization plan

Game passes (one-time):
| Pass | Price | Effect |
|---|---|---|
| 2x Cash | 199 R$ | Double all income |
| VIP | 299 R$ | +25% income, gold name tag, VIP lock lasts 2x |
| Extra Pens | 149 R$ | +4 pen slots |
| Auto Collect | 99 R$ | Cash flows in without stepping on the collector |

Developer products (repeatable):
| Product | Price | Effect |
|---|---|---|
| Small / Big / Huge Cash | 25 / 99 / 399 R$ | Cash scaled to your income |
| Instant Lock (5 min) | 39 R$ | Base can't be raided for 5 min |
| Grow Boost | 49 R$ | Instantly grows all your slimes one stage |
| Server Slime Rain | 199 R$ | Triggers a Slime Rain for the whole server (social, everyone benefits) |

Deliberately avoided: paid random rewards (Roblox requires shown odds and they invite scrutiny), and selling the best slimes for Robux (Steal a Brainrot was criticized as pay-to-win). Everything purchasable is also reachable through play.

Later, when the game crosses 100K DAU: Rewarded Video ("watch an ad for 2x cash for 10 min").
