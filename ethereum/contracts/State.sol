// contracts/State.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./Structs.sol";

/**
 * @title Events - Wormhole protocol event definitions
 * @notice Contains all events emitted by the Wormhole protocol for tracking
 *         guardian set changes and message publications
 */
contract Events {
    /// @notice Emitted when the active guardian set is changed
    /// @param oldGuardianIndex The index of the previous guardian set
    /// @param newGuardianIndex The index of the new active guardian set
    event LogGuardianSetChanged(
        uint32 oldGuardianIndex,
        uint32 newGuardianIndex
    );

    /// @notice Emitted when a message is published through the Wormhole protocol
    /// @param emitter_address The address of the contract that published the message
    /// @param nonce A unique nonce for this message
    /// @param payload The message payload bytes
    event LogMessagePublished(
        address emitter_address,
        uint32 nonce,
        bytes payload
    );
}

/**
 * @title Storage - Wormhole state structure definitions
 * @notice Defines the core state storage structure for the Wormhole protocol
 *         including guardian sets, sequences, governance tracking, and fees
 */
contract Storage {
    /**
     * @title WormholeState - Core state structure
     * @notice Contains all persistent state variables for the Wormhole bridge
     */
    struct WormholeState {
        /// @notice Provider configuration (chain ID, governance settings)
        Structs.Provider provider;

        /// @notice Mapping of guardian set index to guardian set data
        /// @dev Stores all guardian sets, both active and historical
        mapping(uint32 => Structs.GuardianSet) guardianSets;

        /// @notice The index of the currently active guardian set
        /// @dev This is the set used to verify new messages
        uint32 guardianSetIndex;

        /// @notice The time period (in seconds) a guardian set remains valid after replacement
        /// @dev After expiry, the old guardian set is no longer accepted
        uint32 guardianSetExpiry;

        /// @notice Mapping of emitter addresses to their sequence numbers
        /// @dev Ensures unique, ordered message sequencing per emitter
        mapping(address => uint64) sequences;

        /// @notice Mapping of governance action hashes to consumed status
        /// @dev Prevents replay of governance actions
        mapping(bytes32 => bool) consumedGovernanceActions;

        /// @notice Mapping of implementation contract addresses to initialization status
        /// @dev Prevents re-initialization of proxy contracts
        mapping(address => bool) initializedImplementations;

        /// @notice The fee (in wei) charged for publishing messages
        uint256 messageFee;

        /// @notice The EIP-155 chain ID of this blockchain
        /// @dev Used for fork detection and cross-chain identification
        uint256 evmChainId;
    }
}

/**
 * @title State - Wormhole state access contract
 * @notice Provides access to the core Wormhole state variables
 * @dev All contracts that need to read/write Wormhole state inherit from this
 */
contract State {
    /// @notice The singleton WormholeState storage instance
    /// @dev This is the central state storage for the entire Wormhole protocol
    Storage.WormholeState _state;
}
