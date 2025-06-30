// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {Script, console} from "forge-std/Script.sol";
import "forge-std/console2.sol";

/**
 * Execute cbBTC withdraw from gtcbBTCc strategy using merkle verification
 * Usage: source .env && forge script script/Withdraw.s.sol:ExecuteWithdrawScript --rpc-url base --broadcast
 */
contract ExecuteWithdrawScript is Script {
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
    
    // Withdraw amount (20 gtcbBTCc shares)
    // 746,453,569,059
    uint256 public constant WITHDRAW_AMOUNT = 30;

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
        executeWithdrawStrategy();
        vm.stopBroadcast();
    }

    function executeWithdrawStrategy() public {
        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        
        console.log("=== Executing cbBTC Withdraw from gtcbBTCc Strategy ===");
        console.log("Withdraw Amount:", WITHDRAW_AMOUNT, "gtcbBTCc shares");

        // // Check current balances (for comparison)
        // uint256 cbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
        // uint256 gtcbBTCcBalance = ERC20(gtcbBTCc).balanceOf(boringVault);

        // Prepare transaction arrays
        address[] memory targets = new address[](1);
        targets[0] = gtcbBTCc;

        bytes[] memory targetData = new bytes[](1);
        // withdraw(uint256,address,address) - withdraw shares to boringVault, boringVault as owner
        targetData[0] = abi.encodeWithSelector(0xb460af94, WITHDRAW_AMOUNT, boringVault, boringVault);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Get proof for withdraw leaf (index 2)
        bytes32[][] memory manageProofs = new bytes32[][](1);
        manageProofs[0] = getWithdrawProof();

        console.log("Leaf Digest: 0xe93eb21e9f316088a271d8fcb8079715bc908be484d92c4778e0605b89653391");

        // Execute the strategy
        try manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values) {
            console.log("SUCCESS: Withdraw strategy executed!");
            
            // uint256 newCbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
            // uint256 newGtcbBTCcBalance = ERC20(gtcbBTCc).balanceOf(boringVault);
            // uint256 cbbtcReceived = newCbbtcBalance - cbbtcBalance;
            // uint256 sharesWithdrawn = gtcbBTCcBalance - newGtcbBTCcBalance;
            
            // console.log("cbBTC received:");
            // console2.log(cbbtcReceived);
            // console.log("gtcbBTCc shares withdrawn:");
            // console2.log(sharesWithdrawn);
            // console.log("Remaining gtcbBTCc balance:");
            // console2.log(newGtcbBTCcBalance);
            
        } catch Error(string memory reason) {
            console.log("ERROR: Execution failed -", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Execution failed with low-level error");
            console.logBytes(lowLevelData);
        }
    }

    /**
     * Generate merkle proof for cbBTC withdraw from gtcbBTCc leaf (index 2)
     * Based on the WithLBcbbtc.json merkle tree structure
     * Leaf digest: 0xe93eb21e9f316088a271d8fcb8079715bc908be484d92c4778e0605b89653391
     * This is a 4-capacity tree with 3 leaves
     */
    function getWithdrawProof() internal pure returns (bytes32[] memory proof) {
        proof = new bytes32[](2); // 2 proof elements needed for 4-capacity tree
        
        // Proof for leaf at index 2
        // Level 2: sibling is leaf at index 3
        proof[0] = 0xa7a0fd846665d92e66be6155c6221b3acd7145ca7c4e4b67a594e4c516969400;
        
        // Level 1: sibling is the left branch
        proof[1] = 0x18f4cba2e9509c5bf0bf8c7b17a60d7dc92d5470620e0943ab3cbd1daf259467;
    }

    // View function to check current state without broadcasting
    function checkCurrentState() external view {
        console.log("=== Current State Check ===");
        
        uint256 cbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
        uint256 gtcbBTCcBalance = ERC20(gtcbBTCc).balanceOf(boringVault);
        
        console.log("Current cbBTC balance:");
        console2.log(cbbtcBalance);
        console.log("Current gtcbBTCc LP balance:");
        console2.log(gtcbBTCcBalance);
        
        if (gtcbBTCcBalance >= WITHDRAW_AMOUNT) {
            console.log("STATUS: Ready for withdraw");
        } else {
            console.log("STATUS: Insufficient gtcbBTCc balance for withdraw");
        }
    }
} 