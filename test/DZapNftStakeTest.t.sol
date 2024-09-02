//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDZapNftStake} from "script/DeployDZapNftStake.s.sol";
import {DZapRewardToken} from "../src/DZapRewardToken.sol";
import {DZapNftStake} from "../src/DZapNftStake.sol";
import {DZapNft} from "../src/DZapNft.sol";
import {console} from "forge-std/console.sol";

contract DZapNftStakeTest is Test {
    DeployDZapNftStake public deployer;
    DZapRewardToken public rewardToken;
    DZapNftStake public nftStake;
    DZapNft public nft;
    uint256 private key;

    uint256 private constant UNBONDING_PERIOD = 2 minutes;
    uint256 private constant DELAY_PERIOD = 1 minutes;

    address private nftStakeProxyAddress;
    address private rewardTokenProxyAddress;
    address private nftProxyAddress;

    address public USER = makeAddr("USER");

    modifier mintNftToUser() {
        vm.startBroadcast(key);
        nft.mintNft(USER);
        vm.stopBroadcast();
        _;
    }

    modifier stakeNft() {
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nft.approve(address(nftStake), 1);
        nftStake.stakeNft(address(nft), ids);
        vm.stopPrank();
        _;
    }

    modifier unstakeNft() {
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nftStake.unstakeNft(address(nft), ids);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployDZapNftStake();
        (nftStakeProxyAddress, nftProxyAddress, rewardTokenProxyAddress, key) = deployer.run();
        nftStake = DZapNftStake(nftStakeProxyAddress);
        rewardToken = DZapRewardToken(rewardTokenProxyAddress);
        nft = DZapNft(nftProxyAddress);
    }

    ////////////////////////
    ////// Stake Tests//////
    ///////////////////////

    function testRevertsNftStakeIfAddressZero() public mintNftToUser {
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nft.approve(address(nftStake), 1);
        vm.expectRevert(DZapNftStake.DZapNftStake_InvalidAddress.selector);
        nftStake.stakeNft(address(0), ids);
        vm.stopPrank();
    }

    function testRevertsIfUserNotNftOwner() public mintNftToUser {
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 2;
        nft.approve(address(nftStake), 1);
        vm.expectRevert();
        nftStake.stakeNft(address(nft), ids);
        vm.stopPrank();
    }

    function testStakeNft() public mintNftToUser {
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nft.approve(address(nftStake), 1);
        nftStake.stakeNft(address(nft), ids);
        vm.stopPrank();
        assertEq(nft.balanceOf(address(nftStake)), 1);
    }

    ///////////////////
    // Unstake Tests //
    ///////////////////

    function testUnstakeNft() public mintNftToUser stakeNft {
        //stake nft is done by modifier

        //unstake nft
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nftStake.unstakeNft(address(nft), ids);
        DZapNftStake.StakedNftData[] memory stakedNftData = nftStake.getUserStakedNftData(USER);
        console.log(stakedNftData[0].stakedAt);
        assertEq(stakedNftData[0].isUnbonding, true);

        vm.stopPrank();
    }

    function testGetUserStakedNftData() public mintNftToUser stakeNft {
        // stake nft is done by modifier

        //unstake nft
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nftStake.unstakeNft(address(nft), ids);
        DZapNftStake.StakedNftData[] memory expectedData = new DZapNftStake.StakedNftData[](1);
        expectedData[0] = DZapNftStake.StakedNftData({
            owner: USER,
            tokenId: 1,
            stakedAt: block.timestamp,
            lastClaimedAt: block.timestamp,
            isUnbonding: true,
            unbondingStart: block.timestamp
        });

        DZapNftStake.StakedNftData[] memory stakedNftData = nftStake.getUserStakedNftData(USER);

        assertEq(keccak256(abi.encode(stakedNftData)), keccak256(abi.encode(expectedData)));

        vm.stopPrank();
    }

    ////////////////////
    // Withdraw Tests //
    ////////////////////

    function testWithdrawNftFailsIsUnbondingPeriodNotOver() public mintNftToUser stakeNft unstakeNft {
        // stake nft is done by modifier

        //unstake nft
        vm.startPrank(USER);
        vm.expectRevert(DZapNftStake.DZapNftStake_UnbondPeriodNotOver.selector);
        nftStake.withdrawNFT(address(nft), 1);
        vm.stopPrank();
    }

    function testWithdrawNft() public mintNftToUser stakeNft unstakeNft {
        // stake nft is done by modifier

        //unstake nft is done by modifier

        //wait for unbonding period to get over
        vm.startPrank(USER);
        vm.warp(block.timestamp + UNBONDING_PERIOD);

        //withdraw nft
        nftStake.withdrawNFT(address(nft), 1);
        vm.stopPrank();

        assertEq(nft.balanceOf(USER), 1);
    }

    ///////////////////////
    // claim reward tests //
    ///////////////////////

    function testClaimRewards() public mintNftToUser stakeNft {
        // stake nft is done by modifier

        vm.startPrank(USER);

        uint256 expectedReward = 1036800;

        //unstake nft after 1 day
        vm.warp(block.timestamp + 1 days);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nftStake.unstakeNft(address(nft), ids);
        console.log(nftStake.getUserStakedNftData(USER)[0].unbondingStart);
        console.log(block.timestamp);
        //claim rewards after 2 days
        vm.warp(block.timestamp + 2 days);

        nftStake.claimRewards();

        assertEq(rewardToken.balanceOf(USER), expectedReward);

        vm.stopPrank();
    }

    function testPauseStaking() public mintNftToUser {
        // Initially, staking should not be paused
        vm.startBroadcast(key);
        nftStake.pauseStaking();
        vm.stopBroadcast();
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.expectRevert(DZapNftStake.DZapNftStake_StakingPaused.selector);
        nftStake.stakeNft(address(nft), ids);
        vm.stopPrank();
    }

    function testUnableToPauseIfNotOwner() public {
        vm.startPrank(USER);
        vm.expectRevert();
        nftStake.pauseStaking();
        vm.stopPrank();
    }

    function testUnpauseStaking() public mintNftToUser {
        vm.startBroadcast(key);
        nftStake.pauseStaking();

        vm.stopBroadcast();

        //stake nft
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.expectRevert(DZapNftStake.DZapNftStake_StakingPaused.selector);
        nftStake.stakeNft(address(nft), ids);
        vm.stopPrank();

        //unpause staking
        vm.startBroadcast(key);
        nftStake.unpauseStaking();
        vm.stopBroadcast();

        //stake nft
        vm.startPrank(USER);
        uint256[] memory ids2 = new uint256[](1);
        ids2[0] = 1;
        nft.approve(address(nftStake), 1);
        nftStake.stakeNft(address(nft), ids2);
        assertEq(nft.balanceOf(address(nftStake)), 1);
        vm.stopPrank();
    }

    function testNftStakingStatus() public view {
        assertEq(nftStake.getStakingStatus(), false);
    }

    function testSetRewardRate() public {
        vm.startBroadcast(key);
        nftStake.setRewardRate(8);
        vm.stopBroadcast();

        assertEq(nftStake.getRewardRate(), 8);
    }
}
