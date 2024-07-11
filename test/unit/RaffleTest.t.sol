// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 ticketPrice;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address private s_demoPlayerAccount = makeAddr("player");
    uint256 private constant STARTING_BALANCE = 1000 ether;

    event raffleEntered(address indexed player);
    event winnerPicked(address indexed winner, uint256 timeStamp);

    constructor() {
        vm.deal(s_demoPlayerAccount, STARTING_BALANCE);
    }

    //make the sender of the transactions in the functions in which the modifier is applied...
    modifier assignPlayer() {
        vm.prank(s_demoPlayerAccount);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainid();
        ticketPrice = config.ticketPrice;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    //Maybe a dumb thing to say, but you should mark the test functions as external or public cause the testing framwork will call them.

    function testRaffleStartsInOpen() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testCannotEnterRaffleWithLowBalance() external assignPlayer {
        uint256 transactionAmnt = 0.0001 ether;
        uint256 currentBalance = s_demoPlayerAccount.balance;
        // vm.prank(s_demoPlayerAccount);
        vm.expectRevert(Raffle.Raffle__InefficientFunds.selector);
        raffle.enterRaffle{value: transactionAmnt}();
        assert(currentBalance == s_demoPlayerAccount.balance);
    }

    function testEnterRaffleWithProperFund() external assignPlayer {
        uint256 currentBalance = s_demoPlayerAccount.balance;
        raffle.enterRaffle{value: ticketPrice}();
        assert(raffle.getRafflePlayers()[0] == s_demoPlayerAccount);
        assert(s_demoPlayerAccount.balance == currentBalance - ticketPrice);
    }

    function testEnteringRaffleEmitsEvent() external assignPlayer {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit raffleEntered(s_demoPlayerAccount);
        raffle.enterRaffle{value: ticketPrice}();
    }

    function testRefundOfExtraAmount() external assignPlayer {
        uint256 transactionAmt = 1 ether;
        uint256 currentBalance = s_demoPlayerAccount.balance;

        console.log("Before");
        console.log(currentBalance);

        raffle.enterRaffle{value: transactionAmt}();

        console.log("After");
        console.log(currentBalance);

        assert(s_demoPlayerAccount.balance == currentBalance - ticketPrice);
    }

    function testCannotEnterRaffleWhenClosed() external assignPlayer {
        raffle.enterRaffle{value: ticketPrice}();
        //warp is used for stimulating the time passing in a blockchain
        vm.warp(block.timestamp + interval + 1);
        /*
        roll makes the chain add one or more block to the chain
        adding a roll is not necessary but is considered a good practice as it simulates the passing of time in a much more realistic manner as it will be followed up with the increase in block in a real chain.
        */
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.prank(s_demoPlayerAccount);
        vm.expectRevert(Raffle.Raffle__cannotEnterWhileCalculatingWinner.selector);
        raffle.enterRaffle{value: ticketPrice}();
    }

    function testSubscriptionIdIsSet() external {
        assert(helperConfig.getConfigByChainid().subscriptionId == 0);
        assert(raffle.getSubscriptionId() != 0);
    }

    function testPerformUpkeepIsNotDoneWhenCheckUpKeepConditionIsNotMet() external assignPlayer {
        raffle.enterRaffle{value: ticketPrice}();
        vm.prank(s_demoPlayerAccount);
        vm.expectRevert();
        raffle.performUpkeep("");
    }
}
