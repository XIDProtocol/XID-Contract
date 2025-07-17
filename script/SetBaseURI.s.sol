// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/XID.sol";

contract SetBaseURIScript is Script {
    function run() external {
        // Read the deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address xidAddress = vm.envAddress("XID_ADDRESS");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Initialize XID contract instance
        XID xid = XID(xidAddress);

        // Set the new base URI
        // Make sure to include trailing slash if needed
        string memory newBaseURI = "https://api.xid.so/baseURI/"; // Replace with your desired base URI
        
        xid.setTokenURI(newBaseURI);
        
        console.log("Base URI updated to:", newBaseURI);

        vm.stopBroadcast();
    }
} 