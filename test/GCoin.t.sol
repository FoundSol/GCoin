// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "forge-std/Test.sol";
import "../src/GCoin.sol";
import "../src/Treasury.sol";

// Mock stablecoin contract with 6 decimals for testing
contract MyStableCoin is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("MyStableCoin", "MSC") {}

    // Override decimals function to return 6 instead of default 18
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}

// Test contract for GCoin
contract GCoinTest is Test {
    // Instances of ERC20PresetMinterPauser and MyStableCoin contracts to simulate various stablecoins
    ERC20PresetMinterPauser public stablecoin0;
    ERC20PresetMinterPauser public stablecoin1;
    MyStableCoin public stablecoin6digit;

    // Instance of GCoin contract to test
    GCoin public gcoin;

    // Instance of Treasury contract used by GCoin
    Treasury public treasury;

    // Set up the testing environment before each test
    function setUp() public {
        // Deploy mock stablecoins and mint some tokens to the test contract
        stablecoin0 = new ERC20PresetMinterPauser("T0", "T0");
        stablecoin0.mint(address(this), 100);

        stablecoin1 = new ERC20PresetMinterPauser("T1", "T1");
        stablecoin1.mint(address(this), 100);

        stablecoin6digit = new MyStableCoin();
        stablecoin6digit.mint(address(this), 1000000);

        // Deploy GCoin and Treasury contracts
        gcoin = new GCoin();
        address[] memory arr = new address[](0);
        treasury = new Treasury(address(gcoin), msg.sender, arr, arr);

        // Set treasury address in the GCoin contract
        gcoin.setTreasury(address(treasury));
    }

    // Test that minting fails with an invalid stablecoin
    function test_MintWithInvalid() public {
        vm.expectRevert();
        gcoin.stableCoinToGCoin(address(stablecoin0), 10);
    }

    // Test that minting succeeds with a valid stablecoin
    function test_Mint() public {
        gcoin.addStableCoin(address(stablecoin1));
        stablecoin1.approve(address(gcoin), 100);
        gcoin.stableCoinToGCoin(address(stablecoin1), 100);

        uint256 gcoinBalance = gcoin.balanceOf(address(this));
        assertGt(gcoinBalance, 0);
        assertLt(gcoinBalance, 100);
        emit log_int(int256(gcoinBalance));
    }

    // Test that minting succeeds with a 6-decimal stablecoin
    function test_Mint_6digit() public {
        gcoin.addStableCoin(address(stablecoin6digit));
        stablecoin6digit.approve(address(gcoin), 1000000);
        gcoin.stableCoinToGCoin(address(stablecoin6digit), 1000000);

        uint256 gcoinBalance = gcoin.balanceOf(address(this));
        assert(gcoinBalance == 990000000000000000);
    }

    // Test that minting succeeds with a different gCoin value
    function test_Mint_gValue() public {
        gcoin.updateGCoinValueManual(2e18);
        gcoin.addStableCoin(address(stablecoin6digit));
        stablecoin6digit.approve(address(gcoin), 1000000);
        gcoin.stableCoinToGCoin(address(stablecoin6digit), 1000000);

        uint256 gcoinBalance = gcoin.balanceOf(address(this));
        assert(gcoinBalance == 495000000000000000);
    }

    // Test that minting with treasury increase
    function test_Mint_treasury() public {
        gcoin.updateGCoinValueManual(2e18);
        gcoin.addStableCoin(address(stablecoin6digit));
        stablecoin6digit.approve(address(gcoin), 1000000);
        gcoin.stableCoinToGCoin(address(stablecoin6digit), 1000000);

        uint256 stableBalanceGcoin = stablecoin6digit.balanceOf(address(this));
        uint256 stableBalanceTreasury = stablecoin6digit.balanceOf(gcoin.treasury());
        assert(stableBalanceGcoin == 0);
        assert(stableBalanceTreasury == 1000000);
        // console2.log(stableBalanceGcoin, stableBalanceTreasury);
    }

    function test_RevertWhen_CallerIsNotOwner() public {
        vm.expectRevert();
        vm.startPrank(address(111));
        gcoin.mint(address(33), 100);
        vm.stopPrank();
    }
}
