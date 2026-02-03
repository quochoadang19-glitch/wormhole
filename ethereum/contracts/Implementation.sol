// contracts/Implementation.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./Governance.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

/**
 * @title Implementation - Wormhole core message publishing contract
 * @notice This contract provides the core functionality for publishing messages
 *         to the Wormhole network for cross-chain communication
 * @dev Inherits from Governance for upgrade and fee management capabilities
 */
contract Implementation is Governance {
    
    /// @notice Emitted when a message is published through the Wormhole network
    /// @param sender The address that published the message
    /// @param sequence The unique sequence number for this message
    /// @param nonce A nonce for message ordering
    /// @param payload The message payload bytes
    /// @param consistencyLevel The consistency level for finality
    event LogMessagePublished(address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel);

    /**
     * @notice Publishes a message to be attested by the Wormhole guardian network
     * @dev Messages published through this function will be observed and signed by guardians
     * @param nonce A nonce for message ordering and deduplication
     * @param payload The message payload bytes to be published
     * @param consistencyLevel The consistency level determining when the message can be considered final
     * @return sequence The unique sequence number assigned to this message
     */
    function publishMessage(
        uint32 nonce,
        bytes memory payload,
        uint8 consistencyLevel
    ) public payable returns (uint64 sequence) {
        // check fee
        require(msg.value == messageFee(), "invalid fee");

        sequence = useSequence(msg.sender);
        // emit log
        emit LogMessagePublished(msg.sender, sequence, nonce, payload, consistencyLevel);
    }

    /**
     * @dev Internal function to get and increment the sequence number for an emitter
     * @param emitter The address of the message emitter
     * @return sequence The current sequence number before incrementing
     */
    function useSequence(address emitter) internal returns (uint64 sequence) {
        sequence = nextSequence(emitter);
        setNextSequence(emitter, sequence + 1);
    }

    /**
     * @notice Initializes the contract with the correct chain ID mappings
     * @dev This function maps Wormhole chain IDs to their corresponding EVM chain IDs
     *      It is called automatically during contract deployment or upgrade
     * @dev Only runs once - subsequent calls are prevented by the initializer modifier
     */
    function initialize() initializer public virtual {
        // this function needs to be exposed for an upgrade to pass
        if (evmChainId() == 0) {
            uint256 evmChainId;
            uint16 chain = chainId();

            // Wormhole chain ids explicitly enumerated
            if        (chain == 2)  { evmChainId = 1;          // ethereum
            } else if (chain == 4)  { evmChainId = 56;         // bsc
            } else if (chain == 5)  { evmChainId = 137;        // polygon
            } else if (chain == 6)  { evmChainId = 43114;      // avalanche
            } else if (chain == 7)  { evmChainId = 42262;      // oasis
            } else if (chain == 9)  { evmChainId = 1313161554; // aurora
            } else if (chain == 10) { evmChainId = 250;        // fantom
            } else if (chain == 11) { evmChainId = 686;        // karura
            } else if (chain == 12) { evmChainId = 787;        // acala
            } else if (chain == 13) { evmChainId = 8217;       // klaytn
            } else if (chain == 14) { evmChainId = 42220;      // celo
            } else if (chain == 16) { evmChainId = 1284;       // moonbeam
            } else if (chain == 17) { evmChainId = 245022934;  // neon
            } else if (chain == 23) { evmChainId = 42161;      // arbitrum
            } else if (chain == 24) { evmChainId = 10;         // optimism
            } else if (chain == 25) { evmChainId = 100;        // gnosis
            } else {
                revert("Unknown chain id.");
            }

            setEvmChainId(evmChainId);
        }
    }

    /**
     * @dev Modifier that checks the contract has not been initialized yet
     * @dev Uses the OpenZeppelin initializer pattern to ensure one-time initialization
     */
    modifier initializer() {
        address implementation = ERC1967Upgrade._getImplementation();

        require(
            !isInitialized(implementation),
            "already initialized"
        );

        setInitialized(implementation);

        _;
    }

    /// @notice Fallback function - rejects all unexpected calls
    fallback() external payable {revert("unsupported");}

    /// @notice Receive function - rejects direct ETH transfers
    /// @dev The Wormhole contract does not accept direct ETH transfers
    receive() external payable {revert("the Wormhole contract does not accept assets");}
}
