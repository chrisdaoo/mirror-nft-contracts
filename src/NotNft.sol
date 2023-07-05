// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract NotNft {
    uint256 number;

    function increment() public {
        number++;
    }

    function get_number() public view returns (uint256) {
        return number;
    }
}
