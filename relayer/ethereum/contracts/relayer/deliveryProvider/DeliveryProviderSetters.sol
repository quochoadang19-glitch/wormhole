// contracts/Setters.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Context.sol";

import "./DeliveryProviderState.sol";
import "../../interfaces/relayer/IDeliveryProviderTyped.sol";

/**
 * @title DeliveryProviderSetters
 * @notice Internal setter functions for DeliveryProvider contract state
 * @dev Provides internal functions to modify the state of the delivery provider
 *      including ownership, pricing, chain configuration, and asset conversion parameters
 */
contract DeliveryProviderSetters is Context, DeliveryProviderState {
    using GasPriceLib for GasPrice;
    using WeiLib for Wei;

    /**
     * @notice Sets the contract owner
     * @param owner_ The address of the new owner
     */
    function setOwner(address owner_) internal {
        _state.owner = owner_;
    }

    /**
     * @notice Initiates ownership transfer by setting pending owner
     * @param newOwner The address that will become owner after accepting
     */
    function setPendingOwner(address newOwner) internal {
        _state.pendingOwner = newOwner;
    }

    /**
     * @notice Marks an implementation as initialized
     * @param implementation The address of the initialized implementation
     */
    function setInitialized(address implementation) internal {
        _state.initializedImplementations[implementation] = true;
    }

    /**
     * @notice Sets the Wormhole chain ID for this provider
     * @param thisChain The 16-bit Wormhole chain identifier
     */
    function setChainId(uint16 thisChain) internal {
        _state.chainId = thisChain;
    }

    /**
     * @notice Updates the pricing wallet address
     * @param newPricingWallet The address to receive pricing payments
     */
    function setPricingWallet(address newPricingWallet) internal {
        _state.pricingWallet = newPricingWallet;
    }

    /**
     * @notice Sets the core Wormhole relayer contract address
     * @param coreRelayer The payable address of the core relayer
     */
    function setWormholeRelayer(address payable coreRelayer) internal {
        _state.coreRelayer = coreRelayer;
    }

    /**
     * @notice Enables or disables support for a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @param isSupported True to enable chain support
     */
    function setChainSupported(uint16 targetChain, bool isSupported) internal {
        _state.supportedChains[targetChain] = isSupported;
    }

    /**
     * @notice Sets the fixed gas overhead for deliveries to a chain
     * @param chainId The Wormhole chain ID of the target chain
     * @param deliverGasOverhead The gas overhead for delivery execution
     * @dev Reverts if gas overhead exceeds type(uint32).max
     */
    function setDeliverGasOverhead(uint16 chainId, Gas deliverGasOverhead) internal {
        require(Gas.unwrap(deliverGasOverhead) <= type(uint32).max, "deliverGasOverhead too large");
        _state.deliverGasOverhead[chainId] = deliverGasOverhead;
    }

    /**
     * @notice Updates the relayer reward address
     * @param rewardAddress The payable address for relayer rewards
     */
    function setRewardAddress(address payable rewardAddress) internal {
        _state.rewardAddress = rewardAddress;
    }

    /**
     * @notice Sets the relayer address for a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @param newAddress The bytes32-encoded relayer address
     */
    function setTargetChainAddress(uint16 targetChain, bytes32 newAddress) internal {
        _state.targetChainAddresses[targetChain] = newAddress;
    }

    /**
     * @notice Sets the maximum budget for deliveries to a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @param amount The maximum budget in Wei
     * @dev Reverts if amount exceeds type(uint192).max
     */
    function setMaximumBudget(uint16 targetChain, Wei amount) internal {
        require(amount.unwrap() <= type(uint192).max, "amount too large");
        _state.maximumBudget[targetChain] = amount.asTargetNative();
    }

    /**
     * @notice Updates the gas and native currency pricing for a chain
     * @param updateChainId The Wormhole chain ID to update
     * @param updateGasPrice The new gas price
     * @param updateNativeCurrencyPrice The new native currency price
     * @dev Reverts if gas price exceeds type(uint64).max
     */
    function setPriceInfo(
        uint16 updateChainId,
        GasPrice updateGasPrice,
        WeiPrice updateNativeCurrencyPrice
    ) internal {
        require(updateGasPrice.unwrap() <= type(uint64).max, "gas price must be < 2^64");
        _state.data[updateChainId].gasPrice = updateGasPrice;
        _state.data[updateChainId].nativeCurrencyPrice = updateNativeCurrencyPrice;
    }

    /**
     * @notice Sets the asset conversion buffer for a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @param tolerance The buffer percentage (parts per denominator)
     * @param toleranceDenominator The denominator for buffer calculation
     */
    function setAssetConversionBuffer(
        uint16 targetChain,
        uint16 tolerance,
        uint16 toleranceDenominator
    ) internal {
        DeliveryProviderStorage.AssetConversion storage assetConversion =
            _state.assetConversion[targetChain];
        assetConversion.buffer = tolerance;
        assetConversion.denominator = toleranceDenominator;
    }
}
