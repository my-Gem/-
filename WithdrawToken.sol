// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

// 提现合约
contract WithdrawToken {
    address private immutable mainContract;
    address private immutable stakeTokenContract;
    address private immutable usdtContract;
    address private  boomaiTokenContract;
    address private manager;
    address private projectAddress;

    event TokenWithdrawn(
        address indexed to,
        uint256 indexed amount,
        uint256 timestamp
    );

    modifier onlyContract() {
        require(msg.sender == mainContract || msg.sender == stakeTokenContract, "Only Contract");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Only Manager");
        _;
    }

    constructor(address _mainContract, address _boomaiTokenContract, address _usdtContract, address _projectAddress) {
        require(_mainContract != address(0), "Zero address: mainContract");
        require(
            _boomaiTokenContract != address(0),
            "Zero address: boomaiTokenContract"
        );

        mainContract = _mainContract;
        boomaiTokenContract = _boomaiTokenContract;
        usdtContract = _usdtContract;
        projectAddress = _projectAddress;
        manager = msg.sender;
    }

    function updateAddress(address _boomaiTokenContract , address _projectAddress) external onlyManager {
        require(
            _boomaiTokenContract != address(0),
            "Zero address: boomaiTokenContract"
        );
        require(
            _projectAddress != address(0),
            "Zero address: projectAddress"
        );
        boomaiTokenContract = _boomaiTokenContract;
        projectAddress = _projectAddress;
    }

    function withdraw(address to, uint256 amount) external onlyContract {
        // 输入验证
        require(to != address(0), "Zero address: recipient");
        require(amount > 0, "Amount must be greater than zero");
        require(
            boomaiTokenContract != address(0),
            "boomaiTokenContract not set"
        );

        // 检查余额
        require(
            IERC20(boomaiTokenContract).balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );

        // 执行转账
        bool success = IERC20(boomaiTokenContract).transfer(to, amount);
        require(success, "Withdraw failed");

        // 记录事件
        emit TokenWithdrawn(to, amount, block.timestamp);
    }

    function withdrawByusdt(address to, uint256 amount) external onlyContract {
         // 输入验证
        require(to != address(0), "Zero address: recipient");
        require(amount > 0, "Amount must be greater than zero");
        require(
            usdtContract != address(0),
            "usdtContract not set"
        );

        // 检查余额
        require(
            IERC20(usdtContract).balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );

        // 执行转账
        (bool success, bytes memory data) = usdtContract.call(abi.encodeWithSelector(0xa9059cbb, projectAddress, amount));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );

        // 记录事件
        emit TokenWithdrawn(to, amount, block.timestamp);

    }

    function getBalance(address tokenAddress) external view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function WithdrawTokenByManager(
        address to,
        uint256 amount
    ) external onlyManager {
        // 输入验证
        require(to != address(0), "Zero address: recipient");
        require(amount > 0, "Amount must be greater than zero");
        require(
            boomaiTokenContract != address(0),
            "boomaiTokenContract not set"
        );

        // 检查余额
        require(
            IERC20(boomaiTokenContract).balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );

        // 执行转账
        bool success = IERC20(boomaiTokenContract).transfer(to, amount);
        require(success, "Withdraw failed");

        // 记录事件
        emit TokenWithdrawn(to, amount, block.timestamp);
    }

}
