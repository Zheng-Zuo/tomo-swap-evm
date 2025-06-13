// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";

contract WrapNativeTest is Test {
    address user;
    uint256 constant BALANCE = 10000 ether;
    IWETH9 constant WBNB = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"), 45406293);
        user = makeAddr("user");

        vm.startPrank(user);
    }

    modifier airdropWbnb() {
        deal(address(WBNB), user, BALANCE);
        _;
    }

    modifier airdropEth() {
        deal(user, BALANCE);
        _;
    }

    function test_checkInitialState() public view {
        uint256 userEthBalance = user.balance;
        uint256 userWethBalance = WBNB.balanceOf(user);

        assertEq(userEthBalance, 0);
        assertEq(userWethBalance, 0);
    }

    function test_wrapNative() public airdropEth {

        WBNB.deposit{value: BALANCE}();

        uint256 userWethBalance = WBNB.balanceOf(user);
        assertEq(userWethBalance, BALANCE);
        assertEq(user.balance, 0);
    }

    function test_unwrapNative() public airdropWbnb {

        WBNB.withdraw(BALANCE);

        uint256 userEthBalance = user.balance;
        assertEq(userEthBalance, BALANCE);
        assertEq(WBNB.balanceOf(user), 0);
    }
}
