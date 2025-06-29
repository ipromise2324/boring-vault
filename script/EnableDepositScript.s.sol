// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

// source .env && forge script script/EnableDepositScript.s.sol:EnableDepositScript --rpc-url base
contract EnableDepositScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address tellerAddress = 0x8a6279D74dC894beD5fE83571691EBb7b2F7086A;
        // address rolesAuthority = 0xcA4781a6F8e7f1bde87A82751200A58e66ED300E;
        address cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

        // 你可以根據需求調整 allowWithdraws/ sharePremium
        bool allowDeposits = true;
        bool allowWithdraws = true;
        uint16 sharePremium = 0;
        // uint8 MINTER_ROLE = 2;

        vm.startBroadcast(privateKey);

        TellerWithMultiAssetSupport(tellerAddress).updateAssetData(
            ERC20(cbbtc), allowDeposits, allowWithdraws, sharePremium
        );

        // RolesAuthority(rolesAuthority).setPublicCapability(
        //     tellerAddress,
        //     TellerWithMultiAssetSupport.deposit.selector,
        //     true
        // );

        // // 給 teller MINTER_ROLE 權限
        // RolesAuthority(rolesAuthority).setUserRole(
        //     tellerAddress,
        //     MINTER_ROLE,
        //     true
        // );

        vm.stopBroadcast();
    }
}