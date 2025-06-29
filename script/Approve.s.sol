// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {Script, console} from "forge-std/Script.sol";
import "forge-std/console2.sol";

/**
 * Execute cbBTC approve gtcbBTCc strategy using merkle verification
 * Usage: source .env && forge script script/Approve.s.sol:ExecuteStrategyScript --rpc-url base --broadcast
 */
contract ExecuteStrategyScript is Script {
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
    
    // Approve amount (100 cbBTC with 8 decimals)
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
        
        console.log("=== Executing cbBTC Approve gtcbBTCc Strategy ===");
        console.log("Boring Vault:", boringVault);
        console.log("Manager:", managerAddress);
        console.log("cbBTC:", cbbtc);
        console.log("gtcbBTCc:", gtcbBTCc);

        // Check current allowance
        uint256 currentAllowance = ERC20(cbbtc).allowance(boringVault, gtcbBTCc);
        console.log("Current Allowance:");
        console2.log(currentAllowance);

        // Prepare transaction arrays
        address[] memory targets = new address[](1);
        targets[0] = cbbtc;

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, gtcbBTCc, APPROVE_AMOUNT);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Get proof for cbBTC approve gtcbBTCc leaf (需要確定正確的 index)
        bytes32[][] memory manageProofs = new bytes32[][](1);
        manageProofs[0] = getGtcbBTCcApproveProof();

        console.log("Leaf Digest: 0x6b6bac96d1997aaa80f948882e96c6a70848ffbf14d3b57d69fd83f5e85f692d");
        console.log("Approve Amount: 100 cbBTC");

        // Execute the strategy
        try manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values) {
            console.log("SUCCESS: Approve strategy executed!");
            
            uint256 newAllowance = ERC20(cbbtc).allowance(boringVault, gtcbBTCc);
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
     * Generate merkle proof for cbBTC approve gtcbBTCc leaf (index 0)
     * Based on the LombardBTCStrategistLeafs.json merkle tree structure
     * Leaf digest: 0x6b6bac96d1997aaa80f948882e96c6a70848ffbf14d3b57d69fd83f5e85f692d
     * This is a 2-level tree with only 2 leaves
     */
    function getGtcbBTCcApproveProof() internal pure returns (bytes32[] memory proof) {
        proof = new bytes32[](1); // Only 1 proof element needed for 2-level tree
        
        // Proof for leaf at index 0, sibling is leaf at index 1
        proof[0] = 0x144e6401d1e0f0bd4f44e0767ef9eb849ade4d19253a2c52fa4cd69f4709e18b;
    }


    // View function to check current state without broadcasting
    function checkCurrentState() external view {
        console.log("=== Current State Check ===");
        console.log("cbBTC Address:", cbbtc);
        console.log("gtcbBTCc Address:", gtcbBTCc);
        console.log("Boring Vault:", boringVault);
        
        uint256 currentAllowance = ERC20(cbbtc).allowance(boringVault, gtcbBTCc);
        console.log("Current cbBTC Allowance for gtcbBTCc:");
        
        if (currentAllowance >= APPROVE_AMOUNT) {
            console.log("STATUS: Already has sufficient allowance for gtcbBTCc");
        } else if (currentAllowance > 0) {
            console.log("STATUS: Has partial allowance, will increase to 100 cbBTC for gtcbBTCc");
        } else {
            console.log("STATUS: No allowance, will set to 100 cbBTC for gtcbBTCc");
        }
    }
}
