// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

//standard test libs
import "../../lib/forge-std/src/Test.sol";
import "../../lib/forge-std/src/Vm.sol";

//librairies
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//contracts under test
import {StakingContract} from "../../contracts/StakingContract.sol";
import {GoldfinchPool} from  "../../contracts/GoldfinchPool.sol";
import {Wrapper} from "../../contracts/Wrapper.sol";

//interfaces
interface IGoldfinchPool {
    function depositFunds(uint256) external;
}

interface IWrapper {
    function depositERC721(uint256) external;
    function sellTokens(uint256, uint256) external;
    function buyTokens(uint256, uint256) external;
}

interface IStakingContract {
    function stake(uint256) external;
    function getReward() external;
}

contract Test_Liquify is Test {

    using SafeERC20 for IERC20;

    StakingContract private     stake;
    GoldfinchPool   private     pool;
    Wrapper         private     ERC20Wrapper;

    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address rewardsFRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

    address lp = 0x972eA38D8cEb5811b144AFccE5956a279E47ac46;
    address buyer = 0x5a29280d4668622ae19B8bd0bacE271F11Ac89dA;
    address user3 = 0x4e19DaF0ee9CD0cd06099b8E2228156150d2ae9e;


    constructor() {

    }

    // Helper Functions
    function depositPool(uint256 amount, address user) public {
        emit log_string("deposit amount in Goldfinch pool");
        emit log_named_uint("amount", amount);
        vm.startPrank(user);
        IERC20(DAI).safeApprove(address(pool), amount);
        IGoldfinchPool(address(pool)).depositFunds(amount);
        vm.stopPrank();
    }

    function wrapERC721(uint256 tokenID, address user) public {
        emit log_string("deposit ERC721 in wrapper contract and get ERC20 tokens");
        vm.startPrank(user);
        IERC721(pool).approve(address(ERC20Wrapper), tokenID);
        IWrapper(address(ERC20Wrapper)).depositERC721(tokenID);
        emit log_named_uint("user ERC20 balance", IERC20(address(ERC20Wrapper)).balanceOf(user));
        vm.stopPrank();
    }

    function sellERC20(uint256 amount, uint256 price, address user) public {
        emit log_named_uint("Selling following amount of ERC20 tokens", amount);
        vm.startPrank(user);
        IERC20(address(ERC20Wrapper)).safeApprove(address(ERC20Wrapper), amount);
        IWrapper(address(ERC20Wrapper)).sellTokens(amount, price);
        emit log_named_uint("New user ERC20 balance", IERC20(address(ERC20Wrapper)).balanceOf(user));
        vm.stopPrank();
    }

    function buyERC20Tokens(uint256 amount, uint256 orderID, address seller) public {
        emit log_named_uint("seller DAI balance pre-order", IERC20(DAI).balanceOf(seller));
        vm.startPrank(buyer);
        IERC20(DAI).safeApprove(address(ERC20Wrapper), amount);
        IWrapper(address(ERC20Wrapper)).buyTokens(3000 ether, orderID);
        vm.stopPrank();
        emit log_named_uint("seller DAI balance after-order", IERC20(DAI).balanceOf(seller));
    }

    function claimRewards() public {
        emit log_string("claim rewards on Goldfinch and send them to ERC20 staking contract");
        ERC20Wrapper.claimRewardsOnGoldfinch();
        emit log_named_uint("FRAX balance of stakingcontract", IERC20(rewardsFRAX).balanceOf(address(stake)));
    }

    function stakeERC20(address user) public {
        emit log_string("stake ERC20 token to access Goldfinch rewards");
        vm.startPrank(user);
        IERC20(address(ERC20Wrapper)).safeApprove(address(stake), IERC20(address(ERC20Wrapper)).balanceOf(user));
        IStakingContract(address(stake)).stake(IERC20(address(ERC20Wrapper)).balanceOf(user));
        vm.stopPrank();
    }

    function claimStakingRewards(address user) public {
        emit log_string("claiming rewards...");
        vm.startPrank(user);
        IStakingContract(address(stake)).getReward();
        vm.stopPrank();
        emit log_named_uint("FRAX received as reward", IERC20(rewardsFRAX).balanceOf(user));
    }

    // Setup
    function setUp() public {

        //Instantiate new contract instance
        pool = new GoldfinchPool(DAI, rewardsFRAX);
        ERC20Wrapper = new Wrapper(address(pool), DAI, rewardsFRAX);
        stake = new StakingContract(address(ERC20Wrapper));

        ERC20Wrapper.setStakingContract(address(stake));

        stake.addReward(rewardsFRAX, address(ERC20Wrapper), 30 days);

        deal(DAI, lp, 100_000 ether);   
        deal(DAI, buyer, 50_000 ether);
        deal(rewardsFRAX, address(pool), 5000 ether);

    }

    // Simulation
    function test_Simulation() public {

        depositPool(10_000 ether, lp);
        wrapERC721(1, lp);
        sellERC20(5000 ether, 1 ether, lp);
        buyERC20Tokens(3000 ether, 1, lp);
        claimRewards();
        stakeERC20(buyer);

        emit log_string("Fast forwards 15 days for rewards to accrue");
        vm.warp(block.timestamp + 15 days);

        claimStakingRewards(buyer);
    }

}