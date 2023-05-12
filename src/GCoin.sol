// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract GCoin is ERC20, Ownable, Pausable {

    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    uint256 public mintingFee = 1; // 1% fee
    uint256 public gcoinValue;

    AggregatorV3Interface public gcoinPriceFeed;
    mapping(address => ERC20) public stableCoins;

    address public treasury;

    constructor() ERC20("GCoin", "GC") {
        gcoinValue = 1e18; // Initial value set to 1 stable coin
    }

    function addStableCoin(address token) public onlyOwner {
        stableCoins[token] = ERC20(token);
    }

    function setGCoinPriceFeed(address priceFeed) public onlyOwner {
        gcoinPriceFeed = AggregatorV3Interface(priceFeed);
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function getLatestPrice() private view returns (uint256) {
        require(
            address(gcoinPriceFeed) != address(0),
            "GCoin price feed not set"
        );
        (, int256 price, , , ) = gcoinPriceFeed.latestRoundData();
        return uint256(price);
    }

    function getGCoinOutputFromStable(address token, uint256 amount) public view returns (uint256) {
        uint256 stableCoinDecimals = 10**uint256(stableCoins[token].decimals());
        uint256 gcoinAmount = amount
            .mul(stableCoinDecimals)
            .div(gcoinValue)
            .mul(100)
            .div(100 + mintingFee);
        return gcoinAmount;
    }

    function stableCoinToGCoin(address token, uint256 amount) public whenNotPaused {
        ERC20 stableCoin = stableCoins[token];
        require(address(stableCoin) != address(0), "Stable coin not found");
        require(treasury != address(0), "Treasury address not set");

        uint256 allowance = stableCoin.allowance(msg.sender, address(this));
        require(allowance >= amount, "Amount not allowed");

        uint256 stableCoinDecimals = 10**uint256(stableCoin.decimals());
        uint256 gcoinAmount = amount
            .mul(stableCoinDecimals)
            .div(gcoinValue)
            .mul(100)
            .div(100 + mintingFee);

        uint256 initialTreasuryBalance = stableCoin.balanceOf(treasury);
        stableCoin.safeTransferFrom(msg.sender, treasury, amount);
        uint256 finalTreasuryBalance = stableCoin.balanceOf(treasury);

        require(
            finalTreasuryBalance == initialTreasuryBalance.add(amount),
            "Treasury balance did not increase correctly"
        );

        _mint(msg.sender, gcoinAmount);
    }
    function getGCoinValue() public view returns (uint256) {
        return gcoinValue;
    }

    function updateGCoinValue() public onlyOwner {
        uint256 chainlinkValue = getLatestPrice();
        gcoinValue = chainlinkValue;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
