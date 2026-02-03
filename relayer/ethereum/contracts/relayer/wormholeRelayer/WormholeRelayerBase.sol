// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.19;

import {IWormhole} from "../../interfaces/IWormhole.sol";
import {IDeliveryProvider} from "../../interfaces/relayer/IDeliveryProviderTyped.sol";
import {toWormholeFormat, min, pay} from "../../relayer/libraries/Utils.sol";
import {
    ReentrantDelivery,
    DeliveryProviderDoesNotSupportTargetChain,
    VaaKey,
    InvalidMsgValue,
    IWormholeRelayerBase
} from "../../interfaces/relayer/IWormholeRelayerTyped.sol";
import {DeliveryInstruction} from "../../relayer/libraries/RelayerInternalStructs.sol";
import {
    DeliveryTmpState,
    getDeliveryTmpState,
    getDeliverySuccessState,
    getDeliveryFailureState,
    getRegisteredWormholeRelayersState,
    getReentrancyGuardState
} from "./WormholeRelayerStorage.sol";
import "../../interfaces/relayer/TypedUnits.sol";

/**
 * @title WormholeRelayerBase
 * @notice Abstract base contract for Wormhole cross-chain relayer functionality.
 *         Provides core delivery, publishing, and state management for cross-chain messaging.
 * @dev This contract implements the IWormholeRelayerBase interface and handles:
 *      - Message publishing with fee payment
 *      - Delivery tracking (success/failure)
 *      - Refund information management
 *      - Reentrancy protection
 *      Inherited by WormholeRelayerSend and WormholeRelayerDelivery contracts.
 */
abstract contract WormholeRelayerBase is IWormholeRelayerBase {
    using WeiLib for Wei;
    using GasLib for Gas;
    using WeiPriceLib for WeiPrice;
    using GasPriceLib for GasPrice;
    using LocalNativeLib for LocalNative;

    /// @notice Finalized consistency level for standard message delivery
    /// @dev Messages at this level wait for finality before being processed
    uint8 internal constant CONSISTENCY_LEVEL_FINALIZED = 15;

    /// @notice Instant consistency level for immediate message delivery
    /// @dev Messages at this level are processed immediately without waiting for finality
    uint8 internal constant CONSISTENCY_LEVEL_INSTANT = 200;

    /// @notice Reference to the Wormhole core bridge contract
    IWormhole private immutable wormhole_;

    /// @notice This chain's Wormhole chain ID
    uint16 private immutable chainId_;

    /**
     * @notice Constructor sets up the contract with Wormhole core bridge reference
     * @param _wormhole The address of the Wormhole core bridge contract
     */
    constructor(address _wormhole) {
        wormhole_ = IWormhole(_wormhole);
        chainId_ = uint16(wormhole_.chainId());
    }

    /**
     * @notice Gets the registered WormholeRelayer contract address for a target chain
     * @param chainId The Wormhole chain ID of the target chain
     * @return The bytes32-encoded address of the registered relayer on target chain
     */
    function getRegisteredWormholeRelayerContract(uint16 chainId) public view returns (bytes32) {
        return getRegisteredWormholeRelayersState().registeredWormholeRelayers[chainId];
    }

    /**
     * @notice Checks if a delivery attempt has been made for a given delivery hash
     * @param deliveryHash The hash of the delivery VAA
     * @return attempted True if delivery was attempted (success or failure)
     */
    function deliveryAttempted(bytes32 deliveryHash) public view returns (bool attempted) {
        return getDeliverySuccessState().deliverySuccessBlock[deliveryHash] != 0 ||
            getDeliveryFailureState().deliveryFailureBlock[deliveryHash] != 0;
    }

    /**
     * @notice Gets the block number when a delivery succeeded
     * @param deliveryHash The hash of the delivery VAA
     * @return blockNumber The block number of successful delivery (0 if not found)
     */
    function deliverySuccessBlock(bytes32 deliveryHash) public view returns (uint256 blockNumber) {
        return getDeliverySuccessState().deliverySuccessBlock[deliveryHash];
    }

    /**
     * @notice Gets the block number when a delivery failed
     * @param deliveryHash The hash of the delivery VAA
     * @return blockNumber The block number of failed delivery (0 if not found)
     */
    function deliveryFailureBlock(bytes32 deliveryHash) public view returns (uint256 blockNumber) {
        return getDeliveryFailureState().deliveryFailureBlock[deliveryHash];
    }

    //Our get functions require view instead of pure (despite not actually reading storage) because
    //  they can't be evaluated at compile time. (https://ethereum.stackexchange.com/a/120630/103366)

    /**
     * @notice Gets the reference to the Wormhole core bridge
     * @return The IWormhole interface to the core bridge
     */
    function getWormhole() internal view returns (IWormhole) {
        return wormhole_;
    }

    /**
     * @notice Gets this contract's chain ID in Wormhole's format
     * @return The uint16 chain ID
     */
    function getChainId() internal view returns (uint16) {
        return chainId_;
    }

    /**
     * @notice Gets the current message fee for publishing to Wormhole
     * @return The message fee in local native currency
     */
    function getWormholeMessageFee() internal view returns (LocalNative) {
        return LocalNative.wrap(getWormhole().messageFee());
    }

    /**
     * @notice Gets the native value sent with the current transaction
     * @return The msg.value in local native currency
     */
    function msgValue() internal view returns (LocalNative) {
        return LocalNative.wrap(msg.value);
    }

    /**
     * @notice Validates that the sent value matches the expected payment
     * @param wormholeMessageFee The fee for publishing to Wormhole
     * @param deliveryQuote The quoted price for delivery
     * @param paymentForExtraReceiverValue Additional payment for receiver value
     * @dev Reverts if total msg.value doesn't match expected total
     */
    function checkMsgValue(
        LocalNative wormholeMessageFee,
        LocalNative deliveryPrice,
        LocalNative paymentForExtraReceiverValue
    ) internal view {
        if (msgValue() != deliveryPrice + paymentForExtraReceiverValue + wormholeMessageFee) {
            revert InvalidMsgValue(
                msgValue(), deliveryPrice + paymentForExtraReceiverValue + wormholeMessageFee
            );
        }
    }

    /**
     * @notice Publishes a message to Wormhole and pays the delivery provider
     * @param wormholeMessageFee The fee to publish the message
     * @param deliveryQuote The quoted price for delivery
     * @param paymentForExtraReceiverValue Additional payment for receiver value
     * @param encodedInstruction The encoded delivery instruction
     * @param consistencyLevel The consistency level for the message
     * @param rewardAddress The address to receive payment
     * @return sequence The sequence number of the published message
     * @return paymentSucceeded True if payment to reward address succeeded
     */
    function publishAndPay(
        LocalNative wormholeMessageFee,
        LocalNative deliveryQuote,
        LocalNative paymentForExtraReceiverValue,
        bytes memory encodedInstruction,
        uint8 consistencyLevel,
        address payable rewardAddress
    ) internal returns (uint64 sequence, bool paymentSucceeded) {
        sequence = getWormhole().publishMessage{value: wormholeMessageFee.unwrap()}(
            0, encodedInstruction, consistencyLevel
        );

        paymentSucceeded = pay(
            rewardAddress,
            deliveryQuote + paymentForExtraReceiverValue
        );

        emit SendEvent(sequence, deliveryQuote, paymentForExtraReceiverValue);
    }

    /**
     * @notice Reentrancy guard modifier for delivery functions
     * @dev Prevents reentrant calls to critical delivery functions
     */
    modifier nonReentrant() {
        // Reentrancy guard
        if (getReentrancyGuardState().lockedBy != address(0)) {
            revert ReentrantDelivery(msg.sender, getReentrancyGuardState().lockedBy);
        }
        getReentrancyGuardState().lockedBy = msg.sender;

        _;

        getReentrancyGuardState().lockedBy = address(0);
    }

     // ----------------------- delivery transaction temorary storage functions -----------------------

    /**
     * @notice Records refund information for a delivery
     * @param refundChain The Wormhole chain ID for the refund destination
     * @param refundAddress The bytes32-encoded address for the refund
     */
    function recordRefundInformation(uint16 refundChain, bytes32 refundAddress) internal {
        DeliveryTmpState storage state = getDeliveryTmpState();
        state.refundChain = refundChain;
        state.refundAddress = refundAddress;
    }

    /**
     * @notice Clears the stored refund information
     */
    function clearRefundInformation() internal {
        DeliveryTmpState storage state = getDeliveryTmpState();
        state.refundChain = 0;
        state.refundAddress = bytes32(0);
    }

    /**
     * @notice Gets the current refund chain for the active delivery
     * @return The Wormhole chain ID for refund
     */
    function getCurrentRefundChain() internal view returns (uint16) {
        return getDeliveryTmpState().refundChain;
    }

    /**
     * @notice Gets the current refund address for the active delivery
     * @return The bytes32-encoded refund address
     */
    function getCurrentRefundAddress() internal view returns (bytes32) {
        return getDeliveryTmpState().refundAddress;
    }
}
