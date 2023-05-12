pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "forge-std/Test.sol";
import "../src/GCoin.sol";
import "../src/Treasury.sol";

contract GCoinTest is Test {
    ERC20PresetMinterPauser public stablecoin0;
    ERC20PresetMinterPauser public stablecoin1;
    GCoin public gcoin;
    Treasury public treasury;

    function setUp() public {
        stablecoin0 = new ERC20PresetMinterPauser("T0", "T0");
        stablecoin1 = new ERC20PresetMinterPauser("T1", "T1");

        stablecoin0.mint(address(this), 100);
        stablecoin1.mint(address(this), 100);

        gcoin = new GCoin();

        address[] memory arr = new address[](0);
        treasury = new Treasury(address(gcoin), msg.sender, arr, arr);

        gcoin.setTreasury(address(treasury));
    }

    function test_MintWithInvalid() public {
        vm.expectRevert();
        gcoin.stableCoinToGCoin(address(stablecoin0), 10);
    }

    function test_Mint() public {
        gcoin.addStableCoin(address(stablecoin1));

        stablecoin1.approve(address(gcoin), 10);
        gcoin.stableCoinToGCoin(address(stablecoin1), 10);

        uint256 gcoinBalance = gcoin.balanceOf(address(this));
        assertGt(gcoinBalance, 0);
    }
}
