// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function mint(address to, uint256 amount) external;
}

contract MintToken {
    address private immutable mainContract;
    address private immutable boomaiTokenContract;

    event TokensMinted(
        address indexed to,
        uint256 indexed amount,
        uint256 timestamp
    );

    modifier onlyMainContract() {
        require(msg.sender == mainContract, "Only Main Contract");
        _;
    }

    constructor(address _mainContract, address _boomaiTokenContract) {
        require(_mainContract != address(0), "Zero address: mainContract");
        require(_boomaiTokenContract != address(0), "Zero address: boomaiTokenContract");
        
        mainContract = _mainContract;
        boomaiTokenContract = _boomaiTokenContract;
    }

    function mint(address to, uint256 amount) external onlyMainContract {
        // 输入验证
        require(to != address(0), "Zero address: recipient");
        require(amount > 0, "Amount must be greater than zero");
        require(boomaiTokenContract != address(0), "boomaiTokenContract not set");
        
        // 执行铸造
        IERC20(boomaiTokenContract).mint(to, amount);
        
        // 记录事件
        emit TokensMinted(to, amount, block.timestamp);
    }
}