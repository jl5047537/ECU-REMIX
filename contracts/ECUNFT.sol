// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/Counters.sol";

/**
 * @title ECUNFT
 * @dev Реализация ECU-NFT на основе стандарта ERC721
 * с поддержкой хранения метаданных в IPFS
 */
contract ECUNFT is ERC721, ERC721URIStorage, AccessControl, Pausable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private _tokenIdCounter;

    // База URI для метаданных
    string private _baseTokenURI;
    
    // Маппинг для отслеживания существующих токенов
    mapping(uint256 => bool) private _existingTokens;

    /// @dev События для отслеживания важных операций
    event BaseURIChanged(string newBaseURI);
    event PauseStateChanged(bool isPaused);
    event TokenMinted(address indexed to, uint256 indexed tokenId, string uri);
    event TokenBurned(address indexed from, uint256 indexed tokenId);

    constructor() ERC721("ECU NFT", "ECUNFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Проверка валидности URI
     * @param uri URI для проверки
     */
    function _isValidURI(string memory uri) private pure returns (bool) {
        bytes memory uriBytes = bytes(uri);
        if (uriBytes.length == 0) return false;
        
        // Проверяем, что URI начинается с http:// или https:// или ipfs://
        bytes memory http = bytes("http://");
        bytes memory https = bytes("https://");
        bytes memory ipfs = bytes("ipfs://");
        
        bool hasValidPrefix = false;
        if (uriBytes.length >= 7) {
            hasValidPrefix = true;
            // Проверяем http://
            for (uint i = 0; i < 7; i++) {
                if (uriBytes[i] != http[i]) {
                    hasValidPrefix = false;
                    break;
                }
            }
        }
        
        if (!hasValidPrefix && uriBytes.length >= 8) {
            hasValidPrefix = true;
            // Проверяем https://
            for (uint i = 0; i < 8; i++) {
                if (uriBytes[i] != https[i]) {
                    hasValidPrefix = false;
                    break;
                }
            }
        }
        
        if (!hasValidPrefix && uriBytes.length >= 7) {
            hasValidPrefix = true;
            // Проверяем ipfs://
            for (uint i = 0; i < 7; i++) {
                if (uriBytes[i] != ipfs[i]) {
                    hasValidPrefix = false;
                    break;
                }
            }
        }
        
        return hasValidPrefix;
    }

    /**
     * @dev Безопасная чеканка нового NFT с установкой URI
     * @param to Адрес получателя
     * @param uri URI метаданных токена
     * @return tokenId ID нового токена
     */
    function safeMint(address to, string memory uri) public onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        require(to != address(0), "ECUNFT: mint to the zero address");
        require(bytes(uri).length > 0, "ECUNFT: empty URI");
        require(_isValidURI(uri), "ECUNFT: invalid URI format");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _existingTokens[tokenId] = true;

        emit TokenMinted(to, tokenId, uri);
        return tokenId;
    }

    /**
     * @dev Сжигание NFT
     * @param tokenId ID токена для сжигания
     */
    function burn(uint256 tokenId) public onlyRole(BURNER_ROLE) whenNotPaused {
        require(_exists(tokenId), "ECUNFT: token does not exist");
        require(_isApprovedOrOwner(msg.sender, tokenId), "ECUNFT: caller is not owner nor approved");
        
        address owner = ownerOf(tokenId);
        _burn(tokenId);
        delete _existingTokens[tokenId];
        
        emit TokenBurned(owner, tokenId);
    }

    /**
     * @dev Установка базового URI для метаданных
     * @param baseURI Новый базовый URI
     */
    function setBaseURI(string memory baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isValidURI(baseURI), "ECUNFT: invalid URI format");
        _baseTokenURI = baseURI;
        emit BaseURIChanged(baseURI);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
        emit PauseStateChanged(true);
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
        emit PauseStateChanged(false);
    }

    /**
     * @dev Переопределение базового URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Проверка существования токена
     * @param tokenId ID токена для проверки
     */
    function exists(uint256 tokenId) public view returns (bool) {
        return _existingTokens[tokenId];
    }

    // Переопределение необходимых функций
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "ECUNFT: transfer only allowed through controller"
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
} 