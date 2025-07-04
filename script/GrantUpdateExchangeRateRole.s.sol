// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import "forge-std/Script.sol";

/**
 * @title Grant Update Exchange Rate Role
 * @notice Grants UPDATE_EXCHANGE_RATE_ROLE to the deployer address
 * @dev Run with: forge script script/GrantUpdateExchangeRateRole.s.sol:GrantUpdateExchangeRateRole --rpc-url $BASE_RPC_URL base --broadcast
 */
contract GrantUpdateExchangeRateRole is Script {
    // Base network addresses
    address constant ROLES_AUTHORITY = 0xeCF71cdCefB7C09A6f189330F6c6798EEC641F48;
    
    // Role constants (matching DeployArcticArchitecture.sol)
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Using deployer address:", deployer);
        console.log("RolesAuthority contract:", ROLES_AUTHORITY);
        console.log("UPDATE_EXCHANGE_RATE_ROLE:", UPDATE_EXCHANGE_RATE_ROLE);
        
        vm.startBroadcast(deployerPrivateKey);
        
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        
        // Check if the deployer already has the role
        bool hasRole = rolesAuthority.doesUserHaveRole(deployer, UPDATE_EXCHANGE_RATE_ROLE);
        console.log("Deployer currently has UPDATE_EXCHANGE_RATE_ROLE:", hasRole);
        
        if (!hasRole) {
            console.log("Granting UPDATE_EXCHANGE_RATE_ROLE to deployer...");
            rolesAuthority.setUserRole(deployer, UPDATE_EXCHANGE_RATE_ROLE, true);
            console.log("Role granted successfully!");
        } else {
            console.log("Deployer already has the UPDATE_EXCHANGE_RATE_ROLE");
        }
        
        // Verify the role was granted
        bool hasRoleAfter = rolesAuthority.doesUserHaveRole(deployer, UPDATE_EXCHANGE_RATE_ROLE);
        console.log("Final verification - deployer has UPDATE_EXCHANGE_RATE_ROLE:", hasRoleAfter);
        
        vm.stopBroadcast();
    }
} 