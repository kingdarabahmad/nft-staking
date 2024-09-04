//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address deployerAddress;
    }

    address private constant DEFAULT_DEPLOYER_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public activeConfig;

    constructor() {
        if (block.chainid == vm.envUint("TESTNET_CHAINID")) {
            activeConfig = getTestnetConfig();
        } else {
            activeConfig = getAnvilConfig();
        }
    }

    function getTestnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({deployerAddress: vm.envAddress("DEPLOYER_ADDRESS")});
    }

    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({deployerAddress: DEFAULT_DEPLOYER_ADDRESS});
    }
}
