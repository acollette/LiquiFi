// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

// ============================ Interfaces ========================

interface IGoldfinchPool {

    struct LpPosition {
        uint256 amount;
        uint256 timeStamp;
    }

    function tokenIdToPosition(uint256) external view returns (LpPosition memory);

    function claimRewards() external;
}

interface IStakingContract {
    function notifyRewardAmount(address, uint256) external;
}

// ============================ Contract ==========================

/// @title LiquiDeFi protocol
/// @author LiquiDeFi Protocol core team 

contract Wrapper is ERC20, Ownable, IERC721Receiver {

    using SafeERC20 for IERC20;


    // ============================ State Variables ====================

    IStakingContract stakingContract;

    address goldfinchPool;
    uint256 sellOrderID;
    address stablecoin;
    address rewards;

    struct SellOrder {
        address seller;
        uint256 price;
        uint256 amount;   
    }

    mapping (uint256 => SellOrder) public sellOrders;
    mapping (uint256 => address) public ownerOfSellOrder;


    // ============================ Constructor ========================

    constructor(
        address _goldfinchPool,
        address _stablecoin,
        address _rewards
    )
    ERC20("LiquiDeFi", "LQF")
    {
        goldfinchPool = _goldfinchPool;
        stablecoin = _stablecoin;
        rewards = _rewards;
    }

    // ============================ Functions ==========================

    function setStakingContract(address _stakingContract) public onlyOwner {
        stakingContract = IStakingContract(_stakingContract);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function depositERC721(uint256 tokenId) external {
        uint256 amountToMint = IGoldfinchPool(goldfinchPool).tokenIdToPosition(tokenId).amount;
        IERC721(goldfinchPool).safeTransferFrom(_msgSender(), address(this), tokenId);
        _mint(_msgSender(), amountToMint);
    }

    function sellTokens(uint256 amount, uint256 price) external {
        sellOrderID ++;

        SellOrder storage s = sellOrders[sellOrderID];
        s.seller = _msgSender();
        s.price = price;
        s.amount = amount;

        ownerOfSellOrder[sellOrderID] = _msgSender();

        IERC20(address(this)).safeTransferFrom(_msgSender(), address(this), amount);

    }

    function buyTokens(uint256 amount, uint256 orderID) external {
        require(amount < sellOrders[orderID].amount, "not enough tokens left to buy");
        sellOrders[orderID].amount -= amount;

        IERC20(address(this)).safeTransfer(_msgSender(), amount);
        IERC20(stablecoin).safeTransferFrom(_msgSender(), sellOrders[orderID].seller, (amount * sellOrders[orderID].price) / 10**18);

    }

    function claimRewardsOnGoldfinch() external {
        uint256 initBalance = IERC20(rewards).balanceOf(address(this));
        IGoldfinchPool(goldfinchPool).claimRewards();
        uint256 newBalance = IERC20(rewards).balanceOf(address(this));
        IERC20(rewards).safeApprove(address(stakingContract), (newBalance - initBalance));
        stakingContract.notifyRewardAmount(rewards, (newBalance - initBalance));
    }


}