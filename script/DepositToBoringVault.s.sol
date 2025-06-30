// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

// source .env && forge script script/DepositToBoringVault.s.sol:DepositToBoringVault --rpc-url base --broadcast
contract DepositToBoringVault is Script {
    function run() external {
        uint256 privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address deployer = vm.addr(privateKey);
        address tellerAddress = 0x9fAF90689A215cb595e8Af204A0973d0fcad682B;
        address cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

        // Get deployer's cbBTC balance
        uint256 currentBalance = ERC20(cbbtc).balanceOf(deployer);
        console.log("Current cbBTC balance:");
        console2.log(currentBalance);
        
        // Deposit 1/10 of balance
        uint256 amount = currentBalance / 10;
        console.log("Deposit amount (1/10 of balance):");
        console2.log(amount);
        
        uint256 minShares = 0; 

        // // Check assetData
        // (bool allowDeposits, bool allowWithdraws, uint16 sharePremium) =
        //     TellerWithMultiAssetSupport(tellerAddress).assetData(ERC20(cbbtc));
        // console.log("allowDeposits:", allowDeposits);
        // console.log("allowWithdraws:", allowWithdraws);
        // console.log("sharePremium:", uint256(sharePremium));

        // require(allowDeposits, "Deposits not allowed");
        // require(amount > 0, "No balance to deposit");

        vm.startBroadcast(privateKey);

        // Approve cbBTC to teller
        ERC20(cbbtc).approve(tellerAddress, amount);

        // Deposit
        TellerWithMultiAssetSupport(tellerAddress).deposit(ERC20(cbbtc), amount, minShares);

        vm.stopBroadcast();
        
        console.log("SUCCESS: Deposit completed!");
    }
}