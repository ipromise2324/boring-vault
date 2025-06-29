// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Base/CreateLBTCMerkleRoot.s.sol:CreateLBTCMerkleRootScript --rpc-url $BASE_RPC_URL
 */
contract CreateLBTCMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x9b549C0fa55871BF9fE6b9edCF9dc649Fac75d0e;
    address public managerAddress = 0x747e2d36704f59EB18a1b7a7d3884e29628DF28a;
    address public accountantAddress = 0xA06F6C388c0bC49e9Af8d472E6d6821A44d6E3E8;
    address public rawDataDecoderAndSanitizer = 0xFe10Cc403Adc068676dB957Ef3eC0f17c8090178;
    address public aerodromeDecoderAndSanitizer = 0xD657c2A871C467871b59d5992CD3bAb1634dd457;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(base);
        setAddress(false, base, "boringVault", boringVault);
        setAddress(false, base, "managerAddress", managerAddress);
        setAddress(false, base, "accountantAddress", accountantAddress);
        setAddress(false, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "cbBTC");
        token0[1] = getAddress(sourceChain, "cbBTC");
        token0[2] = getAddress(sourceChain, "LBTC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "WBTC");
        token1[2] = getAddress(sourceChain, "WBTC");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](4);
        SwapKind[] memory kind = new SwapKind[](4);
        assets[0] = getAddress(sourceChain, "cbBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "AERO");
        kind[3] = SwapKind.Sell;
        //assets[3] = getAddress(sourceChain, "PENDLE");
        //kind[3] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_05_29_25"), true);

        // ========================== Morpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletCbBTCcore")));

        // ========================= Aerodrome ========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", aerodromeDecoderAndSanitizer);
        address[] memory _token0 = new address[](1);
        _token0[0] = getAddress(sourceChain, "LBTC");
        address[] memory _token1 = new address[](1);
        _token1[0] = getAddress(sourceChain, "cbBTC");

        address[] memory gauges = new address[](1);
        gauges[0] = address(0);

        _addVelodromeV3Leafs(
            leafs, _token0, _token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), gauges
        );

        // ========================== Lombard ========================
        // setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        // _addLombardBTCLeafs(leafs, getERC20(sourceChain, "cbBTC"), getERC20(sourceChain, "LBTC"));

        string memory filePath = "./leafs/Base/LombardBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
