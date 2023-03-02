# Solidity API

## IStakingRewards

### lastTimeRewardApplicable

```solidity
function lastTimeRewardApplicable() external view returns (uint256)
```

### rewardPerToken

```solidity
function rewardPerToken() external view returns (uint256)
```

### earned

```solidity
function earned(address account) external view returns (uint256)
```

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```

### stake

```solidity
function stake(uint256 amount) external
```

### withdraw

```solidity
function withdraw(uint256 amount) external
```

### getReward

```solidity
function getReward() external
```

### exit

```solidity
function exit() external
```

## RewardsDistributionRecipient

### rewardsDistribution

```solidity
address rewardsDistribution
```

### notifyRewardAmount

```solidity
function notifyRewardAmount(uint256 reward, uint256 duration) external virtual
```

### onlyRewardsDistribution

```solidity
modifier onlyRewardsDistribution()
```

## StakingRewards

### rewardsToken

```solidity
contract IERC20 rewardsToken
```

### stakingToken

```solidity
contract IERC20 stakingToken
```

### periodFinish

```solidity
uint256 periodFinish
```

### rewardRate

```solidity
uint256 rewardRate
```

### lastUpdateTime

```solidity
uint256 lastUpdateTime
```

### rewardPerTokenStored

```solidity
uint256 rewardPerTokenStored
```

### userRewardPerTokenPaid

```solidity
mapping(address => uint256) userRewardPerTokenPaid
```

### rewards

```solidity
mapping(address => uint256) rewards
```

### _totalSupply

```solidity
uint256 _totalSupply
```

### _balances

```solidity
mapping(address => uint256) _balances
```

### constructor

```solidity
constructor(address _rewardsDistribution, address _rewardsToken, address _stakingToken) public
```

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```

### lastTimeRewardApplicable

```solidity
function lastTimeRewardApplicable() public view returns (uint256)
```

### rewardPerToken

```solidity
function rewardPerToken() public view returns (uint256)
```

### earned

```solidity
function earned(address account) public view returns (uint256)
```

### stakeWithPermit

```solidity
function stakeWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external
```

### stake

```solidity
function stake(uint256 amount) external
```

### withdraw

```solidity
function withdraw(uint256 amount) public
```

### getReward

```solidity
function getReward() public
```

### exit

```solidity
function exit() external
```

### notifyRewardAmount

```solidity
function notifyRewardAmount(uint256 reward, uint256 rewardsDuration) external
```

### updateReward

```solidity
modifier updateReward(address account)
```

### RewardAdded

```solidity
event RewardAdded(uint256 reward, uint256 periodFinish)
```

### Staked

```solidity
event Staked(address user, uint256 amount)
```

### Withdrawn

```solidity
event Withdrawn(address user, uint256 amount)
```

### RewardPaid

```solidity
event RewardPaid(address user, uint256 reward)
```

## IUniswapV2ERC20

### permit

```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external
```

