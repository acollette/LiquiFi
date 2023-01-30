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


// ============================ Interfaces ========================

// ============================ Contract ==========================

/// @title LiquiDeFi protocol
/// @author LiquiDeFi Protocol core team 

contract GoldfinchPool is ERC721 {

    using SafeERC20 for IERC20;

    // ============================ State Variables ====================

    address stablecoin;
    uint256 tokenCount;

    struct LpPosition {
        uint256 amount;
        uint256 timeStamp;   
    }

    mapping (uint256 => LpPosition) public tokenIdToPosition;


    // ============================ Constructor ========================

    constructor(address _stablecoin) ERC721("NFT", "NFT") {
        stablecoin = _stablecoin;
    }

    // ============================ Functions ==========================

    function depositFunds(uint256 amount) external {
        tokenCount++;

        LpPosition storage p = tokenIdToPosition[tokenCount];
        p.amount = amount;
        p.timeStamp = block.timestamp;

        IERC20(stablecoin).safeTransferFrom(_msgSender(), address(this), amount);
        _safeMint(_msgSender(), tokenCount);

    }

    function claimRewards() external {
        IERC20(stablecoin).safeTransfer(_msgSender(), IERC20(stablecoin).balanceOf(address(this)));
    }

}