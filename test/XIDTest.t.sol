// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/XID.sol";

contract XIDTest is Test {
    XID public xid;
    address public deployer;
    address public user1;
    address public user2;
    address public mockController;

    function setUp() public {
        deployer = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        mockController = makeAddr("mockController");

        xid = new XID();
        xid.setController(mockController);
    }

    function testSetController() public {
        address newController = makeAddr("newController");
        xid.setController(newController);
        assertEq(xid.controller(), newController);
    }

    function testMint() public {
        string memory username = "testuser";
        uint256 tokenId = xid.getTokenIdByUsername(username);
        uint256 registrationYears = 1;

        vm.prank(mockController);
        xid.mint(user1, username, registrationYears);

        assertEq(xid.ownerOf(tokenId), user1);
        assertEq(xid.getAddressByUsername(username), user1);
        assertEq(xid.getUsernameByAddress(user1), username);
    }

    function testBurnXIDViaRemint() public {
        string memory username = "burnuser";
        uint256 tokenId = xid.getTokenIdByUsername(username);
        uint256 registrationYears = 1;

        // Enable registration check first
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        // First mint to user1
        vm.prank(mockController);
        xid.mint(user1, username, registrationYears);

        // Store initial data for verification
        uint256 initialExpirationTime = xid.getUsernameExpirationTime(username);
        assertTrue(initialExpirationTime > 0, "Expiration time should be set");
        assertEq(xid.ownerOf(tokenId), user1, "Wrong initial owner");
        assertEq(xid.getUsernameByAddress(user1), username, "Wrong initial username");

        // Now mint the same username to user2, which should trigger _burnXID for user1
        vm.prank(mockController);
        xid.mint(user2, username, registrationYears);

        // Verify user1's token was burned - should return empty string instead of revert
        assertEq(xid.getUsernameByAddress(user1), "", "Should return empty string for burned user");

        // Verify user2 is now the owner
        assertEq(xid.ownerOf(tokenId), user2, "Wrong new owner");
        assertEq(xid.getUsernameByAddress(user2), username, "Wrong new username");

        // Direct storage checks for user1's old data
        bytes32 usernameSlot = keccak256(abi.encode(user1, uint256(0))); 
        assertEq(uint256(vm.load(address(xid), usernameSlot)), 0, "Username mapping not cleared for user1");
    }

    function testRenew() public {
        string memory username = "renewuser";
        uint256 tokenId = xid.getTokenIdByUsername(username);
        uint256 initialRegistrationYears = 1;
        uint256 renewalYears = 2;

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        vm.prank(mockController);
        xid.mint(user1, username, initialRegistrationYears);

        uint256 initialExpirationTime = xid.getUsernameExpirationTime(username);

        // Simulate time passing
        vm.warp(block.timestamp + 180 days);

        vm.prank(mockController);
        xid.renew(tokenId, renewalYears);

        uint256 newExpirationTime = xid.getUsernameExpirationTime(username);
        assertEq(
            newExpirationTime,
            initialExpirationTime + (renewalYears * 365 days)
        );
    }

    function testTransferRevert() public {
        string memory username = "transferuser";
        uint256 tokenId = xid.getTokenIdByUsername(username);
        uint256 registrationYears = 1;

        vm.prank(mockController);
        xid.mint(user1, username, registrationYears);

        vm.prank(user1);
        vm.expectRevert("XID: SoulBound, Transfer failed");
        xid.transferFrom(user1, user2, tokenId);
    }

    function testSetRegistrationCheckEnabled() public {
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);
        assertTrue(xid.registrationCheckEnabled());

        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(false);
        assertFalse(xid.registrationCheckEnabled());
    }

    function testSetRegistrationDuration() public {
        uint256 newDuration = 2 * 365 days;
        vm.prank(deployer);
        xid.setRegistrationDuration(newDuration);
        assertEq(xid.registrationDuration(), newDuration);
    }

    function testSetTokenURI() public {
        string memory newURI = "https://example.com/";
        vm.prank(deployer);
        xid.setTokenURI(newURI);

        string memory username = "jackleeio";
        uint256 tokenId = xid.getTokenIdByUsername(username);
        uint256 registrationYears = 1;

        vm.prank(mockController);
        xid.mint(user1, username, registrationYears);
    
        console.log("tokenURI: %s", xid.tokenURI(tokenId));

        assertEq(
            xid.tokenURI(tokenId),
            string(abi.encodePacked(newURI, username))
        );
    }

    function testIsRegistrationValid() public {
        string memory username = "validuser";
        uint256 tokenId = xid.getTokenIdByUsername(username);
        uint256 registrationYears = 1;

        vm.prank(mockController);
        xid.mint(user1, username, registrationYears);

        assertTrue(xid.isRegistrationValid(tokenId));

        // Simulate time passing beyond registration period
        vm.warp(block.timestamp + 366 days);

        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        assertFalse(xid.isRegistrationValid(tokenId));
    }

    function testRegistrationExpired() public {
        string memory username = "expireduser";
        uint256 tokenId = xid.getTokenIdByUsername(username);
        uint256 registrationYears = 1;

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        // Mint the token
        vm.prank(mockController);
        xid.mint(user1, username, registrationYears);

        // Get initial expiration time
        uint256 initialExpirationTime = xid.getUsernameExpirationTime(username);
        assertTrue(initialExpirationTime > 0, "Initial expiration time should be set");

        // Move time forward past expiration
        vm.warp(block.timestamp + 366 days);

        // Verify expiration time remains unchanged
        assertEq(xid.getUsernameExpirationTime(username), initialExpirationTime, "Expiration time should remain unchanged");

        // Verify all queries return default values instead of reverting
        assertEq(xid.getUsernameByAddress(user1), "", "Should return empty string for expired registration");
        assertEq(xid.getAddressByUsername(username), address(0), "Should return zero address for expired registration");

        vm.expectRevert("XID: Registration expired");
        xid.getTokenIdByAddress(user1);

        vm.expectRevert("XID: Registration expired");
        xid.getAddressByTokenId(tokenId);

        vm.expectRevert("XID: Registration expired");
        xid.getUsernameByTokenId(tokenId);
    }

    function testUnregisteredQueries() public {
        address unregisteredUser = makeAddr("unregistered");
        string memory nonExistentUsername = "nonexistent";
        uint256 nonExistentTokenId = xid.getTokenIdByUsername(nonExistentUsername);

        // These should return default values instead of reverting
        assertEq(xid.getUsernameByAddress(unregisteredUser), "", "Should return empty string for unregistered user");
        assertEq(xid.getAddressByUsername(nonExistentUsername), address(0), "Should return zero address for nonexistent username");

        // These still revert because they use different logic
        vm.expectRevert("XID: Username is not registered");
        xid.getTokenIdByAddress(unregisteredUser);

        vm.expectRevert(
            abi.encodeWithSignature("ERC721NonexistentToken(uint256)", nonExistentTokenId)
        );
        xid.getAddressByTokenId(nonExistentTokenId);

        vm.expectRevert(
            abi.encodeWithSignature("ERC721NonexistentToken(uint256)", nonExistentTokenId)
        );
        xid.getUsernameByTokenId(nonExistentTokenId);
    }

    function testRebindExpiredXID() public {
        string memory username = "expiredrebind";
        uint256 tokenId = xid.getTokenIdByUsername(username);
        uint256 registrationYears = 1;

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        // First mint to user1
        vm.prank(mockController);
        xid.mint(user1, username, registrationYears);

        // Store initial data
        uint256 initialExpirationTime = xid.getUsernameExpirationTime(username);
        assertEq(xid.ownerOf(tokenId), user1, "Wrong initial owner");
        assertEq(xid.getUsernameByAddress(user1), username, "Wrong initial username");

        // Move time forward past expiration
        vm.warp(block.timestamp + 366 days);

        // Verify queries return default values for expired registration
        assertEq(xid.getUsernameByAddress(user1), "", "Should return empty string for expired registration");

        // Now mint the same username to user2
        vm.prank(mockController);
        xid.mint(user2, username, registrationYears);

        // Verify user2 is now the owner
        assertEq(xid.ownerOf(tokenId), user2, "Wrong new owner");
        assertEq(xid.getUsernameByAddress(user2), username, "Wrong new username");
        
        // Verify new expiration time is set correctly
        uint256 newExpirationTime = xid.getUsernameExpirationTime(username);
        assertGt(newExpirationTime, initialExpirationTime, "New expiration time should be greater");
        assertEq(
            newExpirationTime,
            block.timestamp + (registrationYears * 365 days),
            "Wrong new expiration time"
        );

        // Verify user1's data is cleared - should return empty string
        assertEq(xid.getUsernameByAddress(user1), "", "Should return empty string for cleared user");
    }

    function testGetUsernamesByAddresses() public {
        // Setup test data
        string[] memory usernames = new string[](3);
        usernames[0] = "user1name";
        usernames[1] = "user2name";
        usernames[2] = "user3name";
        
        address[] memory users = new address[](3);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
        users[2] = makeAddr("user3");

        // Mint XID tokens for first two users
        vm.startPrank(mockController);
        xid.mint(users[0], usernames[0], 1);
        xid.mint(users[1], usernames[1], 1);
        vm.stopPrank();

        // Create input array for testing
        address[] memory testAddresses = new address[](4);
        testAddresses[0] = users[0];      // Valid user
        testAddresses[1] = users[1];      // Valid user
        testAddresses[2] = users[2];      // Unminted user
        testAddresses[3] = address(0);    // Zero address

        // Get usernames
        string[] memory resultUsernames = xid.getUsernamesByAddresses(testAddresses);

        // Verify results
        assertEq(resultUsernames.length, 4);
        assertEq(resultUsernames[0], usernames[0]);  // Should return valid username
        assertEq(resultUsernames[1], usernames[1]);  // Should return valid username
        assertEq(resultUsernames[2], "");            // Should return empty string
        assertEq(resultUsernames[3], "");            // Should return empty string
    }

    function testGetAddressesByUsernames() public {
        // Setup test data
        string[] memory usernames = new string[](3);
        usernames[0] = "user1name";
        usernames[1] = "user2name";
        usernames[2] = "user3name";
        
        address[] memory users = new address[](3);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
        users[2] = makeAddr("user3");

        // Mint XID tokens for first two users
        vm.startPrank(mockController);
        xid.mint(users[0], usernames[0], 1);
        xid.mint(users[1], usernames[1], 1);
        vm.stopPrank();

        // Create input array for testing
        string[] memory testUsernames = new string[](4);
        testUsernames[0] = usernames[0];      // Valid username
        testUsernames[1] = usernames[1];      // Valid username
        testUsernames[2] = usernames[2];      // Unminted username
        testUsernames[3] = "nonexistent";     // Nonexistent username

        // Get addresses
        address[] memory resultAddresses = xid.getAddressesByUsernames(testUsernames);

        // Verify results
        assertEq(resultAddresses.length, 4);
        assertEq(resultAddresses[0], users[0]);       // Should return valid address
        assertEq(resultAddresses[1], users[1]);       // Should return valid address
        assertEq(resultAddresses[2], address(0));     // Should return zero address
        assertEq(resultAddresses[3], address(0));     // Should return zero address
    }

    function testGetUsernamesByAddressesWithExpiredRegistrations() public {
        // Setup test data for multiple users
        address[] memory users = new address[](4);
        string[] memory usernames = new string[](4);
        uint256[] memory regYears = new uint256[](4);

        // Initialize test data
        for(uint256 i = 0; i < 4; i++) {
            users[i] = makeAddr(string.concat("user", vm.toString(i)));
            usernames[i] = string.concat("user", vm.toString(i), ".name");
        }
        regYears[0] = 1; // Will expire
        regYears[1] = 2; // Won't expire
        regYears[2] = 1; // Will expire
        regYears[3] = 3; // Won't expire

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        // Mint tokens for all users
        vm.startPrank(mockController);
        for(uint256 i = 0; i < 4; i++) {
            xid.mint(users[i], usernames[i], regYears[i]);
        }
        vm.stopPrank();

        // Move time forward 400 days (just over 1 year)
        vm.warp(block.timestamp + 400 days);

        // Create input array with all users plus an invalid address
        address[] memory testAddresses = new address[](5);
        for(uint256 i = 0; i < 4; i++) {
            testAddresses[i] = users[i];
        }
        testAddresses[4] = address(0); // Add zero address

        // Get usernames
        string[] memory resultUsernames = xid.getUsernamesByAddresses(testAddresses);

        // Verify results
        assertEq(resultUsernames.length, 5);
        assertEq(resultUsernames[0], "");              // Should be empty (expired)
        assertEq(resultUsernames[1], usernames[1]);    // Should be valid (2 year registration)
        assertEq(resultUsernames[2], "");              // Should be empty (expired)
        assertEq(resultUsernames[3], usernames[3]);    // Should be valid (3 year registration)
        assertEq(resultUsernames[4], "");              // Should be empty (zero address)
    }

    function testGetAddressesByUsernamesWithExpiredRegistrations() public {
        // Setup test data for multiple users
        address[] memory users = new address[](4);
        string[] memory usernames = new string[](4);
        uint256[] memory regYears = new uint256[](4);

        // Initialize test data
        for(uint256 i = 0; i < 4; i++) {
            users[i] = makeAddr(string.concat("user", vm.toString(i)));
            usernames[i] = string.concat("user", vm.toString(i), ".name");
        }
        regYears[0] = 1; // Will expire
        regYears[1] = 2; // Won't expire
        regYears[2] = 1; // Will expire
        regYears[3] = 3; // Won't expire

        // Enable registration check
        vm.prank(deployer);
        xid.setRegistrationCheckEnabled(true);

        // Mint tokens for all users
        vm.startPrank(mockController);
        for(uint256 i = 0; i < 4; i++) {
            xid.mint(users[i], usernames[i], regYears[i]);
        }
        vm.stopPrank();

        // Move time forward 400 days (just over 1 year)
        vm.warp(block.timestamp + 400 days);

        // Create input array with all usernames plus a nonexistent username
        string[] memory testUsernames = new string[](5);
        for(uint256 i = 0; i < 4; i++) {
            testUsernames[i] = usernames[i];
        }
        testUsernames[4] = "nonexistent.user";

        // Get addresses
        address[] memory resultAddresses = xid.getAddressesByUsernames(testUsernames);

        // Verify results
        assertEq(resultAddresses.length, 5);
        assertEq(resultAddresses[0], address(0));    // Should be zero address (expired)
        assertEq(resultAddresses[1], users[1]);      // Should be valid (2 year registration)
        assertEq(resultAddresses[2], address(0));    // Should be zero address (expired)
        assertEq(resultAddresses[3], users[3]);      // Should be valid (3 year registration)
        assertEq(resultAddresses[4], address(0));    // Should be zero address (nonexistent user)
    }
}
