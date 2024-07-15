// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

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

    function testRefundOfExtraAmount() external {
        uint256 transactionAmt = 1000 ether;
        uint256 currentBalance = s_demoPlayerAccount.balance;

        console.log("Before");
        console.log(currentBalance);

        vm.prank(s_demoPlayerAccount);
        raffle.enterRaffle{value: transactionAmt}();

        console.log("After");
        console.log(s_demoPlayerAccount.balance);
        console.log(ticketPrice);

        assert(s_demoPlayerAccount.balance == currentBalance - ticketPrice);
    }

    function testCannotEnterRaffleWhenClosed() external assignPlayer {
        //warp is used for stimulating the time passing in a blockchain
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        /*
        roll makes the chain add one or more block to the chain
        adding a roll is not necessary but is considered a good practice as it simulates the passing of time in a much more realistic manner as it will be followed up with the increase in block in a real chain.
        */

        /**
         * The consumer id is for the contract that will recieve the random number, in this case it will be Raffle contract and we need to provide the consumer id
         */
        vm.prank(s_demoPlayerAccount);
        vm.expectRevert(Raffle.Raffle__cannotEnterWhileCalculatingWinner.selector);
        raffle.enterRaffle{value: ticketPrice}();
    }

    function testSubscriptionIdIsSet() external view {
        assert(raffle.getSubscriptionId() != 0);
    }

    function testPerformUpkeepIsNotDoneWhenCheckUpKeepConditionIsNotMet() external assignPlayer {
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 playerLength = 0;
        uint256 balance = 0;
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, raffleState, playerLength, balance)
        );
        raffle.performUpkeep("");
    }

    function testCheckUpkeepReturnsFalseInNotEnoughBalance() external {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckupKeepReturnsFalseWhenRaffleIsClosed() external assignPlayer {
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testConstructorForInitializingValues() external {
        assert(raffle.getTicketPrice() == ticketPrice);
        assert(raffle.getKeyHash() == gasLane);
        assert(raffle.getCallbackGasLimit() == callbackGasLimit);
        vm.prank(s_demoPlayerAccount);
        raffle.enterRaffle{value: ticketPrice}();
        assert(raffle.getRafflePlayers().length != 0);
    }

    function testCheckUpKeepReturnsTrueWhenParamsAreGood() external assignPlayer {
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    function testPerformUpKeepIsCalledWhenCheckUpKeepIsTrue() external assignPlayer {
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testRequestIdIsEmittedInWhenPerformUpKeepSuccessful() external assignPlayer {
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs(); //Records all the event emitted in an array!!!
        raffle.performUpkeep("");
        Vm.Log[] memory idEntries = vm.getRecordedLogs();
        bytes32 reqId = idEntries[1].topics[1];
        console.logUint(uint256(reqId));
        /**
         * The idEntry[0] is occupied by some event emitted from the vrfCoordinator contract and the topic[0] of every event is also some default value
         */
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.CLOSED);
        assert(uint256(reqId) != 0);
    }

    function testFulfilRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId) external assignPlayer {
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.expectRevert();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testCompleteContractEndToEnd() external assignPlayer {
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        uint256 partcipantNumber = 3;
        uint256 startingIndex = 1;
        address expectetedWinner = address(uint160(1));

        for (uint256 i = startingIndex; i < startingIndex + partcipantNumber; i++) {
            address tempPlayer = address(uint160(i));
            hoax(tempPlayer, 10 ether);
            raffle.enterRaffle{value: ticketPrice}();
        }

        uint256 expectetedWinnerStartingBalance = expectetedWinner.balance;
        uint256 startingTime = raffle.getTimeStamp();

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        console.logString("requestId :");
        console.logUint(uint256(requestId));

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 expectetedWinnerEndingBalance = expectetedWinner.balance;
        uint256 endingTime = raffle.getTimeStamp();
        uint256 prize = ticketPrice * (partcipantNumber + 1);

        assert(prize == expectetedWinnerEndingBalance - expectetedWinnerStartingBalance);
        assert(endingTime - startingTime > 0);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(recentWinner == expectetedWinner);
    }
}
