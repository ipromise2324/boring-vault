// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {Script, console} from "forge-std/Script.sol";

/**
 * Execute tBTC approve strategy using merkle verification
 * Usage: source .env && forge script script/ExecuteStrategy.s.sol:ExecuteStrategyScript --rpc-url $BASE_RPC_URL --broadcast --verify -vvvv
 */
contract ExecuteStrategyScript is Script {
    using FixedPointMathLib for uint256;

    // Base network addresses from deployment
    address public boringVault = 0x1cb28c15F0fC5A13Ec63D35480C302c76aF32FFb;
    address public managerAddress = 0xa2BF2DB5aB0edbeFb74b0B9eCA7a0a72d3154770;
    address public rawDataDecoderAndSanitizer = 0x5599a461C5764e7cFc99dB9677E172E61B5d48CB;
    
    // Token and router addresses
    address public tBTC = 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b;
    address public uniswapV3Router = 0x2626664c2603336E57B271c5C0b26F421741e481;
    
    // Merkle root from CbBTCStrategistLeafs.json
    bytes32 public merkleRoot = 0x41e0275a47590b15151f346d68c08e2eb3096dabdab86cc4f5c39362996cf17b;
    
    // Approve amount (100 tBTC with 8 decimals)
    uint256 public constant APPROVE_AMOUNT = 100 * 10**8;

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
        executeApproveStrategy();
        vm.stopBroadcast();
    }

    function executeApproveStrategy() public {
        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(managerAddress);
        
        console.log("=== Executing tBTC Approve Strategy ===");
        console.log("Boring Vault:", boringVault);
        console.log("Manager:", managerAddress);
        console.log("tBTC:", tBTC);
        console.log("UniswapV3 Router:", uniswapV3Router);

        // Check current allowance
        uint256 currentAllowance = ERC20(tBTC).allowance(boringVault, uniswapV3Router);
        console.log("Current Allowance:");
        console.logUint(currentAllowance);

        // Prepare transaction arrays
        address[] memory targets = new address[](1);
        targets[0] = tBTC;

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, uniswapV3Router, APPROVE_AMOUNT);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Get proof for tBTC approve leaf (index 9 in the merkle tree)
        bytes32[][] memory manageProofs = new bytes32[][](1);
        manageProofs[0] = getTBTCApproveProof();

        console.log("Leaf Digest: 0xa3cc79385334a6fd08a2e2d702068b357282d3a9b1b3847cec6ea0c74ab24507");
        console.log("Approve Amount: 100 tBTC");

        // Execute the strategy
        try manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values) {
            console.log("SUCCESS: Approve strategy executed!");
            
            uint256 newAllowance = ERC20(tBTC).allowance(boringVault, uniswapV3Router);
            console.log("New Allowance:");
            console.logUint(newAllowance);
            
            if (newAllowance >= APPROVE_AMOUNT) {
                console.log("SUCCESS: Allowance set correctly!");
            }
        } catch Error(string memory reason) {
            console.log("ERROR: Execution failed -", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Execution failed with low-level error");
            console.logBytes(lowLevelData);
        }
    }

    /**
     * Generate merkle proof for tBTC approve UniswapV3 leaf (index 9)
     * Based on the merkle tree structure from CbBTCStrategistLeafs.json
     * Leaf digest: 0xa3cc79385334a6fd08a2e2d702068b357282d3a9b1b3847cec6ea0c74ab24507
     */
    function getTBTCApproveProof() internal pure returns (bytes32[] memory proof) {
        proof = new bytes32[](5); // 5 levels from leaf to root
        
        // Proof path for leaf at index 9 (tBTC approve UniswapV3 router)
        // Index 9 binary = 01001, reading from right to left for merkle path
        // Using MerkleTree data from CbBTCStrategistLeafs.json
        
        // Level 5 (leaf level): sibling of index 9 is index 8  
        proof[0] = 0xffde829232ef0a51ebdbb33da9947d4e182663098e4c04ea7e41fedc89e7f1b4;
        
        // Level 4: parent index 4, sibling is index 5
        proof[1] = 0x97c45f9b5ca5c727682332e80e94c2b3eac218bafc0aa8fb519de5f79cf567b3;
        
        // Level 3: parent index 2, sibling is index 3  
        proof[2] = 0xa4ab34eebc0cdb0ef82c3fccd4cf921ae099856b4f62d9d554f4733d04177104;
        
        // Level 2: parent index 1, sibling is index 0
        proof[3] = 0xa0e4ddf25b33ca9f0cae1b6d59b0be7baa64c695c52b47483a879dec36f2f56b;
        
        // Level 1: parent index 0, sibling is index 1  
        proof[4] = 0x932d0224e8ececde21fc21a1e48768ca373fed6aca2991a8ee9b521f2ba7fc34;
    }

    // View function to check current state without broadcasting
    function checkCurrentState() external view {
        console.log("=== Current State Check ===");
        console.log("tBTC Address:", tBTC);
        console.log("UniswapV3 Router:", uniswapV3Router);
        console.log("Boring Vault:", boringVault);
        
        uint256 currentAllowance = ERC20(tBTC).allowance(boringVault, uniswapV3Router);
        console.log("Current tBTC Allowance for UniswapV3:");
        
        if (currentAllowance >= APPROVE_AMOUNT) {
            console.log("STATUS: Already has sufficient allowance for UniswapV3");
        } else if (currentAllowance > 0) {
            console.log("STATUS: Has partial allowance, will increase to 100 tBTC for UniswapV3");
        } else {
            console.log("STATUS: No allowance, will set to 100 tBTC for UniswapV3");
        }
    }
}
