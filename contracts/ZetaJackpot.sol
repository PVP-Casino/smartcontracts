// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IRewardPool.sol";

contract ZetaJackpot is zContract, ReentrancyGuard, Ownable {
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

    uint8 public constant tokenDecimal = 18;

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

    constructor(address _rewardPoolAddr, address systemContractAddress) {
        rewardPoolAddr = _rewardPoolAddr;
        roundStatus = STATE.WAITING;
        roundDuration = 120; // 5 secs
        roundIds = 1;

        minEntranceAmount = 0 * 10 ** tokenDecimal; // 2 ZETAP
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

    function enterPot(uint256 _amount) public payable excludeContract {
        require(_amount == msg.value, "not correct amount");
        require(_amount >= minEntranceAmount, "Min");
        require(
            roundLiveTime == 0 ||
                block.timestamp <= roundLiveTime + roundDuration,
            "ended"
        );

        uint256 rAmount = msg.value;

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

    function calculateWinner() public nonReentrant {
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
            uint256 feeAmount = (totalEntryAmount * fee) / 1000;
            uint256 reward = totalEntryAmount - feeAmount;

            payable(winner).transfer(reward);
            IRewardPool(rewardPoolAddr).addRewardWithNativeCoin{
                value: feeAmount
            }();

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

    function withdrawETH(
        address receiver,
        uint256 amount
    ) external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance >= totalEntryAmount + amount, "f");
        payable(receiver).transfer(amount);
    }

    function withdrawToken(
        address receiver,
        address _tokenAddr,
        uint256 amount
    ) external onlyOwner {
        // if (_tokenAddr == tokenAddress) {
        //     uint256 balance = IERC20(_tokenAddr).balanceOf(address(this));
        //     require(balance >= totalEntryAmount + amount, "f");
        // }

        IERC20(_tokenAddr).transfer(receiver, amount);
    }

    receive() external payable {
        enterPot(msg.value);
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
