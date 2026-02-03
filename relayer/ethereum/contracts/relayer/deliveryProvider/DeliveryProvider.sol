// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.19;

import "./DeliveryProviderGovernance.sol";
import "./DeliveryProviderStructs.sol";
import {getSupportedMessageKeyTypes} from "./DeliveryProviderState.sol";
import "../../interfaces/relayer/IDeliveryProviderTyped.sol";
import "../../interfaces/relayer/TypedUnits.sol";
import "../../relayer/libraries/ExecutionParameters.sol";
import {IWormhole} from "../../interfaces/IWormhole.sol";

/**
 * @title DeliveryProvider
 * @notice Core contract for quoting and processing cross-chain delivery pricing.
 *         This contract manages the calculation of delivery costs across different
 *         blockchain networks, including gas estimation, asset conversion, and
 *         refund calculations for unused gas on target chains.
 * @dev Inherits from DeliveryProviderGovernance and implements IDeliveryProvider interface.
 *      Handles both EVM and non-EVM chain delivery pricing with sophisticated fee calculation.
 */
contract DeliveryProvider is DeliveryProviderGovernance, IDeliveryProvider {
    using WeiLib for Wei;
    using GasLib for Gas;
    using GasPriceLib for GasPrice;
    using WeiPriceLib for WeiPrice;
    using TargetNativeLib for TargetNative;
    using LocalNativeLib for LocalNative;

    /// @notice Thrown when caller is not approved to perform the operation
    error CallerNotApproved(address msgSender);
    /// @notice Thrown when the gas price for a chain is zero
    error PriceIsZero(uint16 chain);
    /// @notice Thrown when a calculated value exceeds the maximum allowed
    error Overflow(uint256 value, uint256 max);
    /// @notice Thrown when max refund exceeds the gas limit cost
    error MaxRefundGreaterThanGasLimitCost(uint256 maxRefund, uint256 gasLimitCost);
    /// @notice Thrown when max refund exceeds gas limit cost on source chain
    error MaxRefundGreaterThanGasLimitCostOnSourceChain(uint256 maxRefund, uint256 gasLimitCost);
    /// @notice Thrown when the specified budget is exceeded
    error ExceedsMaximumBudget(uint16 targetChain, uint256 exceedingValue, uint256 maximumBudget);

    /**
     * @notice Quotes the delivery price for an EVM target chain
     * @param targetChain The Wormhole chain ID of the target blockchain
     * @param gasLimit The maximum gas units to be used on the target chain
     * @param receiverValue The amount of native tokens to be delivered to the receiver
     * @return nativePriceQuote The estimated cost in the source chain's native currency
     * @return targetChainRefundPerUnitGasUnused The refund rate per unit of unused gas on target chain
     * @dev Calculates the total cost by combining gas cost, receiver value, and delivery overhead.
     *      Also applies an asset conversion buffer and checks against maximum budget constraints.
     */
        uint16 targetChain,
        Gas gasLimit,
        TargetNative receiverValue
    )
        public
        view
        returns (LocalNative nativePriceQuote, GasPrice targetChainRefundPerUnitGasUnused)
    {
        // Calculates the amount to refund user on the target chain, for each unit of target chain gas unused
        // by multiplying the price of that amount of gas (in target chain currency)
        // by a target-chain-specific constant 'denominator'/('denominator' + 'buffer'), which will be close to 1

        (uint16 buffer, uint16 denominator) = assetConversionBuffer(targetChain);
        targetChainRefundPerUnitGasUnused = GasPrice.wrap(gasPrice(targetChain).unwrap() * (denominator) / (uint256(denominator) + buffer));

        // Calculates the cost of performing a delivery with 'gasLimit' units of gas and 'receiverValue' wei delivered to the target contract

        LocalNative gasLimitCostInSourceCurrency = quoteGasCost(targetChain, gasLimit);
        LocalNative receiverValueCostInSourceCurrency = quoteAssetCost(targetChain, receiverValue);
        nativePriceQuote = quoteDeliveryOverhead(targetChain) + gasLimitCostInSourceCurrency + receiverValueCostInSourceCurrency;
  
        // Checks that the amount of wei that needs to be sent into the target chain is <= the 'maximum budget' for the target chain
        
        TargetNative gasLimitCost = gasLimit.toWei(gasPrice(targetChain)).asTargetNative();
        if(receiverValue.asNative() + gasLimitCost.asNative() > maximumBudget(targetChain).asNative()) {
            revert ExceedsMaximumBudget(targetChain, receiverValue.unwrap() + gasLimitCost.unwrap(), maximumBudget(targetChain).unwrap());
        }
    }

    /**
     * @notice Quotes the delivery price for any target chain with encoded execution parameters
     * @param targetChain The Wormhole chain ID of the target blockchain
     * @param receiverValue The amount of native tokens to be delivered to the receiver
     * @param encodedExecutionParams Optional execution parameters encoded based on chain type
     * @return nativePriceQuote The estimated cost in the source chain's native currency
     * @return encodedExecutionInfo Encoded execution information for the target chain
     * @dev Routes to chain-specific pricing based on execution params version.
     *      Currently supports EVM chains with EVM_V1 execution parameters.
     */
    function quoteDeliveryPrice(
        uint16 targetChain,
        TargetNative receiverValue,
        bytes memory encodedExecutionParams
    ) external view returns (LocalNative nativePriceQuote, bytes memory encodedExecutionInfo) {
        ExecutionParamsVersion version = decodeExecutionParamsVersion(encodedExecutionParams);
        if (version == ExecutionParamsVersion.EVM_V1) {
            EvmExecutionParamsV1 memory parsed = decodeEvmExecutionParamsV1(encodedExecutionParams);
            GasPrice targetChainRefundPerUnitGasUnused;
            (nativePriceQuote, targetChainRefundPerUnitGasUnused) =
                quoteEvmDeliveryPrice(targetChain, parsed.gasLimit, receiverValue);
            return (
                nativePriceQuote,
                encodeEvmExecutionInfoV1(
                    EvmExecutionInfoV1(parsed.gasLimit, targetChainRefundPerUnitGasUnused)
                    )
            );
        } else {
            revert UnsupportedExecutionParamsVersion(uint8(version));
        }
    }

    /**
     * @notice Quotes the asset conversion from source chain to target chain
     * @param targetChain The Wormhole chain ID of the target blockchain
     * @param currentChainAmount The amount of tokens on the current chain
     * @return targetChainAmount The equivalent amount on the target chain
     * @dev Uses the current chain as the source for conversion calculation
     */
    function quoteAssetConversion(
        uint16 targetChain,
        LocalNative currentChainAmount
    ) public view returns (TargetNative targetChainAmount) {
        return quoteAssetConversion(chainId(), targetChain, currentChainAmount);
    }

    /**
     * @notice Internal function to convert an asset amount between two chains
     * @param sourceChain The Wormhole chain ID of the source blockchain
     * @param targetChain The Wormhole chain ID of the target blockchain
     * @param sourceChainAmount The amount of tokens on the source chain
     * @return targetChainAmount The equivalent amount on the target chain
     * @dev Applies asset conversion buffer and uses native currency prices for conversion
     */
    function quoteAssetConversion(
        uint16 sourceChain,
        uint16 targetChain,
        LocalNative sourceChainAmount
    ) internal view returns (TargetNative targetChainAmount) {
        (uint16 buffer, uint16 bufferDenominator) = assetConversionBuffer(targetChain);
        return sourceChainAmount.asNative().convertAsset(
            nativeCurrencyPrice(sourceChain),
            nativeCurrencyPrice(targetChain),
            (bufferDenominator),
            (uint32(buffer) + bufferDenominator),
            false  // round down
        ).asTargetNative();
    }

    /**
     * @notice Returns the reward address where fees should be sent
     * @return The payable address of the reward recipient
     * @dev Used by the protocol to determine where to send delivery fees
     */
    //Returns the address on this chain that rewards should be sent to
    function getRewardAddress() public view returns (address payable) {
        return rewardAddress();
    }

    /**
     * @notice Checks if a target chain is supported by this delivery provider
     * @param targetChain The Wormhole chain ID to check
     * @return supported True if the chain is supported, false otherwise
     */
    function isChainSupported(uint16 targetChain) public view returns (bool supported) {
        return _state.supportedChains[targetChain];
    }

    /**
     * @notice Returns the bitmap of supported message key types
     * @return bitmap A bitmask indicating which message key types are supported
     */
    function getSupportedKeys() public view returns (uint256 bitmap) {
        return getSupportedMessageKeyTypes().bitmap;
    }

    /**
     * @notice Checks if a specific message key type is supported
     * @param keyType The message key type to check (0-255)
     * @return supported True if the key type is supported, false otherwise
     */
    function isMessageKeyTypeSupported(uint8 keyType) public view returns (bool supported) {
        return getSupportedMessageKeyTypes().bitmap & (1 << keyType) > 0;
    }

    /**
     * @notice Gets the delivery provider's address on the target chain
     * @param targetChain The Wormhole chain ID of the target blockchain
     * @return deliveryProviderAddress The bytes32-encoded address of this provider on target chain
     */
    function getTargetChainAddress(uint16 targetChain)
        public
        view
        override
        returns (bytes32 deliveryProviderAddress)
    {
        return targetChainAddress(targetChain);
    }

    /**
     *
     * HELPER METHODS
     *
     */

    /**
     * @notice Quotes the delivery overhead cost for a target chain
     * @param targetChain The Wormhole chain ID of the target blockchain
     * @return nativePriceQuote The overhead cost in source chain's native currency
     * @dev Represents the fixed cost overhead for processing a delivery message
     */
    //Returns the delivery overhead fee required to deliver a message to the target chain, denominated in this chain's wei.
    function quoteDeliveryOverhead(uint16 targetChain) public view returns (LocalNative nativePriceQuote) {
        nativePriceQuote = quoteGasCost(targetChain, deliverGasOverhead(targetChain));
        if(nativePriceQuote.unwrap() > type(uint128).max) {
            revert Overflow(nativePriceQuote.unwrap(), type(uint128).max);
        }
    }

    /**
     * @notice Quotes the gas cost for delivering to a target chain
     * @param targetChain The Wormhole chain ID of the target blockchain
     * @param gasAmount The amount of gas units to quote
     * @return totalCost The total cost in source chain's native currency
     */
    //Returns the price of purchasing gasAmount units of gas on the target chain, denominated in this chain's wei.
    function quoteGasCost(uint16 targetChain, Gas gasAmount) public view returns (LocalNative totalCost) {
        Wei gasCostInSourceChainCurrency =
            assetConversion(targetChain, gasAmount.toWei(gasPrice(targetChain)), chainId());
        totalCost = LocalNative.wrap(gasCostInSourceChainCurrency.unwrap());
    }

    /**
     * @notice Quotes the gas price for a target chain
     * @param targetChain The Wormhole chain ID of the target blockchain
     * @return price The gas price in source chain's native currency per unit of gas
     */
    function quoteGasPrice(uint16 targetChain) public view returns (GasPrice price) {
        price = GasPrice.wrap(quoteGasCost(targetChain, Gas.wrap(1)).unwrap());
        if(price.unwrap() > type(uint88).max) {
            revert Overflow(price.unwrap(), type(uint88).max);
        }
    }

    /**
     * @notice Converts an amount of wei from one chain to another based on native currency prices
     * @param fromChain The Wormhole chain ID of the source blockchain
     * @param fromAmount The amount of wei to convert
     * @param toChain The Wormhole chain ID of the target blockchain
     * @return targetAmount The converted amount in the target chain's wei
     * @dev Reverts if either chain has a zero native currency price
     */
    // relevant for chains that have dynamic execution pricing (e.g. Ethereum)
    function assetConversion(
        uint16 fromChain,
        Wei fromAmount,
        uint16 toChain
    ) internal view returns (Wei targetAmount) {
        if(nativeCurrencyPrice(fromChain).unwrap() == 0) {
            revert PriceIsZero(fromChain);
        } 
        if(nativeCurrencyPrice(toChain).unwrap() == 0) {
            revert PriceIsZero(toChain);
        }
        return fromAmount.convertAsset(
            nativeCurrencyPrice(fromChain),
            nativeCurrencyPrice(toChain),
            1,
            1,
            // round up
            true
        );
    }

    /**
     * @notice Quotes the cost of delivering a specific amount of target chain native tokens
     * @param targetChain The Wormhole chain ID of the target blockchain
     * @param targetChainAmount The amount of target chain native tokens to deliver
     * @return currentChainAmount The equivalent cost in source chain's native currency
     */
    function quoteAssetCost(
        uint16 targetChain,
        TargetNative targetChainAmount
    ) internal view returns (LocalNative currentChainAmount) {
        (uint16 buffer, uint16 bufferDenominator) = assetConversionBuffer(targetChain);
        if(nativeCurrencyPrice(chainId()).unwrap() == 0) {
            revert PriceIsZero(chainId());
        } 
        if(nativeCurrencyPrice(targetChain).unwrap() == 0) {
            revert PriceIsZero(targetChain);
        }
        return targetChainAmount.asNative().convertAsset(
            nativeCurrencyPrice(targetChain),
            nativeCurrencyPrice(chainId()),
            (uint32(buffer) + bufferDenominator),
            (bufferDenominator),
            // round up
            true
        ).asLocalNative();
    }
}
