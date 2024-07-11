//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

/**
 * From what I know so far the helperConfig is used for setting up the network configuration. The info that is setup here is mainly the *same as the info needed for the contract constuctor! Also we can return the data by checking which chain it is using the chain id and *another way is to map the networkconfig and the chainid and then return the networkconfig based on the chain id.
 */
abstract contract CodeConstants {
    //Mock contract constants!!!
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant SEPOLIA_ETH_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    //This is for the localchain only!!!
    NetworkConfig public localNetworkConfig;

    struct NetworkConfig {
        uint256 ticketPrice;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    mapping(uint256 => NetworkConfig) public networkConfig;

    error HelperConfig__ChainNotSupported(uint256 chainid);

    constructor() {
        networkConfig[SEPOLIA_ETH_CHAIN_ID] = getSepoliaEthConfig();
        //need to add the networkConfig here if there are new chains needed for setting up.
    }

    /**
     * Unlike the fundMe contract here we are using a function instead of the constructor and calling that function in the Ruffle contract. In the fundMe we are simply assigining the struct with the values and then calling it in the other contract but i this sincerio we will be calling the function for getting the network config based on the chain id.
     */
    function getConfigByChainid() public returns (NetworkConfig memory) {
        if (networkConfig[block.chainid].vrfCoordinator != address(0)) {
            return networkConfig[block.chainid];
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__ChainNotSupported(block.chainid);
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            ticketPrice: 0.01 ether, //1e16
            interval: 30 seconds,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 109064213244911707800218494862008793638653672925758480575172833685521395175627, // don't why it's zero
            callbackGasLimit: 500000, // 500,000 => don't know why this is the gas limit!
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            ticketPrice: 0.01 ether, //1e16
            interval: 30 seconds,
            vrfCoordinator: address(vrfCoordinator),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0, // ight have to change it up a lill bit.
            callbackGasLimit: 500000, // ? 500,000 => don't know why this is the gas limit!
            link: address(linkToken)
        });

        return localNetworkConfig;
    }
}
