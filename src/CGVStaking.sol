// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CGVStaking is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public cgvToken;

    uint256 public stakingPeriod;
    uint256 public annualRewardRate;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
    }

    struct UserInfo {
        Stake[] stakes;
        uint256 totalStaked;
    }

    mapping(address => UserInfo) private userStakingInfo;
    EnumerableSet.AddressSet private userAddresses;

    constructor(
        address _cgvToken,
        uint256 _stakingPeriod,
        uint256 _annualRewardRate
    ) {
        cgvToken = IERC20(_cgvToken);
        stakingPeriod = _stakingPeriod;
        annualRewardRate = _annualRewardRate;
    }

    function stake(uint256 amount) external whenNotPaused {
        cgvToken.safeTransferFrom(msg.sender, address(this), amount);
        UserInfo storage userInfo = userStakingInfo[msg.sender];
        userInfo.stakes.push(Stake(amount, block.timestamp));
        userInfo.totalStaked = userInfo.totalStaked.add(amount);
        userAddresses.add(msg.sender);
    }

    function withdraw() external nonReentrant whenNotPaused {
        UserInfo storage userInfo = userStakingInfo[msg.sender];
        uint256 totalAmount = 0;
        uint256 totalRewards = 0;
        uint256 i = 0;

        while (i < userInfo.stakes.length) {
            Stake storage currentStake = userInfo.stakes[i];
            uint256 stakedDuration = block.timestamp.sub(
                currentStake.timestamp
            );
            if (stakedDuration >= stakingPeriod) {
                uint256 reward = currentStake
                    .amount
                    .mul(annualRewardRate)
                    .div(100)
                    .mul(stakedDuration)
                    .div(365 days);
                totalRewards = totalRewards.add(reward);
                totalAmount = totalAmount.add(currentStake.amount);

                userInfo.stakes[i] = userInfo.stakes[
                    userInfo.stakes.length - 1
                ];
                userInfo.stakes.pop();
            } else {
                i++;
            }
        }

        require(totalAmount > 0, "No staking rewards to claim.");
        require(
            cgvToken.balanceOf(address(this)) >= totalRewards,
            "Not enough CGV tokens to pay rewards. We are adding more. Please wait"
        );

        userInfo.totalStaked = userInfo.totalStaked.sub(totalAmount);
        cgvToken.safeTransfer(msg.sender, totalAmount);
        cgvToken.safeTransfer(msg.sender, totalRewards);
    }

    function getUserStakingInfoList(address user)
        external
        view
        returns (UserInfo memory)
    {
        return userStakingInfo[user];
    }

    function updateStakingPeriod(uint256 _stakingPeriod) external onlyOwner {
        stakingPeriod = _stakingPeriod;
    }

    function updateAnnualRewardRate(uint256 _annualRewardRate)
        external
        onlyOwner
    {
        annualRewardRate = _annualRewardRate;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getUserStakingInfo(address user)
        public
        view
        returns (uint256 totalStaked, uint256 outstandingCGV)
    {
        UserInfo storage userInfo = userStakingInfo[user];
        totalStaked = userInfo.totalStaked;
        outstandingCGV = 0;

        for (uint256 i = 0; i < userInfo.stakes.length; i++) {
            Stake storage currentStake = userInfo.stakes[i];
            uint256 stakedDuration = block.timestamp.sub(
                currentStake.timestamp
            );
            if (stakedDuration >= stakingPeriod) {
                uint256 reward = currentStake
                    .amount
                    .mul(annualRewardRate)
                    .div(100)
                    .mul(stakedDuration)
                    .div(365 days);
                outstandingCGV = outstandingCGV.add(reward);
            }
        }
    }

    function getTotalOutstandingRewards() external view returns (uint256) {
        uint256 totalOutstandingRewards = 0;
        for (uint256 i = 0; i < userAddresses.length(); i++) {
            address user = userAddresses.at(i);
            (, uint256 outstandingCGV) = getUserStakingInfo(user);
            totalOutstandingRewards = totalOutstandingRewards.add(
                outstandingCGV
            );
        }
        return totalOutstandingRewards;
    }
}
