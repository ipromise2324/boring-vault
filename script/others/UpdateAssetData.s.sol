// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

// source .env && forge script script/others/UpdateAssetData.s.sol:UpdateAssetData --rpc-url base --broadcast
contract UpdateAssetData is Script {
    
    // Base network addresses
    address public constant TELLER = 0x9fAF90689A215cb595e8Af204A0973d0fcad682B;
    address public constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    
    // Store private key
    uint256 private privateKey;
    
    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("base");
        
        address deployer = vm.addr(privateKey);
        console.log("Deployer address:", deployer);
    }
    
    function run() external {
        vm.startBroadcast(privateKey);
        
        // Update cbBTC to allow withdrawals
        updateCbBTCAssetData(true, true, 0); // allowDeposits=true, allowWithdraws=true, sharePremium=0
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Update cbBTC asset data to allow/disallow deposits and withdrawals
     * @param allowDeposits Whether to allow deposits
     * @param allowWithdraws Whether to allow withdrawals
     * @param sharePremium Share premium value (0-6000, representing 0-60%)
     */
    function updateCbBTCAssetData(bool allowDeposits, bool allowWithdraws, uint16 sharePremium) public {
        console.log("=== Updating cbBTC Asset Data ===");
        console.log("cbBTC address:", cbBTC);
        console.log("Allow deposits:", allowDeposits);
        console.log("Allow withdrawals:", allowWithdraws);
        console.log("Share premium:", sharePremium);
        
        // Check current asset data before update
        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(TELLER);
        
        // Get current asset data
        (bool currentAllowDeposits, bool currentAllowWithdraws, uint16 currentSharePremium) = 
            teller.assetData(ERC20(cbBTC));
            
        console.log("=== Current Asset Data ===");
        console.log("Current allow deposits:", currentAllowDeposits);
        console.log("Current allow withdrawals:", currentAllowWithdraws);
        console.log("Current share premium:", currentSharePremium);
        
        // Update asset data
        console.log("=== Updating Asset Data ===");
        teller.updateAssetData(
            ERC20(cbBTC),
            allowDeposits,
            allowWithdraws,
            sharePremium
        );
        
        // Verify the update
        (bool newAllowDeposits, bool newAllowWithdraws, uint16 newSharePremium) = 
            teller.assetData(ERC20(cbBTC));
            
        console.log("=== Updated Asset Data ===");
        console.log("New allow deposits:", newAllowDeposits);
        console.log("New allow withdrawals:", newAllowWithdraws);
        console.log("New share premium:", newSharePremium);
        
        // Verify the changes
        require(newAllowDeposits == allowDeposits, "Deposit setting not updated correctly");
        require(newAllowWithdraws == allowWithdraws, "Withdrawal setting not updated correctly");
        require(newSharePremium == sharePremium, "Share premium not updated correctly");
        
        console.log("SUCCESS: cbBTC asset data updated successfully!");
    }
} 