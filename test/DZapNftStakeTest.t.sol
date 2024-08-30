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

    address public USER = makeAddr("USER");

    modifier mintNftToUser() {
        vm.startBroadcast(key);
        nft.mintNft(USER);
        vm.stopBroadcast();
        _;
    }

    function setUp() public {
        deployer = new DeployDZapNftStake();
        (nftStake, nft, rewardToken, key) = deployer.run();
    }

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

    function testUnstakeNft() public mintNftToUser {
        //stake nft
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nft.approve(address(nftStake), 1);
        nftStake.stakeNft(address(nft), ids);

        //unstake nft
        nftStake.unstakeNft(address(nft), ids);
        DZapNftStake.StakedNftData[] memory stakedNftData = nftStake.getUserStakedNftData(USER);
        console.log(stakedNftData[0].stakedAt);
        assertEq(stakedNftData[0].isUnbonding, true);

        vm.stopPrank();

        //unstake nft
    }

    function testGetUserStakedNftData() public mintNftToUser {
        vm.startPrank(USER);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nft.approve(address(nftStake), 1);
        nftStake.stakeNft(address(nft), ids);

        //unstake nft
        nftStake.unstakeNft(address(nft), ids);
        DZapNftStake.StakedNftData[] memory expectedData = new DZapNftStake.StakedNftData[](1);
        expectedData[0] = DZapNftStake.StakedNftData({
            owner: USER,
            tokenId: 1,
            stakedAt: 1,
            lastClaimedAt: 1,
            isUnbonding: true,
            unbondingStart: 1
        });

        DZapNftStake.StakedNftData[] memory stakedNftData = nftStake.getUserStakedNftData(USER);

        assertEq(keccak256(abi.encode(stakedNftData)), keccak256(abi.encode(expectedData)));

        vm.stopPrank();
    }
}
