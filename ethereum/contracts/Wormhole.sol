// contracts/Wormhole.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Wormhole - Core proxy contract for the Wormhole bridge
 * @notice This contract is the main entry point for the Wormhole bridge on EVM chains.
 *         It uses OpenZeppelin's ERC1967Upgrade pattern for upgradeable proxy pattern.
 * @dev This contract delegates all calls to the implementation contract specified during deployment.
 *      The implementation contract is set during construction and can be upgraded through governance.
 */
contract Wormhole is ERC1967Proxy {
    
    /**
     * @notice Deploys the Wormhole proxy contract
     * @dev Sets up the proxy with the specified implementation contract and initialization data
     * @param setup The address of the setup contract that contains the initialization logic
     * @param initData The initialization data to call on the implementation during deployment
     */
    constructor (address setup, bytes memory initData) ERC1967Proxy(
        setup,
        initData
    ) { }
}
