// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {Script, console} from "forge-std/Script.sol";
import "forge-std/console2.sol";


// forge script script/InitiateAtomicRequest.s.sol:InitiateAtomicRequest --rpc-url base --broadcast
contract InitiateAtomicRequest is Script {
    using FixedPointMathLib for uint256;

    // Base network addresses - update these for your specific deployment
    address public constant ATOMIC_QUEUE = address(0x3080a4989729f3Ad339923Bb46d07f28a531DD12); 
    address public constant BORING_VAULT = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address public constant ACCOUNTANT = address(0xA06F6C388c0bC49e9Af8d472E6d6821A44d6E3E8);
    address public constant TELLER = 0x9fAF90689A215cb595e8Af204A0973d0fcad682B;
    
    // Token addresses (Base network)
    address public constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    
    // Configuration parameters
    uint256 public constant DEFAULT_OFFER_AMOUNT = 1; // 1 vault share by default
    uint256 public constant DEFAULT_DISCOUNT_BPS = 50; // 0.5% discount by default (50 basis points)
    uint64 public constant DEFAULT_DEADLINE_HOURS = 72; // 24 hours deadline
    
    // Store private key as state variable
    uint256 private privateKey;
    
    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("base");
        
        address deployer = vm.addr(privateKey);
        console.log("Using deployer address:", deployer);
    }

    function run() external {
        vm.startBroadcast(privateKey);
        // checkVaultAndRateInfo();
        
        // Example: Create atomic request to exchange BoringVault shares for cbBTC
        createAtomicRequestForCbBTC(DEFAULT_OFFER_AMOUNT, DEFAULT_DISCOUNT_BPS, DEFAULT_DEADLINE_HOURS);
        
        vm.stopBroadcast();
    }

    /**
     * @notice Creates an atomic request to exchange BoringVault shares for cbBTC
     * @param offerAmount Amount of BoringVault shares to offer
     * @param discountBps Discount in basis points (100 = 1%)
     * @param deadlineHours Deadline in hours from now
     */
    function createAtomicRequestForCbBTC(
        uint256 offerAmount,
        uint256 discountBps,
        uint64 deadlineHours
    ) public {
        _createAtomicRequest(
            ERC20(BORING_VAULT), // offer: BoringVault shares
            ERC20(cbBTC),         // want: cbBTC
            offerAmount,
            discountBps,
            deadlineHours
        );
    }

    /**
     * @notice Internal function to create atomic requests
     * @param offer The ERC20 token being offered (typically BoringVault shares)
     * @param want The ERC20 token wanted in return
     * @param offerAmount Amount of offer token to exchange
     * @param discountBps Discount in basis points (100 = 1%)
     * @param deadlineHours Deadline in hours from now
     */
    function _createAtomicRequest(
        ERC20 offer,
        ERC20 want,
        uint256 offerAmount,
        uint256 discountBps,
        uint64 deadlineHours
    ) internal {
        console.log("=== Creating Atomic Request ===");
        console.log("Offer token:", address(offer));
        console.log("Want token:", address(want));
        console.log("Offer amount:", offerAmount);
        console.log("Discount (bps):", discountBps);
        console.log("Deadline (hours):", deadlineHours);

        AtomicQueue atomicQueue = AtomicQueue(ATOMIC_QUEUE);
        AccountantWithRateProviders accountant = AccountantWithRateProviders(ACCOUNTANT);
        
        // Check current user balance and allowance
        address user = msg.sender;
        uint256 userBalance = offer.balanceOf(user);
        uint256 userAllowance = offer.allowance(user, ATOMIC_QUEUE);
        
        console.log("User balance:", userBalance);
        console.log("User allowance:", userAllowance);
        
        // Approve atomic queue if needed
        if (userAllowance < offerAmount) {
            console.log("Approving AtomicQueue to spend tokens...");
            offer.approve(ATOMIC_QUEUE, type(uint256).max);
        }

        // Get current rate from accountant
        uint256 currentRate = accountant.getRateInQuote(want);
        console.log("Current rate from accountant:", currentRate);
        
        // Apply discount to get atomic price
        uint256 atomicPrice = currentRate.mulDivDown(10000 - discountBps, 10000);
        console.log("Atomic price (with discount):", atomicPrice);
        
        // Ensure atomic price fits in uint88
        require(atomicPrice <= type(uint88).max, "Atomic price too large for uint88");
        
        // Calculate deadline
        uint64 deadline = uint64(block.timestamp + (deadlineHours * 1 hours));
        
        // Create atomic request
        AtomicQueue.AtomicRequest memory request = AtomicQueue.AtomicRequest({
            deadline: deadline,
            atomicPrice: uint88(atomicPrice),
            offerAmount: uint96(offerAmount),
            inSolve: false
        });
        
        console.log("Request deadline:", deadline);
        console.log("Request atomic price:", request.atomicPrice);
        console.log("Request offer amount:", request.offerAmount);
        
        // Submit the atomic request
        try atomicQueue.updateAtomicRequest(offer, want, request) {
            console.log("SUCCESS: Atomic request created!");
            
        } catch Error(string memory reason) {
            console.log("ERROR: Failed to create atomic request -", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Failed with low-level error");
            console.logBytes(lowLevelData);
        }
    }

    /**
     * @notice Alternative method using safeUpdateAtomicRequest with built-in safety checks
     * @param offer The ERC20 token being offered
     * @param want The ERC20 token wanted in return
     * @param offerAmount Amount of offer token to exchange
     * @param discountMicroPercent Discount in micro percent (1000000 = 1%, max 10000 = 0.01%)
     * @param deadlineHours Deadline in hours from now
     */
    function createSafeAtomicRequest(
        ERC20 offer,
        ERC20 want,
        uint256 offerAmount,
        uint256 discountMicroPercent,
        uint64 deadlineHours
    ) public {
        console.log("=== Creating Safe Atomic Request ===");
        console.log("Offer token:", address(offer));
        console.log("Want token:", address(want));
        console.log("Offer amount:", offerAmount);
        console.log("Discount (micro %):", discountMicroPercent);
        console.log("Deadline (hours):", deadlineHours);

        AtomicQueue atomicQueue = AtomicQueue(ATOMIC_QUEUE);
        AccountantWithRateProviders accountant = AccountantWithRateProviders(ACCOUNTANT);
        
        // Check that discount is within allowed range
        require(discountMicroPercent <= 10000, "Discount too large"); // Max 1% (0.01 * 1e6)
        
        // Check current user balance and allowance
        address user = msg.sender;
        uint256 userBalance = offer.balanceOf(user);
        uint256 userAllowance = offer.allowance(user, ATOMIC_QUEUE);
        
        console.log("User balance:", userBalance);
        console.log("User allowance:", userAllowance);
        
        require(userBalance >= offerAmount, "Insufficient balance");
        
        // Approve atomic queue if needed
        if (userAllowance < offerAmount) {
            console.log("Approving AtomicQueue to spend tokens...");
            offer.approve(ATOMIC_QUEUE, type(uint256).max);
        }

        // Calculate deadline
        uint64 deadline = uint64(block.timestamp + (deadlineHours * 1 hours));
        
        // Create atomic request (atomicPrice will be calculated by safeUpdateAtomicRequest)
        AtomicQueue.AtomicRequest memory request = AtomicQueue.AtomicRequest({
            deadline: deadline,
            atomicPrice: 0, // Will be overwritten by safeUpdateAtomicRequest
            offerAmount: uint96(offerAmount),
            inSolve: false
        });
        
        console.log("Request deadline:", deadline);
        console.log("Request offer amount:", request.offerAmount);
        
        // Submit the safe atomic request
        try atomicQueue.safeUpdateAtomicRequest(offer, want, request, accountant, discountMicroPercent) {
            console.log("SUCCESS: Safe atomic request created!");
            
        } catch Error(string memory reason) {
            console.log("ERROR: Failed to create safe atomic request -", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Failed with low-level error");
            console.logBytes(lowLevelData);
        }
    }

    /**
     * @notice Check BoringVault balance and accountant rate information
     */
    function checkVaultAndRateInfo() public view {
        address user = vm.addr(privateKey);
        
        // Check BoringVault balance
        ERC20 boringVault = ERC20(BORING_VAULT);
        uint256 userBalance = boringVault.balanceOf(user);
        console.log("BoringVault balance:");
        console2.log(userBalance);

        console.log("");
        console.log("=== cbBTC Rate Info ===");
        
        AccountantWithRateProviders accountant = AccountantWithRateProviders(ACCOUNTANT);
        
        // Check cbBTC rate specifically
        console.log("cbBTC address:", cbBTC);
        
        try accountant.getRateInQuote(ERC20(cbBTC)) returns (uint256 rate) {
            console.log("SUCCESS: cbBTC Rate (getRateInQuote):");
            console2.log(rate);
            
            // // Try getRateInQuoteSafe as well
            // try accountant.getRateInQuoteSafe(ERC20(cbBTC)) returns (uint256 safeRate) {
            //     console.log("SUCCESS: cbBTC Safe Rate (getRateInQuoteSafe):");
            //     console2.log(safeRate);
                
            //     // Calculate what user would get with current balance
            //     if (userBalance > 0) {
            //         uint256 expectedCbBTC = rate.mulDivDown(userBalance, 10**18); // Assuming vault is 18 decimals
            //         console.log("Expected cbBTC for your shares:");
            //         console2.log(expectedCbBTC);
            //     }
            // } catch {
            //     console.log("ERROR: getRateInQuoteSafe failed - might be paused or not set");
            // }
            
        } catch Error(string memory reason) {
            console.log("ERROR: getRateInQuote failed:", reason);
        } catch {
            console.log("ERROR: getRateInQuote failed - rate provider not set");
        }
    }

    /**
     * @notice Convenience function to create a cbBTC request with current user balance
     */
    function createMaxCbBTCRequest() external {
        vm.startBroadcast(privateKey);
        
        ERC20 boringVault = ERC20(BORING_VAULT);
        uint256 userBalance = boringVault.balanceOf(msg.sender);
        
        require(userBalance > 0, "No BoringVault shares to exchange");
        
        createAtomicRequestForCbBTC(userBalance, DEFAULT_DISCOUNT_BPS, DEFAULT_DEADLINE_HOURS);
        
        vm.stopBroadcast();
    }
} 