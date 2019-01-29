pragma solidity ^0.5.0;

import "openzeppelin-eth/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";
import "zos-lib/contracts/Initializable.sol";
import "./MathUtils.sol";


/**
 * @title An Inflationary Token with Premint and Gradual Release
 */

contract InflationaryToken is Initializable, ERC20, Ownable, ERC20Mintable {

    event NewRound(uint256 round);
    event ParameterUpdate(string param);

    string public name;
    uint8 public decimals;
    string public symbol;
    string public version;
    uint256 public initialSupply;
    address public distributor;
    uint256 public initBlockReward;
    uint256 public halvingTime;
    uint256 public lastHalvingPeriod;
    uint256 public startBlock; // Block number at which the contract is deployed

    /**
     * @dev InflationaryToken constructor
     * @param _initialSupply Token supply to start off with - gets minted to the distributor on mintInitialSupply()
     * @param _distributor Address of person/contract that receives newly minted tokens
     * @param _initBlockReward Number of released inflationary tokens per block during the first period
     * @param _halvingTime Number of blocks after which reward halves (e.g. 2102400 for 1 year on Ethereum based on 15 seconds block time)
     * @param _lastHalvingPeriod Number of halvingTime periods after which the reward should stay constant
     */
    function initialize(
        string memory _name, 
        uint8 _decimals, 
        string memory _symbol, 
        string memory _version, 
        uint256 _initialSupply,
        address _distributor,
        uint256 _initBlockReward,
        uint256 _halvingTime,
        uint256 _lastHalvingPeriod
    )   public 
        initializer 
    {
        Ownable.initialize(_distributor);
        ERC20Mintable.initialize(_distributor);

        name = _name;
        decimals = _decimals;
        symbol = _symbol;
        version = _version;
        initialSupply = _initialSupply;
        distributor = _distributor;
        initBlockReward = _initBlockReward;
        halvingTime = _halvingTime;
        lastHalvingPeriod = _lastHalvingPeriod;
        startBlock = block.number;
    }

    /**
     * @dev Mint initial supply. 
            Can only be called by owner. // TODO: Can only be called once.
     */
    function mintInitialSupply() external {
        mint(distributor, initialSupply);
    }

    /**
     * @dev Calculate and mint the number of inflationary tokens from start to lastHalvingPeriod.
            Can only be called by owner. // TODO: Can only be called once.
     */
    function preMintInflation() public {
        uint256 totalRewards;
        uint256 blockReward = initBlockReward;

        for (uint i = 0; i < lastHalvingPeriod; i++) {
            totalRewards += blockReward * halvingTime;
            blockReward = blockReward.div(2);
        }
        mint(distributor, totalRewards);
    }

    // /**
    //  * @dev Initialize the current round. 
    //         Can only be called once per round.
    //  */
    // function initializeRound() external {
    //     uint256 currRound = currentRound();

    //     // Check if already called for the current round
    //     require(lastInitializedRound < currRound, "Current round already initialized");

    //     // Set current round as initialized
    //     lastInitializedRound = currRound;
    //     // Set active transcoders for the round

    //     // Set mintable rewards for the round
    //     setCurrentInflation();

    //     emit NewRound(currRound);
    // }

    /**
     * @dev Return current block number
     */
    function blockNum() public view returns (uint256) {
        return block.number;
    }

    /**
     * @dev Mock transaction to simulate change in block number for testing
     */
    function blockMiner() public {
        name = "NewName";
    }
}

