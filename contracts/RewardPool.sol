// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardPool is Ownable {
    IERC20 token;
    uint256 public totalReward;
    mapping(address => bool) public isFeeContract;

    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
    }

    function allowFeeContract(address addr) external onlyOwner {
        isFeeContract[addr] = true;
    }

    function addReward(uint256 amount) external {
        require(isFeeContract[msg.sender], "not allowed");
        token.transferFrom(msg.sender, address(this), amount);
    }

    function addRewardWithNativeCoin() external payable {
        require(isFeeContract[msg.sender], "not allowed");
    }
}
