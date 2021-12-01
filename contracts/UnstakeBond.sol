// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../interfaces/IStaking.sol";
import "../interfaces/IBondDepository.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IERC20.sol";

contract UnstakeBond {
    constructor(
        address _staking,
        address _KLIMA,
        address _sKLIMA,
        address _sushi_router,
        address _KLIMABCT
    ) {
        staking = _staking;
        KLIMA = _KLIMA;
        sKLIMA = _sKLIMA;
        sushi_router = _sushi_router;
        KLIMABCT = _KLIMABCT;
        initializer = msg.sender;
    }

    address staking;
    address public immutable KLIMA;
    address public immutable sKLIMA;
    address public immutable KLIMABCT;
    address sushi_router;
    address initializer;

    function bond(
        address _bond_depository,
        uint256 _sklima_amount,
        address _recipient,
        bool _bond_type,
        address _principle,
        uint256 _discount
    ) public {
        address recipient = _recipient;
        address bond_depository = _bond_depository;
        uint256 sellAmount;
        uint256 sklima_amount = _sklima_amount;

        require(initializer == msg.sender);
        
        // Only bond if discount is greater than desired amount
        require (_discount >= getDiscount(bond_depository), "Discount too small");
        

        // Unstake KLIMA
        IERC20(sKLIMA).transferFrom(msg.sender, address(this), sklima_amount);
        IERC20(sKLIMA).approve(staking, sklima_amount);
        IStaking(staking).unstake(sklima_amount, false);

        // Get the tokens of the LP Pair

        address token0 = IUniswapV2Pair(KLIMABCT).token0();
        address token1 = IUniswapV2Pair(KLIMABCT).token1();

        address[] memory path = new address[](2);
        if (token0 == KLIMA) {
            path[0] = token0;
            path[1] = token1;
        } else {
            path[1] = token0;
            path[0] = token1;
        }

        if (_bond_type) {
            // Reserve only bonds

            sellAmount = sklima_amount;

            IERC20(KLIMA).approve(sushi_router, sklima_amount);

            uint256[] memory minOut = IUniswapV2Router02(sushi_router)
                .getAmountsOut(sellAmount, path);
                
            IUniswapV2Router02(sushi_router).swapExactTokensForTokens(
                sellAmount,
                (minOut[1] * 995) / 1000,
                path,
                address(this),
                block.timestamp
            );
            
        } else {
            // LP Bonds

            sellAmount = sklima_amount / 2;

            // Approve and perform the swap for half of the unstaked amount to convert to LP

            IERC20(KLIMA).approve(sushi_router, sklima_amount);

            uint256[] memory minOut = IUniswapV2Router02(sushi_router)
                .getAmountsOut(sellAmount, path);

            IUniswapV2Router02(sushi_router).swapExactTokensForTokens(
                sellAmount,
                (minOut[1] * 995) / 1000,
                path,
                address(this),
                block.timestamp
            );

            uint256 token0Balance = IERC20(token0).balanceOf(address(this));
            uint256 token1Balance = IERC20(token1).balanceOf(address(this));

            // Approve tokens and perform the LP transaction

            IERC20(token0).approve(sushi_router, token0Balance);
            IERC20(token1).approve(sushi_router, token1Balance);

            IUniswapV2Router02(sushi_router).addLiquidity(
                token0,
                token1,
                token0Balance,
                token1Balance,
                (token0Balance * 995) / 1000,
                (token1Balance * 995) / 1000,
                address(this),
                block.timestamp
            );
        }

        // Finally approve and bond the newly created LP

        uint256 principleBalance = IERC20(_principle).balanceOf(address(this));
        uint256 bondPrice = IKlimaBondDepository(bond_depository)
            .bondPriceInUSD();
        IERC20(_principle).approve(bond_depository, principleBalance);

        IKlimaBondDepository(bond_depository).deposit(
            principleBalance,
            bondPrice,
            recipient
        );

        // Send back any dust to the originator

        if (IERC20(KLIMA).balanceOf(address(this)) != 0) {
            IERC20(KLIMA).transfer(
                msg.sender,
                IERC20(KLIMA).balanceOf(address(this))
            );
        }
        if (IERC20(token0).balanceOf(address(this)) != 0) {
            IERC20(token0).transfer(
                msg.sender,
                IERC20(token0).balanceOf(address(this))
            );
        }
        if (IERC20(token1).balanceOf(address(this)) != 0) {
            IERC20(token1).transfer(
                msg.sender,
                IERC20(token1).balanceOf(address(this))
            );
        }
    }
    
    function getDiscount(address _bond_depository)
        public
        view
        returns (uint256 _discount)
    {
        uint256 market_price;
        //uint256 bondPrice;
        //uint256 discount;

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(KLIMABCT)
            .getReserves();

        address token0 = IUniswapV2Pair(KLIMABCT).token0();
        
        if (token0 == KLIMA) {
            market_price = reserve1 / reserve0 * 10e8;
        } else {
            market_price = reserve0 / reserve1 * 10e8;
        }

        uint256 bondPrice = IKlimaBondDepository(_bond_depository)
            .bondPriceInUSD();
        
        require(bondPrice < market_price, "Discount is negative");
        
        uint256 discount = ((market_price - bondPrice) * 10000 ) / market_price;

        return discount;
    }
}
