// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "./interfaces/IUniswapV2ERC20.sol";

contract Staking is ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */

    struct PoolInfo {
        uint256 totalSupply;
        address rewardsDistribution;
        address[] rewardTokens;
        mapping(address => mapping(address => uint256)) userRewardPerTokenPaid;
        mapping(address => mapping(address => uint256)) rewards;
        mapping(address => uint256) balances;
        mapping(address => uint256) periodFinish;
        mapping(address => uint256) lastUpdateTime;
        mapping(address => uint256) rewardRate;
        mapping(address => uint256) rewardPerTokenStored;
        mapping(address => uint256) availableRewards;
    }

    mapping(address => PoolInfo) public poolInfo;

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _rewardsDistribution,
        address[] calldata _rewardsTokens,
        address _stakingToken,
        uint256[] calldata _rewardsAmounts,
        uint256 _rewardsDuration
    ) initializer public {
        __ReentrancyGuard_init();
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        PoolInfo storage pool = poolInfo[_stakingToken];
        pool.rewardsDistribution = _rewardsDistribution;
        addNewPool(_stakingToken, _rewardsTokens);
        for (uint256 i = 0; i < _rewardsTokens.length; i++) {
            addRewardsToPool(_stakingToken, _rewardsTokens[i], _rewardsAmounts[i], _rewardsDuration);
        }
    }

    /* ========== VIEWS ========== */

    function totalSupply(address stakingToken) external view returns (uint256) {
        return poolInfo[stakingToken].totalSupply;
    }

    function balanceOf(address stakingToken, address account) external view returns (uint256) {
        return poolInfo[stakingToken].balances[account];
    }

    function lastTimeRewardApplicable(address stakingToken, address rewardToken) public view returns (uint256) {
        return Math.min(block.timestamp, poolInfo[stakingToken].periodFinish[rewardToken]);
    }

    function rewardPerToken(address stakingToken, address rewardToken) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[stakingToken];
        if (pool.totalSupply == 0) {
            return pool.rewardPerTokenStored[rewardToken];
        }
        return
            pool.rewardPerTokenStored[rewardToken].add(
                lastTimeRewardApplicable(stakingToken, rewardToken).sub(pool.lastUpdateTime[rewardToken]).mul(pool.rewardRate[rewardToken]).mul(1e18).div(pool.totalSupply)
            );
    }

    function earned(address stakingToken, address rewardToken, address account) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[stakingToken];
        return
            pool.balances[account]
                .mul(rewardPerToken(stakingToken, rewardToken).sub(pool.userRewardPerTokenPaid[account][rewardToken]))
                .div(1e18)
                .add(pool.rewards[rewardToken][account]);
    }

    function getUserRewardsInfo(address stakingToken, address account) external view returns (uint256, uint256[] memory) {
        PoolInfo storage pool = poolInfo[stakingToken];
        uint256[] memory rewards = new uint256[](pool.rewardTokens.length);
        for (uint256 i = 0; i < pool.rewardTokens.length; i++) {
            rewards[i] = earned(stakingToken, pool.rewardTokens[i], account);
        }
        return (pool.balances[account], rewards);
    }

    function getRewardTokenState(address stakingToken, address rewardToken) external view returns (uint256, uint256, uint256, uint256) {
        PoolInfo storage pool = poolInfo[stakingToken];
        return (
            pool.availableRewards[rewardToken],
            pool.rewardRate[rewardToken],
            pool.lastUpdateTime[rewardToken],
            pool.periodFinish[rewardToken]
        );
    }

    /* ========== ADMIN FUNCTIONS ========== */

    function addNewPool(address _stakingToken, address[] memory _rewardsTokens) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(poolInfo[_stakingToken].rewardTokens.length == 0, "Pool already exists");
        poolInfo[_stakingToken].rewardTokens = _rewardsTokens;
        emit AddPool(_stakingToken, _rewardsTokens);
    }

    function addRewardsToPool(address stakingToken, address rewardToken, uint256 amount, uint256 rewardsDuration) public onlyRole(DEFAULT_ADMIN_ROLE) {
        PoolInfo storage pool = poolInfo[stakingToken];
        IERC20Upgradeable(rewardToken).safeTransferFrom(msg.sender, address(this), amount);
        pool.availableRewards[rewardToken] = pool.availableRewards[rewardToken].add(amount);
        notifyRewardAmount(stakingToken, rewardToken, amount, rewardsDuration);
    }

    function withrawUnusedRewards(address stakingToken, address rewardToken, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        PoolInfo storage pool = poolInfo[stakingToken];
        require(pool.availableRewards[rewardToken] >= amount, "Not enough rewards");
        pool.availableRewards[rewardToken] = pool.availableRewards[rewardToken].sub(amount);
        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, amount);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stakeWithPermit(address stakingToken, uint256 amount, uint deadline, uint8 v, bytes32 r, bytes32 s) external nonReentrant updateRewards(stakingToken, msg.sender) {
        require(amount > 0, "Cannot stake 0");
        PoolInfo storage pool = poolInfo[stakingToken];
        pool.totalSupply = pool.totalSupply.add(amount);
        pool.balances[msg.sender] = pool.balances[msg.sender].add(amount);

        // permit
        IUniswapV2ERC20(address(stakingToken)).permit(msg.sender, address(this), amount, deadline, v, r, s);

        IERC20Upgradeable(stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(stakingToken, msg.sender, amount);
    }

    function stake(address stakingToken, uint256 amount) external nonReentrant updateRewards(stakingToken, msg.sender) {
        require(amount > 0, "Cannot stake 0");
        PoolInfo storage pool = poolInfo[stakingToken];
        require(pool.rewardsDistribution != address(0), "Pool does not exist");
        pool.totalSupply = pool.totalSupply.add(amount);
        pool.balances[msg.sender] = pool.balances[msg.sender].add(amount);
        IERC20Upgradeable(stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(stakingToken, msg.sender, amount);
    }

    function withdraw(address stakingToken, uint256 amount) public nonReentrant updateRewards(stakingToken, msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        PoolInfo storage pool = poolInfo[stakingToken];
        require(pool.rewardsDistribution != address(0), "Pool does not exist");
        pool.totalSupply = pool.totalSupply.sub(amount);
        pool.balances[msg.sender] = pool.balances[msg.sender].sub(amount);
        IERC20Upgradeable(stakingToken).safeTransfer(msg.sender, amount);
        emit Withdrawn(stakingToken, msg.sender, amount);
    }

    function getRewards(address stakingToken) public nonReentrant updateRewards(stakingToken, msg.sender) {
        PoolInfo storage pool = poolInfo[stakingToken];
        for (uint256 i = 0; i < pool.rewardTokens.length; i++) {
            address rewardToken = pool.rewardTokens[i];
            uint256 reward = pool.rewards[rewardToken][msg.sender];
            if (reward > 0) {
                pool.rewards[rewardToken][msg.sender] = 0;
                require(pool.availableRewards[rewardToken] >= reward, string(
                    abi.encodePacked(
                        "Not enough rewards, available: ",
                        StringsUpgradeable.toString(pool.availableRewards[rewardToken]),
                        ", requested: ",
                        StringsUpgradeable.toString(reward)
                    ))
                );
                pool.availableRewards[rewardToken] = pool.availableRewards[rewardToken].sub(reward);
                IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(stakingToken, msg.sender, rewardToken, reward);
            }
        }
    }

    function exit(address stakingToken) external {
        require(earned(stakingToken, poolInfo[stakingToken].rewardTokens[0], msg.sender) > 0, "123");
        getRewards(stakingToken);
        withdraw(stakingToken, poolInfo[stakingToken].balances[msg.sender]);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(address stakingToken, address rewardToken, uint256 reward, uint256 rewardsDuration) internal updateRewards(stakingToken, address(0)) {
        PoolInfo storage pool = poolInfo[stakingToken];
        require(block.timestamp.add(rewardsDuration) >= pool.periodFinish[rewardToken], "Cannot reduce existing period");

        if (block.timestamp >= pool.periodFinish[rewardToken]) {
            pool.rewardRate[rewardToken] = reward.div(rewardsDuration);
        } else {
            uint256 remaining = pool.periodFinish[rewardToken].sub(block.timestamp);
            uint256 leftover = remaining.mul(pool.rewardRate[rewardToken]);
            pool.rewardRate[rewardToken] = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = pool.availableRewards[rewardToken];
        require(pool.rewardRate[rewardToken] <= balance.div(rewardsDuration), 
            "Provided reward too high"
        );
        pool.lastUpdateTime[rewardToken] = block.timestamp;
        pool.periodFinish[rewardToken] = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward, pool.periodFinish[rewardToken]);
    }

    /* ========== MODIFIERS ========== */

    modifier updateRewards(address stakingToken, address account) {
        PoolInfo storage pool = poolInfo[stakingToken];
        if (account != address(0)) {
            for (uint256 i = 0; i < pool.rewardTokens.length; i++) {
                pool.rewardPerTokenStored[pool.rewardTokens[i]] = rewardPerToken(stakingToken, pool.rewardTokens[i]);
                pool.lastUpdateTime[pool.rewardTokens[i]] = lastTimeRewardApplicable(stakingToken, pool.rewardTokens[i]);
                pool.rewards[pool.rewardTokens[i]][account] = earned(stakingToken, pool.rewardTokens[i], account);
                pool.userRewardPerTokenPaid[account][pool.rewardTokens[i]] = pool.rewardPerTokenStored[pool.rewardTokens[i]];
            }
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward, uint256 periodFinish);
    event Staked(address indexed stakingToken, address indexed user, uint256 amount);
    event Withdrawn(address indexed stakingToken, address indexed user, uint256 amount);
    event RewardPaid(address indexed stakingToken, address indexed user, address rewardToken, uint256 reward);
    event AddPool(address indexed stakingToken, address[] rewardTokens);
}
