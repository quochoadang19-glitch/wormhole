// contracts/Setters.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./State.sol";

/**
 * @title Setters - Internal functions for modifying Wormhole state
 * @notice This contract provides internal setter functions for updating the Wormhole contract's state
 * @dev All functions are internal and can only be called by the main Wormhole contract
 */
contract Setters is State {
    /**
     * @notice Updates the current guardian set index
     * @dev Called during guardian set rotation to set the new active guardian set
     * @param newIndex The index of the new active guardian set
     */
    function updateGuardianSetIndex(uint32 newIndex) internal {
        _state.guardianSetIndex = newIndex;
    }

    /**
     * @notice Expires a guardian set by setting its expiration time
     * @dev Called when a guardian set is being replaced, giving 24 hours for finalization
     * @param index The index of the guardian set to expire
     */
    function expireGuardianSet(uint32 index) internal {
        _state.guardianSets[index].expirationTime = uint32(block.timestamp) + 86400;
    }

    /**
     * @notice Stores a new guardian set at the specified index
     * @dev Validates that all guardian keys are non-zero addresses before storing
     * @param set The GuardianSet struct containing guardian keys and expiration
     * @param index The index at which to store the guardian set
     */
    function storeGuardianSet(Structs.GuardianSet memory set, uint32 index) internal {
        uint setLength = set.keys.length;
        for (uint i = 0; i < setLength; i++) {
            require(set.keys[i] != address(0), "Invalid key");
        }
        _state.guardianSets[index] = set;
    }

    /**
     * @notice Marks a contract implementation as initialized
     * @dev Prevents re-initialization of proxy contracts for security
     * @param implementatiom The address of the implementation contract (note: typo in parameter name matches original)
     */
    function setInitialized(address implementatiom) internal {
        _state.initializedImplementations[implementatiom] = true;
    }

    /**
     * @notice Marks a governance action as consumed
     * @dev Prevents replay attacks of governance actions
     * @param hash The hash of the governance action to mark as consumed
     */
    function setGovernanceActionConsumed(bytes32 hash) internal {
        _state.consumedGovernanceActions[hash] = true;
    }

    /**
     * @notice Sets the native chain ID for this deployment
     * @dev Can only be set once during initialization
     * @param chainId The Wormhole chain ID to register
     */
    function setChainId(uint16 chainId) internal {
        _state.provider.chainId = chainId;
    }

    /**
     * @notice Sets the governance chain ID
     * @dev Defines which chain is authorized to send governance messages
     * @param chainId The chain ID of the governance chain
     */
    function setGovernanceChainId(uint16 chainId) internal {
        _state.provider.governanceChainId = chainId;
    }

    /**
     * @notice Sets the governance contract address
     * @dev Defines which contract on the governance chain is authorized
     * @param governanceContract The governance contract address (padded to 32 bytes)
     */
    function setGovernanceContract(bytes32 governanceContract) internal {
        _state.provider.governanceContract = governanceContract;
    }

    /**
     * @notice Sets the message fee for this Wormhole instance
     * @dev Only callable by governance
     * @param newFee The new message fee in wei
     */
    function setMessageFee(uint256 newFee) internal {
        _state.messageFee = newFee;
    }

    /**
     * @notice Sets the next sequence number for an emitter
     * @dev Used when initializing new emitters or resetting sequences
     * @param emitter The address of the emitter contract
     * @param sequence The next sequence number to use
     */
    function setNextSequence(address emitter, uint64 sequence) internal {
        _state.sequences[emitter] = sequence;
    }

    /**
     * @notice Sets the EVM chain ID and validates it matches the current block
     * @dev Used during contract initialization to register the EVM chain ID
     *      Reverts if the provided ID doesn't match the current block's chain ID
     * @param evmChainId The EIP-155 chain ID to register
     */
    function setEvmChainId(uint256 evmChainId) internal {
        require(evmChainId == block.chainid, "invalid evmChainId");
        _state.evmChainId = evmChainId;
    }
}
