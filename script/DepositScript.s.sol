// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

// source .env && forge script script/DepositScript.s.sol:DepositScript --rpc-url base --broadcast
contract DepositScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address boringVault = 0x9bD6942a07fD45C4630Cf67dAD66256efEC4C70e;
        address tellerAddress = 0x8a6279D74dC894beD5fE83571691EBb7b2F7086A;
        address cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
        // 0.000 007 96
        uint256 amount = 1; // 0.00000 928 697 211 329 tBTC (18 decimals)
        uint256 minShares = 0; // 不設下限

        // 查詢 assetData
        (bool allowDeposits, bool allowWithdraws, uint16 sharePremium) =
            TellerWithMultiAssetSupport(tellerAddress).assetData(ERC20(cbbtc));
        console.log("allowDeposits:", allowDeposits);
        console.log("allowWithdraws:", allowWithdraws);
        console.log("sharePremium:", uint256(sharePremium));

        vm.startBroadcast(privateKey);

        // 先 approve USDC 給 teller
        ERC20(cbbtc).approve(boringVault, amount);

        // 存款
        TellerWithMultiAssetSupport(tellerAddress).deposit(ERC20(cbbtc), amount, minShares);

        vm.stopBroadcast();
    }
}