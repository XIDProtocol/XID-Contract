// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/XIDController.sol";

/**
 * @title SetFeeReceiver Script
 * @notice Script to update the fee receiver address in XIDController contract
 * @dev Usage: forge script script/SetFeeReceiver.s.sol --rpc-url <network> --broadcast
 */
contract SetFeeReceiver is Script {
    function run() external {
        // Read the deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Read the XIDController contract address
        address xidControllerAddress = vm.envAddress("XID_CONTROLLER_ADDRESS");
        
        // Read the new fee receiver address from environment variables
        address newFeeReceiver = vm.envAddress("FEE_RECEIVER_ADDRESS");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Initialize XIDController contract instance
        XIDController xidController = XIDController(xidControllerAddress);

        // Get current fee receiver for comparison
        address currentFeeReceiver = xidController.feeReceiver();
        
        // Validate the new address is different and not zero
        require(newFeeReceiver != address(0), "New fee receiver cannot be zero address");
        require(newFeeReceiver != currentFeeReceiver, "New fee receiver is the same as current");

        // Set the new fee receiver
        xidController.setFeeReceiver(newFeeReceiver);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Output the results
        console.log("=== Fee Receiver Update Summary ===");
        console.log("XIDController address:", xidControllerAddress);
        console.log("Previous fee receiver:", currentFeeReceiver);
        console.log("New fee receiver:", newFeeReceiver);
        console.log("Fee receiver successfully updated!");
    }
} 