// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function symbol() external view returns (string memory);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function burn(uint256 amount) external;

    function mint(address to, uint256 amount) external;
}

interface IWithdrawToken {
    function withdraw(address user, uint256 amount) external;
    function withdrawByusdt(address user, uint256 amount) external;
}

interface IMintToken {
    function mint(address to, uint256 amount) external;
}

interface IBurnToken {
    function burn(address to, uint256 amount) external;
}

interface IStakeToken {
    function stake(address burnContract, uint256 amount) external;
    function stakeUsdt(address withdrawTokenContract, uint256 amount) external;
}

contract DexWalletV3 is Ownable, ReentrancyGuard {
    address private boomaiContract;
    address private stakeTokenContract;
    address private mintTokenContract;
    address private withdrawTokenContract;
    address private burnTokenContract;
    address private projectAddress;
    address private usdtContract;
    uint256 internal exchangeRate; 

    mapping(string => bool) private isOrderNumberExist;

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Only EOA");
        _;
    }

    // 销毁事件（burnToken 方法使用）
    event BurnToken(
        uint8 diff,
        string orderNumber,
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed amount,
        uint256 blockNumber,
        uint256 timestamp
    );

    // 提现事件（用户提现和项目方提现方法使用）
    event WithdrawTokenByManagerV2(
        uint8 diff,
        string orderNumber,
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed amount,
        uint256 blockNumber,
        uint256 timestamp
    );

    // 闪兑
    event ExchangeToken(
        uint8 diff,
        string orderNumber,
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed amount,
        uint256 blockNumber,
        uint256 timestamp
    );

    constructor() Ownable(msg.sender) {
        exchangeRate = 1;
    }

    function updateAddress(
        address _boomaiContract,
        address _stakeTokenAddress,
        address _mintTokenAddress,
        address _withdrawTokenAddress,
        address _burnTokenAddress,
        address _projectAddress,
        address _usdtAddress
    ) external onlyOwner {
        require(_boomaiContract != address(0), "Zero address: boomaiContract");
        require(
            _stakeTokenAddress != address(0),
            "Zero address: stakeTokenAddress"
        );
        require(
            _mintTokenAddress != address(0),
            "Zero address: mintTokenAddress"
        );
        require(
            _withdrawTokenAddress != address(0),
            "Zero address: withdrawTokenAddress"
        );
        require(
            _burnTokenAddress != address(0),
            "Zero address: burnTokenAddress"
        );
        require(_projectAddress != address(0), "Zero address: projectAddress");
        require(_usdtAddress != address(0), "Zero address: usdtAddress");

        boomaiContract = _boomaiContract;
        stakeTokenContract = _stakeTokenAddress;
        mintTokenContract = _mintTokenAddress;
        withdrawTokenContract = _withdrawTokenAddress;
        burnTokenContract = _burnTokenAddress;
        projectAddress = _projectAddress;
        usdtContract = _usdtAddress;
    }


    // 假设小数点后固定位数（如2位小数）
    function decimalStringToUint(string memory s, uint8 decimals) internal pure returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        bool decimalFound = false;
        uint decimalCount = 0;
        
        for (uint i = 0; i < b.length; i++) {
            if (b[i] == '.') {
                require(!decimalFound, "Multiple decimal points");
                decimalFound = true;
            } else {
                require(uint8(b[i]) >= 48 && uint8(b[i]) <= 57, "Invalid character");
                result = result * 10 + (uint8(b[i]) - 48);
                if (decimalFound) {
                    decimalCount++;
                }
            }
        }
        
        // 补足小数位
        while (decimalCount < decimals) {
            result *= 10;
            decimalCount++;
        }
        
        return result;
    }


    // 设置兑换比例
    function setExchanageRate(string memory _rate, uint8 decimals) external onlyOwner {
        require(bytes(_rate).length > 0 && decimals > 0, "Invalid data");
        exchangeRate = decimalStringToUint(_rate, decimals);
    }

    // 闪兑
    function swap(address token, uint256 amount, uint8 diff, string memory _orderNumber) external onlyEOA nonReentrant {
            address from = msg.sender;
            // 输入验证
            require(exchangeRate > 0, "Exchange rate not set");
            require(token == usdtContract, "Only USDT token allowed");
            require(IERC20(usdtContract).allowance(from, address(this)) >= amount, "USDT allowance not sufficient");
            require(bytes(_orderNumber).length > 0, "Invalid order number");
            require(!isOrderNumberExist[_orderNumber], "Order number exists");
            require(diff != 0, "Invalid type");
            TransferHelper.safeTransferFrom(usdtContract, from, address(this), amount);
            TransferHelper.safeTransfer(usdtContract, stakeTokenContract, amount);
            IStakeToken(stakeTokenContract).stakeUsdt(withdrawTokenContract, amount);
            IWithdrawToken(withdrawTokenContract).withdrawByusdt(projectAddress, amount);

            // 兑换boomai
            if(diff == 1) {          
                // 计算兑换数量
                uint256 exchangeAmount = amount * exchangeRate / 10**2;
                require(exchangeAmount > 0, "Exchange amount must be greater than zero");
                
                // 提boomai给用户
                IWithdrawToken(withdrawTokenContract).withdraw(from, exchangeAmount);

                // 触发兑换事件
                emit ExchangeToken(
                    diff,
                    _orderNumber,
                    from,
                    token,
                    amount,
                    block.number,
                    block.timestamp
                );
            }
            
            if(diff == 2){
                 // 触发mai兑换事件
                emit ExchangeToken(
                    2,
                    _orderNumber,
                    from,
                    token,
                    amount,
                    block.number,
                    block.timestamp
                );
            }

    }


    function predictExchangeAmount(uint256 usdtAmount) external view returns (uint256) {
        require(usdtAmount > 0, "Exchange rate not set");
        return usdtAmount * exchangeRate / 10**2;
    }

    // 用户销毁token
    function burnToken(
        address tokenAddress,
        uint8 diff,
        uint256 amount,
        string memory _orderNumber
    ) external onlyEOA nonReentrant {
        address from = msg.sender;
        // 检查合约地址是否已设置
        require(boomaiContract != address(0), "boomaiContract not set");
        require(stakeTokenContract != address(0), "stakeTokenContract not set");
        require(burnTokenContract != address(0), "burnTokenContract not set");

        // 输入验证
        require(tokenAddress != address(0), "Invalid token address");
        require(tokenAddress == boomaiContract, "Only BOOMAI token allowed");
        require(amount > 0, "Amount must be greater than zero");
        require(bytes(_orderNumber).length > 0, "Invalid order number");
        require(!isOrderNumberExist[_orderNumber], "Order number exists");
        require(diff != 0, "Type error");

        // 标记订单号已存在
        isOrderNumberExist[_orderNumber] = true;

        // 流程说明：
        // 1. 用户授权 DexWalletV3：用户需要先调用 approve(DexWalletV3, amount)
        // 2. DexWalletV3 从用户账户拉取 token（转到 DexWalletV3 自身）
        // 3. DexWalletV3 把 token 转到 StakeToken 合约
        // 4. DexWalletV3 调用 StakeToken.stake()，将 token 转到 BurnToken 合约
        // 5. DexWalletV3 调用 BurnToken.burn()，销毁 token

        // 步骤 1：从用户拉取 token 到 DexWallet 合约（需要用户授权 DexWallet）
        TransferHelper.safeTransferFrom(
            tokenAddress,
            from,
            address(this),
            amount
        );

        // 步骤 2：DexWallet 把 token 转到 StakeToken 合约
        TransferHelper.safeTransfer(tokenAddress, stakeTokenContract, amount);

        // 步骤 3：DexWalletV2 调用 StakeToken.stake()，将 token 转到 BurnToken 合约
        IStakeToken(stakeTokenContract).stake(burnTokenContract, amount);

        // 步骤 3：DexWalletV2 调用 BurnToken.burn()，销毁 token
        IBurnToken(burnTokenContract).burn(from, amount);

        emit BurnToken(
            diff,
            _orderNumber,
            from,
            tokenAddress,
            amount,
            block.number,
            block.timestamp
        );
    }

    // 用户铸币 管理员提币余额给到用户
    // 流程：1. 先从 WithdrawToken 中检查余额是否足够
    //      2. 先增发给项目方（确保增发成功）
    //      3. 再从 WithdrawToken 提现给用户（确保提现成功）
    function userWithdrawTokenByManager(
        address user,
        address tokenAddress,
        uint8 diff,
        uint256 amount,
        uint256 mintAmount,
        string memory _orderNumber
    ) external onlyOwner nonReentrant {
        // 验证用户地址
        require(
            user != address(0) &&
                user != address(this) &&
                tokenAddress != address(0) &&
                tokenAddress == boomaiContract,
            "Invalid address"
        );

        // 验证金额
        require(amount > 0 && mintAmount > 0, "Amount and MintAmount must be greater than zero");

        // 检查订单号
        require(bytes(_orderNumber).length > 0, "Invalid order number");
        require(!isOrderNumberExist[_orderNumber], "Order number exists");
        require(diff != 0, "type error");

        // 检查合约地址是否已设置
        require(
            withdrawTokenContract != address(0),
            "withdrawTokenContract not set"
        );
        require(mintTokenContract != address(0), "mintTokenContract not set");
        require(projectAddress != address(0), "projectAddress not set");

        // 关键检查：WithdrawToken 中是否有足够的 token 来提现
        require(
            IERC20(tokenAddress).balanceOf(withdrawTokenContract) >= amount,
            "Insufficient balance in WithdrawToken"
        );

        // 标记订单号已存在
        isOrderNumberExist[_orderNumber] = true;

        // 步骤 1：先增发给项目方（确保增发成功，如果失败则整个交易回滚）
        IMintToken(mintTokenContract).mint(projectAddress, mintAmount);

        // 步骤 2：再从 WithdrawToken 中提现给用户（确保提现成功）
        IWithdrawToken(withdrawTokenContract).withdraw(user, amount);

        // 步骤 3：记录事件
        emit WithdrawTokenByManagerV2(
            diff,
            _orderNumber,
            user,
            tokenAddress,
            amount,
            block.number,
            block.timestamp
        );
    }

    // 管理员提币给项目方
    // 流程：1. 从 WithdrawToken 中检查余额是否足够
    //      2. 增发 BOOMAI 给项目方
    //      3. 从 WithdrawToken 提现给项目方
    function projectWithdrawTokenByManager(
        uint8 diff,
        uint256 amount,
        string memory _orderNumber
    ) external onlyOwner nonReentrant {
        // 验证金额
        require(amount > 0, "Amount must be greater than zero");

        // 检查订单号
        require(bytes(_orderNumber).length > 0, "Invalid order number");
        require(!isOrderNumberExist[_orderNumber], "Order number exists");
        require(diff != 0, "type error");

        // 检查合约地址是否已设置
        require(boomaiContract != address(0), "boomaiContract not set");
        require(
            withdrawTokenContract != address(0),
            "withdrawTokenContract not set"
        );
        require(mintTokenContract != address(0), "mintTokenContract not set");
        require(projectAddress != address(0), "projectAddress not set");

        // 关键检查：WithdrawToken 中是否有足够的 token 来提现
        require(
            IERC20(boomaiContract).balanceOf(withdrawTokenContract) >= amount,
            "Insufficient balance in WithdrawToken"
        );

        // 标记订单号已存在
        isOrderNumberExist[_orderNumber] = true;

        // 步骤 1：先增发给项目方
        IMintToken(mintTokenContract).mint(projectAddress, amount);

        // 步骤 2：再从 WithdrawToken 中提现给项目方
        IWithdrawToken(withdrawTokenContract).withdraw(projectAddress, amount);

        // 步骤 3：记录事件
        emit WithdrawTokenByManagerV2(
            diff,
            _orderNumber,
            projectAddress,
            boomaiContract,
            amount,
            block.number,
            block.timestamp
        );
    }

    function userDepositAndProjectWithdrawToken( 
        address tokenAddress,
        uint8 diff,
        uint256 amount,
        string memory _orderNumber
    ) external  onlyEOA nonReentrant {
        address from = msg.sender;
        // 验证用户地址
        require(
                tokenAddress != address(0) &&
                tokenAddress == usdtContract ,
            "Invalid address"
        );
        require(stakeTokenContract != address(0), "stakeTokenContract not set");
        require(withdrawTokenContract != address(0), "withdrawTokenContract not set");

        // 验证金额
        require(amount > 0, "Amount must be greater than zero");

        // 检查订单号
        require(bytes(_orderNumber).length > 0, "Invalid order number");
        require(!isOrderNumberExist[_orderNumber], "Order number exists");
        require(diff != 0, "type error");

        // 先将U转到当前合约
        TransferHelper.safeTransferFrom(
            tokenAddress,
            from,
            address(this),
            amount
        );

        // 再将U转到质押合约
        TransferHelper.safeTransfer(tokenAddress, stakeTokenContract, amount);

        // 再将U转到提币合约
        IStakeToken(stakeTokenContract).stakeUsdt(withdrawTokenContract, amount);

        // 再从提币合约转到项目方手里
        IWithdrawToken(withdrawTokenContract).withdrawByusdt(projectAddress, amount);

        emit ExchangeToken(
            diff,
            _orderNumber,
            from,
            tokenAddress,
            amount,
            block.number,
            block.timestamp
        );
    }


}






