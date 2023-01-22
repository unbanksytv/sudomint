
pragma solidity ^0.8.4;

import "./interfaces/ILayerZeroTreasury.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/ILayerZeroUltraLightNodeV2.sol";

contract TreasuryV2 is ILayerZeroTreasury, Ownable {
    using SafeMath for uint;

    uint public nativeBP;
    uint public zroFee;
    bool public feeEnabled;
    bool public zroEnabled;

    ILayerZeroUltraLightNodeV2 public uln;

    event NativeBP(uint bp);
    event ZroFee(uint zroFee);
    event FeeEnabled(bool feeEnabled);
    event ZroEnabled(bool zroEnabled);

    constructor(address _ulnv2) {
        uln = ILayerZeroUltraLightNodeV2(_ulnv2);
    }

    function getFees(bool payInZro, uint relayerFee, uint oracleFee) external view override returns (uint) {
        if (feeEnabled) {
            if (payInZro) {
                require(zroEnabled, "LayerZero: ZRO is not enabled");
                return zroFee;
            } else {
                return relayerFee.add(oracleFee).mul(nativeBP).div(10000);
            }
        }
        return 0;
    }

    function setFeeEnabled(bool _feeEnabled) external onlyOwner {
        feeEnabled = _feeEnabled;
        emit FeeEnabled(_feeEnabled);
    }

    function setZroEnabled(bool _zroEnabled) external onlyOwner {
        zroEnabled = _zroEnabled;
        emit ZroEnabled(_zroEnabled);
    }

    function setNativeBP(uint _nativeBP) external onlyOwner {
        nativeBP = _nativeBP;
        emit NativeBP(_nativeBP);
    }

    function setZroFee(uint _zroFee) external onlyOwner {
        zroFee = _zroFee;
        emit ZroFee(_zroFee);
    }

    function withdrawZROFromULN(address _to, uint _amount) external onlyOwner {
        uln.withdrawZRO(_to, _amount);
    }

    function withdrawNativeFromULN(address payable _to, uint _amount) external onlyOwner {
        uln.withdrawNative(_to, _amount);
    }
}
// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.5.0;

interface ILayerZeroTreasury {
    function getFees(bool payInZro, uint relayerFee, uint oracleFee) external view returns (uint);
}
// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.0;
pragma abicoder v2;

interface ILayerZeroUltraLightNodeV2 {
    // Relayer functions
    function validateTransactionProof(uint16 _srcChainId, address _dstAddress, uint _gasLimit, bytes32 _lookupHash, bytes32 _blockData, bytes calldata _transactionProof) external;

    // an Oracle delivers the block data using updateHash()
    function updateHash(uint16 _srcChainId, bytes32 _lookupHash, uint _confirmations, bytes32 _blockData) external;

    // can only withdraw the receivable of the msg.sender
    function withdrawNative(address payable _to, uint _amount) external;

    function withdrawZRO(address _to, uint _amount) external;

    // view functions
    function getAppConfig(uint16 _remoteChainId, address _userApplicationAddress) external view returns (ApplicationConfiguration memory);

    function accruedNativeFee(address _address) external view returns (uint);

    struct ApplicationConfiguration {
        uint16 inboundProofLibraryVersion;
        uint64 inboundBlockConfirmations;
        address relayer;
        uint16 outboundProofType;
        uint64 outboundBlockConfirmations;
        address oracle;
    }

    event HashReceived(uint16 indexed srcChainId, address indexed oracle, bytes32 lookupHash, bytes32 blockData, uint confirmations);
    event RelayerParams(bytes adapterParams, uint16 outboundProofType);
    event Packet(bytes payload);
    event InvalidDst(uint16 indexed srcChainId, bytes srcAddress, address indexed dstAddress, uint64 nonce, bytes32 payloadHash);
    event PacketReceived(uint16 indexed srcChainId, bytes srcAddress, address indexed dstAddress, uint64 nonce, bytes32 payloadHash);
    event AppConfigUpdated(address indexed userApplication, uint indexed configType, bytes newConfig);
    event AddInboundProofLibraryForChain(uint16 indexed chainId, address lib);
    event EnableSupportedOutboundProof(uint16 indexed chainId, uint16 proofType);
    event SetChainAddressSize(uint16 indexed chainId, uint size);
    event SetDefaultConfigForChainId(uint16 indexed chainId, uint16 inboundProofLib, uint64 inboundBlockConfirm, address relayer, uint16 outboundProofType, uint64 outboundBlockConfirm, address oracle);
    event SetDefaultAdapterParamsForChainId(uint16 indexed chainId, uint16 indexed proofType, bytes adapterParams);
    event SetLayerZeroToken(address indexed tokenAddress);
    event SetRemoteUln(uint16 indexed chainId, bytes32 uln);
    event SetTreasury(address indexed treasuryAddress);
    event WithdrawZRO(address indexed msgSender, address indexed to, uint amount);
    event WithdrawNative(address indexed msgSender, address indexed to, uint amount);
}
