// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "forge-std/Test.sol";
import "../src/GCoin.sol";
import "../src/Treasury.sol";
import "../src/GCoinStaking.sol";

contract MockToken is ERC20PresetMinterPauser {
    constructor(string memory name, string memory symbol)
        ERC20PresetMinterPauser(name, symbol)
    {}
}

contract GCoinStakingTest is Test {
    GCoin public gcoin;
    Treasury public treasury;
    MockToken public stablecoin0;

    MockToken public cgv;
    GCoinStaking public staking;
    address public stakeholder;

    function setUp() public {
        gcoin = new GCoin();
        address[] memory arr = new address[](0);
        treasury = new Treasury(address(gcoin), msg.sender, arr, arr);
        // Set treasury address in the GCoin contract
        gcoin.setTreasury(address(treasury));


        // mint some gcoin
        stakeholder = address(111);
        stablecoin0 = new MockToken("T0", "T0");
        stablecoin0.mint(stakeholder, 2e18);
        gcoin.addStableCoin(address(stablecoin0));
        vm.startPrank(stakeholder);
        stablecoin0.approve(address(gcoin), 2e18);
        gcoin.stableCoinToGCoin(address(stablecoin0), 2e18);
        vm.stopPrank();

        // set CGV tokens
        cgv = new MockToken("CGV Token", "CGV");

        cgv.mint(address(this), 1e18);

        staking = new GCoinStaking(
            address(gcoin),
            address(cgv),
            3 days,
            10
        );
    }

    function test_Stake() public {
        vm.startPrank(stakeholder);
        gcoin.approve(address(staking), 1e18);
        uint256 gcoinBefore = gcoin.balanceOf(stakeholder);
        staking.stake(1e18);
        (uint256 totalStaked, uint256 outstandingCGV) = staking.getUserStakingInfo(stakeholder);

        // console2.log("after stake", gcoin.balanceOf(address(staking)), gcoin.balanceOf(stakeholder));
        assert(totalStaked == 1e18);
        assert(outstandingCGV == 0);
        assert(gcoin.balanceOf(stakeholder) == gcoinBefore-1e18);

        vm.stopPrank();
    }
}
