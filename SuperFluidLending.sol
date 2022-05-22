//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {     ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, ContextDefinitions, SuperAppDefinitions } from "../@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { IConstantFlowAgreementV1 } from "../@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import { CFAv1Library } from "../@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import { ISuperfluidToken } from "../@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluidToken.sol";
import { ISuperApp } from "../@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperApp.sol";
//import {  } from ;
//only using CFA


contract SuperfluidLending{

    using CFAv1Library for CFAv1Library.InitData;

    //initialize cfaV1 variable
    CFAv1Library.InitData public cfaV1;

    AggregatorV3Interface ETHprice;
    AggregatorV3Interface DAIprice;
    AggregatorV3Interface USDCprice;
    AggregatorV3Interface TUSDprice;

    ISuperfluidToken ETHx;
    ISuperfluidToken DAIx;
    ISuperfluidToken USDCx;
    ISuperfluidToken TUSDx;
    
    

    struct TokenPrice{ address AggregatorV3Interface; uint price; }
    TokenPrice[] tokenPrices;



    mapping (ISuperfluidToken => uint) collateralToPercentage;//doesnt need to exist
    //uint example would be 1 for 100% ideally idk figure it out later
    mapping (ISuperfluidToken => uint) borrowedAssetToPercentage;
    //some sort of storage for what is valid collateral
    mapping (address => TokenPrice) public tokenToStruct;

    mapping (ISuperfluidToken => AggregatorV3Interface) tokenToOracle;

    mapping (ISuperfluidToken => uint) prices;

    

    ISuperfluidToken[] public collateral;
    ISuperfluidToken[] public borrowableTokens;
    ISuperfluidToken[] public allValidTokens;

    struct CurrentLoans {
        uint _collateralAmount;
        uint _borrowedAmount;
        ISuperfluidToken _collateral; //i want this to be an array but dont really know how
        ISuperfluidToken _borrowed; // i want this to be an array also
        address _owner;
    }

    uint[] public loansAmount;

    mapping (address => uint) ownerToLoanNumber; //this doesn't allow users to take out multiple loans which is bad unless we make the struct use arrays and stuff

    CurrentLoans[] public loans;

    uint counterOfLoans = 0;

    constructor (ISuperfluid host) {
        //cfa = IConstantFlowAgreementV1(0xF4C5310E51F6079F601a5fb7120bC72a70b96e2A);

        address owner = msg.sender;

        cfaV1 = CFAv1Library.InitData(
            host,
            IConstantFlowAgreementV1(
                address(
                    host.getAgreementClass(
                        keccak256(
                            "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
                        )
                    )
                )
            )
        );

        // by default, all 6 callbacks defined in the ISuperApp interface
        // are forwarded to a SuperApp.
        // If you inherit from SuperAppBase, there's a default implementation
        // for each callback which will revert.
        // Developers will want to avoid reverting in Super App callbacks, 
        // In particular, you want to avoid reverting within the termination callback
        // (see rules below regarding the termination callback for more info)
        // you need to make sure only those actually implemented (overridden)
        // are ever invoked. That's achieved by setting the _NOOP flag for those
        // callbacks which you don't need and didn't implement.
        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        // can be an empty string in dev or testnet deployments
        string memory registrationKey = "";

        host.registerAppWithKey(configWord, registrationKey);

        //all the kovan addresses
        //kovan testnet addresses for tokens
        ETHprice = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        DAIprice = AggregatorV3Interface(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a);
        USDCprice = AggregatorV3Interface(0x9211c6b3BF41A10F78539810Cf5c64e1BB78Ec60);
        TUSDprice = AggregatorV3Interface(0x2ca5A90D34cA333661083F89D831f757A9A50148); //USDT oracle address for Koven testnet - didn't have TUSD/USD pair

        tokenToStruct[0xDD5462a7dB7856C9128Bc77Bd65c2919Ee23C6E1] = TokenPrice(0x9326BFA02ADD2366b30bacB125260Af641031331, 0); //this is a bullshit token i got from a faucet lmao
        tokenToStruct[0xe3CB950Cb164a31C66e32c320A800D477019DCFF] = TokenPrice(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a, 0);
        tokenToStruct[0x25B5cD2E6ebAedAa5E21d0ECF25A567EE9704aA7] = TokenPrice(0x9211c6b3BF41A10F78539810Cf5c64e1BB78Ec60, 0);
        tokenToStruct[0xB20200908d60f1d7bc68594f677bC15070a87504] = TokenPrice(0x2ca5A90D34cA333661083F89D831f757A9A50148, 0);

        ETHx = ISuperfluidToken(0xDD5462a7dB7856C9128Bc77Bd65c2919Ee23C6E1);
        DAIx = ISuperfluidToken(0xe3CB950Cb164a31C66e32c320A800D477019DCFF);
        USDCx = ISuperfluidToken(0x25B5cD2E6ebAedAa5E21d0ECF25A567EE9704aA7);
        TUSDx = ISuperfluidToken(0xB20200908d60f1d7bc68594f677bC15070a87504);

        
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

        checkLiquidation(); //finsihi this
    }

    function checkSpecificPrice(ISuperfluidToken token) public view returns(uint) {
        AggregatorV3Interface priceOracle = tokenToOracle[token];
        (,int priceAGAIN,,,) = priceOracle.latestRoundData();
        uint8 decimals = priceOracle.decimals();
        uint priceOfToken =  uint(priceAGAIN) / decimals;
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

    function liquidate(uint loanNumber, uint _amount, ISuperfluid _token) external returns(bool) {
        refreshPrices();
        //fill this out
    }

    function borrow(ISuperfluidToken _asset, uint _amount, ISuperfluidToken _borrowedAsset, uint _amountBorrowed, uint howLongTheStreamShouldLastInSeconds) external {
        refreshPrices();
        address msgSender = address(msg.sender);
        uint flowRate = _amount / howLongTheStreamShouldLastInSeconds;
        uint borrowFlowRate = _amountBorrowed / howLongTheStreamShouldLastInSeconds;

        require(_asset != _borrowedAsset, "you can't borrow the same token, silly goose");
        //require token to be applicable so we dont get useless shitcoins
        require(prices[_asset] != 0 && prices[_borrowedAsset] != 0, 'not valid tokens');

        (int msgSenderBalance,,,) = _asset.realtimeBalanceOfNow(msgSender);
        (int ourBalance,,,) = _borrowedAsset.realtimeBalanceOfNow(address(this));
        
        require(uint(msgSenderBalance) >= _amount);
        require(uint(ourBalance) >= _amountBorrowed);

        uint worthOfCollateral = checkSpecificPrice(_asset) * _amount;
        uint worthOfBorrowed = checkSpecificPrice(_borrowedAsset) * _amountBorrowed;

        uint borrowRatio = (borrowedAssetToPercentage[_borrowedAsset]);

        require(worthOfBorrowed >= worthOfCollateral * borrowRatio);
        //uint collateralRatio = collateralToPercentage[_collateralToken] * 100; // x100 for percentage

        //cfaV1.updateFlowOperatorPermissions(_borrowedAsset, msgSender, 6, _amountBorrowed);

        //IERC20(_asset).approve(address(this), _amount);
        //ISuperfluidToken(_asset).transferFrom(msgSender, address(this), _amount);

        //ISuperfluidToken(_asset).transfer(msgSender, _amountBorrowed);
        cfaV1.createFlow(msgSender, _asset, int96(int(flowRate)));

        //cfaV1.createFlow(msgSender, _borrowedAsset, int96(int(borrowFlowRate)));


        //interest adding function or whatever needs to be implemented

        //https://github.com/aave/protocol-v2/blob/master/contracts/protocol/lendingpool/LendingPool.sol
        //use ctrl + F _executeBorrow
        loans.push(CurrentLoans(_amount, _amountBorrowed, _asset, _borrowedAsset, msg.sender)); //adds to db of current loans
        ownerToLoanNumber[msg.sender] = counterOfLoans;
        
        (bool liquidationStatus,,) = checkLiquidation(); //no gas so worth adding after every function!

        if (liquidationStatus == true) {
            //liquidate the loan or emit an event to liquidate
        }


        counterOfLoans++;
    }

    function fund(ISuperfluidToken _asset, uint _amount) external {
        refreshPrices();

        require(prices[_asset] != 0);

        uint priceOfAsset = checkSpecificPrice(_asset); //might not be relevant

        uint indexForLoan = ownerToLoanNumber[msg.sender];

        require(loans[indexForLoan]._collateral == _asset);
//        require(_asset.balanceOf(msg.sender) >= _amount);

        //_asset.approve(address(this), _amount);
        //_asset.transferFrom(msg.sender, address(this), _amount);

        loans[indexForLoan]._collateralAmount += _amount;


    }

    function takeOutCollateral() external {
        refreshPrices();


    }
}