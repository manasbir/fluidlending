//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { ISuperfluid } from "./@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { IConstantFlowAgreementV1 } from "./@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
//import { IInstantDistributionAgreementV1 } from "../node_modules/@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";

//only using CFA
contract SuperfluidLending {
    AggregatorV3Interface public priceFeed;
    AggregatorV3Interface ETHprice;
    AggregatorV3Interface DAIprice;
    AggregatorV3Interface USDCprice;
    AggregatorV3Interface price;

    struct TokenPrice{ address AggregatorV3Interface; uint price; }
    TokenPrice[] tokenPrices;



    mapping (ISuperfluid => uint) collateralToPercentage;//doesnt need to exist
    //uint example would be 1 for 100% ideally idk figure it out later
    mapping (ISuperfluid => uint) borrowedAssetToPercentage;
    //some sort of storage for what is valid collateral
    mapping (address => TokenPrice) public tokenToStruct;

    mapping (ISuperfluid => AggregatorV3Interface) tokenToOracle;

    mapping (ISuperfluid => uint) prices;

    

    ISuperfluid[] public collateral;
    ISuperfluid[] public borrowableTokens;
    ISuperfluid[] public allValidTokens;

    struct CurrentLoans {
        uint _collateralAmount;
        uint _borrowedAmount;
        ISuperfluid _collateral; //i want this to be an array but dont really know how
        ISuperfluid _borrowed; // i want this to be an array also
        address _owner;
    }

    uint[] public loansAmount;

    mapping (address => uint) ownerToLoanNumber; //this doesn't allow users to take out multiple loans which is bad unless we make the struct use arrays and stuff

    CurrentLoans[] public loans;

    uint counterOfLoans = 0;

    constructor () {
        address owner = msg.sender;

        ISuperfluid ETHx;
        ISuperfluid DAIx;
        ISuperfluid USDCx;
        ISuperfluid MATICx;

        //all the kovan addresses
        ETHprice = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        DAIprice = AggregatorV3Interface(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a);
        USDCprice = AggregatorV3Interface(0x396c5E36DD0a0F5a5D33dae44368D4193f69a1F0);
        LINKprice = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        tokenToStruct[0xFab46E002BbF0b4509813474841E0716E6730136] = TokenPrice(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a, 0); //this is a bullshit token i got from a faucet lmao
    }

    function refreshPrices() public {
        uint lengthOfValidTokens = allValidTokens.length;
        for (uint i; i < lengthOfValidTokens; i++) {
            AggregatorV3Interface priceOracle = tokenToOracle[allValidTokens[i]];
            (,int price,,,) = priceOracle.latestRoundData();
            uint8 decimals = priceOracle.decimals();
            uint priceOfToken =  uint(price) / decimals;
            prices[allValidTokens[i]] = priceOfToken;
        }

        checkLiquidation();
    }

    function checkSpecificPrice(IERC20 token) public view returns(uint) {
        AggregatorV3Interface priceOracle = tokenToOracle[token];
        (,int price,,,) = priceOracle.latestRoundData();
        uint8 decimals = priceOracle.decimals();
        uint priceOfToken =  uint(price) / decimals;
        return priceOfToken;
    }


    function checkLiquidation() public view returns(bool isLiquidatable, address owner, uint loanNumber){
        for (uint i; i < loans.length; i++){
            //check if loan is liquidatable then emit even or something idk
            if (loans[i]._borrowedAmount * prices[loans[i]._borrowed] > loans[i]._collateralAmount * collateralToPercentage[loans[i]._collateral]) {
                isLiquidatable = true;

                return (isLiquidatable, owner, i); //now loan is liquidatable
            }
        }
    }

    function liquidate(uint loanNumber, uint _amount, IERC20 token) external returns(bool) {

    }

    function borrow(ISuperfluid _asset, uint _amount, ISuperfluid _borrowedAsset, uint _amountBorrowed) external {
        refreshPrices();

        require(_asset != _borrowedAsset, "you can't borrow the same token, silly goose");
        //require token to be applicable so we dont get useless shitcoins
        require(prices[_asset] != 0 && prices[_borrowedAsset] != 0, 'not valid tokens');
        
        require(_asset.balanceOf(address(msg.sender)) >= _amount);
        require(_borrowedAsset.balanceOf(address(this)) >= _amountBorrowed);

        uint priceOfAsset = checkSpecificPrice(_asset);
        uint priceOfBorrowedAsset = checkSpecificPrice(_borrowedAsset);

        uint worthOfCollateral = priceOfAsset * _amount;
        uint worthOfBorrowed = priceOfBorrowedAsset * _amountBorrowed;
        //uint collateralRatio = collateralToPercentage[_collateralToken] * 100; // x100 for percentage

        //might not be necessary
        uint borrowRatio = (borrowedAssetToPercentage[_borrowedAsset]);


        //checking if the loan is even possible
        require(worthOfBorrowed >= worthOfCollateral * borrowRatio);
        require(_asset.balanceOf(address(this)) >= _amount);

/*         _asset.approve(address(this), _amount);
        _asset.transferFrom(msg.sender, address(this), _amount);



        _asset.transfer(msg.sender, _amountBorrowed); */
        //interest adding function or whatever needs to be implemented

        //https://github.com/aave/protocol-v2/blob/master/contracts/protocol/lendingpool/LendingPool.sol
        //use ctrl + F _executeBorrow
        loans.push(CurrentLoans(_amount, _amountBorrowed, _asset, _borrowedAsset, msg.sender)); //adds to db of current loans
        ownerToLoanNumber[msg.sender] = counterOfLoans;
        
        (bool liquidationStatus,, uint loanNumber) = checkLiquidation(); //no gas so worth adding after every function!

        if (liquidationStatus == true) {
            //liquidate the loan or emit an event to liquidate
        }


        counterOfLoans++;
    }

    function fund(ISuperfluid _asset, uint _amount) external {
        refreshPrices();

        require(prices[_asset] != 0);

        uint priceOfAsset = checkSpecificPrice(_asset); //might not be relevant

        uint indexForLoan = ownerToLoanNumber[msg.sender];

        require(loans[indexForLoan]._collateral == _asset);
        require(_asset.balanceOf(msg.sender) >= _amount);

        _asset.approve(address(this), _amount);
        _asset.transferFrom(msg.sender, address(this), _amount);

        loans[indexForLoan]._collateralAmount += _amount;


    }

    function takeOutCollateral() external {
        refreshPrices();


    }
}