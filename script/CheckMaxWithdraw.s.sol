// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";
import "forge-std/console2.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

interface IERC4626 {
    function maxWithdraw(address owner) external view returns (uint256 assets);
    function maxRedeem(address owner) external view returns (uint256 shares);
    function balanceOf(address account) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
}

/**
 * Check maximum withdrawal amount from gtcbBTCc for BoringVault
 * Usage: source .env && forge script script/CheckMaxWithdraw.s.sol:CheckMaxWithdraw --rpc-url base
 */
contract CheckMaxWithdraw is Script {
    // Base network addresses
    address public boringVault = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address public gtcbBTCc = 0x6770216aC60F634483Ec073cBABC4011c94307Cb;
    address cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    function setUp() external {
        // Create fork at a specific block (e.g., block 12345678 on Base)
        // uint256 blockNumber = 32209276;
        // vm.createSelectFork("base", blockNumber);
        vm.createSelectFork("base");

    }
    function run() external view {
        checkMaxWithdraw();
    }

    function checkMaxWithdraw() public view {
        IERC4626 vault = IERC4626(gtcbBTCc);
        
        console.log("=== BoringVault Maximum Withdrawal Analysis ===");
        console.log("BoringVault Address:", boringVault);
        console.log("gtcbBTCc Vault Address:", gtcbBTCc);
        console.log("cbBTC Address:", cbbtc);
        console.log("");

        // Get current balances
        uint256 sharesBalance = vault.balanceOf(boringVault);
        uint256 cbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
        
        console.log("Current BoringVault Holdings:");
        console.log("- gtcbBTCc Shares:");
        console2.log(sharesBalance);
        console.log("- cbBTC Balance:");
        console2.log(cbbtcBalance);
        console.log("");

        // Check maximum withdrawal amounts
        uint256 maxWithdrawAssets = vault.maxWithdraw(boringVault);
        
        console.log("Maximum Withdrawal Limits:");
        console.log("- Max Withdraw (cbBTC assets):");
        console2.log(maxWithdrawAssets);
    }
} 
