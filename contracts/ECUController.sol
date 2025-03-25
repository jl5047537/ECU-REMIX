// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ECUToken.sol";
import "./ECUNFT.sol";

/**
 * @title ECUController
 * @dev Контроллер для управления связкой ECU токен + ECU-NFT
 * Реализует механизм mint-on-demand и управление парами токенов
 */
contract ECUController is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    ECUToken public immutable ecuToken;
    ECUNFT public immutable ecuNFT;
    IERC20 public immutable usdtToken;
    
    // Маппинг для хранения связей между NFT и токенами
    mapping(uint256 => bool) public nftTokenPairs;
    
    /// @dev События контракта
    event PairMinted(address indexed owner, uint256 tokenId, uint256 amount);
    event PairBurned(address indexed owner, uint256 tokenId, uint256 amount);
    event PairTransferred(address indexed from, address indexed to, uint256 tokenId, uint256 amount);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);
    event PauseStateChanged(bool isPaused);

    /**
     * @dev Конструктор контроллера
     * @param _ecuToken Адрес контракта ECU токена
     * @param _ecuNFT Адрес контракта ECU NFT
     * @param _usdtToken Адрес контракта USDT
     */
    constructor(
        address _ecuToken,
        address _ecuNFT,
        address _usdtToken
    ) {
        require(_ecuToken != address(0), "ECUController: zero address for ECU token");
        require(_ecuNFT != address(0), "ECUController: zero address for ECU NFT");
        require(_usdtToken != address(0), "ECUController: zero address for USDT token");
        
        ecuToken = ECUToken(_ecuToken);
        ecuNFT = ECUNFT(_ecuNFT);
        usdtToken = IERC20(_usdtToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Функция mint-on-demand
     * Создает новую пару ECU токен + ECU-NFT за 1 USDT
     * @param tokenURI URI метаданных для NFT
     */
    function mintPair(string memory tokenURI) external nonReentrant whenNotPaused {
        require(bytes(tokenURI).length > 0, "ECUController: empty token URI");
        
        // Проверяем и переводим USDT
        uint256 usdtAmount = 1e6; // 1 USDT = 1e6 (6 decimals)
        require(usdtToken.balanceOf(msg.sender) >= usdtAmount, "ECUController: insufficient USDT balance");
        require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "ECUController: USDT transfer failed");
        
        // Чеканим ECU токен
        uint256 ecuAmount = 1e6; // 1 ECU = 1e6 (6 decimals)
        ecuToken.mint(msg.sender, ecuAmount);
        
        // Чеканим NFT
        uint256 tokenId = ecuNFT.safeMint(msg.sender, tokenURI);
        
        // Сохраняем связь
        nftTokenPairs[tokenId] = true;
        
        emit PairMinted(msg.sender, tokenId, ecuAmount);
    }

    /**
     * @dev Функция сжигания пары токенов
     * @param tokenId ID токена NFT для сжигания
     */
    function burnPair(uint256 tokenId) external nonReentrant whenNotPaused {
        require(nftTokenPairs[tokenId], "ECUController: pair does not exist");
        require(ecuNFT.ownerOf(tokenId) == msg.sender, "ECUController: not the owner of NFT");
        
        uint256 ecuAmount = 1e6; // 1 ECU = 1e6 (6 decimals)
        require(ecuToken.balanceOf(msg.sender) >= ecuAmount, "ECUController: insufficient ECU balance");
        
        // Сжигаем токены
        ecuToken.burn(msg.sender, ecuAmount);
        ecuNFT.burn(tokenId);
        
        // Удаляем связь
        delete nftTokenPairs[tokenId];
        
        // Возвращаем USDT
        uint256 usdtAmount = 1e6; // 1 USDT = 1e6 (6 decimals)
        require(usdtToken.transfer(msg.sender, usdtAmount), "ECUController: USDT transfer failed");
        
        emit PairBurned(msg.sender, tokenId, ecuAmount);
    }

    /**
     * @dev Передача пары токенов другому адресу
     * @param to Адрес получателя
     * @param tokenId ID токена NFT для передачи
     */
    function transferPair(address to, uint256 tokenId) external nonReentrant whenNotPaused {
        require(to != address(0), "ECUController: transfer to zero address");
        require(nftTokenPairs[tokenId], "ECUController: pair does not exist");
        require(ecuNFT.ownerOf(tokenId) == msg.sender, "ECUController: not the owner of NFT");
        
        uint256 ecuAmount = 1e6; // 1 ECU = 1e6 (6 decimals)
        require(ecuToken.balanceOf(msg.sender) >= ecuAmount, "ECUController: insufficient ECU balance");
        
        // Передаем токены
        ecuToken.transferFrom(msg.sender, to, ecuAmount);
        ecuNFT.transferFrom(msg.sender, to, tokenId);
        
        emit PairTransferred(msg.sender, to, tokenId, ecuAmount);
    }

    /**
     * @dev Ставит контракт на паузу
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit PauseStateChanged(true);
    }

    /**
     * @dev Снимает контракт с паузы
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
        emit PauseStateChanged(false);
    }

    /**
     * @dev Функция для экстренного вывода токенов
     * @param token Адрес токена для вывода
     * @param amount Количество токенов
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "ECUController: zero token address");
        require(amount > 0, "ECUController: zero amount");
        require(IERC20(token).transfer(msg.sender, amount), "ECUController: transfer failed");
        emit EmergencyWithdraw(token, msg.sender, amount);
    }
} 