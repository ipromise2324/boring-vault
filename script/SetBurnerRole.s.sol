// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

// source .env && forge script script/SetBurnerRole.s.sol:SetBurnerRole --rpc-url base --broadcast
contract SetBurnerRole is Script {
    
    // Base network addresses
    address public constant ROLES_AUTHORITY = 0xeCF71cdCefB7C09A6f189330F6c6798EEC641F48;
    address public constant BORING_VAULT = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address public constant TELLER = 0x9fAF90689A215cb595e8Af204A0973d0fcad682B;
    
    // Role definitions (from DeployArcticArchitecture.sol)
    uint8 public constant BURNER_ROLE = 3;
    
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
        
        // Setup BURNER_ROLE permissions for Teller
        setupBurnerRole();
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Setup BURNER_ROLE permissions for Teller to call BoringVault.exit
     */
    function setupBurnerRole() public {
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        
        console.log("=== Setting up BURNER_ROLE permissions ===");
        console.log("BURNER_ROLE value:", BURNER_ROLE);
        console.log("BoringVault address:", BORING_VAULT);
        console.log("Teller address:", TELLER);
        console.log("RolesAuthority address:", ROLES_AUTHORITY);
        
        // Step 1: Set role capability - allow BURNER_ROLE to call BoringVault.exit
        bytes4 exitSelector = BoringVault.exit.selector;
        console.log("BoringVault.exit selector:", bytes4ToString(exitSelector));
        
        bool hasCapability = rolesAuthority.doesRoleHaveCapability(BURNER_ROLE, BORING_VAULT, exitSelector);
        console.log("BURNER_ROLE has capability before:", hasCapability);
        
        if (!hasCapability) {
            console.log("Setting role capability...");
            rolesAuthority.setRoleCapability(BURNER_ROLE, BORING_VAULT, exitSelector, true);
            console.log("Role capability set successfully");
        } else {
            console.log("Role capability already set");
        }
        
        // Step 2: Grant BURNER_ROLE to Teller
        bool hasRole = rolesAuthority.doesUserHaveRole(TELLER, BURNER_ROLE);
        console.log("Teller has BURNER_ROLE before:", hasRole);
        
        if (!hasRole) {
            console.log("Granting BURNER_ROLE to Teller...");
            rolesAuthority.setUserRole(TELLER, BURNER_ROLE, true);
            console.log("BURNER_ROLE granted to Teller successfully");
        } else {
            console.log("Teller already has BURNER_ROLE");
        }
        
        // Step 3: Verify the setup
        console.log("=== Verification ===");
        bool finalCapability = rolesAuthority.doesRoleHaveCapability(BURNER_ROLE, BORING_VAULT, exitSelector);
        bool finalRole = rolesAuthority.doesUserHaveRole(TELLER, BURNER_ROLE);
        
        console.log("Final capability check:", finalCapability);
        console.log("Final role check:", finalRole);
        
        if (finalCapability && finalRole) {
            console.log("SUCCESS: BURNER_ROLE permissions setup complete!");
            console.log("Teller can now call BoringVault.exit for redeemSolve operations");
        } else {
            console.log("FAILED: Permission setup incomplete");
        }
    }
    
    /**
     * @notice Check current BURNER_ROLE permissions
     */
    function checkBurnerRole() external view {
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        bytes4 exitSelector = BoringVault.exit.selector;
        
        console.log("=== Current BURNER_ROLE Status ===");
        console.log("BURNER_ROLE value:", BURNER_ROLE);
        console.log("BoringVault address:", BORING_VAULT);
        console.log("Teller address:", TELLER);
        console.log("Exit selector:", bytes4ToString(exitSelector));
        
        bool hasCapability = rolesAuthority.doesRoleHaveCapability(BURNER_ROLE, BORING_VAULT, exitSelector);
        bool hasRole = rolesAuthority.doesUserHaveRole(TELLER, BURNER_ROLE);
        
        console.log("BURNER_ROLE has capability:", hasCapability);
        console.log("Teller has BURNER_ROLE:", hasRole);
        
        if (hasCapability && hasRole) {
            console.log("Permissions are properly set");
        } else {
            console.log("Permissions need to be set");
        }
    }
    
    /**
     * @notice Remove BURNER_ROLE from Teller (for testing purposes)
     */
    function removeBurnerRole() external {
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        
        console.log("=== Removing BURNER_ROLE from Teller ===");
        rolesAuthority.setUserRole(TELLER, BURNER_ROLE, false);
        console.log("BURNER_ROLE removed from Teller");
    }
    
    /**
     * @notice Convert bytes4 to string for logging
     */
    function bytes4ToString(bytes4 _bytes4) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(10);
        result[0] = "0";
        result[1] = "x";
        for (uint i = 0; i < 4; i++) {
            result[2 + i * 2] = hexChars[uint8(_bytes4[i] >> 4)];
            result[3 + i * 2] = hexChars[uint8(_bytes4[i] & 0x0f)];
        }
        return string(result);
    }
} 