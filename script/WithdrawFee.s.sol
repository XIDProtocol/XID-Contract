// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../src/XIDController.sol";

contract WithdrawFee is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address xidControllerAddress = vm.envAddress("XID_CONTROLLER_ADDRESS");

        XIDController xidController = XIDController(xidControllerAddress);

        xidController.claimFees();

        vm.stopBroadcast();
    }
}
