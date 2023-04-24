pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract GCoin is ERC20, Ownable {
    using SafeMath for uint256;

    AggregatorV3Interface internal stableCoinPriceFeed;
    ERC20 public stableCoin;

    uint256 public mintingFee = 1; // 1% fee
    uint256 public stableCoinDecimals;
    uint256 public gcoinValue;
    address constant ETHER = address(0);

    mapping(address => AggregatorV3Interface) public priceFeeds;
    mapping(address => uint256) public discountFactors;

    constructor(address _stableCoin, address _stableCoinPriceFeed)
        ERC20("GCoin", "GC")
    {
        stableCoin = ERC20(_stableCoin);
        stableCoinPriceFeed = AggregatorV3Interface(_stableCoinPriceFeed);
        stableCoinDecimals = 10**uint256(stableCoin.decimals());
        gcoinValue = stableCoinDecimals; // Initial value set to 1 stable coin
    }

    function addTokenPriceFeed(address token, address priceFeed)
        public
        onlyOwner
    {
        priceFeeds[token] = AggregatorV3Interface(priceFeed);
    }

    function setDiscountFactor(address token, uint256 discount)
        public
        onlyOwner
    {
        discountFactors[token] = discount;
    }

    function getLatestPrice(address token) private view returns (uint256) {
        AggregatorV3Interface priceFeed = priceFeeds[token];
        require(
            address(priceFeed) != address(0),
            "Price feed not found for token"
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function stableCoinToGCoin(uint256 amount) public {
        uint256 allowance = stableCoin.allowance(msg.sender, address(this));
        require(allowance >= amount, "Amount not allowed");

        uint256 gcoinAmount = amount
            .mul(stableCoinDecimals)
            .div(gcoinValue)
            .mul(100)
            .div(100 + mintingFee);
        stableCoin.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, gcoinAmount);
    }

    /*
    This is really doesnt make sense, why people use other tokens to mint GCoin with 15% off?
    If it is more like lending platform, then need to implement a bunch more to enable lending, redemption and liquidation.
    */
    function tokenToGCoin(uint256 amount, address token) public payable {
        if (token == ETHER) {
            uint256 ethAmount = msg.value;
            uint256 ethPrice = getLatestPrice(ETHER);
            uint256 ethAmountInStableCoin = ethAmount.mul(ethPrice).div(
                stableCoinDecimals
            );

            uint256 discountedEthAmount = ethAmountInStableCoin
                .mul(100 - discountFactors[ETHER])
                .div(100);
            uint256 gcoinAmount = discountedEthAmount
                .mul(stableCoinDecimals)
                .div(gcoinValue)
                .mul(100)
                .div(100 + mintingFee);
            _mint(msg.sender, gcoinAmount);
        } else {
            uint256 allowance = ERC20(token).allowance(
                msg.sender,
                address(this)
            );
            require(allowance >= amount, "Amount not allowed");

            uint256 tokenPrice = getLatestPrice(token);
            uint256 tokenAmountInStableCoin = amount.mul(tokenPrice).div(
                stableCoinDecimals
            );

            uint256 discountedTokenAmount = tokenAmountInStableCoin
                .mul(100 - discountFactors[token])
                .div(100);
            uint256 gcoinAmount = discountedTokenAmount
                .mul(stableCoinDecimals)
                .div(gcoinValue)
                .mul(100)
                .div(100 + mintingFee);

            ERC20(token).transferFrom(msg.sender, address(this), amount);
            _mint(msg.sender, gcoinAmount);
        }
    }

    function getGCoinValue() public view returns (uint256) {
        return gcoinValue;
    }

    function updateGCoinValue() public onlyOwner {
        uint256 chainlinkValue = getLatestPrice(address(stableCoin));
        gcoinValue = chainlinkValue;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
