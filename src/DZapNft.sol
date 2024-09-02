//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DZapNft is Initializable, ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public s_totalNftMinted;

    // constructor() ERC721("DzapNft", "DZAP") Ownable(msg.sender) {
    //     s_totalNftMinted = 0;
    // }
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("DzapNft", "DZAP");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        s_totalNftMinted = 0;
    }

    function mintNft(address to) public onlyOwner {
        s_totalNftMinted++;
        _mint(to, s_totalNftMinted);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
