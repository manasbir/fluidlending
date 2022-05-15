//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


//standard aave-esque lending
contract BoilerplateLending {

    AggregatorV3Interface public priceFeed;
    AggregatorV3Interface ETHprice;
    AggregatorV3Interface DAIprice;
    AggregatorV3Interface USDCprice;
    AggregatorV3Interface LINKprice;

    struct TokenPrice{ address AggregatorV3Interface; uint price; }
    TokenPrice[] tokenPrices;

    mapping (address => uint) collateralToPercentage;
    //uint example would be 1 for 100% ideally idk figure it out later
    mapping (address => uint) borrowedAssetToPercentage;
    //some sort of storage for what is valid collateral
    mapping (address => TokenPrice) public tokenToPrice;

    mapping (IERC20 => AggregatorV3Interface) tokenPrice;

    IERC20[] public collateral;
    IERC20[] public borrowableTokens;
    IERC20[] public allValidTokens;

    uint[] public prices;

    struct CurrentLoans {
        uint _collateralAmount;
        uint _borrowedAmount;
        address _collateral;
        address _borrowed;
        address _owner;
    }

    CurrentLoans[] public loans;

    constructor () {
        address owner = msg.sender;
        //all the kovan addresses
        ETHprice = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        DAIprice = AggregatorV3Interface(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a);
        USDCprice = AggregatorV3Interface(0x396c5E36DD0a0F5a5D33dae44368D4193f69a1F0);
        LINKprice = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        tokenToPrice[0xFab46E002BbF0b4509813474841E0716E6730136] = TokenPrice(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a, 0); //this is a bullshit token i got from a faucet lmao
    }

    function checkPrices(IERC20 token) public view returns(uint[] memory) {
        uint lengthOfValidTokens = allValidTokens.length;
        for (uint i; i < lengthOfValidTokens; i++) {
            AggregatorV3Interface priceOracle = tokenPrice[allValidTokens[i]];
            (,int price,,,) = priceOracle.latestRoundData();
            uint8 decimals = priceOracle.decimals();
            uint priceOfToken =  uint(price) / decimals;
            
        }
        return priceOfToken;




       /*  //we want iterable data type for our addresses
        AggregatorV3Interface priceOracle = tokenPrice[token];
        (,int price,,,) = priceOracle.latestRoundData();
        uint8 decimals = priceOracle.decimals();
        uint priceOfToken =  uint(price) / decimals;
        return(priceOfToken); */
    }


    function checkLiquidation() public view returns(bool isLiquidatable, address owner){
        for (uint i; i < loans.length; i++){
            //check if loan is liquidatable then emit even or something idk
            if (loans[i]._borrowedAmount > loans[i]._collateralAmount * 1 /* healthfactor we somehow determine GET THE ORACLE STUFF IMPLEMENTED */) {
                return (isLiquidatable, owner); //now loan is liquidatable
            }
        }
    }

    function borrow(address _asset, uint _amount, address _borrowedAsset, uint _amountBorrowed) external {
        //require token to be applicable so we dont get useless shitcoins
        require(collateralToPercentage[_asset] != 0 && borrowedAssetToPercentage[_borrowedAsset] != 0, 'not valid tokens');
        //require(condition);
        //uint collateralRatio = collateralToPercentage[_collateralToken] * 100; // x100 for percentage

        //averages the two collateral ratios seems kinda dumb imo, but idk wht to do
        uint borrowRatio = (collateralToPercentage[_asset] + borrowedAssetToPercentage[_borrowedAsset]) / 2;


        //checking if the loan is even possible
        require(_amountBorrowed >= _amount * borrowRatio);
        require(IERC20(_asset).balanceOf(address(this)) >= _amount);

        IERC20(_asset).approve(address(this), _amount);
        IERC20(_asset).transferFrom(msg.sender, address(this), _amount);



        IERC20(_asset).transfer(msg.sender, _amountBorrowed);
        //interest adding function or whatever needs to be implemented

        //https://github.com/aave/protocol-v2/blob/master/contracts/protocol/lendingpool/LendingPool.sol
        //use ctrl + F _executeBorrow
        loans.push(CurrentLoans(_amount, _amountBorrowed, _asset, _borrowedAsset, msg.sender)); //adds to db of current loans
        (bool liquidationStatus, address owner) = checkLiquidation(); //no gas so worth adding after every function!

    }



}