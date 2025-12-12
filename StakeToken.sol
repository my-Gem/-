// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StakeToken {
    address private immutable mainContract;
    address private immutable boomaiTokenContract;
    address private immutable usdtContract;

    event StakeTransferred(
        address indexed burnContract,
        uint256 indexed amount,
        uint256 timestamp
    );

    modifier onlyMainContract() {
        require(msg.sender == mainContract, "StakeToken: Only Main Contract");
        _;
    }

    constructor(address _mainContract, address _boomaiTokenContract, address _usdtContract) {
        require(_mainContract != address(0), "Zero address: mainContract");
        require(
            _boomaiTokenContract != address(0),
            "Zero address: boomaiTokenContract"
        );
        mainContract = _mainContract;
        boomaiTokenContract = _boomaiTokenContract;
        usdtContract = _usdtContract;
    }

    /**
     * @dev stake 方法：将 token 从 StakeToken 合约转移到 BurnToken 合约
     * @param burnContract BurnToken 合约地址
     * @param amount 转移数量
     */
    function stake(
        address burnContract,
        uint256 amount
    ) external onlyMainContract {
        require(burnContract != address(0), "Zero address: burnContract");
        require(amount > 0, "Amount must be greater than zero");
        require(
            IERC20(boomaiTokenContract).balanceOf(address(this)) >= amount,
            "Insufficient balance in StakeToken"
        );

        // 从 StakeToken 合约将 token 转给 BurnToken 合约
        bool success = IERC20(boomaiTokenContract).transfer(
            burnContract,
            amount
        );
        require(success, "Transfer to BurnToken failed");

        emit StakeTransferred(burnContract, amount, block.timestamp);
    }


    function stakeUsdt(
        address withdrawTokenContract,
        uint256 amount
    ) external onlyMainContract {
        require(withdrawTokenContract != address(0), "Zero address: withdrawTokenContract");
        require(amount > 0, "Amount must be greater than zero");
        require(
            IERC20(usdtContract).balanceOf(address(this)) >= amount,
            "Insufficient balance in StakeToken"
        );

       (bool success, bytes memory data) = usdtContract.call(abi.encodeWithSelector(0xa9059cbb, withdrawTokenContract, amount));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );

        emit StakeTransferred(withdrawTokenContract, amount, block.timestamp);

    }

    /**
     * @dev 获取合约在 BOOMAI token 中的余额
     */
    function getBalance() external view returns (uint256) {
        return IERC20(boomaiTokenContract).balanceOf(address(this));
    }

}
