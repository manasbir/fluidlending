//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

//standard aave-esque lending
contract BoilerplateLending {
    //only DAI for wETH loan for now
    IERC20 DAI = IERC20(/* insert dai address */);
    IERC20 wETH = IERC20(/* insert wETH address */);
    //some sort of storage for what is valid collateral

    function loan(uint _borrowAmount, uint _collateralAmount) external {
        //require for healthfactor stuff eg require(_collateralAmount > _borrowAmount * 1.5, "not enough collateral");
        wETH.approve(address(this), _collateralAmount);
        wETH.transferFrom(msg.sender, address(this), _collateralAmount);

        DAI.transferFrom(address(this), msg.sender, _borrowAmount);

        //interest adding function or whatever
        //we need some way to liquidate or some way to set a loan to liquidatable
        //do we need to store all of our current loans in a struct/mapping
        //https://github.com/aave/protocol-v2/blob/master/contracts/protocol/lendingpool/LendingPool.sol
        //use ctrl + F _executeBorrow
    }

}