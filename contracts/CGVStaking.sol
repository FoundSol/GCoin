// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CGVStaking is Ownable {
    using SafeMath for uint256;

    IERC20 public cgvToken;

    uint256 public stakingPeriod;
    uint256 public rewardPerToken;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Stake[]) public stakes;

    /*
    This is missing a bunch of functions, such as how the staking actually works
     */

    constructor(
        address _cgvToken,
        uint256 _stakingPeriod,
        uint256 _rewardPerToken
    ) {
        cgvToken = IERC20(_cgvToken);
        stakingPeriod = _stakingPeriod;
        rewardPerToken = _rewardPerToken;
    }

    function stake(uint256 amount) external {
        cgvToken.transferFrom(msg.sender, address(this), amount);
        Stake memory newStake = Stake(amount, block.timestamp);
        stakes[msg.sender].push(newStake);
    }

    function withdraw() external {
        uint256 totalAmount = 0;
        uint256 totalRewards = 0;
        uint256 i = 0;

        while (i < stakes[msg.sender].length) {
            Stake storage stake = stakes[msg.sender][i];
            if (block.timestamp.sub(stake.timestamp) >= stakingPeriod) {
                totalAmount = totalAmount.add(stake.amount);
                totalRewards = totalRewards.add(
                    stake.amount.mul(rewardPerToken)
                );
                stakes[msg.sender][i] = stakes[msg.sender][
                    stakes[msg.sender].length - 1
                ];
                stakes[msg.sender].pop();
            } else {
                i++;
            }
        }

        require(totalAmount > 0, "No staking rewards to claim.");
        cgvToken.transfer(msg.sender, totalAmount.add(totalRewards));
    }

    function updateStakingPeriod(uint256 _stakingPeriod) external onlyOwner {
        stakingPeriod = _stakingPeriod;
    }

    function updateRewardPerToken(uint256 _rewardPerToken) external onlyOwner {
        rewardPerToken = _rewardPerToken;
    }
}
