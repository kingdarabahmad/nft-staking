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
    address private deployerAddress;

    uint256 private constant UNBONDING_PERIOD = 2 minutes;
    uint256 private constant DELAY_PERIOD = 1 minutes;
    uint256 private constant PRECISION = 1e18;

    address private nftStakeProxyAddress;
    address private rewardTokenProxyAddress;
    address private nftProxyAddress;

    address public USER = makeAddr("USER");

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
        (nftStakeProxyAddress, nftProxyAddress, rewardTokenProxyAddress, deployerAddress) = deployer.run();
        nftStake = DZapNftStake(nftStakeProxyAddress);
        rewardToken = DZapRewardToken(rewardTokenProxyAddress);
        nft = DZapNft(nftProxyAddress);
    }

    function _mintNftToUser(address to, uint256 amount) internal {
        vm.startBroadcast(deployerAddress);
        for (uint256 i = 1; i <= amount; i++) {
            nft.mintNft(to);
        }

        vm.stopBroadcast();
    }

    function _createTokenIdsArray(uint256 length) internal pure returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](length);
        for (uint256 i = 0; i < ids.length; i++) {
            ids[i] = i + 1;
        }
        return ids;
    }

    function _approveTokenIds(address to, uint256[] memory tokenIds) internal {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.approve(address(to), tokenIds[i]);
        }
    }

    ////////////////////////
    ////// Stake Tests//////
    ///////////////////////

    function testRevertNftStakeIfAddressZero() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory tokenIds = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), tokenIds);

        vm.expectRevert(DZapNftStake.DZapNftStake_InvalidAddress.selector);
        nftStake.stakeNft(address(0), tokenIds);

        vm.stopPrank();
    }

    function testRevertNftStakeIfUserNotNftOwner() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory tokenIds = _createTokenIdsArray(2);

        //approve token id  "1" to nftStakeContract
        nft.approve(address(nftStake), 1);

        //stake should fails as user is not owner of token id "2"
        vm.expectRevert();
        nftStake.stakeNft(address(nft), tokenIds);

        vm.stopPrank();
    }

    function testSuccessNftStake() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        assertEq(nft.balanceOf(address(nftStake)), 1);
        vm.stopPrank();
    }

    ///////////////////
    // Unstake Tests //
    ///////////////////

    function testSuccessNftUnstake() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        //unstake nft
        nftStake.unstakeNft(address(nft), ids);

        //check if user unstaked nft
        DZapNftStake.StakedNftData[] memory stakedNftData = nftStake.getUserStakedNftData(USER);

        assertEq(stakedNftData[0].isUnbonding, true);

        vm.stopPrank();
    }

    function testGetUserStakedNftData() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        DZapNftStake.StakedNftData[] memory expectedData = new DZapNftStake.StakedNftData[](1);
        expectedData[0] = DZapNftStake.StakedNftData({
            owner: USER,
            tokenId: 1,
            stakedAt: block.timestamp,
            lastClaimedAt: block.timestamp,
            isUnbonding: false,
            unbondingStart: 0,
            lastClaimedBlock: block.number,
            blockNumberWhenUnbondingStarted: block.number
        });

        DZapNftStake.StakedNftData[] memory stakedNftData = nftStake.getUserStakedNftData(USER);

        assertEq(keccak256(abi.encode(stakedNftData)), keccak256(abi.encode(expectedData)));

        vm.stopPrank();
    }

    ////////////////////
    // Withdraw Tests //
    ////////////////////

    function testWithdrawRevertsIfUnbondingPeriodNotOver() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        //unstake nft
        nftStake.unstakeNft(address(nft), ids);

        //withdraw nft
        vm.expectRevert(DZapNftStake.DZapNftStake_UnbondPeriodNotOver.selector);
        nftStake.withdrawNFT(address(nft), 1);

        vm.stopPrank();
    }

    function testSuccessWithdrawNft() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        //unstake nft
        nftStake.unstakeNft(address(nft), ids);

        //withdraw nft after unponding periosd is over
        vm.warp(block.timestamp + UNBONDING_PERIOD);
        nftStake.withdrawNFT(address(nft), 1);

        assertEq(nft.balanceOf(USER), 1);
        vm.stopPrank();
    }

    ///////////////////////
    // claim reward tests //
    ///////////////////////

    function testClaimRewardsRevertIfDelayPeriodNotOver() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        // expects revert if claiming reward before delay period
        vm.expectRevert(DZapNftStake.DZapNftStake_DelayPeriodNotOver.selector);
        nftStake.claimRewards();

        vm.stopPrank();
    }

    function testClaimRewardsRevertIfNoRewards() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        //claiming reward after delay period is over but no rewards
        vm.warp(block.timestamp + DELAY_PERIOD);
        vm.expectRevert(DZapNftStake.DZapNftStake_NoRewardToClaim.selector);
        nftStake.claimRewards();

        vm.stopPrank();
    }

    function testSuccessClaimRewards() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        DZapNftStake.StakedNftData memory _stakedNft = nftStake.getUserStakedNftData(USER)[0];
        uint256 rewardRate = nftStake.getRewardRate();
        uint256 expectedRewards = (((block.number - _stakedNft.lastClaimedBlock) * rewardRate) * PRECISION) / PRECISION;

        //claiming reward after 2 days
        vm.warp(block.timestamp + 2 days);
        vm.roll(block.number + 100);
        nftStake.claimRewards();
        console.log(rewardToken.balanceOf(USER), expectedRewards);
        vm.stopPrank();
    }

    function testSuccessClaimRewardsAfterUnstake() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        //unstake after some block passed
        vm.roll(block.number + 100);
        nftStake.unstakeNft(address(nft), ids);

        uint256 expectedRewards = 400e18;

        //claiming reward after delay period is over
        vm.warp(block.timestamp + DELAY_PERIOD);
        nftStake.claimRewards();

        assertEq(rewardToken.balanceOf(USER), expectedRewards);
        vm.stopPrank();
    }

    function testGetAccumulatedRewards() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);

        //rewards accumulated of user after "100" blocks passed
        vm.roll(block.number + 100);
        uint256 rewardsCalculated = nftStake.getAccumulatedRewards(USER);
        uint256 expectedRewards = 400e18;

        assertEq(rewardsCalculated, expectedRewards);
        vm.stopPrank();
    }

    function testSuccessPauseStaking() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        // Initially, staking should not be paused
        vm.startBroadcast(deployerAddress);
        nftStake.pauseStaking();
        vm.stopBroadcast();

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //stake nft
        vm.expectRevert(DZapNftStake.DZapNftStake_StakingPaused.selector);
        nftStake.stakeNft(address(nft), ids);
        vm.stopPrank();
    }

    function testRevertPauseIfNotOwner() public {
        vm.startPrank(USER);
        vm.expectRevert();
        nftStake.pauseStaking();
        vm.stopPrank();
    }

    function testSuccessUnpauseStaking() public {
        //mint token to user
        _mintNftToUser(USER, 1);

        //pause staking by nftStake owner
        vm.startBroadcast(deployerAddress);
        nftStake.pauseStaking();
        vm.stopBroadcast();

        vm.startPrank(USER);

        //create tokenIds array
        uint256[] memory ids = _createTokenIdsArray(1);

        //stale nft
        vm.expectRevert(DZapNftStake.DZapNftStake_StakingPaused.selector);
        nftStake.stakeNft(address(nft), ids);
        vm.stopPrank();

        //unpause staking by nftStake owner
        vm.startBroadcast(deployerAddress);
        nftStake.unpauseStaking();
        vm.stopBroadcast();

        vm.startPrank(USER);

        // approve token ids to nftStakeContract
        _approveTokenIds(address(nftStake), ids);

        //stake nft
        nftStake.stakeNft(address(nft), ids);
        assertEq(nft.balanceOf(address(nftStake)), 1);
        vm.stopPrank();
    }

    function testNftStakingStatus() public view {
        assertEq(nftStake.getStakingStatus(), false);
    }

    function testSuccessSetRewardRate() public {
        //set reward rate
        vm.startBroadcast(deployerAddress);
        uint256 newRewardRate = 0.5e18;
        nftStake.setRewardRate(newRewardRate);
        vm.stopBroadcast();

        assertEq(nftStake.getRewardRate(), newRewardRate);
    }
}
