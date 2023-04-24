pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GCoin.sol";

contract Treasury is Ownable {
    using SafeERC20 for ERC20;
    using SafeERC20 for GCoin;
    using SafeMath for uint256;

    address public TM;

    // Supported stablecoins
    address[] public stableCoins;
    address[] public nonStableCoins;

    // Treasury reserves
    mapping(address => uint256) public liquidReserve;
    mapping(address => uint256) public illiquidReserve;

    address public SOME_ADDRESS;

    // GCoin contract
    GCoin public gcoin;

    constructor(
        address _gcoin,
        address _TM,
        address[] memory _stableCoins,
        address[] memory _nonStableCoins
    ) {
        gcoin = GCoin(_gcoin);
        TM = _TM;
        stableCoins = _stableCoins;
        nonStableCoins = _nonStableCoins;
    }

    // Function to update TM address
    function updateTM(address _newTM) public onlyOwner {
        TM = _newTM;
    }

    function defendLowerBound(uint256 amount, address stableCoin)
        external
        onlyTM
    {
        uint256 currentPrice = gcoin.getGCoinValue();
        /*
        Figure out how to get traded price, maybe this is just manually controled by TM
         */
        uint256 tradedPrice = 0;

        require(
            currentPrice < tradedPrice.mul(98).div(100),
            "Price is not below lower bound"
        );

        // Buy GCoin from NSP using liquid reserves
        liquidReserve[stableCoin] = liquidReserve[stableCoin].sub(amount);
        /*
        This is up in the air, should we implement this over another contract
        possibly to integrate the AMM directly?
        */
        ERC20(stableCoin).safeTransfer(SOME_ADDRESS, amount);

        // Burn GCoin to raise the price
        /*
        This is up in the air, as in why need to burn the token? If every mint actually used money to put the money into the treasury, do we burn?
        */
        uint256 gcAmount = amount.mul(ERC20(stableCoin).decimals()).div(
            currentPrice
        );
        gcoin.burn(SOME_ADDRESS, gcAmount);
    }

    /*

This is really not needed, because people can mint from GCoin directly using the orcale price,
why the AMM price go up above 1.02? If so, arbitrager will mint from GCoin and sell the coin to AMM to bring down prices.

 */

    function defendUpperBound(uint256 amount, address stableCoin)
        external
        onlyTM
    {
        uint256 currentPrice = gcoin.getGCoinValue();
        /*
        Figure out how to get traded price, maybe this is just manually controled by TM
         */
        uint256 tradedPrice = 0;
        require(
            currentPrice > tradedPrice.mul(102).div(100),
            "Price is not above upper bound"
        );

        // Mint GCoin
        uint256 gcAmount = amount.mul(ERC20(stableCoin).decimals()).div(
            currentPrice
        );
        gcoin.mint(TM, gcAmount); // wouldn't work since no access.

        // Sell GCoin for stablecoin, AMM integration? or separate contract maybe, or manually do it
        gcoin.safeTransferFrom(TM, SOME_ADDRESS, gcAmount);
        ERC20(stableCoin).safeTransferFrom(SOME_ADDRESS, address(this), amount);

        // Increase liquid reserves
        liquidReserve[stableCoin] = liquidReserve[stableCoin].add(amount);
    }

    modifier onlyTM() {
        require(msg.sender == TM, "Caller is not the Treasury Manager");
        _;
    }

    function addToLiquidReserve(address asset, uint256 amount)
        external
        onlyOwner
    {
        liquidReserve[asset] = liquidReserve[asset].add(amount);
    }

    function removeFromLiquidReserve(address asset, uint256 amount)
        external
        onlyOwner
    {
        liquidReserve[asset] = liquidReserve[asset].sub(amount);
    }

    function addToIlliquidReserve(address asset, uint256 amount)
        external
        onlyOwner
    {
        illiquidReserve[asset] = illiquidReserve[asset].add(amount);
    }

    function removeFromIlliquidReserve(address asset, uint256 amount)
        external
        onlyOwner
    {
        illiquidReserve[asset] = illiquidReserve[asset].sub(amount);
    }

    function calculateCAR() public view returns (uint256) {
        uint256 totalValue = 0;
        uint256 circulatingSupply = gcoin.totalSupply().sub(
            gcoin.balanceOf(address(this))
        );

        // Calculate the value of stablecoin reserves
        for (uint256 i = 0; i < stableCoins.length; i++) {
            uint256 stableCoinValue = liquidReserve[stableCoins[i]];
            totalValue = totalValue.add(stableCoinValue);
        }

        // Calculate the value of non-stablecoin reserves with a discount factor of 15%
        for (uint256 i = 0; i < nonStableCoins.length; i++) {
            uint256 nonStableCoinValue = illiquidReserve[nonStableCoins[i]];
            nonStableCoinValue = nonStableCoinValue.mul(85).div(100);
            totalValue = totalValue.add(nonStableCoinValue);
        }

        // Calculate CAR
        uint256 car = totalValue.mul(100).div(circulatingSupply);
        return car;
    }
}
