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
import {IRewardToken} from "./interfaces/IRewardToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DZapNftStake is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /////////////////
    // Errors      //
    /////////////////
    error DZapNftStake_InvalidAddress();
    error DZapNftStake_TokenIdsLengthZero();
    error DZapNftStake_NotOwnerOfTokenId();
    error DZapNftStake_NFTNotFoundOrAlreadyUnbonded();
    error DZapNftStake_ContractAlreadyInitialized();
    error DZapNftStake_UnbondPeriodNotOver();
    error DZapNftStake_NoRewardToClaim();
    error DZapNftStake_StakingPaused();
    error DZapNftStake_NotAnOwner();

    ///////////////////////////
    // State variables      //
    ///////////////////////////
    uint256 private constant UNBONDING_PERIOD = 2 minutes;
    uint256 private constant DELAY_PERIOD = 1 minutes;

    IRewardToken private i_rewardToken;
    bool private s_paused;
    uint256 private s_rewardRate;
    bool private s_initialized = false;

    struct StakedNftData {
        address owner;
        uint256 tokenId;
        uint256 stakedAt;
        uint256 lastClaimedAt;
        bool isUnbonding;
        uint256 unbondingStart;
    }

    mapping(address user => StakedNftData[] stakedNfts) private s_userStakedNfts;
    mapping(address => uint256) private s_pendingRewards;

    ///////////////////////////
    // Events                //
    ///////////////////////////

    event NftStaked(address indexed user, uint256[] indexed tokenIds);
    event NftUnstaked(address indexed user, uint256 indexed tokenId);
    event RewardClaimed(address indexed user, uint256 amount);
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

    modifier onlyWhenNotPaused() {
        if (s_paused) {
            revert DZapNftStake_StakingPaused();
        }
        _;
    }

    /////////////////
    // Functions   //
    /////////////////

    function initialize(address i_rewardTokenContract) public initializer {
        if (s_initialized) {
            revert DZapNftStake_ContractAlreadyInitialized();
        }
        s_initialized = true;
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        i_rewardToken = IRewardToken(i_rewardTokenContract);
        s_paused = false;
        s_rewardRate = 4;
    }

    /////////////////////////////////////
    //  Public and External functions  //
    /////////////////////////////////////

    function stakeNft(address _nftContract, uint256[] memory _tokenIds)
        public
        AddressMustNotZero(_nftContract)
        TokenIdsLengthNotZero(_tokenIds)
        onlyWhenNotPaused
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            IERC721 nftContract = IERC721(_nftContract);

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

    function withdrawNFT(address _nftContract, uint256 _tokenId) public {
        (bool found, uint256 index) = _findStakedNftIndex(msg.sender, _tokenId);
        if (found) {
            StakedNftData memory stakedNft = s_userStakedNfts[msg.sender][index];
            if (!(block.timestamp >= stakedNft.unbondingStart + UNBONDING_PERIOD)) {
                revert DZapNftStake_UnbondPeriodNotOver();
            }
            //remove NFT from the record

            s_userStakedNfts[msg.sender][index] = s_userStakedNfts[msg.sender][s_userStakedNfts[msg.sender].length - 1];
            s_userStakedNfts[msg.sender].pop();

            //tansfer back the nft to user
            IERC721 nftContract = IERC721(_nftContract);
            nftContract.transferFrom(address(this), msg.sender, _tokenId);
        }
    }

    function claimRewards() external {
        uint256 userRewards = _calculateRewards(msg.sender);

        if (userRewards <= 0) {
            revert DZapNftStake_NoRewardToClaim();
        }
        s_pendingRewards[msg.sender] = 0;
        i_rewardToken.mint(msg.sender, userRewards);

        emit RewardClaimed(msg.sender, userRewards);
    }

    function pauseStaking() external onlyOwner {
        s_paused = true;
    }

    function unpauseStaking() external onlyOwner {
        s_paused = false;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        s_rewardRate = _rewardRate;
    }

    ///////////////////////////////////////
    // Private and Internal Functions     //
    /////////////////////////////////////////
    function _findStakedNftIndex(address _user, uint256 _tokenId) internal view returns (bool, uint256) {
        for (uint256 i = 0; i < s_userStakedNfts[_user].length; i++) {
            if (s_userStakedNfts[_user][i].tokenId == _tokenId) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function _calculateRewards(address user) internal returns (uint256) {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < s_userStakedNfts[user].length; i++) {
            StakedNftData memory stakedNFT = s_userStakedNfts[user][i];

            if (stakedNFT.unbondingStart + UNBONDING_PERIOD > block.timestamp) {
                continue;
            }
            if ((block.timestamp >= stakedNFT.lastClaimedAt + DELAY_PERIOD)) {
                uint256 rewards = (block.timestamp - stakedNFT.lastClaimedAt) * s_rewardRate;
                totalRewards += rewards;
                s_userStakedNfts[user][i].lastClaimedAt = block.timestamp;
            }
        }

        return totalRewards;
    }

    function _authorizeUpgrade(address newImplementation) internal view override {}

    ////////////////////////////////////////////
    // Public and External view Functions     //
    ///////////////////////////////////////////
    function getUserStakedNftData(address _user) public view returns (StakedNftData[] memory) {
        return s_userStakedNfts[_user];
    }

    function getStakingStatus() public view returns (bool) {
        return s_paused;
    }

    function getRewardRate() public view returns (uint256) {
        return s_rewardRate;
    }
}
