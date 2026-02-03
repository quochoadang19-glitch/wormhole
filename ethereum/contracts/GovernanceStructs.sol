// contracts/GovernanceStructs.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./libraries/external/BytesLib.sol";
import "./Structs.sol";

/**
 * @title GovernanceStructs - Governance structure definitions and parsing
 * @notice Contains structs and parsing functions for governance-related data structures
 *         used in Wormhole's on-chain governance system
 */
contract GovernanceStructs {
    using BytesLib for bytes;

    /**
     * @notice Enumeration of governance actions that can be performed
     */
    enum GovernanceAction {
        UpgradeContract,      /// Action 1: Upgrade contract implementation
        UpgradeGuardianset   /// Action 2: Upgrade guardian set
    }

    /**
     * @notice Structure representing a contract upgrade governance action
     * @dev Contains all information needed to upgrade a contract implementation
     */
    struct ContractUpgrade {
        bytes32 module;              /// Governance module identifier (must be "Core")
        uint8 action;                /// Action type (must be 1)
        uint16 chain;                /// Target chain ID for the upgrade
        address newContract;         /// Address of the new contract implementation
    }

    /**
     * @notice Structure representing a guardian set upgrade governance action
     * @dev Contains the new guardian set and its index for rotation
     */
    struct GuardianSetUpgrade {
        bytes32 module;                      /// Governance module identifier
        uint8 action;                        /// Action type (must be 2)
        uint16 chain;                       /// Target chain ID
        Structs.GuardianSet newGuardianSet; /// The new guardian set configuration
        uint32 newGuardianSetIndex;         /// Index at which to register the new guardian set
    }

    /**
     * @notice Structure representing a message fee update governance action
     * @dev Contains the new message fee configuration
     */
    struct SetMessageFee {
        bytes32 module;      /// Governance module identifier
        uint8 action;        /// Action type (must be 3)
        uint16 chain;        /// Target chain ID
        uint256 messageFee;  /// New message fee in wei
    }

    /**
     * @notice Structure representing a fee transfer governance action
     * @dev Used to transfer accumulated protocol fees to a recipient
     */
    struct TransferFees {
        bytes32 module;      /// Governance module identifier
        uint8 action;        /// Action type (must be 4)
        uint16 chain;        /// Target chain ID
        uint256 amount;      /// Amount of fees to transfer
        bytes32 recipient;   /// Recipient address for the fees
    }

    /**
     * @notice Structure representing a chain ID recovery governance action
     * @dev Used to recover/reset the EVM chain ID mapping after a fork
     */
    struct RecoverChainId {
        bytes32 module;      /// Governance module identifier
        uint8 action;        /// Action type (must be 5)
        uint256 evmChainId;  /// The EVM chain ID to recover to
        uint16 newChainId;   /// The new Wormhole chain ID
    }

    /**
     * @notice Parses a contract upgrade VAA payload
     * @dev Validates the action type and extracts contract upgrade data
     * @param encodedUpgrade The encoded contract upgrade data from the VAA payload
     * @return cu The parsed ContractUpgrade struct
     */
    function parseContractUpgrade(bytes memory encodedUpgrade) public pure returns (ContractUpgrade memory cu) {
        uint index = 0;

        cu.module = encodedUpgrade.toBytes32(index);
        index += 32;

        cu.action = encodedUpgrade.toUint8(index);
        index += 1;

        require(cu.action == 1, "invalid ContractUpgrade");

        cu.chain = encodedUpgrade.toUint16(index);
        index += 2;

        cu.newContract = address(uint160(uint256(encodedUpgrade.toBytes32(index))));
        index += 32;

        require(encodedUpgrade.length == index, "invalid ContractUpgrade");
    }

    /**
     * @notice Parses a guardian set upgrade VAA payload
     * @dev Validates the action type and extracts guardian set data
     * @param encodedUpgrade The encoded guardian set upgrade data from the VAA payload
     * @return gsu The parsed GuardianSetUpgrade struct
     */
    function parseGuardianSetUpgrade(bytes memory encodedUpgrade) public pure returns (GuardianSetUpgrade memory gsu) {
        uint index = 0;

        gsu.module = encodedUpgrade.toBytes32(index);
        index += 32;

        gsu.action = encodedUpgrade.toUint8(index);
        index += 1;

        require(gsu.action == 2, "invalid GuardianSetUpgrade");

        gsu.chain = encodedUpgrade.toUint16(index);
        index += 2;

        gsu.newGuardianSetIndex = encodedUpgrade.toUint32(index);
        index += 4;

        uint8 guardianLength = encodedUpgrade.toUint8(index);
        index += 1;

        gsu.newGuardianSet = Structs.GuardianSet({
            keys : new address[](guardianLength),
            expirationTime : 0
        });

        for(uint i = 0; i < guardianLength; i++) {
            gsu.newGuardianSet.keys[i] = encodedUpgrade.toAddress(index);
            index += 20;
        }

        require(encodedUpgrade.length == index, "invalid GuardianSetUpgrade");
    }

    /**
     * @notice Parses a set message fee VAA payload
     * @dev Validates the action type and extracts the new fee
     * @param encodedSetMessageFee The encoded fee update data from the VAA payload
     * @return smf The parsed SetMessageFee struct
     */
    function parseSetMessageFee(bytes memory encodedSetMessageFee) public pure returns (SetMessageFee memory smf) {
        uint index = 0;

        smf.module = encodedSetMessageFee.toBytes32(index);
        index += 32;

        smf.action = encodedSetMessageFee.toUint8(index);
        index += 1;

        require(smf.action == 3, "invalid SetMessageFee");

        smf.chain = encodedSetMessageFee.toUint16(index);
        index += 2;

        smf.messageFee = encodedSetMessageFee.toUint256(index);
        index += 32;

        require(encodedSetMessageFee.length == index, "invalid SetMessageFee");
    }

    /**
     * @notice Parses a transfer fees VAA payload
     * @dev Validates the action type and extracts fee transfer data
     * @param encodedTransferFees The encoded fee transfer data from the VAA payload
     * @return tf The parsed TransferFees struct
     */
    function parseTransferFees(bytes memory encodedTransferFees) public pure returns (TransferFees memory tf) {
        uint index = 0;

        tf.module = encodedTransferFees.toBytes32(index);
        index += 32;

        tf.action = encodedTransferFees.toUint8(index);
        index += 1;

        require(tf.action == 4, "invalid TransferFees");

        tf.chain = encodedTransferFees.toUint16(index);
        index += 2;

        tf.amount = encodedTransferFees.toUint256(index);
        index += 32;

        tf.recipient = encodedTransferFees.toBytes32(index);
        index += 32;

        require(encodedTransferFees.length == index, "invalid TransferFees");
    }

    /**
     * @notice Parses a recover chain ID VAA payload
     * @dev Validates the action type and extracts chain ID recovery data
     * @param encodedRecoverChainId The encoded chain ID recovery data from the VAA payload
     * @return rci The parsed RecoverChainId struct
     */
    function parseRecoverChainId(bytes memory encodedRecoverChainId) public pure returns (RecoverChainId memory rci) {
        uint index = 0;

        rci.module = encodedRecoverChainId.toBytes32(index);
        index += 32;

        rci.action = encodedRecoverChainId.toUint8(index);
        index += 1;

        require(rci.action == 5, "invalid RecoverChainId");

        rci.evmChainId = encodedRecoverChainId.toUint256(index);
        index += 32;

        rci.newChainId = encodedRecoverChainId.toUint16(index);
        index += 2;

        require(encodedRecoverChainId.length == index, "invalid RecoverChainId");
    }
}
