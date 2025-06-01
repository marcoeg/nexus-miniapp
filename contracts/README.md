# Nexus26 ‑ TON Prediction‑Market Smart‑Contracts

> **MVP scope:** 2026 FIFA World Cup prediction platform (simple 1×2, player‑prop, over/under & tournament‑progress markets) with points pre‑token phase, reputation & achievements, liquidity incentives and gas‑sponsored settlement.

---

## Repository layout

```
contracts/
  libraries/          ← compile first (pure code, no state)
    ErrorCodes.tact
    PlatformConstants.tact

  common/             ← shared mix‑ins
    AccessControl.tact

  managers/           ← stateful services
    StakeVault.tact
    TreasuryManager.tact
    PointsRegistry.tact
    ReputationManager.tact
    LiquidityManager.tact
    SettlementRouter.tact

  core/               ← per‑match logic
    MatchRegistry.tact
    OracleCoordinator.tact
    MarketFactory.tact
    PredictionMarket.tact
    OverUnderMarket.tact
    PlayerPerformanceMarket.tact
    TournamentProgressMarket.tact

  tokens/             ← non‑transferable & future Jetton code
    AchievementNFT.tact
    // RimetJetton.tact (to be added at token launch)

  utils/              ← optional helpers (off‑chain use)
    GasEstimator.tact
    BatchOperations.tact
    MarketStats.tact
    EmergencyController.tact
```

### Quick file map

| Path                      | Purpose                                                                                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **libraries/**            | Pure libraries: global constants (`PlatformConstants`) and error IDs (`ErrorCodes`). Must be deployed first as other contracts import them. |
| **common/AccessControl**  | Ownable + role‑based + pausable modifiers. All stateful contracts extend this.                                                              |
| **managers/**             | Platform‑wide singletons (vault, treasury, reputation, etc.).                                                                               |
| **core/**                 | One instance *per match* / market. `PredictionMarket` is the 1×2 base; other markets inherit and specialise.                                |
| **tokens/AchievementNFT** | Soul‑bound NFT granting bonus multipliers.                                                                                                  |
| **utils/**                | Non‑critical helpers for batching, gas estimation, stats, emergency ops.                                                                    |

---

## Prerequisites

* **Tact compiler** ≥ `v0.10.0`
  Install via npm:

  ```bash
  npm install -g tact-cli
  ```
* **Node.js** ≥ 18 (for Tact tooling).
* A local TON node or test‑net access for deployment (e.g. [toncli](https://github.com/ton-community/toncli) or \[tondev]).

---

## Compilation order

> Tact supports automatic dependency resolution, but on some versions you must deploy libraries first so addresses are known.

1. **Libraries**

   ```bash
   tact compile contracts/libraries/ErrorCodes.tact
   tact compile contracts/libraries/PlatformConstants.tact
   ```
2. **Common mix‑ins**

   ```bash
   tact compile contracts/common/AccessControl.tact
   ```
3. **Managers (singletons)** – compile & deploy in this order so addresses can be wired:

   ```bash
   tact compile contracts/managers/StakeVault.tact
   tact compile contracts/managers/TreasuryManager.tact
   tact compile contracts/managers/PointsRegistry.tact
   tact compile contracts/managers/ReputationManager.tact
   tact compile contracts/managers/LiquidityManager.tact
   tact compile contracts/managers/SettlementRouter.tact
   ```
4. **Tokens**

   ```bash
   tact compile contracts/tokens/AchievementNFT.tact
   ```
5. **Core protocol**

   ```bash
   tact compile contracts/core/MatchRegistry.tact
   tact compile contracts/core/OracleCoordinator.tact
   tact compile contracts/core/MarketFactory.tact
   tact compile contracts/core/PredictionMarket.tact
   tact compile contracts/core/OverUnderMarket.tact
   tact compile contracts/core/PlayerPerformanceMarket.tact
   tact compile contracts/core/TournamentProgressMarket.tact
   ```
6. **Utils** (optional)

   ```bash
   tact compile contracts/utils/*
   ```

You can batch‑compile everything with:

```bash
tact compile contracts/**/**/*.tact --output build/
```

---

## Deployment (test‑net quick‑start)

1. **Fund a key** on test‑net with a small amount of TON.
2. **Deploy libraries** – they produce addresses you’ll need for imports (if not using code‑salt addresses).

   ```bash
   tact deploy build/libraries/ErrorCodes.cell --wc -1 --value 1ton
   tact deploy build/libraries/PlatformConstants.cell --wc -1 --value 1ton
   ```
3. **Deploy AccessControl** (pure code so cheap).
4. **Deploy managers** – pass constructor params (owner address, jetton root, etc.).
5. **Deploy MatchRegistry** and **OracleCoordinator** supplying manager addresses.
6. **Deploy MarketFactory** with:

   * `matchRegistry` address
   * Code cells of market templates (output by compiler)
7. Use MarketFactory to create markets, then interact:

   ```bash
   tact run <MarketFactory> createSimpleMarket 1001   # match id 1001
   tact run <PredictionMarket> predict 0 10000000000  # 10 $RIMET on home win
   ```

Detailed scripts (TonConnect‑compatible) are in `scripts/` (add your own).

---

## Testing

A minimal `hardhat‑ton` test suite lives in `tests/` (not included here):

1. **Unit tests** for managers (fee splits, vault logic).
2. **Integration** happy‑path:

   * Create market
   * User stakes
   * Oracle posts result
   * SettlementRouter batch‑settles
   * Assert final Jetton balances, reputation, achievements.

Run with:

```bash
npm install
task test         # uses ton‑dev‑cli local node
```

---

## About \$RIMET Jetton

* `$RIMET` is **not** included in this repository because the tokenomics (supply,
  vesting, distribution) are still undergoing legal review.
* The contracts interact with `$RIMET` **abstractly** via Jetton‑wallet messages
  (standard op `0xf8a7ea5`).  When the Jetton root is launched, its address
  simply needs to be inserted into `PlatformConstants.JETTON_ROOT` and the
  system will function without redeploying other contracts.
* Conversion of pre‑token **Points** to `$RIMET` Jettons is triggered once the
  root is live by calling `PointsRegistry.enableConversion(rootAddress)` and
  then users claim via `convertToTokens()`.

---

## License

All contracts are released under **MIT** – see individual file headers.
