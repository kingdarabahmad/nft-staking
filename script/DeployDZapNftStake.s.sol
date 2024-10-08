//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DZapNftStake} from "../src/DZapNftStake.sol";
import {DZapNft} from "../src/DZapNft.sol";
import {DZapRewardToken} from "../src/DZapRewardToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDZapNftStake is Script {
    address private deployerAddress;

    function run() external returns (address, address, address, address) {
        HelperConfig config = new HelperConfig();
        deployerAddress = config.activeConfig();
        vm.startBroadcast(deployerAddress);

        //nft
        DZapNft nft = new DZapNft();
        ERC1967Proxy proxyNft = new ERC1967Proxy(address(nft), "");
        DZapNft(address(proxyNft)).initialize();

        //for rewardToken
        DZapRewardToken rewardToken = new DZapRewardToken();
        ERC1967Proxy proxyRewardToken = new ERC1967Proxy(address(rewardToken), "");
        DZapRewardToken(address(proxyRewardToken)).initialize();

        //for nftStake
        DZapNftStake nftStake = new DZapNftStake();
        ERC1967Proxy proxyNftStake = new ERC1967Proxy(address(nftStake), "");
        DZapNftStake(address(proxyNftStake)).initialize(address(proxyRewardToken));

        vm.stopBroadcast();
        return (address(proxyNftStake), address(proxyNft), address(proxyRewardToken), deployerAddress);
    }
}
