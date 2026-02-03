// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.19;

import "../../interfaces/relayer/TypedUnits.sol";
import {BytesParsing} from "../../relayer/libraries/BytesParsing.sol";

/**
 * @title ExecutionParameters
 * @notice Library for encoding and decoding EVM execution parameters and info structures.
 *         This library provides functions to serialize/deserialize execution parameters
 *         for cross-chain message delivery using a versioned encoding scheme.
 * @dev Supports EVM_V1 encoding format with gas limits and refund calculations.
 *      All encoding/decoding functions are pure for gas optimization.
 */
library ExecutionParameters {
    /// @notice Thrown when execution params version doesn't match expected version
    error UnexpectedExecutionParamsVersion(uint8 version, uint8 expectedVersion);
    /// @notice Thrown when execution params version is not supported
    error UnsupportedExecutionParamsVersion(uint8 version);
    /// @notice Thrown when target chain ID doesn't match execution params version
    error TargetChainAndExecutionParamsVersionMismatch(uint16 targetChain, uint8 version);
    /// @notice Thrown when execution info version doesn't match expected version
    error UnexpectedExecutionInfoVersion(uint8 version, uint8 expectedVersion);
    /// @notice Thrown when execution info version is not supported
    error UnsupportedExecutionInfoVersion(uint8 version);
    /// @notice Thrown when target chain ID doesn't match execution info version
    error TargetChainAndExecutionInfoVersionMismatch(uint16 targetChain, uint8 version);
    /// @notice Thrown when instruction version doesn't match override version
    error VersionMismatchOverride(uint8 instructionVersion, uint8 overrideVersion);

    using BytesParsing for bytes;

    /**
     * @notice EVM execution parameters version enum
     * @dev Used to version the encoding format for EVM-specific execution parameters
     */
    enum ExecutionParamsVersion {EVM_V1}

    /**
     * @notice EVM execution parameters structure for V1 encoding
     * @dev Contains gas limit for target chain execution
     * @param gasLimit The maximum gas units to allocate for target chain execution
     */
    struct EvmExecutionParamsV1 {
        Gas gasLimit;
    }

    /**
     * @notice EVM execution info version enum
     * @dev Used to version the encoding format for EVM-specific execution info
     */
    enum ExecutionInfoVersion {EVM_V1}

    /**
     * @notice EVM execution info structure for V1 encoding
     * @dev Contains gas limit and refund rate for cross-chain delivery info
     * @param gasLimit The maximum gas units allocated for target chain execution
     * @param targetChainRefundPerGasUnused The refund rate per unit of unused gas on target chain
     */
    struct EvmExecutionInfoV1 {
        Gas gasLimit;
        GasPrice targetChainRefundPerGasUnused;
    }

    /**
     * @notice Decodes the execution params version from encoded data
     * @param data The encoded execution parameters
     * @return version The decoded execution params version
     */
    function decodeExecutionParamsVersion(bytes memory data)
        pure
        returns (ExecutionParamsVersion version)
    {
        (version) = abi.decode(data, (ExecutionParamsVersion));
    }

    /**
     * @notice Decodes the execution info version from encoded data
     * @param data The encoded execution info
     * @return version The decoded execution info version
     */
    function decodeExecutionInfoVersion(bytes memory data)
        pure
        returns (ExecutionInfoVersion version)
    {
        (version) = abi.decode(data, (ExecutionInfoVersion));
    }

    /**
     * @notice Encodes EVM execution params to V1 format
     * @param executionParams The EVM execution parameters to encode
     * @return The encoded bytes containing version and gas limit
     */
    function encodeEvmExecutionParamsV1(EvmExecutionParamsV1 memory executionParams)
        pure
        returns (bytes memory)
    {
        return abi.encode(uint8(ExecutionParamsVersion.EVM_V1), executionParams.gasLimit);
    }

    /**
     * @notice Decodes EVM execution params from V1 format
     * @param data The encoded execution parameters
     * @return executionParams The decoded EVM execution parameters
     * @dev Reverts if version doesn't match EVM_V1
     */
    function decodeEvmExecutionParamsV1(bytes memory data)
        pure
        returns (EvmExecutionParamsV1 memory executionParams)
    {
        uint8 version;
        (version, executionParams.gasLimit) = abi.decode(data, (uint8, Gas));

        if (version != uint8(ExecutionParamsVersion.EVM_V1)) {
            revert UnexpectedExecutionParamsVersion(version, uint8(ExecutionParamsVersion.EVM_V1));
        }
    }

    /**
     * @notice Encodes EVM execution info to V1 format
     * @param executionInfo The EVM execution info to encode
     * @return The encoded bytes containing version, gas limit, and refund rate
     */
    function encodeEvmExecutionInfoV1(EvmExecutionInfoV1 memory executionInfo)
        pure
        returns (bytes memory)
    {
        return abi.encode(
            uint8(ExecutionInfoVersion.EVM_V1),
            executionInfo.gasLimit,
            executionInfo.targetChainRefundPerGasUnused
        );
    }

    /**
     * @notice Decodes EVM execution info from V1 format
     * @param data The encoded execution info
     * @return executionInfo The decoded EVM execution info
     * @dev Reverts if version doesn't match EVM_V1
     */
    function decodeEvmExecutionInfoV1(bytes memory data)
        pure
        returns (EvmExecutionInfoV1 memory executionInfo)
    {
        uint8 version;
        (version, executionInfo.gasLimit, executionInfo.targetChainRefundPerGasUnused) =
            abi.decode(data, (uint8, Gas, GasPrice));

        if (version != uint8(ExecutionInfoVersion.EVM_V1)) {
            revert UnexpectedExecutionInfoVersion(version, uint8(ExecutionInfoVersion.EVM_V1));
        }
    }

    /**
     * @notice Creates empty EVM execution params with zero gas limit
     * @return executionParams Empty execution params structure
     */
    function getEmptyEvmExecutionParamsV1()
        pure
        returns (EvmExecutionParamsV1 memory executionParams)
    {
        executionParams.gasLimit = Gas.wrap(uint256(0));
    }
}

