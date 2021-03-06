// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8;

contract StakeManager {

    /// minimum number of blocks to after 'unlock' before amount can be withdrawn.
    uint32 immutable public unstakeDelayBlocks;

    constructor(uint32 _unstakeDelayBlocks) {
        unstakeDelayBlocks = _unstakeDelayBlocks;
    }

    event StakeAdded(
        address indexed paymaster,
        uint256 totalStake
    );

    /// Emitted once a stake is scheduled for withdrawal
    event StakeUnlocking(
        address indexed paymaster,
        uint256 withdrawBlock
    );

    event StakeWithdrawn(
        address indexed paymaster,
        address withdrawAddress,
        uint256 amount
    );

    /// @param stake - amount of ether staked for this paymaster
    /// @param withdrawStake - once 'unlocked' the value is no longer staked.
    /// @param withdrawBlock - first block number 'withdraw' will be callable, or zero if the unlock has not been called
    struct StakeInfo {
        uint112 stake;
        uint112 withdrawStake;
        uint32 withdrawBlock;
    }

    /// maps relay managers to their stakes
    mapping(address => StakeInfo) public stakes;

    function getStakeInfo(address paymaster) external view returns (StakeInfo memory stakeInfo) {
        return stakes[paymaster];
    }

    /**
     * add stake value for this paymaster.
     * cancel any pending unlock
     */
    function addStake() external payable {
        stakes[msg.sender].stake = uint112(stakes[msg.sender].stake + msg.value + stakes[msg.sender].withdrawStake);
        stakes[msg.sender].withdrawStake = 0;
        stakes[msg.sender].withdrawBlock = 0;
        emit StakeAdded(msg.sender, stakes[msg.sender].stake);
    }

    function unlockStake() external {
        StakeInfo storage info = stakes[msg.sender];
        require(info.withdrawBlock == 0, "already pending");
        require(info.stake != 0, "no stake to unlock");
        uint32 withdrawBlock = uint32(block.number) + unstakeDelayBlocks;
        info.withdrawBlock = withdrawBlock;
        info.withdrawStake = info.stake;
        info.stake = 0;
        emit StakeUnlocking(msg.sender, withdrawBlock);
    }

    function withdrawStake(address payable withdrawAddress) external {
        StakeInfo storage info = stakes[msg.sender];
        require(info.withdrawStake > 0, "no unlocked stake");
        require(info.withdrawBlock <= block.number, "Withdrawal is not due");
        uint256 amount = info.withdrawStake;
        info.withdrawStake = 0;
        withdrawAddress.transfer(amount);
        info.withdrawBlock = 0;
        emit StakeWithdrawn(msg.sender, withdrawAddress, amount);
    }


    function isPaymasterStaked(address paymaster, uint requiredStake) public view returns (bool) {
        return stakes[paymaster].stake >= requiredStake;
    }
}
