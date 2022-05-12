//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

//standard aave-esque lending
contract BoilerplateLending {
    mapping (address => uint) collateralToPercentage;
    //uint example would be 1 for 100% ideally idk figure it out later
    mapping (address => uint) borrowedAssetToPercentage;
    //some sort of storage for what is valid collateral

    struct CurrentLoans {
        uint _collateralAmount;
        uint _borrowedAmount;
        address _collateral;
        address _borrowed;
        address _owner;
    }

    CurrentLoans[] public loans;


    function checkLiquidation() public view returns(bool isLiquidatable, address owner){
        for (uint i; i < loans.length; i++){
            //check if loan is liquidatable then emit even or something idk
            CurrentLoans[] memory loan;
            if (loan[i]._borrowedAmount > loan[i]._collateralAmount * /* healthfactor we somehow determine GET THE ORACLE STUFF IMPLEMENTED */) {
                return (isLiquidatable, owner); //now loan is liquidatable
            }
        }
    }

    function borrow(address _asset, uint _amount, address _borrowedAsset, uint _amountBorrowed) external {
        //require for healthfactor stuff eg require(_collateralAmount > _borrowAmount * 1.5, "not enough collateral");
        //require token to be applicable so we dont get useless shitcoins
        require(collateralToPercentage[_asset] != 0 && borrowedAssetToPercentage[_borrowedAsset] != 0);
        //uint collateralRatio = collateralToPercentage[_collateralToken] * 100; // x100 for percentage

        //averages the two collateral ratios seems kinda dumb imo, but idk wht to do
        uint borrowRatio = (collateralToPercentage[_asset] + borrowedAssetToPercentage[_borrowedAsset]) / 2;


        //checking if the loan is even possible
        require(_amountBorrowed >= _amount * borrowRatio);
        require(IERC20(_asset).balanceOf(address(this)) >= _amount);

        IERC20(_asset).approve(address(this), _amount);
        IERC20(_asset).transferFrom(msg.sender, address(this), _amount);



        IERC20(_asset).transfer(msg.sender, _amountBorrowed);
        //interest adding function or whatever
        //we need some way to liquidate or some way to set a loan to liquidatable
        //do we need to store all of our current loans in a struct/mapping??
        //https://github.com/aave/protocol-v2/blob/master/contracts/protocol/lendingpool/LendingPool.sol
        //use ctrl + F _executeBorrow
        loans.push(CurrentLoans(_amount, _amountBorrowed, _asset, _borrowedAsset, msg.sender));
        checkLiquidation(); //no gas so worth adding after every function!

    }



}