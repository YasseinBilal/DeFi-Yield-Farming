// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimplifiedYieldFarm is ERC4626, ReentrancyGuard, Ownable {
    uint256 public totalRewards; // Total rewards available for distribution
    uint256 public rewardPerShare; // Accumulated rewards per share, scaled by 1e18

    mapping(address => uint256) public userRewards; // Tracks user's unclaimed rewards

    constructor(
        IERC20 _underlyingToken,
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC4626(_underlyingToken) ERC20(name, symbol) Ownable(initialOwner) {}

    /**
     * @notice Fund rewards for distribution to users.
     * @param rewardAmount The total amount of vault shares to be distributed as rewards.
     */
    function fundRewards(uint256 rewardAmount) external onlyOwner {
        require(rewardAmount > 0, "Invalid reward amount");
        require(totalSupply() > 0, "No shares to distribute rewards to");

        totalRewards += rewardAmount;

        // Mint reward tokens to the contract itself
        _mint(address(this), rewardAmount);
    }

    /**
     * @notice Calculate pending rewards for a user.
     * @param account The user's address.
     */
    function _calculatePendingReward(
        address account
    ) internal view returns (uint256) {
        uint256 accumulatedReward = (balanceOf(account) * rewardPerShare) /
            1e18;
        return accumulatedReward - userRewards[account];
    }

    /**
     * @notice Update reward calculations before any deposit/withdraw actions.
     */
    modifier updateRewards(address account) {
        if (totalSupply() > 0) {
            rewardPerShare += (totalRewards * 1e18) / totalSupply();
            totalRewards = 0; // Reset rewards pool after updating
        }
        if (account != address(0)) {
            userRewards[account] += _calculatePendingReward(account);
        }
        _;
    }

    /**
     * @notice Deposit underlying tokens and update rewards.
     */
    function deposit(
        uint256 assets,
        address receiver
    ) public override nonReentrant updateRewards(receiver) returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /**
     * @notice Withdraw underlying tokens and update rewards.
     */
    function withdraw(
        uint256 shares,
        address receiver,
        address owner
    ) public override nonReentrant updateRewards(owner) returns (uint256) {
        return super.withdraw(shares, receiver, owner);
    }

    /**
     * @notice Claim rewards for the caller in the form of vault shares.
     */
    function claimRewards() external nonReentrant updateRewards(msg.sender) {
        uint256 rewards = userRewards[msg.sender];
        require(rewards > 0, "No rewards to claim");

        userRewards[msg.sender] = 0;
        _mint(msg.sender, rewards); // Mint vault shares as rewards
    }
}
