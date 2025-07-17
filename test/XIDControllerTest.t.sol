// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/XID.sol";
import "../src/XIDController.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract XIDControllerTest is Test {
    XID public xid;
    XIDController public xidController;
    address public deployer;
    address public user1;
    address public signer;
    uint256 public constant MINT_FEE = 0.069 ether;
    uint256 public constant RENEWAL_FEE = 0.069 ether;
    uint256 private deployerPrivateKey;
    uint256 private signerPrivateKey;

    // Added receive function to receive ether
    receive() external payable {}

    // Setup function to initialize the test environment
    function setUp() public {
        // Use fixed test private keys (Hardhat default accounts)
        signerPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        deployer = vm.addr(deployerPrivateKey);
        signer = vm.addr(signerPrivateKey);
        user1 = makeAddr("user1");

        vm.startPrank(deployer);

        xid = new XID();
        xidController = new XIDController(
            address(xid),
            signer,
            deployer,
            MINT_FEE,
            RENEWAL_FEE
        );
        xid.setController(address(xidController));

        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.deal(deployer, 1 ether);
    }

    // Test the minting functionality (mint fee is not free and registrationCheckEnabled is false)
    function testMint() public {
        string memory xUsername = "test123";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 1;
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        // Impersonate user1
        // vm.prank() is used for single call impersonation
        vm.prank(user1);
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        assertEq(
            xid.ownerOf(
                uint256(keccak256(abi.encodePacked(".x", xUsername)))
            ),
            user1
        ); // Check if user1 is the owner of the minted token

        address userAddress = xid.getAddressByUsername(xUsername);
        console.log("userAddress:", userAddress);
        console.log("user1:", user1);
        assertEq(userAddress, user1);
    }

    // Test mint with registrationCheckEnabled is true and mint fee is not free
    function testMintWithRegistrationCheckEnabled() public {
        string memory xUsername = "testRegistrationCheck";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 2;
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        // Impersonate user1
        vm.prank(user1);
        uint256 totalFee = MINT_FEE + RENEWAL_FEE * (registrationYears - 1);
        xidController.mint{value: totalFee}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        // Check if the token was minted correctly
        uint256 tokenId = xid.getTokenIdByUsername(xUsername);
        assertEq(xid.ownerOf(tokenId), user1);

        // Check if the registration expiration time is set correctly
        uint256 expectedExpirationTime = block.timestamp + (365 days * registrationYears);
        assertEq(xid.getUsernameExpirationTime(xUsername), expectedExpirationTime);

        // check the balance of the xidController
        assertEq(address(xidController).balance, totalFee);
    }

    // Test that only signer's signature can mint
    function testOnlySignerCanMint() public {
        string memory xUsername = "testSigner";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 1;
        bytes memory validSignature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        bytes memory invalidSignature = _getInvalidSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        // Attempt to mint with invalid signature
        vm.prank(user1);
        vm.expectRevert("Invalid signature");
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            invalidSignature
        );

        // Mint with valid signature should succeed
        vm.prank(user1);
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            validSignature
        );

        assertEq(
            xid.ownerOf(
                uint256(keccak256(abi.encodePacked(".x", xUsername)))
            ),
            user1
        );
    }

    // Test that signature can't mint after expireAt
    function testSignatureCantMintAfterExpireAt() public {
        string memory xUsername = "testExpire";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 1;
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        // Simulate time passing beyond expireAt
        vm.warp(expireAt + 1);

        // Attempt to mint after expireAt
        vm.prank(user1);
        vm.expectRevert("Expired signature");
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );
    }

    // Test the renewal functionality
    function testRenewal() public {
        string memory xUsername = "test456";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 1;
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        // First mint
        vm.prank(user1);
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        uint256 initialExpiry = xid.getUsernameExpirationTime(xUsername);
        console.log("initialExpiry:", initialExpiry);

        // Simulate some time passing
        vm.warp(block.timestamp + 30 days);

        uint256 renewalYears = 2;
        uint256 initialBalance = address(xidController).balance;

        // Test renewal from a different address (user2)
        address user2 = makeAddr("user2");
        vm.deal(user2, 1 ether);
        vm.prank(user2);
        xidController.renew{value: RENEWAL_FEE * renewalYears}(
            xUsername,
            renewalYears
        );

        // Check if the registration expiration time is updated correctly
        assertEq(
            xid.getUsernameExpirationTime(xUsername),
            initialExpiry + (365 days * renewalYears)
        );

        // Make sure controller gets the right fee
        uint256 expectedFee = RENEWAL_FEE * renewalYears;
        uint256 finalBalance = address(xidController).balance;
        uint256 feeDiff = finalBalance - initialBalance;
        
        // Check if the fee is correct
        assertEq(feeDiff, expectedFee, "Incorrect fee sent to the controller");

        // Check the balance change of the XIDController
        assertEq(
            address(xidController).balance,
            initialBalance + expectedFee,
            "XIDController balance did not update correctly"
        );
    }

    // Test the withdraw functionality
    function testWithdraw() public {
        string memory xUsername = "test789";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 1;
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        vm.prank(user1);
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        assertEq(address(xidController).balance, MINT_FEE);

        address feeReceiver = xidController.feeReceiver();
        uint256 initialReceiverBalance = feeReceiver.balance;

        xidController.claimFees();

        assertEq(address(xidController).balance, 0);
        assertEq(feeReceiver.balance, initialReceiverBalance + MINT_FEE);
    }

    // Test setting the mint fee
    function testSetMintFee() public {
        uint256 initialMintFee = xidController.mintFee();
        console.log("initialMintFee: %s BNB", vm.toString(initialMintFee));
        
        uint256 newMintFee = 0.1 ether;
        vm.prank(deployer); // Impersonate deployer
        xidController.setMintFee(newMintFee);
        assertEq(xidController.mintFee(), newMintFee); // Check if the mint fee is updated correctly
        
        console.log("newMintFee: %s BNB", vm.toString(newMintFee));
    }

    // Test setting the renewal fee
    function testSetRenewalFee() public {
        uint256 newRenewalFee = 0.05 ether;
        vm.prank(deployer); // Impersonate deployer
        xidController.setRenewalFeePerYear(newRenewalFee);
        assertEq(xidController.renewalFeePerYear(), newRenewalFee); // Check if the renewal fee is updated correctly
    }

    // Test setting the signer
    function testSetSigner() public {
        address newSigner = makeAddr("newSigner");
        vm.prank(deployer); // Impersonate deployer
        xidController.setSigner(newSigner);
        assertEq(xidController.signer(), newSigner); // Check if the signer is updated correctly
    }

    // Test that only the owner can set the signer
    function testOnlyOwnerCanSetSigner() public {
        address newSigner = makeAddr("newSigner");

        // Non-owner call should fail
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        xidController.setSigner(newSigner);

        // Owner call should succeed
        vm.prank(deployer);
        xidController.setSigner(newSigner);
        assertEq(xidController.signer(), newSigner); // Check if the signer is updated correctly
    }

    // Test that only the owner can set the mint fee
    function testOnlyOwnerCanSetMintFee() public {
        uint256 newMintFee = 0.1 ether;

        // Non-owner call should fail
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        xidController.setMintFee(newMintFee);

        // Owner call should succeed
        vm.prank(deployer);
        xidController.setMintFee(newMintFee);
        assertEq(xidController.mintFee(), newMintFee); // Check if the mint fee is updated correctly
    }

    // Test that only the owner can set the renewal fee per year
    function testOnlyOwnerCanSetRenewalFeePerYear() public {
        uint256 newRenewalFee = 0.05 ether;

        // Non-owner call should fail
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        xidController.setRenewalFeePerYear(newRenewalFee);

        // Owner call should succeed
        vm.prank(deployer);
        xidController.setRenewalFeePerYear(newRenewalFee);
        assertEq(xidController.renewalFeePerYear(), newRenewalFee); // Check if the renewal fee is updated correctly
    }

    // Test replay attack
    function testReplayAttack() public {
        string memory xUsername = "replayTest";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 1;
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        vm.prank(user1); // Impersonate user1
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        // Replay the same signature
        vm.expectRevert("Invalid signature");
        vm.prank(user1);
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );
    }

    // Helper function: generate mint signature
    function _getMintSignature(
        string memory xUsername,
        address user,
        uint256 expireAt,
        uint256 chainId,
        uint8 isFree,
        uint256 registrationYears
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                xUsername,
                user,
                expireAt,
                chainId,
                xidController.nonces(user),
                isFree,
                registrationYears
            )
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            ethSignedMessageHash
        );
        return abi.encodePacked(r, s, v);
    }

    // Helper function: generate renewal signature
    function _getRenewalSignature(
        string memory xUsername,
        address user,
        uint256 expireAt,
        uint256 chainId,
        uint256 renewalYears
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                xUsername,
                user,
                expireAt,
                chainId,
                xidController.nonces(user),
                renewalYears
            )
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            ethSignedMessageHash
        );
        return abi.encodePacked(r, s, v);
    }

    // Test mint fee adjustment
    function testMintFeeAdjustment() public {
        string memory xUsername = "feeTestUser";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 1;
        uint256 newMintFee = 0.1 ether;
        bytes memory signature;

        // Update mintFee
        vm.prank(deployer);
        xidController.setMintFee(newMintFee);

        // Using the old fee should fail
        signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );
        vm.prank(user1);
        vm.expectRevert("Insufficient mint fee");
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        // Using the new fee should succeed
        vm.prank(user1);
        xidController.mint{value: newMintFee}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        // Verify the user successfully minted
        uint256 tokenId = xid.getTokenIdByUsername(xUsername);
        assertEq(xid.ownerOf(tokenId), user1);
    }

    // Test renewal fee adjustment
    function testRenewalFeeAdjustment() public {
        string memory xUsername = "renewalFeeTestUser";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 1;
        uint256 renewalYears = 2;
        uint256 newRenewalFeePerYear = 0.08 ether;

        // First mint
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );
        vm.prank(user1);
        xidController.mint{value: xidController.mintFee()}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        // Update renewalFeePerYear
        vm.startPrank(deployer);
        xid.setRegistrationCheckEnabled(true);
        xidController.setRenewalFeePerYear(newRenewalFeePerYear);
        vm.stopPrank();

        console.log("New total renewal fee:", newRenewalFeePerYear * renewalYears);
        console.log("Old total renewal fee:", RENEWAL_FEE * renewalYears);

        // Using the old renewal fee should fail
        vm.prank(user1);
        vm.expectRevert("Insufficient renewal fee");
        xidController.renew{value: RENEWAL_FEE * renewalYears}(
            xUsername,
            renewalYears
        );

        // Using the new renewal fee should succeed
        vm.prank(user1);
        xidController.renew{value: newRenewalFeePerYear * renewalYears}(
            xUsername,
            renewalYears
        );

        // Verify the renewal was successful
        uint256 expectedExpiry = block.timestamp + (365 days * (registrationYears + renewalYears));
        assertEq(
            xid.getUsernameExpirationTime(xUsername), 
            expectedExpiry,
            "Registration expiration time not updated correctly"
        );
    }

    // Helper function: generate invalid signature
    function _getInvalidSignature(
        string memory xUsername,
        address user,
        uint256 expireAt,
        uint256 chainId,
        uint8 isFree,
        uint256 registrationYears
    ) internal view returns (bytes memory) {
        uint256 invalidPrivateKey = 0x7c8521182940a5b3ce0d6a2d8a2a5b3ce0d6a2d8a2a5b3ce0d6a2d8a2a5b3ce0;
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                xUsername,
                user,
                expireAt,
                chainId,
                xidController.nonces(user),
                isFree,
                registrationYears
            )
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            invalidPrivateKey,
            ethSignedMessageHash
        );
        return abi.encodePacked(r, s, v);
    }

    // New test cases

    /**
     * @dev Test free mint (isFree = 1)
     */
    function testFreeMint() public {
        string memory xUsername = "freeuser";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 1;
        uint256 registrationYears = 1;
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        uint256 initialBalance = address(xidController).balance;

        // Free mint, no need to send BNB
        vm.prank(user1);
        xidController.mint(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        // Verify token was successfully minted
        uint256 tokenId = xid.getTokenIdByUsername(xUsername);
        assertEq(xid.ownerOf(tokenId), user1);

        // Verify contract balance didn't change
        assertEq(address(xidController).balance, initialBalance);
    }

    /**
     * @dev Test chain ID validation
     */
    function testInvalidChainId() public {
        string memory xUsername = "chaintest";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 wrongChainId = 999; // Wrong chain ID
        uint8 isFree = 0;
        uint256 registrationYears = 1;
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            wrongChainId,
            isFree,
            registrationYears
        );

        vm.prank(user1);
        vm.expectRevert("Invalid ChainId");
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            wrongChainId,
            isFree,
            registrationYears,
            signature
        );
    }

    /**
     * @dev Test registrationYears boundary conditions
     */
    function testRegistrationYearsBoundary() public {
        string memory xUsername = "boundarytest";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 0; // Invalid registration years
        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        vm.prank(user1);
        vm.expectRevert("Registration years must be at least 1");
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );
    }

    /**
     * @dev Test renewalYears boundary conditions
     */
    function testRenewalYearsBoundary() public {
        string memory xUsername = "renewalboundary";

        // First mint a token
        vm.prank(user1);
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            block.timestamp + 1 days,
            block.chainid,
            0,
            1,
            _getMintSignature(xUsername, user1, block.timestamp + 1 days, block.chainid, 0, 1)
        );

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        // Test renewalYears = 0
        vm.prank(user1);
        vm.expectRevert("Renewal years must be greater than 1");
        xidController.renew{value: RENEWAL_FEE}(xUsername, 0);
    }

    /**
     * @dev Test setFeeReceiver function
     */
    function testSetFeeReceiver() public {
        address newFeeReceiver = makeAddr("newFeeReceiver");
        
        // Non-owner call should fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        xidController.setFeeReceiver(newFeeReceiver);

        // Owner call should succeed
        vm.expectEmit(true, true, false, false);
        emit XIDController.FeeReceiverChanged(deployer, newFeeReceiver);
        
        vm.prank(deployer);
        xidController.setFeeReceiver(newFeeReceiver);
        
        assertEq(xidController.feeReceiver(), newFeeReceiver);
    }

    /**
     * @dev Test claimFees function
     */
    function testClaimFees() public {
        // First mint some tokens to generate fees
        string memory xUsername = "claimtest";
        vm.prank(user1);
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            block.timestamp + 1 days,
            block.chainid,
            0,
            1,
            _getMintSignature(xUsername, user1, block.timestamp + 1 days, block.chainid, 0, 1)
        );

        address feeReceiver = xidController.feeReceiver();
        uint256 initialBalance = feeReceiver.balance;
        uint256 contractBalance = address(xidController).balance;

        // Anyone can call claimFees
        vm.expectEmit(true, false, false, true);
        emit XIDController.FeesClaimed(feeReceiver, contractBalance);
        
        vm.prank(user1);
        xidController.claimFees();

        // Verify fees were correctly transferred
        assertEq(address(xidController).balance, 0);
        assertEq(feeReceiver.balance, initialBalance + contractBalance);
    }

    /**
     * @dev Test calling claimFees when there are no fees
     */
    function testClaimFeesWhenNoFees() public {
        vm.prank(user1);
        vm.expectRevert("No fees to claim");
        xidController.claimFees();
    }

    /**
     * @dev Test setSigner with zero address
     */
    function testSetSignerZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert("Signer address cannot be zero");
        xidController.setSigner(address(0));
    }

    /**
     * @dev Test event emission
     */
    function testControllerEvents() public {
        address newSigner = makeAddr("newSigner");
        address newFeeReceiver = makeAddr("newFeeReceiver");
        uint256 newMintFee = 0.1 ether;
        uint256 newRenewalFee = 0.05 ether;

        vm.startPrank(deployer);

        // Test SignerChanged event
        vm.expectEmit(true, true, false, false);
        emit XIDController.SignerChanged(signer, newSigner);
        xidController.setSigner(newSigner);

        // Test FeeReceiverChanged event
        vm.expectEmit(true, true, false, false);
        emit XIDController.FeeReceiverChanged(deployer, newFeeReceiver);
        xidController.setFeeReceiver(newFeeReceiver);

        // Test MintFeeChanged event
        vm.expectEmit(false, false, false, true);
        emit XIDController.MintFeeChanged(MINT_FEE, newMintFee);
        xidController.setMintFee(newMintFee);

        // Test RenewalFeePerYearChanged event
        vm.expectEmit(false, false, false, true);
        emit XIDController.RenewalFeePerYearChanged(RENEWAL_FEE, newRenewalFee);
        xidController.setRenewalFeePerYear(newRenewalFee);

        vm.stopPrank();
    }

    /**
     * @dev Test fee calculation for multi-year registration
     */
    function testMultiYearRegistrationFee() public {
        string memory xUsername = "multiyear";
        uint256 expireAt = block.timestamp + 1 days;
        uint256 chainId = block.chainid;
        uint8 isFree = 0;
        uint256 registrationYears = 5;

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        bytes memory signature = _getMintSignature(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears
        );

        uint256 expectedTotalFee = MINT_FEE + RENEWAL_FEE * (registrationYears - 1);

        // Insufficient fee should fail
        vm.prank(user1);
        vm.expectRevert("Insufficient mint fee");
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        // Correct fee should succeed
        vm.prank(user1);
        xidController.mint{value: expectedTotalFee}(
            xUsername,
            user1,
            expireAt,
            chainId,
            isFree,
            registrationYears,
            signature
        );

        // Verify contract balance
        assertEq(address(xidController).balance, expectedTotalFee);
    }

    /**
     * @dev Test insufficient fee when renewing
     */
    function testRenewInsufficientFee() public {
        string memory xUsername = "renewfeetest";
        
        // First mint a token
        vm.prank(user1);
        xidController.mint{value: MINT_FEE}(
            xUsername,
            user1,
            block.timestamp + 1 days,
            block.chainid,
            0,
            1,
            _getMintSignature(xUsername, user1, block.timestamp + 1 days, block.chainid, 0, 1)
        );

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        uint256 renewalYears = 2;
        uint256 requiredFee = RENEWAL_FEE * renewalYears;

        // Insufficient fee should fail
        vm.prank(user1);
        vm.expectRevert("Insufficient renewal fee");
        xidController.renew{value: requiredFee - 1}(xUsername, renewalYears);

        // Correct fee should succeed
        vm.prank(user1);
        xidController.renew{value: requiredFee}(xUsername, renewalYears);
    }
}
