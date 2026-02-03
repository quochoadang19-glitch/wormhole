// contracts/Structs.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

/**
 * @title Structs - Core data structures for the Wormhole protocol
 * @notice Contains all fundamental data structures used throughout the Wormhole bridge
 *         including provider info, guardian sets, signatures, and verified messages (VM)
 */
interface Structs {
    
    /**
     * @notice Configuration data for a blockchain provider
     * @dev Contains chain identification and governance settings
     */
    struct Provider {
        /// @notice The Wormhole chain ID for this blockchain
        uint16 chainId;
        /// @notice The Wormhole chain ID where governance is executed
        uint16 governanceChainId;
        /// @notice The governance contract address on the governance chain (left-padded)
        bytes32 governanceContract;
    }

    /**
     * @notice A set of guardians that sign messages
     * @dev Guardians are responsible for observing and signing messages on the network
     */
    struct GuardianSet {
        /// @notice Array of guardian addresses
        address[] keys;
        /// @notice Unix timestamp when this guardian set expires
        ///         0 means it never expires (until replaced by governance)
        uint32 expirationTime;
    }

    /**
     * @notice A signature from a single guardian
     * @dev Used within the VM structure to collect guardian signatures
     */
    struct Signature {
        /// @notice The r component of the ECDSA signature
        bytes32 r;
        /// @notice The s component of the ECDSA signature
        bytes32 s;
        /// @notice The v component of the ECDSA signature (27 or 28)
        uint8 v;
        /// @notice The index of this guardian in the guardian set
        uint8 guardianIndex;
    }

    /**
     * @notice A fully verified and signed message (VAA - Verifiable Anonymous Attestation)
     * @dev This is the core message format used throughout the Wormhole network
     */
    struct VM {
        /// @notice The version of this VM structure (currently 1)
        uint8 version;
        /// @notice Unix timestamp when the message was published
        uint32 timestamp;
        /// @notice Nonce for message ordering and deduplication
        uint32 nonce;
        /// @notice The Wormhole chain ID of the emitter
        uint16 emitterChainId;
        /// @notice The address of the emitter (left-padded to 32 bytes)
        bytes32 emitterAddress;
        /// @notice Unique sequence number for messages from this emitter
        uint64 sequence;
        /// @notice Consistency level determining when message can be consumed
        uint8 consistencyLevel;
        /// @notice The message payload
        bytes payload;

        /// @notice The guardian set index used to verify this message
        uint32 guardianSetIndex;
        /// @notice Array of guardian signatures
        Signature[] signatures;

        /// @notice Hash of the message body (used for signature verification)
        bytes32 hash;
    }
}
