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
    error DZapNftStake_DelayPeriodNotOver();

    ///////////////////////////
    // State variables      //
    ///////////////////////////
    uint256 private constant UNBONDING_PERIOD = 2 minutes;
    uint256 private constant DELAY_PERIOD = 1 minutes;
    uint256 private constant PRECISION = 1e18;

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
        uint256 lastClaimedBlock;
        uint256 blockNumberWhenUnbondingStarted;
    }

    mapping(address user => StakedNftData[] stakedNfts) private s_userStakedNfts;

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
        s_rewardRate = 4 * PRECISION;
    }

    /////////////////////////////////////
    //  Public and External functions  //
    /////////////////////////////////////

    /**
     * @notice Stakes one or more NFTs from a specified contract.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenIds An array of token IDs to stake.
     * @dev The caller must be the owner of the NFTs being staked.
     * @dev The NFT contract must be a valid ERC721 contract.
     * @dev The contract must not be paused.
     * @dev Emits a {NftStaked} event.
     */
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
                    unbondingStart: 0,
                    lastClaimedBlock: block.number,
                    blockNumberWhenUnbondingStarted: block.number
                })
            );
        }
        emit NftStaked(msg.sender, _tokenIds);
    }

    /**
     * @notice Initiates the unstaking process for one or more NFTs from a specified contract.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenIds An array of token IDs to unstake.
     * @dev The caller must be the owner of the NFTs being unstaked.
     * @dev The NFT contract must be a valid ERC721 contract.
     * @dev The NFTs must be currently staked and not already in the process of being unstaked.
     * @dev Emits a {NftUnstaked} event for each NFT that is successfully unstaked.
     * @dev Emits a {NftNotFoundOrAlreadyUnbounded} event for each NFT that is not found or is already being unstaked.
     */
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
                    s_userStakedNfts[msg.sender][j].blockNumberWhenUnbondingStarted = block.number;
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

    /**
     * @notice Withdraws a staked NFT after the unbonding period has ended.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT to withdraw.
     * @dev The caller must be the owner of the NFT.
     * @dev The NFT must be currently staked and in the process of being unstaked.
     * @dev The unbonding period must have ended.
     * @dev The NFT is transferred back to the caller.
     */
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

    /**
     * @notice Claims rewards for all staked NFTs after the delay period has ended.
     * @dev The caller must be the owner of the staked NFTs.
     * @dev The delay period must have ended since the last claim.
     * @dev Rewards are calculated based on the staked NFTs and minted to the caller.
     * @dev Emits a {RewardClaimed} event with the claimed reward amount.
     */
    function claimRewards() external {
        //claim rewards after Delay period over
        uint256 userRewards = 0;
        StakedNftData[] memory stakedNfts = s_userStakedNfts[msg.sender];
        for (uint256 i = 0; i < stakedNfts.length; i++) {
            StakedNftData memory stakedNft = stakedNfts[i];

            if (stakedNft.lastClaimedAt + DELAY_PERIOD > block.timestamp) {
                revert DZapNftStake_DelayPeriodNotOver();
            }

            userRewards += _calculateRewards(stakedNft);
            s_userStakedNfts[msg.sender][i].lastClaimedAt = block.timestamp;
            s_userStakedNfts[msg.sender][i].lastClaimedBlock = block.number;
        }

        if (userRewards <= 0) {
            revert DZapNftStake_NoRewardToClaim();
        }

        i_rewardToken.mint(msg.sender, userRewards);

        emit RewardClaimed(msg.sender, userRewards);
    }

    /**
     * @notice Pauses staking functionality.
     * @dev Only the contract owner can call this function.
     * @dev Sets the paused state to true, preventing new staking actions.
     */
    function pauseStaking() external onlyOwner {
        s_paused = true;
    }

    /**
     * @notice Unpauses staking functionality.
     * @dev Only the contract owner can call this function.
     * @dev Sets the paused state to false, re-enabling staking actions.
     */
    function unpauseStaking() external onlyOwner {
        s_paused = false;
    }

    /**
     * @notice Sets the reward rate for staked NFTs.
     * @param _tokenPerBlockInWei The new reward rate in wei per block.
     * @dev Only the contract owner can call this function.
     * @dev The reward rate is calculated by multiplying the input value by `PRECISION` and dividing by `PRECISION`.
     * @dev The reward rate affects the amount of rewards earned by staked NFTs.
     */
    function setRewardRate(uint256 _tokenPerBlockInWei) external onlyOwner {
        s_rewardRate = (_tokenPerBlockInWei * PRECISION) / PRECISION;
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

    function _calculateRewards(StakedNftData memory _stakedNft) internal view returns (uint256) {
        uint256 currentClaimedBlock = block.number;
        uint256 rewards = 0;
        if (_stakedNft.isUnbonding) {
            rewards = (
                ((_stakedNft.blockNumberWhenUnbondingStarted - _stakedNft.lastClaimedBlock) * s_rewardRate) * PRECISION
            ) / PRECISION;

            return rewards;
        } else {
            rewards = (((currentClaimedBlock - _stakedNft.lastClaimedBlock) * s_rewardRate) * PRECISION) / PRECISION;

            return rewards;
        }
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

    function getAccumulatedRewards(address user) public view returns (uint256) {
        StakedNftData[] memory stakedNfts = s_userStakedNfts[user];
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < stakedNfts.length; i++) {
            totalRewards += _calculateRewards(stakedNfts[i]);
        }
        return totalRewards;
    }
}
