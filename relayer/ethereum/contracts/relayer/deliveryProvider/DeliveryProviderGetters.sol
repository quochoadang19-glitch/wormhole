// contracts/Getters.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.19;

import "../../interfaces/IWormhole.sol";
import "../../interfaces/relayer/TypedUnits.sol";

import "./DeliveryProviderState.sol";

/**
 * @title DeliveryProviderGetters
 * @notice Read-only getter functions for DeliveryProvider contract state
 * @dev Provides public view functions to access the internal state of the delivery provider
 *      including ownership, pricing, chain configuration, and asset conversion parameters
 */
contract DeliveryProviderGetters is DeliveryProviderState {
    /**
     * @notice Returns the current owner of the contract
     * @return The address of the contract owner
     */
    function owner() public view returns (address) {
        return _state.owner;
    }

    /**
     * @notice Returns the pending owner awaiting ownership transfer
     * @return The address of the pending owner
     * @dev This address must call acceptOwnership() to complete the transfer
     */
    function pendingOwner() public view returns (address) {
        return _state.pendingOwner;
    }

    /**
     * @notice Returns the wallet address that receives pricing payments
     * @return The payable address of the pricing wallet
     */
    function pricingWallet() public view returns (address) {
        return _state.pricingWallet;
    }

    /**
     * @notice Checks if a specific implementation has been initialized
     * @param impl The implementation address to check
     * @return True if the implementation is initialized
     */
    function isInitialized(address impl) public view returns (bool) {
        return _state.initializedImplementations[impl];
    }

    /**
     * @notice Returns the Wormhole chain ID for this delivery provider
     * @return The 16-bit Wormhole chain identifier
     */
    function chainId() public view returns (uint16) {
        return _state.chainId;
    }

    /**
     * @notice Returns the core relayer contract address
     * @return The address of the core relayer contract
     */
    function coreRelayer() public view returns (address) {
        return _state.coreRelayer;
    }

    /**
     * @notice Returns the gas price for a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @return The gas price in the chain's native currency
     */
    function gasPrice(uint16 targetChain) public view returns (GasPrice) {
        return _state.data[targetChain].gasPrice;
    }

    /**
     * @notice Returns the native currency price for a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @return The price of the chain's native currency in USD (scaled)
     */
    function nativeCurrencyPrice(uint16 targetChain) public view returns (WeiPrice) {
        return _state.data[targetChain].nativeCurrencyPrice;
    }

    /**
     * @notice Returns the fixed gas overhead for delivering to a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @return The gas overhead for delivery execution
     */
    function deliverGasOverhead(uint16 targetChain) public view returns (Gas) {
        return _state.deliverGasOverhead[targetChain];
    }

    /**
     * @notice Returns the maximum budget for deliveries to a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @return The maximum target native token budget for deliveries
     */
    function maximumBudget(uint16 targetChain) public view returns (TargetNative) {
        return _state.maximumBudget[targetChain];
    }

    /**
     * @notice Returns the registered relayer address for a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @return The bytes32-encoded relayer address on the target chain
     */
    function targetChainAddress(uint16 targetChain) public view returns (bytes32) {
        return _state.targetChainAddresses[targetChain];
    }

    /**
     * @notice Returns the reward address where relayer payments are sent
     * @return The payable address for relayer rewards
     */
    function rewardAddress() public view returns (address payable) {
        return _state.rewardAddress;
    }

    /**
     * @notice Returns the asset conversion buffer parameters for a target chain
     * @param targetChain The Wormhole chain ID of the target chain
     * @return buffer The percentage buffer for asset conversion (parts per bufferDenominator)
     * @return bufferDenominator The denominator for calculating the buffer percentage
     */
    function assetConversionBuffer(uint16 targetChain)
        public
        view
        returns (uint16 buffer, uint16 bufferDenominator)
    {
        DeliveryProviderStorage.AssetConversion storage assetConversion =
            _state.assetConversion[targetChain];
        return (assetConversion.buffer, assetConversion.denominator);
    }
}
