// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.19;

import "../../interfaces/relayer/TypedUnits.sol";
import "../../interfaces/relayer/IWormholeRelayerTyped.sol";

/**
 * @title RelayerInternalStructs
 * @notice Internal data structures for Wormhole cross-chain relayer operations.
 *         Defines the core instruction types for delivery and redelivery operations.
 * @dev This library contains the message structures used internally by the relayer
 *      to encode and process cross-chain delivery instructions.
 */

/**
 * @notice Represents a user's request to deliver a message to a target chain
 * @dev This is the primary instruction type for initiating cross-chain deliveries
 * @custom:member targetChain The Wormhole chain ID of the destination chain
 * @custom:member targetAddress The bytes32-encoded address to call on target chain
 * @custom:member payload The calldata to execute on the target chain
 * @custom:member requestedReceiverValue The amount of target chain native tokens to send with the call
 * @custom:member extraReceiverValue Additional receiver value for processing fees
 * @custom:member encodedExecutionInfo Packed execution parameters (gas limit, refund rate)
 * @custom:member refundChain The chain to refund any overpayment to
 * @custom:member refundAddress The address to refund to on the refund chain
 * @custom:member refundDeliveryProvider The delivery provider receiving the refund
 * @custom:member sourceDeliveryProvider The provider processing this delivery
 * @custom:member senderAddress The address that initiated the delivery request
 * @custom:member messageKeys Optional VAA keys to include with the delivery
 */
struct DeliveryInstruction {
    uint16 targetChain;
    bytes32 targetAddress;
    bytes payload;
    TargetNative requestedReceiverValue;
    TargetNative extraReceiverValue;
    bytes encodedExecutionInfo;
    uint16 refundChain;
    bytes32 refundAddress;
    bytes32 refundDeliveryProvider;
    bytes32 sourceDeliveryProvider;
    bytes32 senderAddress;
    MessageKey[] messageKeys;
}

/**
 * @title EVM-specific delivery instruction
 * @notice Internal structure for EVM chain delivery execution
 * @dev Meant to hold all necessary values for `CoreRelayerDelivery::executeInstruction`
 *      Nothing more and nothing less.
 * @custom:member sourceChain The Wormhole chain ID of the source chain
 * @custom:member targetAddress The EVM address (bytes32) to call
 * @custom:member payload The calldata to execute
 * @custom:member gasLimit The gas limit for target execution
 * @custom:member totalReceiverValue Total native tokens to send with call
 * @custom:member targetChainRefundPerGasUnused Refund rate per unused gas unit
 * @custom:member senderAddress The original sender's address
 * @custom:member deliveryHash Hash of the delivery VAA
 * @custom:member signedVaas Array of signed VAAs for this delivery
 */
struct EvmDeliveryInstruction {
  uint16 sourceChain;
  bytes32 targetAddress;
  bytes payload;
  Gas gasLimit;
  TargetNative totalReceiverValue;
  GasPrice targetChainRefundPerGasUnused;
  bytes32 senderAddress;
  bytes32 deliveryHash;
  bytes[] signedVaas;
}

/**
 * @notice Represents a request to redeliver/retry a failed delivery
 * @dev Allows users to modify parameters and retry a failed cross-chain delivery
 * @custom:member deliveryVaaKey The VAA key of the failed delivery
 * @custom:member targetChain The destination chain for redelivery
 * @custom:member newRequestedReceiverValue Updated receiver value for the redelivery
 * @custom:member newEncodedExecutionInfo Updated execution parameters
 * @custom:member newSourceDeliveryProvider Updated source delivery provider
 * @custom:member newSenderAddress Updated sender address
 */
struct RedeliveryInstruction {
    VaaKey deliveryVaaKey;
    uint16 targetChain;
    TargetNative newRequestedReceiverValue;
    bytes newEncodedExecutionInfo;
    bytes32 newSourceDeliveryProvider;
    bytes32 newSenderAddress;
}

/**
 * @notice Parameters to override a failed delivery attempt
 * @dev When a user requests a `resend()`, a `RedeliveryInstruction` is emitted by the
 *     WormholeRelayer and in turn converted by the relay provider into an encoded (=serialized)
 *     `DeliveryOverride` struct which is then passed to `delivery()` to override the parameters of
 *     a previously failed delivery attempt.
 *
 * @custom:member newReceiverValue must >= than the `receiverValue` specified in the original
 *     `DeliveryInstruction`
 * @custom:member newExecutionInfo for EVM_V1, must contain a gasLimit and targetChainRefundPerGasUnused
 * such that 
 * - gasLimit is >= the `gasLimit` specified in the `executionParameters`
 *     of the original `DeliveryInstruction`
 * - targetChainRefundPerGasUnused is >=  the `targetChainRefundPerGasUnused` specified in the original
 *     `DeliveryInstruction`
 * @custom:member redeliveryHash the hash of the redelivery which is being performed
 */
struct DeliveryOverride {
    TargetNative newReceiverValue;
    bytes newExecutionInfo;
    bytes32 redeliveryHash;
}
