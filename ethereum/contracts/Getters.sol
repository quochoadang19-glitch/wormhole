// contracts/Getters.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./State.sol";

/**
 * @title Getters - View functions for retrieving Wormhole state
 * @notice This contract provides read-only access to the Wormhole contract's internal state
 *         including guardian sets, governance settings, and chain configuration
 * @dev All functions in this contract are view functions that do not modify state
 */
contract Getters is State {
    /**
     * @notice Retrieves a specific guardian set by index
     * @dev Returns the full GuardianSet struct including keys and expiration time
     * @param index The index of the guardian set to retrieve
     * @return Structs.GuardianSet The guardian set containing the list of guardians and their expiry timestamp
     */
    function getGuardianSet(uint32 index) public view returns (Structs.GuardianSet memory) {
        return _state.guardianSets[index];
    }

    /**
     * @notice Returns the index of the current active guardian set
     * @dev This is the guardian set used to verify current messages
     * @return uint32 The index of the current guardian set in the guardianSets mapping
     */
    function getCurrentGuardianSetIndex() public view returns (uint32) {
        return _state.guardianSetIndex;
    }

    /**
     * @notice Returns the expiry time for guardian sets
     * @dev After this timestamp, a guardian set is considered expired and should be replaced
     * @return uint32 The Unix timestamp when guardian sets expire
     */
    function getGuardianSetExpiry() public view returns (uint32) {
        return _state.guardianSetExpiry;
    }

    /**
     * @notice Checks if a governance action has already been consumed
     * @dev Prevents replay of governance actions that have already been executed
     * @param hash The hash of the governance action to check
     * @return bool True if the governance action has been consumed, false otherwise
     */
    function governanceActionIsConsumed(bytes32 hash) public view returns (bool) {
        return _state.consumedGovernanceActions[hash];
    }

    /**
     * @notice Checks if a contract implementation has been initialized
     * @dev Used to prevent re-initialization of proxy contracts
     * @param impl The address of the implementation contract to check
     * @return bool True if the implementation has been initialized, false otherwise
     */
    function isInitialized(address impl) public view returns (bool) {
        return _state.initializedImplementations[impl];
    }

    /**
     * @notice Returns the native chain ID of this deployment
     * @dev This is the chain ID registered in the Wormhole network for this contract
     * @return uint16 The chain ID of this blockchain
     */
    function chainId() public view returns (uint16) {
        return _state.provider.chainId;
    }

    /**
     * @notice Returns the EVM chain ID of this deployment
     * @dev This is the EIP-155 chain ID, which may differ from the Wormhole chain ID
     *      Used to detect if the contract is running on a fork
     * @return uint256 The EIP-155 chain ID of this blockchain
     */
    function evmChainId() public view returns (uint256) {
        return _state.evmChainId;
    }

    /**
     * @notice Checks if the contract is running on a fork
     * @dev Compares the registered EVM chain ID with the current block's chain ID
     * @return bool True if running on a fork (IDs don't match), false otherwise
     */
    function isFork() public view returns (bool) {
        return evmChainId() != block.chainid;
    }

    /**
     * @notice Returns the governance chain ID
     * @dev The chain ID authorized to send governance messages to this contract
     * @return uint16 The chain ID of the governance chain
     */
    function governanceChainId() public view returns (uint16){
        return _state.provider.governanceChainId;
    }

    /**
     * @notice Returns the governance contract address
     * @dev The contract address on the governance chain authorized to send governance messages
     * @return bytes32 The governance contract address (padded to 32 bytes)
     */
    function governanceContract() public view returns (bytes32){
        return _state.provider.governanceContract;
    }

    /**
     * @notice Returns the fee required to send a message
     * @dev This fee is charged to messages sent through this Wormhole instance
     * @return uint256 The message fee in wei
     */
    function messageFee() public view returns (uint256) {
        return _state.messageFee;
    }
}
