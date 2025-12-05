// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

interface IBoomai {
    function burn(uint256 amount) external;
}

contract BurnToken {
    address private immutable mainContract;
    address private immutable boomaiTokenContract;

    event TokensBurned(uint256 indexed amount, uint256 timestamp);

    modifier onlyMainContract() {
        require(msg.sender == mainContract, "Only Main Contract");
        _;
    }

    constructor(address _mainContract, address _boomaiTokenContract) {
        require(_mainContract != address(0), "Zero address: mainContract");
        require(
            _boomaiTokenContract != address(0),
            "Zero address: boomaiTokenContract"
        );

        mainContract = _mainContract;
        boomaiTokenContract = _boomaiTokenContract;
    }

    function burn(address, uint256 amount) external onlyMainContract {
        // 输入验证
        require(amount > 0, "Amount must be greater than zero");
        require(
            boomaiTokenContract != address(0),
            "boomaiTokenContract not set"
        );

        // 检查 BurnToken 合约的 BOOMAI token 余额
        require(
            IERC20(boomaiTokenContract).balanceOf(address(this)) >= amount,
            "Insufficient balance in BurnToken"
        );

        // 调用 Boomai 合约的 burn 方法销毁 token
        IBoomai(boomaiTokenContract).burn(amount);

        // 记录事件
        emit TokensBurned(amount, block.timestamp);
    }
}