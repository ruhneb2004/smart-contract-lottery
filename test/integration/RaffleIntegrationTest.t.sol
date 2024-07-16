//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {CreateSubscription, FundSubscription} from "script/Interactions.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract RaffleIntegrationTest is Test {
    Raffle private raffle;
    HelperConfig private helperConfig;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
    }

    modifier skipIfLocal() {
        if (block.chainid == 31337) return;
        _;
    }

    function testCreateAndFundSubscription() external skipIfLocal {
        CreateSubscription createSubscriptionContract = new CreateSubscription();
        FundSubscription fundSubscription = new FundSubscription();

        uint256 subId;
        address vrfCoordinator;
        (subId, vrfCoordinator) = createSubscriptionContract.run();
        console.log("subId: ", subId);
        console.log("coordinator addr: ", vrfCoordinator);
        address linkTokenAddr = fundSubscription.run();
        //checking the link balance
        uint256 balance = LinkToken(linkTokenAddr).balanceOf(vrfCoordinator);
        assert(balance != 0);
    }
}
