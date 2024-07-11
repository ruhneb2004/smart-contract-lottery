// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
    function run() external returns (uint256) {
        return createSubscription();
    }

    function createSubscription() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        VRFCoordinatorV2_5Mock vrfCoordinator = VRFCoordinatorV2_5Mock(helperConfig.getConfigByChainid().vrfCoordinator);
        vm.startBroadcast();
        uint256 subscriptionId = vrfCoordinator.createSubscription();
        vm.stopBroadcast();
        console.log(subscriptionId);
        return subscriptionId;
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 constant FUND_AMT = 3e18;

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
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }
}
