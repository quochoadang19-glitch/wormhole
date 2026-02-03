// contracts/State.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.19;

import "../../interfaces/relayer/TypedUnits.sol";

/**
 * @title DeliveryProviderState
 * @notice State structures and storage for DeliveryProvider contract
 * @dev Defines the storage layout for the delivery provider including pricing,
 *      chain configuration, and asset conversion parameters
 */
contract DeliveryProviderStorage {
    /**
     * @notice Stores pricing information for a target chain
     * @dev Contains both gas price and native currency pricing data
     * @custom:member gasPrice The price of purchasing 1 unit of gas on the target chain,
     *              denominated in target chain's wei
     * @custom:member nativeCurrencyPrice The price of the native currency denominated in USD * 10^6
     */
    struct PriceData {
        // The price of purchasing 1 unit of gas on the target chain, denominated in target chain's wei.
        GasPrice gasPrice;
        // The price of the native currency denominated in USD * 10^6
        WeiPrice nativeCurrencyPrice;
    }

    /**
     * @notice Stores asset conversion buffer parameters for cross-chain pricing
     * @dev Used to upcharge users for the value attached to cross-chain messages
     * @custom:member buffer The buffer percentage (parts per denominator)
     * @custom:member denominator The denominator for buffer calculation
     * @dev The cost calculation is:
     *      (denominator + buffer) / denominator * converted amount
     */
    struct AssetConversion {
        // The following two fields are a percentage buffer that is used to upcharge the user for the value attached to the message sent.
        // The cost of getting 'targetAmount' on the target chain for the receiverValue is
        // (denominator + buffer) / (denominator) * (the converted amount in source chain currency using the 'quoteAssetPrice' values)
        uint16 buffer;
        uint16 denominator;
    }

    /**
     * @notice The complete state struct for the DeliveryProvider
     * @dev Contains all mutable state including ownership, pricing, chain configs, and mappings
     * @custom:member chainId Wormhole chain id of this blockchain
     * @custom:member owner Current contract owner
     * @custom:member pendingOwner Pending target of ownership transfer
     * @custom:member pricingWallet Address allowed to modify pricing
     * @custom:member coreRelayer Address of the core relayer contract
     * @custom:member initializedImplementations Dictionary of implementation contract -> initialized flag
     * @custom:member supportedChains Supported chains to deliver to
     * @custom:member targetChainAddresses Contracts of this relay provider on other chains
     * @custom:member data Dictionary of wormhole chain id -> price data
     * @custom:member deliverGasOverhead The delivery overhead gas required to deliver a message
     * @custom:member maximumBudget The maximum budget allowed for a delivery on target chain
     * @custom:member assetConversion Dictionary of wormhole chain id -> assetConversion
     * @custom:member rewardAddress Reward address for the relayer
     */
    struct State {
        // Wormhole chain id of this blockchain.
        uint16 chainId;
        // Current owner.
        address owner;
        // Pending target of ownership transfer.
        address pendingOwner;
        // Address that is allowed to modify pricing
        address pricingWallet;
        // Address of the core relayer contract.
        address coreRelayer;
        // Dictionary of implementation contract -> initialized flag
        mapping(address => bool) initializedImplementations;
        // Supported chains to deliver to
        mapping(uint16 => bool) supportedChains;
        // Contracts of this relay provider on other chains
        mapping(uint16 => bytes32) targetChainAddresses;
        // Dictionary of wormhole chain id -> price data
        mapping(uint16 => PriceData) data;
        // The delivery overhead gas required to deliver a message to targetChain, denominated in targetChain's gas.
        mapping(uint16 => Gas) deliverGasOverhead;
        // The maximum budget that is allowed for a delivery on target chain, denominated in the targetChain's wei.
        mapping(uint16 => TargetNative) maximumBudget;
        // Dictionary of wormhole chain id -> assetConversion
        mapping(uint16 => AssetConversion) assetConversion;
        // Reward address for the relayer. The WormholeRelayer contract transfers the reward for relaying messages here.
        address payable rewardAddress;
    }
}

/**
 * @title DeliveryProviderState
 * @notice Contract exposing the delivery provider state storage
 * @dev Used as a base contract to access the internal _state variable
 */
contract DeliveryProviderState {
    DeliveryProviderStorage.State _state;
}

/**
 * @notice Stores supported message key type information
 * @dev Used for tracking which VAA key types are supported by the provider
 * @custom:member bitmap Bitmap encoding of supported message key types
 */
struct SupportedMessageKeyTypes {
    uint256 bitmap;
}

//keccak256("SupportedMessageKeyTypes") - 1
bytes32 constant SUPPORTED_MESSAGE_KEY_TYPES_SLOT =
    0x5e6997bab73a9a9b8f33ae518f391b0426896f5c5f2d9fdce4ddbda5f4773406;

/**
 * @notice Retrieves the supported message key types storage slot
 * @return state The storage pointer to SupportedMessageKeyTypes
 * @dev Uses assembly to directly access the specific storage slot
 */
function getSupportedMessageKeyTypes()
    pure
    returns (SupportedMessageKeyTypes storage state)
{
    assembly ("memory-safe") {
        state.slot := SUPPORTED_MESSAGE_KEY_TYPES_SLOT
    }
}
