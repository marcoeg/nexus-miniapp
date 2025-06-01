Below is the **end‑to‑end operational playbook** for a single football fixture on Nexus26—written from the viewpoint of a platform operator (admin / match‑manager account). Function names refer to the Tact contracts you now have in the repo.

---

## 1 . Pre‑tournament bootstrap (one‑time)

| Step | Action                                             | Contract / Call                                                                                                                  | Notes                                                           |
| ---- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| 1‑A  | Deploy core libraries & helpers                    | `PlatformConstants`, `ErrorCodes`, `AccessControl`                                                                               | Done once.                                                      |
| 1‑B  | Deploy manager layer                               | `StakeVault`, `TreasuryManager`, `ReputationManager`, `LiquidityManager`, `PointsRegistry`, `SettlementRouter`, `AchievementNFT` | Pass `$RIMET` Jetton‑root addr to StakeVault & TreasuryManager. |
| 1‑C  | Deploy **MatchRegistry** and **OracleCoordinator** | `MatchRegistry(owner)` → address **R**<br>`OracleCoordinator(owner, R, [oracle1, oracle2…])`                                     | Registry address **R** will be referenced by every market.      |
| 1‑D  | Deploy **MarketFactory**                           | `MarketFactory(owner, R, codeSimple, codePlayer, codeOU, codeTP)`                                                                | `code*` = raw‑code cells of compiled market classes.            |

---

## 2 . Set up a fixture & markets (per match)

| Step | When                             | What you do                                                                                                                                         | Call / Params                                                                                                                                                        |
| ---- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2‑A  | As soon as fixture list is known | **Register the match**                                                                                                                              | `MatchRegistry.addMatch(matchId, kickoffTs, teamMeta, msg.sender)`                                                                                                   |
| 2‑B  | Immediately after                | **Create 1×2 market**                                                                                                                               | `MarketFactory.createSimpleMarket(matchId)`                                                                                                                          |
| 2‑C  | Optionally                       | **Create special markets**<br>• First‑scorer goals ≥ 1? → PlayerPerformance<br>• O/U 2.5 goals → OverUnder<br>• Team reach QF? → TournamentProgress | `createPlayerMarket(matchId, playerId, statType, threshold)`<br>`createOverUnderMarket(matchId, 25)`  // 2.5 goals<br>`createTournamentMarket(matchId, 2 /*QF*/, 0)` |
| 2‑D  | Right after deployment           | **Seed initial odds** (only for UI; contract is pari‑mutuel)                                                                                        | Off‑chain DB or subgraph; no on‑chain call needed.                                                                                                                   |
| 2‑E  | Anytime before kickoff           | **Open market** (if you set it ‘Inactive’ first)                                                                                                    | `MatchRegistry.openMarket(matchId)`                                                                                                                                  |

---

## 3 . Users deposit & predict

| Actor                         | What happens on‑chain                                               |
| ----------------------------- | ------------------------------------------------------------------- |
| User                          | `StakeVault.deposit(100 $RIMET)` – one‑time activation stake        |
| User                          | Approves Jetton transfer to market (wallet UX)                      |
| User                          | `PredictionMarket.predict(outcome, amount)` (or specialised market) |
| Market                        | Updates odds pools and emits `Predicted`                            |
| Liquidity Provider (optional) | `LiquidityManager.provideLiquidity(marketAddr, amount)`             |

---

## 4 . Kick‑off guard & market close

* A keeper bot calls `MatchRegistry.closeMarket(matchId)` exactly
  **15 min before group‑stage kickoff / 30 min for knockouts / 60 min for final**.
  Prediction functions revert after this flag.

---

## 5 . Result ingestion (oracle flow)

| Step | Actor       | Call                                                                                                              |
| ---- | ----------- | ----------------------------------------------------------------------------------------------------------------- |
| 5‑A  | Oracle #1   | `OracleCoordinator.submit({matchKey, winner})`                                                                    |
| 5‑B  | Oracle #2   | Same payload                                                                                                      |
| 5‑C  | Coordinator | Reaches 2‑of‑N consensus → sends internal msg → `MatchRegistry.setResult(matchId, winner)` (emits `ResultPosted`) |

*(If an oracle key mis‑behaves you can `removeOracle(addr)` and, in an emergency, push a manual result from an owner wallet.)*

---

## 6 . Settlement & payouts

| Step | Who triggers  | On‑chain flow                                                                                                                                                                                                                                                          |
| ---- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 6‑A  | Bot or anyone | `SettlementRouter.enqueueSettlement(market, totalValue)` for every affected market                                                                                                                                                                                     |
| 6‑B  | Bot           | `SettlementRouter.settleBatch(n)`<br>• Router loops `PredictionMarket.settle(winner)` and pays TON gas.                                                                                                                                                                |
| 6‑C  | Market.settle | • Calculates losers’ pool → calls `TreasuryManager.distributeLosingStakes()` (85/10/5 split).<br>• Computes each winner reward using `ReputationManager.multiplierOf()` + `AchievementNFT.bonusOf()`.<br>• Transfers Jettons to winners.<br>• Emits `Settled(winner)`. |
| 6‑D  | StakeVault    | For every user whose last open position closed, the market (via admin hook) calls `decrementPositions`; when positions==0 the user can withdraw activation stake.                                                                                                      |

---

## 7 . Post‑settlement updates

| Contract            | Call                                                                                     | Effect                                     |
| ------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------ |
| `ReputationManager` | `addResult(user, correct?, stake, oddsBucket)` (via market)                              | Adjusts rep 0‑100, emits `ScoreChanged`.   |
| `PointsRegistry`    | `releasePredictionSlot(user)`                                                            | Frees one of five active‑prediction slots. |
| `AchievementNFT`    | Market (or off‑chain bot) mints new achievements when criteria met (e.g., 5‑win streak). |                                            |
| `LiquidityManager`  | Market calls `recordFees( fee )`                                                         | Updates APY stats for LPs.                 |

---

## 8 . Edge‑case / emergency operations

| Scenario               | Action                                                                                         |
| ---------------------- | ---------------------------------------------------------------------------------------------- |
| Need to pause a market | `EmergencyController.pauseMarket(mktAddr)` – `whenNotPaused` guard blocks further predictions. |
| Drain stuck Jettons    | `EmergencyController.drainToTreasury(mktAddr, TREASURY_WALLET)` (owner only).                  |
| User needs funds early | StakeVault `emergencyUnlock(1000 BPS)` → returns 90 \$RIMET, burns 10 \$RIMET as penalty.      |

---

## 9 . Daily / weekly cron tasks

| Frequency | Task                                | Call                                                    |
| --------- | ----------------------------------- | ------------------------------------------------------- |
| Weekly    | Issue engagement points             | `PointsRegistry.allocateWeeklyPoints([addr1, addr2 …])` |
| Daily     | Top‑up SettlementRouter TON balance | Send TON (`>>`) or call `SettlementRouter.topUp()`      |
| As needed | Rotate oracle keys                  | `OracleCoordinator.addOracle / removeOracle`            |

---

### About \$RIMET Jetton in this flow

* Until the real `$RIMET` root is deployed, tests use a **mock Jetton root**; its
  address is passed to **StakeVault**, **TreasuryManager**, **LiquidityManager**.
* At main‑net launch you simply deploy the official Jetton root, fund users’
  Jetton wallets, and **update the root address in new contract deployments**.
  Existing markets remain valid because transfers rely on the wallet interface
  (op `0xf8a7ea5`)—only the root address differs.

---

Follow these steps and your prediction platform will cycle smoothly from match
creation through final reputation updates—all on‑chain and audit‑friendly.
