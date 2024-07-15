// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run() external returns (uint256, address) {
        return createSubscription();
    }

    function createSubscription() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        VRFCoordinatorV2_5Mock vrfCoordinator = VRFCoordinatorV2_5Mock(helperConfig.getConfigByChainid().vrfCoordinator);
        vm.startBroadcast();
        uint256 subscriptionId = vrfCoordinator.createSubscription();
        vm.stopBroadcast();
        console.log(subscriptionId);
        return (subscriptionId, address(vrfCoordinator));
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 constant FUND_AMT = 3e21;

    function run() external {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfigByChainid().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfigByChainid().subscriptionId;
        address linkToken = helperConfig.getConfigByChainid().link;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
        console.log("Vrfcoordinator address: ", vrfCoordinator);
        console.log("subscription id: ", subscriptionId);
        console.log("On chain: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMT * 100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        address mostRecentlyDeployedContractAddr = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid); // Raffle contract address
        addConsumerUsingConfig(mostRecentlyDeployedContractAddr);
    }

    function addConsumerUsingConfig(address consumerContractAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfigByChainid().subscriptionId;
        address vrfCoordinator = helperConfig.getConfigByChainid().vrfCoordinator;
        addConsumer(consumerContractAddress, vrfCoordinator, subId);
    }

    function addConsumer(address consumerContractAddress, address vrfCoordinator, uint256 subId) public {
        console.log("Vrfcoordinator address: ", vrfCoordinator);
        console.log("subscription id: ", subId);
        console.log("On chain: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumerContractAddress);
        vm.stopBroadcast();
    }
}
