// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {AtomicSolverV4} from "src/atomic-queue/AtomicSolverV4.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ContractNames} from "resources/ContractNames.sol";
import "forge-std/Script.sol";

/**
 * @title Deploy Atomic Queue And Solver
 * @notice Deploys AtomicQueue and AtomicSolverV4 contracts with proper permissions for redeemSolve functionality
 * @dev Run with: forge script script/DeployAtomicQueueAndSolver.s.sol:DeployAtomicQueueAndSolver --rpc-url base --broadcast
 */
contract DeployAtomicQueueAndSolver is Script, ContractNames {
    // Base network addresses - using existing deployed contracts
    address constant ROLES_AUTHORITY = 0xeCF71cdCefB7C09A6f189330F6c6798EEC641F48;
    address constant TELLER = 0xBEEF69Ac7870777598A04B2bd4771c71212E6aBc;
    address constant BORING_VAULT = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address constant DEPLOYER = 0x4A7bCebEc5b0A02Ad51F858741a76cFA17fDe637;
    
    // Role constants - using values that don't conflict with existing architecture
    uint8 public constant SOLVER_ROLE = 12; // From existing architecture
    uint8 public constant QUEUE_ROLE = 13;  // New role for AtomicQueue
    uint8 public constant CAN_SOLVE_ROLE = 14; // New role for solver permissions
    uint8 public constant MULTISIG_ROLE = 9; // From existing architecture
    uint8 public constant OWNER_ROLE = 8; // From existing architecture
    
    // Contracts to deploy
    AtomicQueue public atomicQueue;
    AtomicSolverV4 public atomicSolverV4;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deployment Configuration ===");
        console.log("Deployer address:", deployer);
        console.log("RolesAuthority:", ROLES_AUTHORITY);
        console.log("Teller:", TELLER);
        console.log("BoringVault:", BORING_VAULT);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        
        // Deploy AtomicQueue
        console.log("Deploying AtomicQueue...");
        atomicQueue = new AtomicQueue(deployer, rolesAuthority);
        console.log("AtomicQueue deployed at:", address(atomicQueue));
        
        // Deploy AtomicSolverV4
        console.log("Deploying AtomicSolverV4...");
        atomicSolverV4 = new AtomicSolverV4(deployer, rolesAuthority);
        console.log("AtomicSolverV4 deployed at:", address(atomicSolverV4));
        
        // Setup role capabilities
        console.log("\n=== Setting up Role Capabilities ===");
        
        // AtomicQueue public functions - anyone can call these
        if (!rolesAuthority.isCapabilityPublic(address(atomicQueue), AtomicQueue.updateAtomicRequest.selector)) {
            rolesAuthority.setPublicCapability(address(atomicQueue), AtomicQueue.updateAtomicRequest.selector, true);
            console.log("Set updateAtomicRequest as public capability");
        }
        
        if (!rolesAuthority.isCapabilityPublic(address(atomicQueue), AtomicQueue.safeUpdateAtomicRequest.selector)) {
            rolesAuthority.setPublicCapability(address(atomicQueue), AtomicQueue.safeUpdateAtomicRequest.selector, true);
            console.log("Set safeUpdateAtomicRequest as public capability");
        }
        
        if (!rolesAuthority.isCapabilityPublic(address(atomicQueue), AtomicQueue.solve.selector)) {
            rolesAuthority.setPublicCapability(address(atomicQueue), AtomicQueue.solve.selector, true);
            console.log("Set solve as public capability");
        }
        
        // AtomicQueue admin functions - MULTISIG_ROLE
        if (!rolesAuthority.doesRoleHaveCapability(MULTISIG_ROLE, address(atomicQueue), AtomicQueue.pause.selector)) {
            rolesAuthority.setRoleCapability(MULTISIG_ROLE, address(atomicQueue), AtomicQueue.pause.selector, true);
            console.log("Set pause capability for MULTISIG_ROLE");
        }
        
        if (!rolesAuthority.doesRoleHaveCapability(MULTISIG_ROLE, address(atomicQueue), AtomicQueue.unpause.selector)) {
            rolesAuthority.setRoleCapability(MULTISIG_ROLE, address(atomicQueue), AtomicQueue.unpause.selector, true);
            console.log("Set unpause capability for MULTISIG_ROLE");
        }
        
        // AtomicSolverV4 finishSolve - QUEUE_ROLE (called by AtomicQueue)
        if (!rolesAuthority.doesRoleHaveCapability(QUEUE_ROLE, address(atomicSolverV4), AtomicSolverV4.finishSolve.selector)) {
            rolesAuthority.setRoleCapability(QUEUE_ROLE, address(atomicSolverV4), AtomicSolverV4.finishSolve.selector, true);
            console.log("Set finishSolve capability for QUEUE_ROLE");
        }
        
        // AtomicSolverV4 solve functions - CAN_SOLVE_ROLE
        if (!rolesAuthority.doesRoleHaveCapability(CAN_SOLVE_ROLE, address(atomicSolverV4), AtomicSolverV4.p2pSolve.selector)) {
            rolesAuthority.setRoleCapability(CAN_SOLVE_ROLE, address(atomicSolverV4), AtomicSolverV4.p2pSolve.selector, true);
            console.log("Set p2pSolve capability for CAN_SOLVE_ROLE");
        }
        
        if (!rolesAuthority.doesRoleHaveCapability(CAN_SOLVE_ROLE, address(atomicSolverV4), AtomicSolverV4.redeemSolve.selector)) {
            rolesAuthority.setRoleCapability(CAN_SOLVE_ROLE, address(atomicSolverV4), AtomicSolverV4.redeemSolve.selector, true);
            console.log("Set redeemSolve capability for CAN_SOLVE_ROLE");
        }
        
        if (!rolesAuthority.doesRoleHaveCapability(CAN_SOLVE_ROLE, address(atomicSolverV4), AtomicSolverV4.migrationRedeemSolve.selector)) {
            rolesAuthority.setRoleCapability(CAN_SOLVE_ROLE, address(atomicSolverV4), AtomicSolverV4.migrationRedeemSolve.selector, true);
            console.log("Set migrationRedeemSolve capability for CAN_SOLVE_ROLE");
        }
        
        // AtomicSolverV4 admin functions - OWNER_ROLE
        if (!rolesAuthority.doesRoleHaveCapability(OWNER_ROLE, address(atomicSolverV4), AtomicSolverV4.rescueTokens.selector)) {
            rolesAuthority.setRoleCapability(OWNER_ROLE, address(atomicSolverV4), AtomicSolverV4.rescueTokens.selector, true);
            console.log("Set rescueTokens capability for OWNER_ROLE");
        }
        
        // TellerWithMultiAssetSupport bulkWithdraw - SOLVER_ROLE (for redeemSolve)
        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(payable(TELLER));
        if (!rolesAuthority.doesRoleHaveCapability(SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector)) {
            rolesAuthority.setRoleCapability(SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true);
            console.log("Set bulkWithdraw capability for SOLVER_ROLE");
        }
        
        // Setup user roles
        console.log("\n=== Setting up User Roles ===");
        
        // Give AtomicQueue the QUEUE_ROLE so it can call finishSolve
        if (!rolesAuthority.doesUserHaveRole(address(atomicQueue), QUEUE_ROLE)) {
            rolesAuthority.setUserRole(address(atomicQueue), QUEUE_ROLE, true);
            console.log("Granted QUEUE_ROLE to AtomicQueue");
        }
        
        // Give AtomicSolverV4 the SOLVER_ROLE so it can call bulkWithdraw
        if (!rolesAuthority.doesUserHaveRole(address(atomicSolverV4), SOLVER_ROLE)) {
            rolesAuthority.setUserRole(address(atomicSolverV4), SOLVER_ROLE, true);
            console.log("Granted SOLVER_ROLE to AtomicSolverV4");
        }
        
        // Give deployer the CAN_SOLVE_ROLE for testing/operations
        if (!rolesAuthority.doesUserHaveRole(deployer, CAN_SOLVE_ROLE)) {
            rolesAuthority.setUserRole(deployer, CAN_SOLVE_ROLE, true);
            console.log("Granted CAN_SOLVE_ROLE to deployer");
        }
        
        vm.stopBroadcast();
        
        // Final verification
        console.log("\n=== Deployment Summary ===");
        console.log("AtomicQueue:", address(atomicQueue));
        console.log("AtomicSolverV4:", address(atomicSolverV4));
        console.log("");
        console.log("Role Assignments:");
        console.log("- AtomicQueue has QUEUE_ROLE:", rolesAuthority.doesUserHaveRole(address(atomicQueue), QUEUE_ROLE));
        console.log("- AtomicSolverV4 has SOLVER_ROLE:", rolesAuthority.doesUserHaveRole(address(atomicSolverV4), SOLVER_ROLE));
        console.log("- Deployer has CAN_SOLVE_ROLE:", rolesAuthority.doesUserHaveRole(deployer, CAN_SOLVE_ROLE));
        console.log("");
        console.log("Ready for redeemSolve operations!");
    }
} 