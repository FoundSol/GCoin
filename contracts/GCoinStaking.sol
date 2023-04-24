// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GCoinStaking is Ownable {
    using SafeMath for uint256;

    IERC20 public gcoinToken;
    IERC20 public cgvToken;

    uint256 public stakingPeriod;
    uint256 public annualRewardRate;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Stake[]) public stakes;

    constructor(address _gcoinToken, address _cgvToken, uint256 _stakingPeriod, uint256 _annualRewardRate) {
        gcoinToken = IERC20(_gcoinToken);
        cgvToken = IERC20(_cgvToken);
        stakingPeriod = _stakingPeriod;
        annualRewardRate = _annualRewardRate;
    }

    function stake(uint256 amount) external {
        gcoinToken.transferFrom(msg.sender, address(this), amount);
        Stake memory newStake = Stake(amount, block.timestamp);
        stakes[msg.sender].push(newStake);
    }

    function withdraw() external {
        uint256 totalAmount = 0;
        uint256 totalRewards = 0;
        uint256 i = 0;

        while (i < stakes[msg.sender].length) {
            Stake storage stake = stakes[msg.sender][i];
            uint256 stakedDuration = block.timestamp.sub(stake.timestamp);
            if (stakedDuration >= stakingPeriod) {
                totalAmount = totalAmount.add(stake.amount);
                uint256 reward = stake.amount.mul(annualRewardRate).div(100).mul(stakedDuration).div(365 days);
                totalRewards = totalRewards.add(reward);
                stakes[msg.sender][i] = stakes[msg.sender][stakes[msg.sender].length - 1];
                stakes[msg.sender].pop();
            } else {
                i++;
            }
        }

        require(totalAmount > 0, "No staking rewards to claim.");
        gcoinToken.transfer(msg.sender, totalAmount);
        cgvToken.transfer(msg.sender, totalRewards);
    }

    function updateStakingPeriod(uint256 _stakingPeriod) external onlyOwner {
        stakingPeriod = _stakingPeriod;
    }

    function updateAnnualRewardRate(uint256 _annualRewardRate) external onlyOwner {
        annualRewardRate = _annualRewardRate;
    }
}
