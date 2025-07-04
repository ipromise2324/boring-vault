// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import "forge-std/Script.sol";

/**
 * @title Unpause Accountant
 * @notice Checks the pause status of the accountant and unpause it if needed
 * @dev Run with: forge script script/UnpauseAccountant.s.sol:UnpauseAccountant --rpc-url base --broadcast
 */
contract UnpauseAccountant is Script {
    // Base network addresses
    address constant ACCOUNTANT = 0xA06F6C388c0bC49e9Af8d472E6d6821A44d6E3E8;
    address constant ROLES_AUTHORITY = 0xeCF71cdCefB7C09A6f189330F6c6798EEC641F48;
    
    // Role constants (matching DeployArcticArchitecture.sol)
    uint8 public constant MULTISIG_ROLE = 9;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Using deployer address:", deployer);
        console.log("Accountant contract:", ACCOUNTANT);
        console.log("RolesAuthority contract:", ROLES_AUTHORITY);
        
        AccountantWithRateProviders accountant = AccountantWithRateProviders(ACCOUNTANT);
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        
        // Check current pause status
        (, , , , , , , , bool isPaused, , , ) = accountant.accountantState();
        console.log("=== Current Accountant Status ===");
        console.log("Is Paused:", isPaused);
        
        if (!isPaused) {
            console.log("Accountant is already unpaused. No action needed.");
            return;
        }
        
        // Check if deployer has MULTISIG_ROLE
        bool hasMultisigRole = rolesAuthority.doesUserHaveRole(deployer, MULTISIG_ROLE);
        console.log("Deployer has MULTISIG_ROLE:", hasMultisigRole);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Grant MULTISIG_ROLE if deployer doesn't have it
        if (!hasMultisigRole) {
            console.log("Granting MULTISIG_ROLE to deployer...");
            rolesAuthority.setUserRole(deployer, MULTISIG_ROLE, true);
            console.log("MULTISIG_ROLE granted successfully!");
        }
        
        // Unpause the accountant
        console.log("Unpausing accountant contract...");
        accountant.unpause();
        console.log("Accountant unpaused successfully!");
        
        vm.stopBroadcast();
        
        // Verify the unpause was successful
        (, , , , , , , , bool isPausedAfter, , , ) = accountant.accountantState();
        console.log("=== Final Status ===");
        console.log("Is Paused after unpause:", isPausedAfter);
        
        if (!isPausedAfter) {
            console.log("SUCCESS: Accountant is now unpaused and ready for operations!");
        } else {
            console.log("ERROR: Accountant is still paused after unpause call");
        }
    }
} 