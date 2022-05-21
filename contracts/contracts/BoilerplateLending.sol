//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


//standard aave-esque lending
contract BoilerplateLending {

    AggregatorV3Interface public priceFeed;
    AggregatorV3Interface ETHprice;
    AggregatorV3Interface DAIprice;
    AggregatorV3Interface USDCprice;
    AggregatorV3Interface TUSDprice;

    struct TokenPrice{ address AggregatorV3Interface; uint price; }
    TokenPrice[] tokenPrices;



    mapping (IERC20 => uint) collateralToPercentage;//doesnt need to exist
    //uint example would be 1 for 100% ideally idk figure it out later
    mapping (IERC20 => uint) borrowedAssetToPercentage; //only exists to know valid token lmfao
    //some sort of storage for what is valid collateral
    mapping (address => TokenPrice) public tokenToStruct;

    mapping (IERC20 => AggregatorV3Interface) tokenToOracle;

    mapping (IERC20 => uint) prices;

    

    IERC20[] public collateral;
    IERC20[] public borrowableTokens;
    IERC20[] public allValidTokens;

    struct CurrentLoans {
        uint _collateralAmount;
        uint _borrowedAmount;
        IERC20 _collateral; //i want this to be an array but dont really know how
        IERC20 _borrowed; // i want this to be an array also
        address _owner;
    }

    uint[] public loansAmount;

    mapping (address => uint) ownerToLoanNumber; //this doesn't allow users to take out multiple loans which is bad unless we make the struct use arrays and stuff

    CurrentLoans[] public loans;

    uint counterOfLoans = 0;

    constructor () {
        address owner = msg.sender;
        //all the kovan addresses
        ETHprice = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        DAIprice = AggregatorV3Interface(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a);
        USDCprice = AggregatorV3Interface(0x9211c6b3BF41A10F78539810Cf5c64e1BB78Ec60);
        TUSDprice = AggregatorV3Interface(0x2ca5A90D34cA333661083F89D831f757A9A50148); //USDT oracle address for Koven testnet - didn't have TUSD/USD pair

        tokenToStruct[0xDD5462a7dB7856C9128Bc77Bd65c2919Ee23C6E1] = TokenPrice(0x9326BFA02ADD2366b30bacB125260Af641031331, 0); //this is a bullshit token i got from a faucet lmao
        tokenToStruct[0xe3CB950Cb164a31C66e32c320A800D477019DCFF] = TokenPrice(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a, 0);
        tokenToStruct[0x25B5cD2E6ebAedAa5E21d0ECF25A567EE9704aA7] = TokenPrice(0x9211c6b3BF41A10F78539810Cf5c64e1BB78Ec60, 0);
        tokenToStruct[0xB20200908d60f1d7bc68594f677bC15070a87504] = TokenPrice(0x2ca5A90D34cA333661083F89D831f757A9A50148, 0);
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

        //checkLiquidation();
    }

    function checkSpecificPrice(IERC20 token) public view returns(uint) {
        AggregatorV3Interface priceOracle = tokenToOracle[token];
        (,int price,,,) = priceOracle.latestRoundData();
        uint8 decimals = priceOracle.decimals();
        uint priceOfToken =  uint(price) / decimals;
        return priceOfToken;
    }


    function checkLiquidation(uint _index) public view returns(bool isLiquidatable, address owner, uint loanNumber){
        if (loans[_index]._borrowedAmount * prices[loans[_index]._borrowed] > loans[_index]._collateralAmount * collateralToPercentage[loans[_index]._collateral]) {
            isLiquidatable = true;

            return (isLiquidatable, owner, _index); //now loan is liquidatable
        } else {
            return (isLiquidatable = false, owner, _index);
        }
    }

    function liquidate(uint loanNumber, uint _amount, IERC20 token) external returns(bool) {

    }

    function borrow(IERC20 _asset, uint _amount, IERC20 _borrowedAsset, uint _amountBorrowed) external {
        refreshPrices();
        address msgSender = address(msg.sender);

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
        require(IERC20(_asset).balanceOf(address(this)) >= _amount);

        IERC20(_asset).approve(address(this), _amount);
        IERC20(_asset).transferFrom(msgSender, address(this), _amount);



        IERC20(_asset).transfer(msgSender, _amountBorrowed);
        //interest adding function or whatever needs to be implemented

        //https://github.com/aave/protocol-v2/blob/master/contracts/protocol/lendingpool/LendingPool.sol
        //use ctrl + F _executeBorrow
        loans.push(CurrentLoans(_amount, _amountBorrowed, _asset, _borrowedAsset, msg.sender)); //adds to db of current loans
        ownerToLoanNumber[msg.sender] = counterOfLoans;
        
        //(bool liquidationStatus,, uint loanNumber) = checkLiquidation(); //no gas so worth adding after every function!

        //if (liquidationStatus == true) {
            //liquidate the loan or emit an event to liquidate
            //liquidate(x, x, x);
       // }


        counterOfLoans++;
    }

    function fund(IERC20 _asset, uint _amount) external {
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