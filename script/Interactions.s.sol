// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfigByChainid().vrfCoordinator;
        address account = helperConfig.getConfigByChainid().account;
        return createSubscription(vrfCoordinator, account);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        vm.startBroadcast(account);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log(subscriptionId);
        return (subscriptionId, address(vrfCoordinator));
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 constant FUND_AMT = 2e18;

    function run() external returns (address) {
        address linkTokenAddr = fundSubscriptionUsingConfig();
        return linkTokenAddr;
    }

    function fundSubscriptionUsingConfig() public returns (address tokenAddr) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfigByChainid().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfigByChainid().subscriptionId;
        address linkToken = helperConfig.getConfigByChainid().link;
        address account = helperConfig.getConfigByChainid().account;
        address linkTokenAddr = fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
        return linkTokenAddr;
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account)
        public
        returns (address tokenAddr)
    {
        console.log("Vrfcoordinator address inside fundSub: ", vrfCoordinator);
        console.log("subscription id: ", subscriptionId);
        console.log("On chain: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMT * 100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMT, abi.encode(subscriptionId));
            vm.stopBroadcast();

            return linkToken;
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
        address account = helperConfig.getConfigByChainid().account;
        uint256 subId = helperConfig.getConfigByChainid().subscriptionId;
        address vrfCoordinator = helperConfig.getConfigByChainid().vrfCoordinator;
        console.log("inside add consumer", vrfCoordinator);

        console.log("somewhere", vrfCoordinator);
        addConsumer(consumerContractAddress, vrfCoordinator, subId, account);
    }

    function addConsumer(address consumerContractAddress, address vrfCoordinator, uint256 subId, address account)
        public
    {
        console.log("Vrfcoordinator address: ", vrfCoordinator);
        console.log("subscription id: ", subId);
        console.log("On chain: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumerContractAddress);
        vm.stopBroadcast();
    }
}
