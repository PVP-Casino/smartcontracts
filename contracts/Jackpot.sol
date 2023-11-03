// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IRewardPool.sol";

contract Jackpot is zContract, ReentrancyGuard, Ownable {
    SystemContract public immutable systemContract;

    modifier onlySystem() {
        require(
            msg.sender == address(systemContract),
            "Only system contract can call this function"
        );
        _;
    }

    enum STATE {
        WAITING,
        STARTED,
        LIVE,
        CALCULATING_WINNER
    }

    struct Entry {
        address player;
        uint256 amount;
    }

    address public tokenAddress;
    uint8 public tokenDecimal;

    STATE public roundStatus;
    uint256 public entryIds;
    uint256 public roundIds;
    uint256 public roundDuration;
    uint256 public roundStartTime;
    uint256 public roundLiveTime;
    uint256 public minEntranceAmount;
    uint256 public currentEntryCount;
    Entry[] public currentEntries;

    uint256 public totalEntryAmount;
    uint256 public nonce;
    uint256 public calculateIndex;

    address public rewardPoolAddr;
    uint256 public fee = 3;

    constructor(
        address _tokenAddr,
        address _rewardPoolAddr,
        address systemContractAddress
    ) {
        tokenAddress = _tokenAddr;
        rewardPoolAddr = _rewardPoolAddr;

        tokenDecimal = IERC20(tokenAddress).decimals();
        roundStatus = STATE.WAITING;
        roundDuration = 5; // 5 secs
        roundIds = 1;

        minEntranceAmount = 2 * 10 ** tokenDecimal; // 2 ZETAP
        systemContract = SystemContract(systemContractAddress);
    }

    modifier excludeContract() {
        require(tx.origin == msg.sender, "Contract");
        _;
    }

    event EnteredPot(
        uint256 indexed roundId,
        uint256 indexed entryId,
        address indexed player,
        uint256 amount
    );
    event StartedCalculating(uint256 indexed roundId);
    event CalculateWinner(
        uint256 indexed roundId,
        address indexed winner,
        uint256 reward,
        uint256 total,
        uint256 user
    );

    function enterPot(uint256 _amount) public excludeContract {
        unchecked {
            require(_amount >= minEntranceAmount, "Min");
            require(
                roundLiveTime == 0 ||
                    block.timestamp <= roundLiveTime + roundDuration,
                "ended"
            );

            IERC20 token = IERC20(tokenAddress);
            uint256 beforeBalance = token.balanceOf(address(this));
            token.transferFrom(msg.sender, address(this), _amount);
            uint256 rAmount = token.balanceOf(address(this)) - beforeBalance;

            uint256 count = currentEntryCount;
            if (currentEntries.length == count) {
                currentEntries.push();
            }

            Entry storage entry = currentEntries[count];
            entry.player = msg.sender;
            entry.amount = rAmount;
            ++currentEntryCount;
            ++entryIds;
            totalEntryAmount = totalEntryAmount + rAmount;

            if (
                currentEntryCount >= 2 &&
                currentEntries[count - 1].player != msg.sender &&
                roundStatus == STATE.STARTED
            ) {
                roundStatus = STATE.LIVE;
                roundLiveTime = block.timestamp;
            } else if (currentEntryCount == 1) {
                roundStatus = STATE.STARTED;
                roundStartTime = block.timestamp;
            }

            emit EnteredPot(roundIds, entryIds, msg.sender, rAmount);
        }
    }

    function calculateWinner() public {
        bool isRoundEnded = roundStatus == STATE.LIVE &&
            roundLiveTime + roundDuration < block.timestamp;
        require(
            isRoundEnded || roundStatus == STATE.CALCULATING_WINNER,
            "Not ended"
        );

        if (isRoundEnded) {
            nonce = fullFillRandomness() % totalEntryAmount;
            calculateIndex = 0;
        }
        (address winner, uint256 index) = determineWinner();
        if (winner != address(0)) {
            IERC20 token = IERC20(tokenAddress);
            uint256 feeAmount = (totalEntryAmount * fee) / 1000;
            uint256 reward = totalEntryAmount - feeAmount;

            token.transfer(winner, reward);
            IERC20(tokenAddress).approve(rewardPoolAddr, feeAmount);
            IRewardPool(rewardPoolAddr).addReward(feeAmount);

            emit CalculateWinner(
                roundIds,
                winner,
                reward,
                totalEntryAmount,
                _getUserAmount(winner)
            );

            initializeRound();
        } else {
            roundStatus = STATE.CALCULATING_WINNER;
            emit StartedCalculating(roundIds);
        }
    }

    function _getUserAmount(
        address user
    ) internal view returns (uint256 value) {
        uint256 length = currentEntryCount;
        for (uint256 i = 0; i < length; i++) {
            if (currentEntries[i].player == user)
                value += currentEntries[i].amount;
        }
    }

    /**
     * @dev Attempts to select a random winner
     */
    function determineWinner()
        internal
        returns (address winner, uint256 winnerIndex)
    {
        uint256 start = calculateIndex;
        uint256 length = currentEntryCount;
        uint256 _nonce = nonce;
        for (
            uint256 index = 0;
            index < 3000 && (start + index) < length;
            index++
        ) {
            uint256 amount = currentEntries[start + index].amount;
            if (_nonce <= amount) {
                //That means that the winner has been found here
                winner = currentEntries[start + index].player;
                winnerIndex = start + index;
                return (winner, winnerIndex);
            }
            _nonce -= amount;
        }
        nonce = _nonce;
        calculateIndex = start + 3000;
    }

    function initializeRound() internal {
        delete currentEntryCount;
        delete roundLiveTime;
        delete roundStartTime;
        delete totalEntryAmount;
        roundStatus = STATE.WAITING;
        ++roundIds;
    }

    /**   @dev generates a random number
     */
    function fullFillRandomness() internal view returns (uint256) {
        return
            uint256(
                uint128(
                    bytes16(
                        keccak256(
                            abi.encodePacked(block.difficulty, block.timestamp)
                        )
                    )
                )
            );
    }

    /**
     * @dev returns status of current round
     */
    function getRoundStatus()
        external
        view
        returns (
            uint256 _roundIds,
            STATE _roundStatus,
            uint256 _roundStartTime,
            uint256 _roundLiveTime,
            uint256 _roundDuration,
            uint256 _totalAmount,
            uint256 _entryCount,
            uint256 _minEntranceAmount
        )
    {
        _roundIds = roundIds;
        _roundStatus = roundStatus;
        _roundLiveTime = roundLiveTime;
        _roundStartTime = roundStartTime;
        _roundDuration = roundDuration;
        _minEntranceAmount = minEntranceAmount;
        _totalAmount = totalEntryAmount;
        _entryCount = currentEntryCount;
    }

    function setRoundDuration(uint256 value) external onlyOwner {
        roundDuration = value;
    }

    function setFeePercent(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setTokenAddress(address addr) external onlyOwner {
        tokenAddress = addr;
    }

    function withdrawETH(address receiver, uint256 amount) external onlyOwner {
        bool sent = payable(receiver).send(amount);
        require(sent, "fail");
    }

    function withdrawToken(
        address receiver,
        address _tokenAddr,
        uint256 amount
    ) external onlyOwner {
        if (_tokenAddr == tokenAddress) {
            uint256 balance = IERC20(_tokenAddr).balanceOf(address(this));
            require(balance >= totalEntryAmount + amount, "f");
        }

        IERC20(_tokenAddr).transfer(receiver, amount);
    }

    function setMinimumEntranceAmount(uint256 amount) external onlyOwner {
        minEntranceAmount = amount;
    }

    function setRewardPoolAddress(address addr) external onlyOwner {
        rewardPoolAddr = addr;
    }

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override onlySystem {
        // TODO: implement the logic
    }
}
