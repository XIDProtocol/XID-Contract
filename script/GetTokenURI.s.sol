// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/XID.sol";

contract GetTokenURIScript is Script {
    function run() external {
        // Read the deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address xidAddress = vm.envAddress("XID_ADDRESS");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Initialize XID contract instance
        XID xid = XID(xidAddress);

        // Get tokenId for a specific username
        string memory username = "elonmusk"; // Replace with the username you want to check
        uint256 tokenId = xid.getTokenIdByUsername(username);

        // Get and log the tokenURI
        string memory uri = xid.tokenURI(tokenId);
        
        console.log("Token URI for username '%s' (tokenId: %s):", username, tokenId);
        console.log(uri);

        vm.stopBroadcast();
    }
} 