//SPDX-License-Idenfitier: MIT
pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/** @title A simple raffle contract written in solidity
 * @author Benhur P Benny
 * @notice You can use this contract to create a simple raffle, but it's only for learnign purposes and not production ready
 * @dev A contract for a simple raffle
 */

contract Raffle is VRFConsumerBaseV2Plus {
    //Errors
    error Raffle__InefficientFunds();

    uint256 private immutable i_ticketPrice;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    //Events
    event raffleEntered(address indexed player);

    constructor(
        uint256 _ticketPrice,
        uint256 _interval,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_ticketPrice = _ticketPrice;
        s_lastTimeStamp = block.timestamp;
        i_interval = _interval;
        vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    }

    function enterRaffle() external payable {
        /*
        This is more gas effiecient than using require, also in solditiy 0.8.26 we can use require with custom error messages but
        it is still more gas efficient to use revert with error and for using it we need to use a specific compiler.
        */
        if (msg.value < i_ticketPrice) {
            revert Raffle__InefficientFunds();
        }
        s_players.push(payable(msg.sender));
        emit raffleEntered(msg.sender);
        /*
        Whenever we update the storage we need to emit an event, I don't know why but it's a good practice and also I will look into the why part
        */
    }

    function getWinner() external view {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }

        // requestId = s_vrfCoordinator.requestRandomWords(
        //     VRFV2PlusClient.RandomWordsRequest({
        //         keyHash: keyHash,
        //         subId: s_subscriptionId,
        //         requestConfirmations: requestConfirmations,
        //         callbackGasLimit: callbackGasLimit,
        //         numWords: numWords,
        //         extraArgs: VRFV2PlusClient._argsToBytes(
        //             VRFV2PlusClient.ExtraArgsV1({
        //                 nativePayment: enableNativePayment
        //             })
        //         )
        //     })
        // );
    }

    //Getter functions
    function getTicketPrice() external view returns (uint256) {
        return i_ticketPrice;
    }
}
