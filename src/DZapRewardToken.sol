//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DZapRewardToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    // constructor() ERC20("DzapRewardToken", "DZAPRT") Ownable(msg.sender) {}
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("DzapRewardToken", "DZAPRT");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {}
}
