//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

//! I may have to change the using config functions to their normal versions!!!

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }

    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainid();
        console.log("chain id from deploy", block.chainid);

        console.log("From deployRaffle", config.vrfCoordinator);

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator, config.account);
            console.log("DeployRaffle: ", config.subscriptionId);
            //returns a subId if the subId is not set or is zero!.

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.ticketPrice,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumerContract = new AddConsumer();
        addConsumerContract.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account);

        return (raffle, helperConfig);
    }
}
