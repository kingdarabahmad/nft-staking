//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DZapNft is ERC721, Ownable {
    uint256 public s_totalNftMinted;

    constructor() ERC721("DzapNft", "DZAP") Ownable(msg.sender) {
        s_totalNftMinted = 0;
    }

    function mintNft(address to) public onlyOwner {
        s_totalNftMinted++;
        _mint(to, s_totalNftMinted);
    }
}
