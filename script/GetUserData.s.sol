// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../src/XIDController.sol";
import "../src/XID.sol";

contract GetUserDataScript is Script {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    function run() external {
        // Read private key for sending transactions
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Use private key to start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deployed contract addresses, ensure they are correct
        address xidAddress = vm.envAddress("XID_ADDRESS"); // Replace with actual address

        // Initialize contract instance
        XID xid = XID(xidAddress);

        address userAddress = xid.getAddressByUsername("elonmusk");
        console.log("userAddress:", userAddress);
        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}

