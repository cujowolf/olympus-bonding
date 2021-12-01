// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IKlimaBondDepository {
    function bondPriceInUSD() external view returns (uint256 price_);

    function deposit(
        uint256 _amount,
        uint256 _maxPrice,
        address _depositor
    ) external returns (uint256);

    function pendingPayoutFor(address _depositor)
        external
        view
        returns (uint256 pendingPayout_);
}
