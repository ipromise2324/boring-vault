// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

// source .env && forge script script/MerkleRootCreation/SetMerkleRoot.s.sol:SetManageRootScript --rpc-url base --broadcast
contract SetManageRootScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address managerAddress = 0x604E583c4fBDEC99944D158eCbC7020830274BCa;
        address strategist = 0x4A7bCebEc5b0A02Ad51F858741a76cFA17fDe637;
        bytes32 newRoot = 0x41e0275a47590b15151f346d68c08e2eb3096dabdab86cc4f5c39362996cf17b;

        vm.startBroadcast(privateKey);
        ManagerWithMerkleVerification(managerAddress).setManageRoot(strategist, newRoot);
        vm.stopBroadcast();

        bytes32 afterRoot = ManagerWithMerkleVerification(managerAddress).manageRoot(strategist);
        console.log("After update:");
        console.logBytes32(afterRoot);
    }
}