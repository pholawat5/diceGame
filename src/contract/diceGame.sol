pragma solidity ^0.6.6;

import 'https://github.com/smartcontractkit/chainlink/blob/develop/evm-contracts/src/v0.6/VRFConsumerBase.sol';

contract diceGame is VRFConsumerBase{
    
    bytes32 constant internal keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    address constant VRFC_address = 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B;
    address constant LINK_address = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    uint256 constant half = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
    
    event Withdraw(address admin, uint256 amount);
    event Received(address indexed sender, uint256 amount);
    event Result(uint256 id, uint256 bet, uint256 randomSeed, uint256 amount, address player, uint256 winAmount, uint256 randomResult, uint256 time);
    
    uint256 internal fee;
    uint256 public randomResult;
    bytes32 public reqId;
    
    uint256 public gameId;
    uint256 public lastGameId;
    address payable public admin;
    mapping(uint256 => Game) public games;
    
    struct Game {
        uint256 id;
        uint256 bet;
        uint256 seed;
        uint256 amount;
        address payable player;
    }
    
    modifier onlyAdmin(){
        require(msg.sender == admin,'This action is forbidden! (Admin Only)');
        _;
    }
    
    modifier onlyVRFC(){
        require(msg.sender == VRFC_address,'This action is forbidden! (VRFC Only)');
        _;
    }
    
    constructor()
        VRFConsumerBase(
            VRFC_address,
            LINK_address
        ) public
    {
        fee = 0.1 * 10 ** 18;
        admin = msg.sender;
    }
    
    function game(uint256 bet, uint256 seed) public payable returns (bool){
        require(bet <= 1,'Error, accept only 0 and 1');
        require(address(this).balance >= bet, 'Insufficient funds');
        games[gameId] = Game(gameId, bet, seed, msg.value, msg.sender);
        
        gameId = gameId + 1;
        
        getRandomNumber(seed);
        
        return true;
    }
    
    receive() external payable{
        emit Received(msg.sender, msg.value);
    }
    
    function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, 'Not enough LINK - send LINK to this contract to proceed');
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        reqId = requestId;
        
        verdict(randomResult);
    }
    
    function verdict(uint256 random) public payable onlyVRFC{
        for(uint i = lastGameId; i < gameId; i++){
            uint256 winAmount = 0;
            if((random >= half && games[i].bet == 1) || (random <= half && games[i].bet == 0)){
                winAmount = games[i].amount*2;
                games[i].player.transfer(winAmount);
            }
            emit Result(games[i].id, games[i].bet, games[i].seed, games[i].amount, games[i].player, winAmount, random, block.timestamp);
        }
        
        lastGameId = gameId;
    }
    
    function withdrawEther(uint256 amount) external payable onlyAdmin {
        require(address(this).balance >= amount, 'Insufficient Balance');
        admin.transfer(amount);
        emit Withdraw(admin, amount);
    }
    
    function withdrawLink(uint256 amount) external onlyAdmin{
        require(LINK.transfer(msg.sender, amount),'Error, unable to transfer');
    }
}