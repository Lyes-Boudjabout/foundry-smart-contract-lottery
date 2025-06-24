// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { VRFConsumerBaseV2Plus } from "@chainlink/contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import { VRFV2PlusClient } from "@chainlink/contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import { AutomationCompatibleInterface } from "@chainlink/contracts/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A sample Raffle Contract
 * @author Lyes Boudjabout
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF V2.5 and Custom Logic Automation
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /** Errors */
    error Raffle__NotEnoughETH();
    error Raffle__NotEnoughTimePassed();
    error Raffle__TransferFailed();
    error Raffle__NotEnoughPlayersToPlay();
    error Raffle__CantEnterInCalcPhase();
    error Raffle__UpkeepConditionUnsatisfied(uint256 contractBalance, uint8 raffleState, uint256 numberOfPlayers);

    /** Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    
    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;
    mapping(uint256 => address payable[]) private s_requestIdToPlayers;

    /** Events */
    event RaffleEntry(address indexed player);
    event WinnerSelected(address payable indexed winner);

    /** Functions */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETH();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__CantEnterInCalcPhase();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntry(msg.sender);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        //restore the array of players from the mapping
        address payable[] memory m_players = s_requestIdToPlayers[requestId];
        if (m_players.length == 0) {
            revert Raffle__NotEnoughPlayersToPlay();
        }

        //Get the winner
        uint256 indexOfWinner = randomWords[0] % m_players.length;
        s_recentWinner = m_players[indexOfWinner];

        //send the contract balance to the winner
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerSelected(s_recentWinner);

        //Resetting the players array
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        //Reopening the raffle
        s_raffleState = RaffleState.OPEN;
    }

    /**
     * @dev this function is used by automation service to check trigger conditions
     * @return upkeepNeeded
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded ,"");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool success,) = checkUpkeep('');
        if (!success) {
            revert Raffle__UpkeepConditionUnsatisfied(address(this).balance, uint8(s_raffleState), s_players.length);
        }

        //changing the state of the raffle
        s_raffleState = RaffleState.CALCULATING;

        //sending the request to get a random number
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        s_requestIdToPlayers[requestId] = s_players;
    }

    /** Getter Functions */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
    
    function getInterval() external view returns (uint256) {
        return i_interval;
    }
    
    function getKeyHash() external view returns (bytes32) {
        return i_keyHash;
    }
    
    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address payable) {
        return s_recentWinner;
    }
    
    function getPlayerById(uint256 id) external view returns (address payable) {
        return s_players[id];
    }

    function getSubscriptionId() external view returns (uint256) {
        return i_subscriptionId;
    }

    function getRequestConfirmationsNumber() external pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }

    function getNumWords() external pure returns (uint16) {
        return NUM_WORDS;
    }

    function getCallbackGasLimit() external view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }
}
