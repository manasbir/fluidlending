//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, ContextDefinitions, SuperAppDefinitions } from "../@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { IConstantFlowAgreementV1 } from "../@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import { CFAv1Library } from "../@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import { ISuperfluidToken } from "../@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluidToken.sol";
import { ISuperApp } from "../@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperApp.sol";

//standard aave-esque lending
contract BoilerplateLending {

    AggregatorV3Interface ETHprice;
    AggregatorV3Interface DAIprice;
    AggregatorV3Interface USDCprice;
    AggregatorV3Interface TUSDprice;

    ISuperToken ETHx;
    ISuperToken DAIx;
    ISuperToken USDCx;
    ISuperToken TUSDx;

    mapping (ISuperToken => uint) collateralToPercentage;//doesnt need to exist
    //uint example would be 1 for 100% ideally idk figure it out later
    mapping (ISuperToken => uint) borrowedAssetToPercentage; //only exists to know valid token lmfao
    //some sort of storage for what is valid collateral

    mapping (ISuperToken => AggregatorV3Interface) tokenToOracle;

    mapping (ISuperToken => uint) prices;

    

    ISuperToken[] private collateral;
    ISuperToken[] private borrowableTokens;
    ISuperToken[] private allValidTokens;

    struct CurrentLoans {
        uint _collateralAmount;
        uint _borrowedAmount;
        ISuperToken _collateral; //i want this to be an array but dont really know how
        ISuperToken _borrowed; // i want this to be an array also
        address _owner;
    }

    uint[] private loansAmount;

    mapping (address => uint) ownerToLoanNumber; //this doesn't allow users to take out multiple loans which is bad unless we make the struct use arrays and stuff

    CurrentLoans[] private loans;

    uint counterOfLoans = 0;

    constructor () {
        //address owner = msg.sender;

        //all the kovan addresses
        //kovan testnet addresses for tokens
        ETHprice = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        DAIprice = AggregatorV3Interface(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a);
        USDCprice = AggregatorV3Interface(0x9211c6b3BF41A10F78539810Cf5c64e1BB78Ec60);
        TUSDprice = AggregatorV3Interface(0x2ca5A90D34cA333661083F89D831f757A9A50148); //USDT oracle address for Koven testnet - didn't have TUSD/USD pair

        ETHx = ISuperToken(0xDD5462a7dB7856C9128Bc77Bd65c2919Ee23C6E1);
        DAIx = ISuperToken(0xe3CB950Cb164a31C66e32c320A800D477019DCFF);
        USDCx = ISuperToken(0x25B5cD2E6ebAedAa5E21d0ECF25A567EE9704aA7);
        TUSDx = ISuperToken(0xB20200908d60f1d7bc68594f677bC15070a87504);

        borrowedAssetToPercentage[ETHx] = 110;
        borrowedAssetToPercentage[DAIx] = 110;
        borrowedAssetToPercentage[USDCx] = 110;
        borrowedAssetToPercentage[TUSDx] = 110;

        tokenToOracle[ETHx] = ETHprice;
        tokenToOracle[DAIx] = DAIprice;
        tokenToOracle[USDCx] = USDCprice;
        tokenToOracle[TUSDx] = TUSDprice;
    }

    function checkSpecificPrice(ISuperToken _token) public view returns(uint) {
        AggregatorV3Interface priceOracle = tokenToOracle[_token];
        (,int price,,,) = priceOracle.latestRoundData();
        uint8 decimals = priceOracle.decimals();
        return (uint(price) / (10 ** uint256(decimals)));
    }


    function checkLiquidation(uint _index) public view returns(bool isLiquidatable){
        if (loans[_index]._borrowedAmount * prices[loans[_index]._borrowed] > loans[_index]._collateralAmount * (borrowedAssetToPercentage[loans[_index]._borrowed] / 100)) {
            isLiquidatable = true;

            return isLiquidatable; //now loan is liquidatable
        } else {
            return isLiquidatable = false;
        }
    }

    function liquidate(uint _loanNumber) external returns(bool) {
        address msgSender = msg.sender;

        bool canLiquidate = checkLiquidation(_loanNumber);

        require(canLiquidate == true, "why are you trying to liquidate a loan that is healthy???");

        uint liquidationAmount = loans[_loanNumber]._borrowedAmount * 100 / 105;

        require(loans[_loanNumber]._borrowed.balanceOf(msgSender) >= liquidationAmount, 'you dont have enough money');
        require(loans[_loanNumber]._borrowed.allowance(msgSender, address(this)) >= liquidationAmount, 'we dont have persmission to use your funds');
        
        loans[_loanNumber]._borrowed.transferFrom(msgSender, address(this), liquidationAmount);
        
        return true;
    }

    function borrow(ISuperToken _asset, uint _amount, ISuperToken _borrowedAsset, uint _amountBorrowed) public {
        address msgSender = address(msg.sender);

        require(_asset != _borrowedAsset, "you can't borrow the same token, silly goose");
        //require token to be applicable so we dont get useless shitcoins
        require(prices[_asset] != 0 && prices[_borrowedAsset] != 0, 'not valid tokens');
        
        require(_asset.balanceOf(address(msg.sender)) >= _amount, "you dont have enough tokens");
        require(_borrowedAsset.balanceOf(address(this)) >= _amountBorrowed, "we dont have enough of that token");

        uint priceOfAsset = checkSpecificPrice(_asset);
        uint priceOfBorrowedAsset = checkSpecificPrice(_borrowedAsset);

        uint worthOfCollateral = priceOfAsset * _amount;
        uint worthOfBorrowed = priceOfBorrowedAsset * _amountBorrowed;

        //checking if the loan is even possible
        require(worthOfBorrowed * borrowedAssetToPercentage[_borrowedAsset] / 100 >= worthOfCollateral, "you should add more collateral");

        //ISupertoken(_asset).approve(address(this), _amount);
        require(_asset.allowance(msgSender, address(this)) >= _amount, 'we need approval to use your tokens');
        _asset.transferFrom(msgSender, address(this), _amount);

        _asset.transfer(msgSender, _amountBorrowed);
        //interest adding function or whatever needs to be implemented

        loans.push(CurrentLoans(_amount, _amountBorrowed, _asset, _borrowedAsset, msg.sender)); //adds to db of current loans & super problamatic
        ownerToLoanNumber[msg.sender] = counterOfLoans;

        counterOfLoans++;
    }

    function fund(uint _amount) external {
        address msgSender = msg.sender;

        uint indexForLoan = ownerToLoanNumber[msg.sender];

        require(loans[indexForLoan]._collateral.allowance(msgSender, address(this)) >= _amount, 'we need approval to use your tokens');
        loans[indexForLoan]._collateral.transferFrom(msgSender, address(this), _amount);

        loans[indexForLoan]._collateralAmount += _amount;
    }

    function takeOutCollateral() external {
        address msgSender = msg.sender;

        uint _index = ownerToLoanNumber[msg.sender];

        require(loans[_index]._borrowed.balanceOf(msg.sender) >= loans[_index]._borrowedAmount && loans[_index]._collateral.balanceOf(msg.sender) >= loans[_index]._collateralAmount, "we may or may not have gone insolvent lmao");
        require(loans[_index]._borrowed.allowance(msgSender, address(this)) >= loans[_index]._borrowedAmount, 'we need approval to use your tokens');
        
        loans[_index]._borrowed.transferFrom(msgSender, address(this), loans[_index]._borrowedAmount);
        loans[_index]._collateral.transfer(msgSender, loans[_index]._collateralAmount);
    }

}