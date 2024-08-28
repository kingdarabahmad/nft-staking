//SPDX-License-Identifier: MIT

// layout of contract
// version
// imports
// intefaces, libraries, contracts
// errors
// type declarations
// state variables
// Events
// modifiers
// functions

// Layout of functions:
// constructor
// recieve function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view and pure functions
pragma solidity ^0.8.18;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DZapNftStake {
    /////////////////
    // Errors      //
    /////////////////
    error DZapNftStake_InvalidAddress();
    error DZapNftStake_TokenIdsLengthZero();
    error DZapNftStake_NotOwnerOfTokenId();
    error DZapNftStake_NFTNotFoundOrAlreadyUnbonded();

    ///////////////////////////
    // State variables      //
    ///////////////////////////
    IERC20 immutable i_rewardToken;

    struct StakedNftData {
        address owner;
        uint256 tokenId;
        uint256 stakedAt;
        uint256 lastClaimedAt;
        bool isUnbonding;
        uint256 unbondingStart;
    }

    mapping(address user => StakedNftData[] stakedNfts) public s_userStakedNfts;

    ///////////////////////////
    // Events                //
    ///////////////////////////
    event NftStaked(address indexed user, uint256[] indexed tokenIds);
    event NftUnstaked(address indexed user, uint256 indexed tokenId);
    event NftNotFoundOrAlreadyUnbounded();

    ////////////////
    // Modifiers  //
    ////////////////

    modifier AddressMustNotZero(address contractAddress) {
        if (contractAddress == address(0)) {
            revert DZapNftStake_InvalidAddress();
        }
        _;
    }

    modifier TokenIdsLengthNotZero(uint256[] memory _tokenIds) {
        if (_tokenIds.length == 0) {
            revert DZapNftStake_TokenIdsLengthZero();
        }
        _;
    }

    /////////////////
    // Functions   //
    /////////////////

    constructor(address _rewardTokenContract) {
        i_rewardToken = IERC20(_rewardTokenContract);
    }

    /////////////////////////////////////
    //  Public and External functions  //
    /////////////////////////////////////

    function stakeNft(address _nftContract, uint256[] memory _tokenIds)
        public
        AddressMustNotZero(_nftContract)
        TokenIdsLengthNotZero(_tokenIds)
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            IERC721 nftContract = IERC721(_nftContract);

            if (nftContract.ownerOf(_tokenIds[i]) != msg.sender) {
                revert DZapNftStake_NotOwnerOfTokenId();
            }

            //transfer nfts to contract
            nftContract.transferFrom(msg.sender, address(this), _tokenIds[i]);

            //push the staked nft data in userStakedNfts
            s_userStakedNfts[msg.sender].push(
                StakedNftData({
                    owner: msg.sender,
                    tokenId: _tokenIds[i],
                    stakedAt: block.timestamp,
                    lastClaimedAt: block.timestamp,
                    isUnbonding: false,
                    unbondingStart: 0
                })
            );
        }
        emit NftStaked(msg.sender, _tokenIds);
    }

    function unstakeNft(address _nftContract, uint256[] memory _tokenIds)
        public
        AddressMustNotZero(_nftContract)
        TokenIdsLengthNotZero(_tokenIds)
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < s_userStakedNfts[msg.sender].length; j++) {
                if (
                    s_userStakedNfts[msg.sender][j].tokenId == _tokenIds[i]
                        && s_userStakedNfts[msg.sender][j].isUnbonding == false
                ) {
                    s_userStakedNfts[msg.sender][j].isUnbonding = true;
                    s_userStakedNfts[msg.sender][j].unbondingStart = block.timestamp;
                    found = true;
                    emit NftUnstaked(msg.sender, _tokenIds[i]);
                    break;
                }
            }
            if (!found) {
                emit NftNotFoundOrAlreadyUnbounded();
            }
        }
    }

    ///////////////////////////////////////
    // Private and Internal Functions     //
    /////////////////////////////////////////

    ////////////////////////////////////////////
    // Public and External view Functions     //
    ///////////////////////////////////////////
}
