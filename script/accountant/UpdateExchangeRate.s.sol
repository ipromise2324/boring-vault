// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";
import "forge-std/console2.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

interface IERC4626 {
    function maxWithdraw(address owner) external view returns (uint256 assets);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IAccountant {
    function updateExchangeRate(uint96 newExchangeRate) external;
    function getRate() external view returns (uint256 rate);
    function previewUpdateExchangeRate(uint96 newExchangeRate) 
        external view returns (bool updateWillPause, uint256 newFeesOwedInBase, uint256 totalFeesOwedInBase);
}

/**
 * Calculate and update exchange rate based on total assets / total supply
 * Usage: source .env && forge script script/accountant/UpdateExchangeRate.s.sol:UpdateExchangeRate --rpc-url base --broadcast
 */
contract UpdateExchangeRate is Script {
    using FixedPointMathLib for uint256;

    // Base network addresses
    address public boringVault = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address public gtcbBTCc = 0x6770216aC60F634483Ec073cBABC4011c94307Cb;
    address public accountant = 0xA06F6C388c0bC49e9Af8d472E6d6821A44d6E3E8;
    address cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    // Store private key as state variable
    uint256 private privateKey;

    function setUp() external {
        // Load private key from environment variable
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        
        // Create fork connection to Base network
        vm.createSelectFork("base");
        
        // Log the address that will be used
        address deployer = vm.addr(privateKey);
        console.log("Using deployer address:", deployer);
    }

    function run() external {
        // // Check first without broadcasting
        // calculateNewExchangeRate();
        
        // Then execute if user wants to broadcast
        vm.startBroadcast(privateKey);
        executeExchangeRateUpdate();
        vm.stopBroadcast();
    }

    function calculateNewExchangeRate() public view returns (uint96 newExchangeRate) {
        IERC4626 vault = IERC4626(gtcbBTCc);
        IERC4626 boringVaultToken = IERC4626(boringVault);
        IAccountant acc = IAccountant(accountant);
        
        console.log("=== Exchange Rate Calculation ===");
        
        // Get current state
        uint256 cbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
        uint256 maxWithdrawFromMorpho = vault.maxWithdraw(boringVault);
        uint256 totalSupply = boringVaultToken.totalSupply();
        uint256 currentRate = acc.getRate();
        
        console.log("Current Holdings:");
        console.log("- cbBTC Balance:");
        console2.log(cbbtcBalance);
        console.log("- Max Withdraw from Morpho:");
        console2.log(maxWithdrawFromMorpho);
        console.log("- Total Supply:");
        console2.log(totalSupply);
        console.log("- Current Exchange Rate:");
        console2.log(currentRate);
        console.log("");
        
        // Calculate total assets
        uint256 totalAssets = cbbtcBalance + maxWithdrawFromMorpho;
        console.log("Total Assets:");
        console2.log(totalAssets);
        
        // Calculate new exchange rate
        // Exchange rate = total assets / total supply (in 8 decimals for cbBTC)
        if (totalSupply == 0) {
            newExchangeRate = 1e8; // 1:1 ratio if no supply
        } else {
            // Scale to 8 decimals (cbBTC decimals)
            newExchangeRate = uint96((totalAssets * 1e8) / totalSupply);
        }
        
        console.log("Calculated New Exchange Rate:");
        console2.log(newExchangeRate);
        
        // Calculate percentage change
        if (currentRate > 0) {
            uint256 changePercent;
            bool isIncrease;
            if (newExchangeRate >= currentRate) {
                isIncrease = true;
                changePercent = ((newExchangeRate - currentRate) * 10000) / currentRate;
            } else {
                isIncrease = false;
                changePercent = ((currentRate - newExchangeRate) * 10000) / currentRate;
            }
            
            console.log("Change:");
            if (isIncrease) {
                console.log("- Increase:");
            } else {
                console.log("- Decrease:");
            }
            console2.log(changePercent);
            console.log("basis points (1bp = 0.01%)");
        }
        console.log("");
        
        return newExchangeRate;
    }

    function executeExchangeRateUpdate() public {
        uint96 newExchangeRate = calculateNewExchangeRate();
        IAccountant acc = IAccountant(accountant);
        
        // Preview the update to check if it will pause
        (bool updateWillPause, uint256 newFeesOwed, uint256 totalFeesOwed) = 
            acc.previewUpdateExchangeRate(newExchangeRate);
        
        console.log("Update Preview:");
        console.log("- Will pause contract:", updateWillPause);
        console.log("- New fees owed:");
        console2.log(newFeesOwed);
        console.log("- Total fees owed:");
        console2.log(totalFeesOwed);
        console.log("");
        
        if (updateWillPause) {
            console.log("WARNING: This update will PAUSE the contract!");
            console.log("This could be due to:");
            console.log("- Exchange rate change exceeds allowed bounds");
            console.log("- Not enough time has passed since last update");
            console.log("- Rate is outside safety parameters");
            console.log("");
            console.log("Proceeding with update anyway...");
        }
        
        // Execute the update
        try acc.updateExchangeRate(newExchangeRate) {
            console.log("SUCCESS: Exchange rate updated!");
            
            // Verify the new rate
            uint256 updatedRate = acc.getRate();
            console.log("New exchange rate in contract:");
            console2.log(updatedRate);
            
        } catch Error(string memory reason) {
            console.log("ERROR: Update failed -", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Update failed with low-level error");
            console.logBytes(lowLevelData);
        }
    }

    // View-only function to just calculate without updating
    function checkExchangeRate() external view {
        calculateNewExchangeRate();
    }
} 