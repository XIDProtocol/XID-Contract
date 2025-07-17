// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/XID.sol";
import "../src/XIDController.sol";

/// @title Script to deploy XID, XIDController contracts
/// @notice This script deploys all contracts and performs necessary initialization
contract DeployContract is Script {
    function run() external {
        // Read the deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Read the signer's address from environment variables
        address signerAddress = vm.envAddress("SIGNER_ADDRESS");
        // Read the fee receiver's address from environment variables (Added)
        address feeReceiverAddress = vm.envAddress("FEE_RECEIVER_ADDRESS");
        // Read the actual owner's address from environment variables (Optional)
        // address ownerAddress = vm.envAddress("OWNER_ADDRESS");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy XID contract
        XID xid = new XID();

        // Set minting fee to 0.028 BNB
        uint256 mintFee = 0.028 ether;
        // Set annual renewal fee to 0.028 BNB
        uint256 renewalFeePerYear = 0.028 ether;

        // Deploy XIDController contract with necessary parameters
        XIDController xidController = new XIDController(
            address(xid),
            signerAddress,
            feeReceiverAddress,  // Fix: Add missing parameter
            mintFee,
            renewalFeePerYear
        );

        // Set the controller address of XID contract to the newly deployed XIDController address
        xid.setController(address(xidController));

        // Optional: Enable registration check (Default is disabled)
        // xid.setRegistrationCheckEnabled(true);

        // Optional: Set base URI for tokens
        // xid.setTokenURI("https://api.xid.so/metadata/");

        // Transfer ownership of XID and XIDController to the actual owner (Optional)
        // xid.transferOwnership(ownerAddress);
        // xidController.transferOwnership(ownerAddress);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Output deployed contract addresses for future use
        console.log("=== Deployment Summary ===");
        console.log("XID deployed at:", address(xid));
        console.log("XIDController deployed at:", address(xidController));
        console.log("Signer address:", signerAddress);
        console.log("Fee receiver address:", feeReceiverAddress);
        console.log("Mint fee:", mintFee);
        console.log("Renewal fee per year:", renewalFeePerYear);
        console.log("Registration check enabled:", xid.registrationCheckEnabled());
        // console.log("Ownership transferred to:", ownerAddress);
    }
}
