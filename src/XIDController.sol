// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./XID.sol";

/**
 * @title XIDController
 * @notice Controls the minting and renewal operations for XID
 * @dev Implements signature-based verification for minting and renewal operations
 * with fee management and access control
 */
contract XIDController is Ownable, Nonces {
    using ECDSA for bytes32;

    // Reference to the XID contract
    XID public xID;

    // Address authorized to sign minting and renewal messages
    address public signer;

    // Address that receives the fees
    address public feeReceiver;

    // Fee required for minting a new XID
    uint256 public mintFee;

    // Fee required per year for renewing XID
    uint256 public renewalFeePerYear;

    // Immutable chain ID used for signature verification
    uint256 private immutable _cachedChainId;

    /**
     * @notice Emitted when the authorized signer address is updated
     * @param oldSigner Previous authorized signer address
     * @param newSigner New authorized signer address
     */
    event SignerChanged(address indexed oldSigner, address indexed newSigner);

    /**
     * @notice Emitted when the fee receiver address is updated
     */
    event FeeReceiverChanged(address indexed oldReceiver, address indexed newReceiver);

    /**
     * @notice Emitted when the minting fee is updated
     * @param oldFee Previous minting fee
     * @param newFee New minting fee
     */
    event MintFeeChanged(uint256 oldFee, uint256 newFee);

    /**
     * @notice Emitted when the annual renewal fee is updated
     * @param oldFee Previous annual renewal fee
     * @param newFee New annual renewal fee
     */
    event RenewalFeePerYearChanged(uint256 oldFee, uint256 newFee);

    /**
     * @notice Emitted when fees are claimed
     */
    event FeesClaimed(address indexed to, uint256 amount);

    /**
     * @notice Initializes the XIDController contract
     * @param XIDAddress Address of the XID contract
     * @param signerAddress Address authorized to sign minting and renewal messages
     * @param feeReceiverAddress Address that receives the fees
     * @param price Initial minting fee
     * @param renewPricePerYear Initial annual renewal fee
     * @dev Sets initial parameters and caches the chain ID for signature verification
     */
    constructor(
        address XIDAddress,
        address signerAddress,
        address feeReceiverAddress,
        uint256 price,
        uint256 renewPricePerYear
    ) Ownable(msg.sender) {
        xID = XID(XIDAddress);
        signer = signerAddress;
        feeReceiver = feeReceiverAddress;
        mintFee = price;
        renewalFeePerYear = renewPricePerYear;
        _cachedChainId = block.chainid;
    }

    /**
     * @dev Mints a new XID token if provided signature is valid.
     * @param xUsername The X username to be associated with the XID.
     * @param user The address of user who will receive the XID.
     * @param expireAt The expiration time of signature.
     * @param chainId The chain ID.
     * @param isFree Indicates if the minting is free (1 for free, 0 otherwise).
     * @param registrationYears The number of years to register XID for.
     * @param signature The signature to verify the mint request.
     */
    function mint(
        string memory xUsername,
        address user,
        uint256 expireAt,
        uint256 chainId,
        uint8 isFree,
        uint256 registrationYears,
        bytes memory signature
    ) external payable {
        require(chainId == _cachedChainId, "Invalid ChainId");
        require(
            registrationYears >= 1,
            "Registration years must be at least 1"
        );

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                xUsername,
                user,
                expireAt,
                chainId,
                _useNonce(user),
                isFree,
                registrationYears
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );

        require(expireAt >= block.timestamp, "Expired signature");
        require(
            ECDSA.recover(ethSignedMessageHash, signature) == signer,
            "Invalid signature"
        );

        if (isFree == 0) {
            uint256 totalFee = mintFee;
            if (xID.registrationCheckEnabled()) {
                totalFee += renewalFeePerYear * (registrationYears - 1);
            }
            require(msg.value >= totalFee, "Insufficient mint fee");
        }

        xID.mint(user, xUsername, registrationYears);
    }

    /**
     * @notice Renews an existing XID token for additional years
     * @param xUsername The X username associated with the XID to renew
     * @param renewalYears The number of years to renew for
     */
    function renew(
        string memory xUsername,
        uint256 renewalYears
    ) external payable {
        require(renewalYears >= 1, "Renewal years must be greater than 1");
        
        uint256 tokenId = xID.getTokenIdByUsername(xUsername);
        uint256 totalFee = renewalFeePerYear * renewalYears;
        require(msg.value >= totalFee, "Insufficient renewal fee");

        xID.renew(tokenId, renewalYears);
    }

    /**
     * @dev Sets a new signer address. Only callable by the owner.
     * @param newSigner The new signer address.
     */
    function setSigner(address newSigner) public onlyOwner {
        require(newSigner != address(0), "Signer address cannot be zero");
        address oldSigner = signer;
        signer = newSigner;
        emit SignerChanged(oldSigner, newSigner);
    }

    /**
     * @dev Sets a new fee receiver address. Only callable by the owner.
     * @param newFeeReceiver The new fee receiver address.
     */
    function setFeeReceiver(address newFeeReceiver) public onlyOwner {
        address oldReceiver = feeReceiver;
        feeReceiver = newFeeReceiver;
        emit FeeReceiverChanged(oldReceiver, newFeeReceiver);
    }

    /**
     * @dev Sets a new mint fee. Only callable by the owner.
     * @param newFee The new mint fee.
     */
    function setMintFee(uint256 newFee) public onlyOwner {
        uint256 oldFee = mintFee;
        mintFee = newFee;
        emit MintFeeChanged(oldFee, newFee);
    }

    /**
     * @dev Sets a new renewal fee per year. Only callable by the owner.
     * @param newFee The new renewal fee per year.
     */
    function setRenewalFeePerYear(uint256 newFee) public onlyOwner {
        uint256 oldFee = renewalFeePerYear;
        renewalFeePerYear = newFee;
        emit RenewalFeePerYearChanged(oldFee, newFee);
    }

    /**
     * @dev Claims all accumulated fees to the fee receiver address.
     * Can be called by anyone.
     */
    function claimFees() public {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to claim");
        
        (bool success, ) = payable(feeReceiver).call{value: balance}("");
        require(success, "Fee transfer failed");
        
        emit FeesClaimed(feeReceiver, balance);
    }

}
