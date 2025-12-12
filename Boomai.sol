// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BOOMAI is ERC20, Ownable {
    address private mainContract;
    address private withdrawContract;
    address private burnContract;
    address private stakeContract;
    address private mintContract;

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    modifier onlyContract() {
        require(
                msg.sender == mainContract ||
                msg.sender == withdrawContract ||
                msg.sender == burnContract ||
                msg.sender == stakeContract ||
                msg.sender == mintContract,
                "BOOMAI: Only Contract"
        );
        _;
    }

    constructor() ERC20("BOOMAI", "BOOMAI") Ownable(msg.sender) {}

    function totalSupply() public view virtual override returns (uint256) {
        return 2000000 ether;
    }

    /**
     * @dev 管理员铸造新代币
     * @param to 接收代币的地址
     * @param amount 铸造数量
     */
    function mintByOwner(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "BOOMAI: mint to the zero address");
        require(amount > 0, "BOOMAI: mint amount must be greater than 0");

        _mint(to, amount);
    }

    function mint(address to, uint256 amount) external onlyContract {
        require(to != address(0), "BOOMAI: mint to the zero address");
        require(amount > 0, "BOOMAI: mint amount must be greater than 0");

        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function burn(address account, uint256 amount) external onlyContract {
        require(account != address(0), "BOOMAI: burn from the zero address");
        require(
            balanceOf(account) >= amount,
            "BOOMAI: burn amount exceeds balance"
        );

        _burn(account, amount);
        emit TokensBurned(account, amount);
    }

    /**
     * @dev 销毁调用者自己的代币
     * @param amount 销毁数量
     */
    function burn(uint256 amount) external {
        address from = msg.sender;
        require(amount > 0, "BOOMAI: burn amount must be greater than 0");
        require(
            balanceOf(from) >= amount,
            "BOOMAI: burn amount exceeds balance"
        );

        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    /**
     * @dev 从指定地址销毁代币（需要授权）
     * @param account 代币持有者地址
     * @param amount 销毁数量
     */
    function burnFrom(address account, uint256 amount) external {
        require(account != address(0), "BOOMAI: burn from the zero address");
        require(amount > 0, "BOOMAI: burn amount must be greater than 0");
        require(
            balanceOf(account) >= amount,
            "BOOMAI: burn amount exceeds balance"
        );

        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
        emit TokensBurned(account, amount);
    }

    /**
     * @dev 更新合约地址参数
     * @param _mainContract 主合约地址
     * @param _withdrawContract 提币合约地址
     */
    function updateAddress(
        address _mainContract,
        address _withdrawContract,
        address _burnContract,
        address _stakeContract,
        address _mintContract
    ) external onlyOwner {
        require(
            _withdrawContract != address(0) && _mainContract != address(0),
            "BOOMAI: zero address for contract"
        );
        mainContract = _mainContract;
        withdrawContract = _withdrawContract;
        burnContract = _burnContract;
        stakeContract = _stakeContract;
        mintContract = _mintContract;
    }

    /**
     * @dev 更新总量数据
     */
    function updateParams() external onlyOwner {
        _mint(withdrawContract, 2000000 ether);
    }

}






