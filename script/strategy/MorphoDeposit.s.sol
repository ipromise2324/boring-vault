// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {Script, console} from "forge-std/Script.sol";
import "forge-std/console2.sol";

/**
 * Execute cbBTC approve + deposit to gtcbBTCc strategy using merkle verification
 * Usage: source .env && forge script script/strategy/MorphoDeposit.s.sol:MorphoDeposit --rpc-url base --broadcast
 */
contract MorphoDeposit is Script {
    using FixedPointMathLib for uint256;

    // Base network addresses from deployment
    address public boringVault = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address public managerAddress = 0x747e2d36704f59EB18a1b7a7d3884e29628DF28a;
    address public rawDataDecoderAndSanitizer = 0xFe10Cc403Adc068676dB957Ef3eC0f17c8090178;
    
    // Token addresses
    address cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public gtcbBTCc = 0x6770216aC60F634483Ec073cBABC4011c94307Cb;
    
    // Merkle root from WithLBcbbtc.json
    bytes32 public merkleRoot = 0xa735cdd01a0b7c6abecd86ba5cd2b43b96332a01959c232050d02a45dde7baa2;

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
        // Use the specific private key for broadcasting
        vm.startBroadcast(privateKey);
        // checkCurrentState();
        executeApproveAndDepositStrategy();
        vm.stopBroadcast();
    }

    function executeApproveAndDepositStrategy() public {
        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        
        console.log("=== Executing cbBTC Approve + Deposit to gtcbBTCc Strategy ===");

        // Get BoringVault's current cbBTC balance
        uint256 cbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
        console.log("BoringVault cbBTC Balance:");
        console2.log(cbbtcBalance);
        
        // Calculate deposit amount (1/10 of balance)
        uint256 depositAmount = cbbtcBalance / 10;
        console.log("Deposit Amount (1/10 of balance):");
        console2.log(depositAmount);
        
        // Calculate approve amount
        uint256 approveAmount = depositAmount;
        console.log("Approve Amount:");
        console2.log(approveAmount);
        
        require(depositAmount > 0, "No balance to deposit");

        // Prepare transaction arrays for both operations
        address[] memory targets = new address[](2);
        targets[0] = cbbtc;      // First: approve cbBTC
        targets[1] = gtcbBTCc;   // Second: deposit to gtcbBTCc

        bytes[] memory targetData = new bytes[](2);
        // First operation: approve gtcbBTCc to spend cbBTC
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, gtcbBTCc, approveAmount);
        // Second operation: deposit cbBTC to gtcbBTCc
        targetData[1] = abi.encodeWithSelector(0x6e553f65, depositAmount, boringVault);

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Get proofs for both operations
        bytes32[][] memory manageProofs = new bytes32[][](2);
        manageProofs[0] = getApproveProof();  // Proof for approve (index 0)
        manageProofs[1] = getDepositProof();  // Proof for deposit (index 1)

        console.log("Approve Leaf Digest: 0x6b6bac96d1997aaa80f948882e96c6a70848ffbf14d3b57d69fd83f5e85f692d");
        console.log("Deposit Leaf Digest: 0x144e6401d1e0f0bd4f44e0767ef9eb849ade4d19253a2c52fa4cd69f4709e18b");

        // Execute both operations in sequence
        try manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values) {
            console.log("SUCCESS: Approve + Deposit strategy executed!");
            
            uint256 newAllowance = ERC20(cbbtc).allowance(boringVault, gtcbBTCc);
            uint256 newGtcbBTCcBalance = ERC20(gtcbBTCc).balanceOf(boringVault);
            
            console.log("New cbBTC Allowance:");
            console2.log(newAllowance);
            console.log("New gtcbBTCc LP balance:");
            console2.log(newGtcbBTCcBalance);
            
        } catch Error(string memory reason) {
            console.log("ERROR: Execution failed -", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Execution failed with low-level error");
            console.logBytes(lowLevelData);
        }
    }

    /**
     * Generate merkle proof for cbBTC approve gtcbBTCc leaf (index 0)
     * Based on the WithLBcbbtc.json merkle tree structure
     * Leaf digest: 0x6b6bac96d1997aaa80f948882e96c6a70848ffbf14d3b57d69fd83f5e85f692d
     */
    function getApproveProof() internal pure returns (bytes32[] memory proof) {
        proof = new bytes32[](2); // 2 proof elements needed for 4-capacity tree
        
        // Proof for leaf at index 0
        // Level 2: sibling is leaf at index 1
        proof[0] = 0x144e6401d1e0f0bd4f44e0767ef9eb849ade4d19253a2c52fa4cd69f4709e18b;
        
        // Level 1: sibling is the right branch
        proof[1] = 0x4c3041929422fba1275f915776a7056f5194d5ecd671d2a83f82e48b9bee5c6b;
    }

    /**
     * Generate merkle proof for cbBTC deposit to gtcbBTCc leaf (index 1)
     * Based on the WithLBcbbtc.json merkle tree structure
     * Leaf digest: 0x144e6401d1e0f0bd4f44e0767ef9eb849ade4d19253a2c52fa4cd69f4709e18b
     */
    function getDepositProof() internal pure returns (bytes32[] memory proof) {
        proof = new bytes32[](2); // 2 proof elements needed for 4-capacity tree
        
        // Proof for leaf at index 1
        // Level 2: sibling is leaf at index 0
        proof[0] = 0x6b6bac96d1997aaa80f948882e96c6a70848ffbf14d3b57d69fd83f5e85f692d;
        
        // Level 1: sibling is the right branch
        proof[1] = 0x4c3041929422fba1275f915776a7056f5194d5ecd671d2a83f82e48b9bee5c6b;
    }

    // View function to check current state without broadcasting
    function checkCurrentState() public view {
        console.log("=== Current State Check ===");
        
        uint256 cbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
        uint256 gtcbBTCcBalance = ERC20(gtcbBTCc).balanceOf(boringVault);
        uint256 allowance = ERC20(cbbtc).allowance(boringVault, gtcbBTCc);
        
        console.log("BoringVault cbBTC Balance:");
        console2.log(cbbtcBalance);
        console.log("BoringVault gtcbBTCc Balance:");
        console2.log(gtcbBTCcBalance);
        console.log("Current cbBTC Allowance:");
        console2.log(allowance);
        
        uint256 depositAmount = cbbtcBalance / 10;
        console.log("Potential Deposit Amount (1/10 of balance):");
        console2.log(depositAmount);
        
        if (depositAmount > 0) {
            console.log("STATUS: Ready for approve + deposit");
        } else {
            console.log("STATUS: No cbBTC balance to deposit");
        }
    }
} 