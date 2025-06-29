// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {BaseAddresses} from "test/resources/BaseAddresses.sol";
import {Authority} from "@solmate/auth/Auth.sol";

// Import Decoder and Sanitizer to deploy.
import {LombardBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LombardBtcDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Base/DeployLombardBtc.s.sol:DeployLombardBtcScript --evm-version london --broadcast --etherscan-api-key $BASESCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployLombardBtcScript is DeployArcticArchitecture, BaseAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "LeBron cbBTC Vault";
    string public boringVaultSymbol = "LBcbBTCv";
    uint8 public boringVaultDecimals = 8;
    address public owner = 0x4A7bCebEc5b0A02Ad51F858741a76cFA17fDe637;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("base");
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = true;
        configureDeployment.setupRoles = true;
        configureDeployment.setupDepositAssets = true;
        configureDeployment.setupWithdrawAssets = true;
        configureDeployment.finishSetup = true;
        configureDeployment.setupTestUser = true;
        configureDeployment.saveDeploymentDetails = true;
        configureDeployment.deployerAddress = owner;
        configureDeployment.balancerVault = balancerVault;
        configureDeployment.WETH = address(WETH);

        vm.startBroadcast(privateKey);

        // Save deployer.        
        // Deploy a new Deployer contract first
        Deployer newDeployer = new Deployer(owner, Authority(address(0)));
        configureDeployment.deployerAddress = address(newDeployer);

        // Save deployer.
        deployer = newDeployer;

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = LombardBtcRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = LombardBtcName;
        names.manager = LombardBtcManagerName;
        names.accountant = LombardBtcAccountantName;
        names.teller = LombardBtcTellerName;
        names.rawDataDecoderAndSanitizer = LombardBtcDecoderAndSanitizerName;
        names.delayedWithdrawer = LombardBtcDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = cbBTC;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1.00377152e8;
        //  4 decimals
        accountantParameters.platformFee = 0.015e4;
        accountantParameters.performanceFee = 0;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(LombardBtcDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names.boringVault), uniswapV3NonFungiblePositionManager);

        // Setup extra deposit assets.
        // none
        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: cbBTC,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        bool allowPublicDeposits = true;
        bool allowPublicWithdraws = true;
        uint64 shareLockPeriod = 1 days;
        address delayedWithdrawFeeAddress = liquidPayoutAddress;

        _deploy(
            "Base/LombardBtcDeployment.json",
            owner,
            boringVaultName,
            boringVaultSymbol,
            boringVaultDecimals,
            creationCode,
            constructorArgs,
            delayedWithdrawFeeAddress,
            allowPublicDeposits,
            allowPublicWithdraws,
            shareLockPeriod,
            owner
        );

        vm.stopBroadcast();
    }
}
