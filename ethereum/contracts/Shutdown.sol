// contracts/Shutdown.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./Governance.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

/**
 * @title Shutdown - Emergency shutdown contract for Wormhole
 * @notice This contract implements a stripped-down version of the Wormhole core
 *         messaging protocol that serves as a drop-in replacement for Wormhole's
 *         implementation contract during emergency situations.
 * @dev Key features:
 *      - All outgoing messages are disabled (non-governance)
 *      - Contract remains upgradeable through governance
 *      - Can be used for migration or emergency stopping of the bridge
 */
contract Shutdown is Governance  {
    
    /**
     * @notice Initializes the Shutdown contract
     * @dev Marks the implementation as initialized to allow governance upgrades
     * @dev NOTE: This function intentionally has no 'initializer' modifier
     *            to allow this contract to be upgraded to multiple times
     */
    function initialize() public {
        address implementation = ERC1967Upgrade._getImplementation();
        setInitialized(implementation);

        // this function needs to be exposed for an upgrade to pass
        // NOTE: leave this function empty! It specifically does not have an
        // 'initializer' modifier, to allow this contract to be upgraded to
        // multiple times.
    }
}
