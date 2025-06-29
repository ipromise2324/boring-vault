// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {Script, console} from "forge-std/Script.sol";
import "forge-std/console2.sol";

/**
 * Execute cbBTC deposit to gtcbBTCc strategy using merkle verification
 * Usage: source .env && forge script script/Deposit.s.sol:ExecuteDepositScript --rpc-url base --broadcast
 */
contract ExecuteDepositScript is Script {
    using FixedPointMathLib for uint256;

    // Base network addresses from deployment
    address public boringVault = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address public managerAddress = 0x747e2d36704f59EB18a1b7a7d3884e29628DF28a;
    address public rawDataDecoderAndSanitizer = 0xFe10Cc403Adc068676dB957Ef3eC0f17c8090178;
    
    // Token addresses
    address cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public gtcbBTCc = 0x6770216aC60F634483Ec073cBABC4011c94307Cb;
    
    // Merkle root from LombardBTCStrategistLeafs.json
    bytes32 public merkleRoot = 0x18f4cba2e9509c5bf0bf8c7b17a60d7dc92d5470620e0943ab3cbd1daf259467;
    
    // Deposit amount (10 cbBTC with 8 decimals)
    uint256 public constant DEPOSIT_AMOUNT = 50;

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
        executeDepositStrategy();
        vm.stopBroadcast();
    }

    function executeDepositStrategy() public {
        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        
        console.log("=== Executing cbBTC Deposit to gtcbBTCc Strategy ===");
        // console.log("Boring Vault:", boringVault);
        // console.log("Manager:", managerAddress);
        // console.log("cbBTC:", cbbtc);
        // console.log("gtcbBTCc:", gtcbBTCc);

        // // Check current balances
        // uint256 cbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
        // uint256 gtcbBTCcBalance = ERC20(gtcbBTCc).balanceOf(boringVault);
        // console.log("BoringVault cbBTC Balance:");
        // console2.log(cbbtcBalance);
        // console.log("BoringVault gtcbBTCc Balance:");
        // console2.log(gtcbBTCcBalance);

        // // Check allowance
        // uint256 allowance = ERC20(cbbtc).allowance(boringVault, gtcbBTCc);
        // console.log("cbBTC Allowance for gtcbBTCc:");
        // console2.log(allowance);

        // require(allowance >= DEPOSIT_AMOUNT, "Insufficient allowance for deposit");
        // require(cbbtcBalance >= DEPOSIT_AMOUNT, "Insufficient cbBTC balance for deposit");

        // Prepare transaction arrays
        address[] memory targets = new address[](1);
        targets[0] = gtcbBTCc;

        bytes[] memory targetData = new bytes[](1);
        // deposit(uint256,address) - deposit amount to boringVault
        targetData[0] = abi.encodeWithSelector(0x6e553f65, DEPOSIT_AMOUNT, boringVault);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Get proof for deposit leaf (index 1)
        bytes32[][] memory manageProofs = new bytes32[][](1);
        manageProofs[0] = getDepositProof();

        console.log("Leaf Digest: 0x144e6401d1e0f0bd4f44e0767ef9eb849ade4d19253a2c52fa4cd69f4709e18b");
        console.log("Deposit Amount: 10 cbBTC");

        // Execute the strategy
        try manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values) {
            console.log("SUCCESS: Deposit strategy executed!");
            
            // uint256 newCbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
            // uint256 newGtcbBTCcBalance = ERC20(gtcbBTCc).balanceOf(boringVault);
            // console.log("New BoringVault cbBTC Balance:");
            // console2.log(newCbbtcBalance);
            // console.log("New BoringVault gtcbBTCc Balance:");
            // console2.log(newGtcbBTCcBalance);
            
            // if (newGtcbBTCcBalance > gtcbBTCcBalance) {
            //     console.log("SUCCESS: Deposit completed successfully!");
            //     uint256 received = newGtcbBTCcBalance - gtcbBTCcBalance;
            //     console.log("gtcbBTCc received:");
            //     console2.log(received);
            // }
        } catch Error(string memory reason) {
            console.log("ERROR: Execution failed -", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Execution failed with low-level error");
            console.logBytes(lowLevelData);
        }
    }

    /**
     * Generate merkle proof for cbBTC deposit to gtcbBTCc leaf (index 1)
     * Based on the LombardBTCStrategistLeafs.json merkle tree structure
     * Leaf digest: 0x144e6401d1e0f0bd4f44e0767ef9eb849ade4d19253a2c52fa4cd69f4709e18b
     * This is a 2-level tree with only 2 leaves
     */
    function getDepositProof() internal pure returns (bytes32[] memory proof) {
        proof = new bytes32[](1); // Only 1 proof element needed for 2-level tree
        
        // Proof for leaf at index 1, sibling is leaf at index 0
        proof[0] = 0x6b6bac96d1997aaa80f948882e96c6a70848ffbf14d3b57d69fd83f5e85f692d;
    }

    // View function to check current state without broadcasting
    function checkCurrentState() external view {
        console.log("=== Current State Check ===");
        console.log("cbBTC Address:", cbbtc);
        console.log("gtcbBTCc Address:", gtcbBTCc);
        console.log("Boring Vault:", boringVault);
        
        uint256 cbbtcBalance = ERC20(cbbtc).balanceOf(boringVault);
        uint256 gtcbBTCcBalance = ERC20(gtcbBTCc).balanceOf(boringVault);
        uint256 allowance = ERC20(cbbtc).allowance(boringVault, gtcbBTCc);
        
        console.log("BoringVault cbBTC Balance:");
        console2.log(cbbtcBalance);
        console.log("BoringVault gtcbBTCc Balance:");
        console2.log(gtcbBTCcBalance);
        console.log("cbBTC Allowance for gtcbBTCc:");
        console2.log(allowance);
        
        if (allowance >= DEPOSIT_AMOUNT) {
            console.log("STATUS: Has sufficient allowance for deposit");
        } else {
            console.log("STATUS: Insufficient allowance - need to approve first");
        }
        
        if (cbbtcBalance >= DEPOSIT_AMOUNT) {
            console.log("STATUS: Has sufficient cbBTC balance for deposit");
        } else {
            console.log("STATUS: Insufficient cbBTC balance for deposit");
        }
    }
} 