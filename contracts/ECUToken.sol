// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/Pausable.sol";

/**
 * @title ECUToken
 * @dev Реализация ECU токена на основе стандарта ERC20
 * Токен имеет 6 decimals для соответствия USDT
 */
contract ECUToken is ERC20, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @dev Событие эмитируется при изменении состояния паузы
    event PauseStateChanged(bool isPaused);

    constructor() ERC20("ECU Token", "ECU") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Функция чеканки новых токенов
     * @param to Адрес получателя
     * @param amount Количество токенов (в единицах с учетом 6 decimals)
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) whenNotPaused {
        require(to != address(0), "ECUToken: mint to the zero address");
        require(amount > 0, "ECUToken: mint amount must be positive");
        _mint(to, amount);
    }

    /**
     * @dev Функция сжигания токенов
     * @param from Адрес, с которого сжигаются токены
     * @param amount Количество токенов для сжигания (в единицах с учетом 6 decimals)
     */
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) whenNotPaused {
        require(from != address(0), "ECUToken: burn from the zero address");
        require(amount > 0, "ECUToken: burn amount must be positive");
        require(balanceOf(from) >= amount, "ECUToken: burn amount exceeds balance");
        _burn(from, amount);
    }

    /**
     * @dev Ставит контракт на паузу
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
        emit PauseStateChanged(true);
    }

    /**
     * @dev Снимает контракт с паузы
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
        emit PauseStateChanged(false);
    }

    /**
     * @dev Переопределение transfer для обеспечения работы только через контроллер
     */
    function transfer(address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        require(hasRole(MINTER_ROLE, msg.sender), "ECUToken: transfer only allowed through controller");
        require(to != address(0), "ECUToken: transfer to the zero address");
        return super.transfer(to, amount);
    }

    /**
     * @dev Переопределение transferFrom для обеспечения работы только через контроллер
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        require(hasRole(MINTER_ROLE, msg.sender), "ECUToken: transfer only allowed through controller");
        require(from != address(0), "ECUToken: transfer from the zero address");
        require(to != address(0), "ECUToken: transfer to the zero address");
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Переопределение decimals для соответствия USDT (6 decimals)
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }
} 