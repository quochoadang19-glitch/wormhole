// contracts/Setup.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./Governance.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

/**
 * @title Setup - Wormhole contract initialization contract
 * @notice This contract handles the initial setup and initialization of the Wormhole bridge.
 *         It configures the initial guardian set, chain IDs, and upgrades to the implementation.
 * @dev This contract is only called once during initial deployment.
 */
contract Setup is Setters, ERC1967Upgrade {
    
    /**
     * @notice Initializes the Wormhole contract with initial configuration
     * @dev Sets up the initial guardian set, chain IDs, and upgrades to the implementation
     * @param implementation The address of the initial implementation contract
     * @param initialGuardians The addresses of the initial guardian set members
     * @param chainId The Wormhole chain ID for this network
     * @param governanceChainId The Wormhole chain ID for the governance network
     * @param governanceContract The governance contract address on the governance chain
     * @param evmChainId The EVM chain ID (EIP-155) for this network
     */
    function setup(
        address implementation,
        address[] memory initialGuardians,
        uint16 chainId,
        uint16 governanceChainId,
        bytes32 governanceContract,
        uint256 evmChainId
    ) public {
        require(initialGuardians.length > 0, "no guardians specified");

        Structs.GuardianSet memory initialGuardianSet = Structs.GuardianSet({
            keys : initialGuardians,
            expirationTime : 0
        });

        storeGuardianSet(initialGuardianSet, 0);
        // initial guardian set index is 0, which is the default value of the storage slot anyways

        setChainId(chainId);

        setGovernanceChainId(governanceChainId);
        setGovernanceContract(governanceContract);

        setEvmChainId(evmChainId);

        _upgradeTo(implementation);

        // See https://github.com/wormhole-foundation/wormhole/issues/1930 for
        // why we set this here
        setInitialized(implementation);
    }
}
