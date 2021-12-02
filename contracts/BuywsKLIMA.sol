// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IStakingHelper.sol";
import "../interfaces/IwsKLIMA.sol";

contract BuywsKLIMA {
    constructor(
        address _USDC,
        address _BCT,
        address _KLIMA,
        address _sKLIMA,
        address _wsKLIMA,
        address _staking,
        address _sushi_router
    ) {
        USDC = _USDC;
        BCT = _BCT;
        KLIMA = _KLIMA;
        sKLIMA = _sKLIMA;
        wsKLIMA = _wsKLIMA;
        staking = _staking;
        sushi_router = _sushi_router;
    }

    address public USDC;
    address public BCT;
    address public KLIMA;
    address public sKLIMA;
    address public wsKLIMA;
    address public staking;
    //address public gOHM;

    address public sushi_router;

    function buyKLIMAwithUSDC(uint256 _amount, uint256 _maxSlippage) public {
        // Swap from USDC to KLIMA through BCT

        address[] memory path = new address[](3);

        path[0] = USDC;
        path[1] = BCT;
        path[2] = KLIMA;

        uint256[] memory minOut = IUniswapV2Router02(sushi_router)
            .getAmountsOut(_amount, path);

        IERC20(USDC).transferFrom(msg.sender, address(this), _amount);

        IERC20(USDC).approve(sushi_router, _amount);

        IUniswapV2Router02(sushi_router).swapExactTokensForTokens(
            _amount,
            (minOut[2] * (1000 - _maxSlippage)) / 1000,
            path,
            address(this),
            block.timestamp
        );

        // Stake the KLIMA

        IERC20(KLIMA).approve(staking, IERC20(KLIMA).balanceOf(address(this)));

        IStakingHelper(staking).stake(IERC20(KLIMA).balanceOf(address(this)));

        // Wrap the sKLIMA

        IERC20(sKLIMA).approve(
            wsKLIMA,
            IERC20(sKLIMA).balanceOf(address(this))
        );

        IwsKLIMA(wsKLIMA).wrap(IERC20(sKLIMA).balanceOf(address(this)));

        // Send the wsKLIMA back to sender

        IERC20(wsKLIMA).transfer(
            msg.sender,
            IERC20(wsKLIMA).balanceOf(address(this))
        );
    }
}
