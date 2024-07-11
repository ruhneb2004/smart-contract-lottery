//SPDX-License-Idenfitier: MIT
pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A simple raffle contract written in solidity
 * @author Benhur P Benny
 * @notice You can use this contract to create a simple raffle, but it's only for learnign purposes and not production ready
 * @dev A contract for a simple raffle
 */
contract Raffle is VRFConsumerBaseV2Plus {
    //Errors
    error Raffle__InefficientFunds();
    error Raffle__UpkeepNotNeeded(uint256 isRaffleOpen, uint256 isIntervalCompleted, uint256 hasPlayers, uint256 hasEth);
    error Raffle__moneyTransferFailed();
    error Raffle__cannotEnterWhileCalculatingWinner();
    error Raffle__tranferExcessFundsCancelled(uint256 excessAmount);

    //type declarations
    enum RaffleState {
        OPEN, //0
        CLOSED //1

    }

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_ticketPrice;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    //Events
    event raffleEntered(address indexed player);
    event winnerPicked(address indexed winner, uint256 timeStamp);

    constructor(
        uint256 _ticketPrice,
        uint256 _interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_ticketPrice = _ticketPrice;
        s_lastTimeStamp = block.timestamp;
        i_interval = _interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        /*
        This is more gas effiecient than using require, also in solditiy 0.8.26 we can use require with custom error messages but
        it is still more gas efficient to use revert with error and for using it we need to use a specific compiler.
        */
        if (s_raffleState == RaffleState.CLOSED) {
            revert Raffle__cannotEnterWhileCalculatingWinner();
        }
        if (msg.value < i_ticketPrice) {
            revert Raffle__InefficientFunds();
        }
        if (msg.value > i_ticketPrice) {
            (bool success,) = payable(msg.sender).call{value: msg.value - i_ticketPrice}("");
            if (!success) {
                revert Raffle__tranferExcessFundsCancelled(msg.value - i_ticketPrice);
            }
        }
        s_players.push(payable(msg.sender));
        emit raffleEntered(msg.sender);
        /*
        Whenever we update the storage variable we need to emit an event, I don't know why but it's a good practice and also I will look into the why part
        */
    }

    /**
     * Below functions checkUpkeep and performUpkeep are part of the
     * chainlink automatation. The chainlink contract calls the checkUpkeep function at spceifed intervals to check whether the performUpKeep function needs to be called.
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        /**
         * @dev The checkupkeep function is used to check the given conditions and if the all of
         * them are true then we will assign upKeepNeeded to true. When the upKeepNeeded is true then it will call the
         * performUpKeep function and the desired function will be executed.
         * Conditions:
         * 1. If the raffle is closed then the upKeepNeeded will be false.
         * 2. If the time interval is not completed then the upKeepNeeded will be false.
         * 3. If the contract have some eth and also some players then the upKeepNeeded will be true.
         * 4. If your sunscription has some link then the upKeepNeeded will be true.
         * @return upKeepNeeded - It is a boolean value which is used to check whether the given conditions are true or not.
         */
        bool isRaffleOpen = (s_raffleState == RaffleState.OPEN);
        bool isIntervalCompleted = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasEth = address(this).balance > 0;
        upkeepNeeded = isRaffleOpen && isIntervalCompleted && hasPlayers && hasEth;
        return (upkeepNeeded, "");
    }

    //below function is used for performing the upkeep and also setting up the data for the vrf request.
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                uint256(s_raffleState), s_lastTimeStamp, s_players.length, address(this).balance
            );
        }

        s_raffleState = RaffleState.CLOSED;

        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
    }

    //Below function selects the winner and sends the money to the winner
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winnerAddress = s_players[winnerIndex];
        s_recentWinner = winnerAddress;
        (bool success,) = winnerAddress.call{value: address(this).balance}("");
        emit winnerPicked(s_recentWinner, s_lastTimeStamp);
        if (!success) {
            revert Raffle__moneyTransferFailed();
        }
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        //emit event as storage is updated!!!
    }

    //Getter functions
    function getTicketPrice() external view returns (uint256) {
        return i_ticketPrice;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getRafflePlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getSubscriptionId() external view returns (uint256) {
        return i_subscriptionId;
    }
}
