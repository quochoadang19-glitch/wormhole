// contracts/Governance.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./Structs.sol";
import "./GovernanceStructs.sol";
import "./Messages.sol";
import "./Setters.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

/**
 * @title Governance - On-chain governance implementation for Wormhole
 * @notice This contract provides the core governance functionality for the Wormhole bridge,
 *         including contract upgrades, fee changes, and guardian set management
 * @dev All governance actions are validated through VAA (Verifiable Anonymous Attestation) signatures
 *      from the guardian network before execution
 */
abstract contract Governance is GovernanceStructs, Messages, Setters, ERC1967Upgrade {
    
    /// @notice Emitted when a contract is upgraded through governance
    /// @param oldContract The address of the previous contract implementation
    /// @param newContract The address of the new contract implementation
    event ContractUpgraded(address indexed oldContract, address indexed newContract);
    
    /// @notice Emitted when a new guardian set is added
    /// @param index The index of the newly added guardian set
    event GuardianSetAdded(uint32 indexed index);

    // "Core" (left padded)
    bytes32 constant module = 0x00000000000000000000000000000000000000000000000000000000436f7265;

    /**
     * @notice Upgrades the contract implementation through governance
     * @dev Validates the VAA signature before executing the upgrade
     * @param _vm The raw VAA (Verifiable Anonymous Attestation) bytes containing the upgrade data
     */
    function submitContractUpgrade(bytes memory _vm) public {
        require(!isFork(), "invalid fork");

        Structs.VM memory vm = parseVM(_vm);

        // Verify the VAA is valid before processing it
        (bool isValid, string memory reason) = verifyGovernanceVM(vm);
        require(isValid, reason);

        GovernanceStructs.ContractUpgrade memory upgrade = parseContractUpgrade(vm.payload);

        // Verify the VAA is for this module
        require(upgrade.module == module, "Invalid Module");

        // Verify the VAA is for this chain
        require(upgrade.chain == chainId(), "Invalid Chain");

        // Record the governance action as consumed
        setGovernanceActionConsumed(vm.hash);

        // Upgrades the implementation to the new contract
        upgradeImplementation(upgrade.newContract);
    }

    /**
     * @notice Updates the message fee through governance
     * @dev Only callable by valid governance VAA from the guardian network
     * @param _vm The raw VAA bytes containing the fee update data
     */
    function submitSetMessageFee(bytes memory _vm) public {
        Structs.VM memory vm = parseVM(_vm);

        // Verify the VAA is valid before processing it
        (bool isValid, string memory reason) = verifyGovernanceVM(vm);
        require(isValid, reason);

        GovernanceStructs.SetMessageFee memory upgrade = parseSetMessageFee(vm.payload);

        // Verify the VAA is for this module
        require(upgrade.module == module, "Invalid Module");

        // Verify the VAA is for this chain
        require(upgrade.chain == chainId() && !isFork(), "Invalid Chain");

        // Record the governance action as consumed to prevent reentry
        setGovernanceActionConsumed(vm.hash);

        // Updates the messageFee
        setMessageFee(upgrade.messageFee);
    }

    /**
     * @notice Deploys a new guardian set through governance
     * @dev Adds the new guardian set and increments the current guardian set index
     * @param _vm The raw VAA bytes containing the new guardian set data
     */
    function submitNewGuardianSet(bytes memory _vm) public {
        Structs.VM memory vm = parseVM(_vm);
