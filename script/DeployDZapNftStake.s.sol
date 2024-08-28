//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DZapNftStake} from "../src/DZapNftStake.sol";
import {DZapNft} from "../src/DZapNft.sol";
import {DZapRewardToken} from "../src/DZapRewardToken.sol";

contract DeployDZapNftStake is Script {
    uint256 private constant deployerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external returns (DZapNftStake, DZapNft, DZapRewardToken, uint256) {
        vm.startBroadcast(deployerKey);
        DZapNft nft = new DZapNft();
        DZapRewardToken rewardToken = new DZapRewardToken();
        DZapNftStake nftStake = new DZapNftStake(address(rewardToken));

        vm.stopBroadcast();
        return (nftStake, nft, rewardToken, deployerKey);
    }
}
