// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
 
import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
 
contract CounterTest is Test {
    Counter counter;
 
    function setUp() public {
        counter = new Counter();
    }
 
    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }
 
    function test_SetNumber() public {
        counter.setNumber(42);
        assertEq(counter.number(), 42);
    }
}