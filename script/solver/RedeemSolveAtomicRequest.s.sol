// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {AtomicSolverV4} from "src/atomic-queue/AtomicSolverV4.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {Script, console} from "forge-std/Script.sol";
import "forge-std/console2.sol";

// source .env && forge script script/solver/RedeemSolveAtomicRequest.s.sol:RedeemSolveAtomicRequest --rpc-url base --broadcast
contract RedeemSolveAtomicRequest is Script {
    using FixedPointMathLib for uint256;

    // Base network addresses
    address public constant ATOMIC_QUEUE = 0x3080a4989729f3Ad339923Bb46d07f28a531DD12;
    address public constant ATOMIC_SOLVER_V4 = 0xd3C6171515c183be2E0569Dd2adD2De095c99682;
    address public constant BORING_VAULT = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address public constant TELLER = 0x9fAF90689A215cb595e8Af204A0973d0fcad682B;
    
    // Token addresses (Base network)
    address public constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    
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
        
        // Redeem solve for cbBTC requests
        redeemSolveCbBTCRequests();
        
        vm.stopBroadcast();
    }

    /**
     * @notice Redeem solve for cbBTC atomic requests
     * @dev This redeems BoringVault shares to get cbBTC, then provides cbBTC to users
     */
    function redeemSolveCbBTCRequests() public {
        // Get user address to solve for
        address[] memory users = new address[](1);
        users[0] = 0x4A7bCebEc5b0A02Ad51F858741a76cFA17fDe637;
        
        address solver = msg.sender;
        address user = users[0];

        console.log("=== Before redeemSolve ===");
        console.log("Solver address:", solver);
        console.log("User address:", user);
        
        console.log("=== Executing redeemSolve ===");
        AtomicSolverV4(ATOMIC_SOLVER_V4).redeemSolve(
            AtomicQueue(ATOMIC_QUEUE),
            ERC20(BORING_VAULT),  // offer: BoringVault shares to redeem
            ERC20(cbBTC),         // want: cbBTC to provide to user
            users,
            0,                    // minimumAssetsOut: accept any amount from redemption
            type(uint256).max,    // maxAssets: no limit on assets to provide
            TellerWithMultiAssetSupport(TELLER)
        );
    }
} 