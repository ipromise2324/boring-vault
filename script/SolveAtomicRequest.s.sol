// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {AtomicSolverV4} from "src/atomic-queue/AtomicSolverV4.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {Script, console} from "forge-std/Script.sol";
import "forge-std/console2.sol";

// source .env && forge script script/SolveAtomicRequest.s.sol:SolveAtomicRequest --rpc-url base --broadcast
contract SolveAtomicRequest is Script {
    using FixedPointMathLib for uint256;

    // Base network addresses
    address public constant ATOMIC_QUEUE = 0x3080a4989729f3Ad339923Bb46d07f28a531DD12;
    address public constant ATOMIC_SOLVER_V4 = 0xd3C6171515c183be2E0569Dd2adD2De095c99682;
    address public constant BORING_VAULT = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address public constant ACCOUNTANT = 0xA06F6C388c0bC49e9Af8d472E6d6821A44d6E3E8;
    
    // Token addresses (Base network)
    address public constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    
    // Store private key
    uint256 internal privateKey;
    
    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("base");
        
        address deployer = vm.addr(privateKey);
        console.log("Using solver address:", deployer);
    }

    function run() external {
        vm.startBroadcast(privateKey);
        
        // Example: Solve cbBTC atomic requests
        solveCbBTCRequests();
        
        vm.stopBroadcast();
    }

    /**
     * @notice Solve all pending cbBTC atomic requests
     */
    function solveCbBTCRequests() public {
        // Get user address to solve for
        address[] memory users = new address[](1);
        users[0] = 0x4A7bCebEc5b0A02Ad51F858741a76cFA17fDe637;
        
        address solver = msg.sender;
        address user = users[0];

        console.log("=== Before p2pSolve ===");
        console.log("Solver address:", solver);
        console.log("User address:", user);
        
        ERC20(cbBTC).approve(ATOMIC_SOLVER_V4, type(uint256).max);
        
        console.log("=== Executing p2pSolve ===");
        AtomicSolverV4(ATOMIC_SOLVER_V4).p2pSolve(
            AtomicQueue(ATOMIC_QUEUE),
            ERC20(BORING_VAULT),
            ERC20(cbBTC),
            users,
            0,
            type(uint256).max
        );
    }
} 