//Raffle
//Enter the lottery (paying some amount)
//Pick a random winner (verifiably random)
//Winner to be selected every X minutes -> completly automated
//Chainlink Oracle -> Randomness, Automated Execution (Chainlink Keeper)

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
//12
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Raffle__NotEnoughETHEntered();//5
error Raffle__TransferFailed(); //17
error Raffle__NotOpen();//18
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);//19

contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type declarations */ //18
    enum RaffleState {
        OPEN,
        CALCULATING
    } //uint256 0 = OPEN, 1 = CALCULATING

    /* State variables*/
    //2 i_ cheap gas and user can see
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;//6
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; //14
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId; 
    uint16 private constant REQUEST_CONFIRMATIONS = 3; //constant
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1; //we only want 1 number for 1 winner only
   
    //16Lottery Variables
    address private s_recentWinner;
    //uint256 private s_state; //to pending, open, closed, calculatiog
    RaffleState private s_raffleState;//18
    uint256 private s_lastTimeStamp;//19
    uint256 private immutable i_interval;

    /* Events */
    //9
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    //3
    constructor(
        address vrfCoordinatorV2, 
        uint256 entranceFee, 
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2); //14
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    //1
    function enterRaffle() public payable {
        //5require(msg.value > i_entranceFee, "Not enough ETH!") below is new way save gas
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }
        //18
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        //8typecast it payable keep record people entry the raffle
        s_players.push(payable(msg.sender));
        //9Emit an event when we update a dynamic array or mapping
        //Named events with the function name reversed e.g RaffleEnter
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev this is the function that the chainlink keeper nodes call
     * they look for the `upkeepNeeded` to return true
     * the following should be true in order to return true:
     * 1. out time interval should have passed
     * 2. the lottery should have at least 1 player, and have some ETH
     * 3. our subscription is funded with link
     * 4.the lottery should be in an "open" state
     */
    function checkUpkeep(
        bytes memory //calldata /* checkData*/ 
    )   public 
        override 
        returns (
            bool upkeepNeeded, 
            bytes memory /* performData */
        )
    {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        //(block.timestamp - last block timestamp) > interval
    }
    //19 change this requestRandomWinner to performUpkeep
    function performUpkeep(bytes calldata /* performData */) external override{
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance, 
                s_players.length,
                uint256(s_raffleState)
            );
        }
        //10 request the random number
        //once we get it, do something with it
        //two transcation process //14
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //keyHash --> gaslane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    //11 fulfullrandomnumber //callbackgaslimit will block the request random number //15, 16
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}(""); //17 send $ to winner
        //require(success) use revert to save gas
        if(!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner); //17
    }

    //4
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    //7 input parameter storage variable s_players
    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    //16
    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    //19 code cleanup /** checkupkeep function will have 2 warnings, but good compiled file */
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
