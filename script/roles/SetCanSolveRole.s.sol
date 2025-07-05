// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";

// forge script script/roles/SetCanSolveRole.s.sol:SetCanSolveRole --rpc-url base --broadcast
contract SetCanSolveRole is Script {
    
    // Base network addresses
    address public constant ROLES_AUTHORITY = 0xeCF71cdCefB7C09A6f189330F6c6798EEC641F48;
    
    // Role definitions
    uint8 public constant CAN_SOLVE_ROLE = 14;
    
    // Store private key
    uint256 private privateKey;
    
    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("base");
        
        address deployer = vm.addr(privateKey);
        console.log("Setting CAN_SOLVE_ROLE for address:", deployer);
    }

    function run() external {
        vm.startBroadcast(privateKey);
        
        address solver = 0xA96ce17978B8bC96936dF79A6803F24549dE2048;
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        
        console.log("=== Setting CAN_SOLVE_ROLE ===");
        console.log("Target address:", solver);
        console.log("CAN_SOLVE_ROLE value:", CAN_SOLVE_ROLE);
        
        // Check if user already has the role
        bool hasRole = rolesAuthority.doesUserHaveRole(solver, CAN_SOLVE_ROLE);
        console.log("Already has CAN_SOLVE_ROLE:", hasRole);
        
        if (!hasRole) {
            console.log("Granting CAN_SOLVE_ROLE...");
            rolesAuthority.setUserRole(solver, CAN_SOLVE_ROLE, true);
            console.log("SUCCESS: CAN_SOLVE_ROLE granted!");
        } else {
            console.log("Address already has CAN_SOLVE_ROLE");
        }
        
        // Verify the role was set
        bool hasRoleAfter = rolesAuthority.doesUserHaveRole(solver, CAN_SOLVE_ROLE);
        console.log("Has CAN_SOLVE_ROLE after:", hasRoleAfter);
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Check if an address has CAN_SOLVE_ROLE
     * @param userAddress The address to check
     */
    function checkCanSolveRole(address userAddress) external view {
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        bool hasRole = rolesAuthority.doesUserHaveRole(userAddress, CAN_SOLVE_ROLE);
        
        console.log("=== CAN_SOLVE_ROLE Check ===");
        console.log("Address:", userAddress);
        console.log("Has CAN_SOLVE_ROLE:", hasRole);
    }
    
    /**
     * @notice Remove CAN_SOLVE_ROLE from the current address
     */
    function removeCanSolveRole() external {
        vm.startBroadcast(privateKey);
        
        address deployer = vm.addr(privateKey);
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        
        console.log("=== Removing CAN_SOLVE_ROLE ===");
        console.log("Target address:", deployer);
        
        bool hasRole = rolesAuthority.doesUserHaveRole(deployer, CAN_SOLVE_ROLE);
        console.log("Currently has CAN_SOLVE_ROLE:", hasRole);
        
        if (hasRole) {
            console.log("Removing CAN_SOLVE_ROLE...");
            rolesAuthority.setUserRole(deployer, CAN_SOLVE_ROLE, false);
            console.log("SUCCESS: CAN_SOLVE_ROLE removed!");
        } else {
            console.log("Address doesn't have CAN_SOLVE_ROLE");
        }
        
        vm.stopBroadcast();
    }
} 