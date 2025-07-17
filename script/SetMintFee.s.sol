// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/XIDController.sol";

contract SetMintFee is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address xidControllerAddress = vm.envAddress("XID_CONTROLLER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        XIDController xidController = XIDController(xidControllerAddress);

        // New mintFee (0.0068 BNB)
        uint256 newMintFee = 0.0068 ether;

        xidController.setMintFee(newMintFee);

        vm.stopBroadcast();

        console.log("Mint fee updated to:", newMintFee);
    }
}
