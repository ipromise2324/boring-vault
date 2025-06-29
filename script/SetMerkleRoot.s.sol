// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

// source .env && forge script script/SetMerkleRoot.s.sol:SetManageRootScript --rpc-url base --broadcast
contract SetManageRootScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address managerAddress = 0x747e2d36704f59EB18a1b7a7d3884e29628DF28a;
        address strategist = 0x4A7bCebEc5b0A02Ad51F858741a76cFA17fDe637;
        bytes32 newRoot = 0x78d90651260928ab2cb4c00df65b1f428c9e5a9f69e97b7ec80a8ab20a8592ca;

        vm.startBroadcast(privateKey);
        ManagerWithMerkleVerification(managerAddress).setManageRoot(strategist, newRoot);
        vm.stopBroadcast();

        bytes32 afterRoot = ManagerWithMerkleVerification(managerAddress).manageRoot(strategist);
        console.log("After update:");
        console.logBytes32(afterRoot);
    }
}