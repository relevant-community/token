pragma solidity ^0.5.0;

import "openzeppelin-eth/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";
import "zos-lib/contracts/Initializable.sol";
import "./MathUtils.sol";


/**
 * @title A General Inflationary Token
 */

contract InflationaryToken is Initializable, ERC20, Ownable, ERC20Mintable {

    event NewRound(uint256 round);
    event ParameterUpdate(string param);

    string public name;
    uint8 public decimals;
    string public symbol;
    string public version;
    uint256 public initialSupply;
    uint256 public inflationRate;
    address public distributor;
    uint256 public roundLength;
    // Current number of mintable tokens. Reset every round
    uint256 public currentMintableTokens;
    // Current number of minted tokens. Reset every round
    uint256 public currentMintedTokens;
    // Last initialized round. After first round, this is the last round during which initializeRound() was called
    uint256 public lastInitializedRound;
    // Block in which the contract is deployed
    uint256 public startBlock;

    /**
     * @dev InflationaryToken constructor
     * @param _initialSupply Token supply to start off with - gets minted to the distributor on mintInitialSupply()
     * @param _inflationRate Base inflation rate per round as a percentage of current total token supply (expressed in ppm)
     * @param _distributor Address of person/contract that receives newly minted tokens
     * @param _roundLength Round length in blocks
     */
    function initialize(
        string memory _name, 
        uint8 _decimals, 
        string memory _symbol, 
        string memory _version, 
        uint256 _inflationRate,
        uint256 _initialSupply,
        address _distributor,
        uint256 _roundLength
    )   public 
        initializer 
    {
        Ownable.initialize(_distributor);
        ERC20Mintable.initialize(_distributor);

        name = _name;
        decimals = _decimals;
        symbol = _symbol;
        version = _version;
        // Inflation must be valid percentage
        require(MathUtils.validPerc(_inflationRate), "Invalid inflation value");
        inflationRate = _inflationRate;
        initialSupply = _initialSupply;
        distributor = _distributor;
        roundLength = _roundLength;

        startBlock = block.number;
    }

    /**
     * @dev Mint initial supply. 
            Can only be called by owner.
     */
    function mintInitialSupply() external {
        mint(distributor, initialSupply);
    }

    /**
     * @dev Calculate and set the number of mintable tokens for the current round.
     */
    function setCurrentInflation() internal returns (uint256) {
        // At this point we can later dynamically adjust the inflation based e.g. on participation:
        // setInflation();

        // Set mintable tokens based on current inflation and current total token supply
        currentMintableTokens = MathUtils.percOf(totalSupply(), inflationRate);
        currentMintedTokens = 0;
    }

    /**
     * @dev Mint inflationary tokens for the round. 
            Can only be called by owner. 
            For now, all inflationary token of the current round get minted at once and go to the distributor.
            Later this could be called by the user to get the appropriate fraction of currentMintableTokens directly from the contract.
     */
    function mintCurrentInflation() public {
        mint(distributor, currentMintableTokens);
    }

    /**
     * @dev Initialize the current round. 
            Can only be called once per round.
     */
    function initializeRound() external {
        uint256 currRound = currentRound();

        // Check if already called for the current round
        require(lastInitializedRound < currRound, "Current round already initialized");

        // Set current round as initialized
        lastInitializedRound = currRound;
        // Set active transcoders for the round

        // Set mintable rewards for the round
        setCurrentInflation();

        emit NewRound(currRound);
    }

    /**
     * @dev Return current round
     */
    function currentRound() public view returns (uint256) {
        // Compute # of rounds since start (div truncates quotient)
        uint256 roundsSinceStart = blockNum().sub(startBlock).div(roundLength);
        return roundsSinceStart;
    }

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

