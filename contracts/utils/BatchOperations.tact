// SPDX‑License‑Identifier: MIT
import "../common/AccessControl.tact";
import "../libraries/ErrorCodes.tact";

contract BatchOperations {

    uint8 constant MAX_BATCH = 10;

    /// batch predict – user calls once, this contract forwards
    external fn batchPredict(
        address[] markets,
        uint8[]   outcomes,
        uint128[] amounts
    ) {
        require(markets.length == outcomes.length &&
                markets.length == amounts.length,
                ErrorCodes.ERR_BAD_INPUT);
        require(markets.length <= MAX_BATCH, ErrorCodes.ERR_BATCH_TOO_LARGE);

        for (uint8 i = 0; i < markets.length; ++i) {
            var body = beginCell()
                .storeUint(0, 32)          // selector not used
                .storeUint(outcomes[i], 8)
                .storeUint(amounts[i], 128)
                .endCell();

            sendInternalMessage(
                msg.sender,
                markets[i],
                0.3 ton,
                false,
                body
            );
        }
    }
}
