// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

interface IRewardPool {
    function isFeeContract(address) external view returns (bool);

    function addReward(uint256 amount) external;

    function addRewardWithNativeCoin() external payable;
}
