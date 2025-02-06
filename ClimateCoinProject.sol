// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Contrato principal de gestión de ClimateCoin
    contract GestionClimateCoin {
    // Variable para almacenar el propietario del contrato
    address public owner;

    // Instancia del contrato ClimateCoin
    ClimateCoin public climateCoin;

    // Variables para gestionar las fees
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18; // Suministro inicial de tokens
    uint256 public feePercentage = 2; // Fee inicial (en %)

    // Eventos
    event NFTMinted(
        uint256 tokenId,
        uint256 credits,
        string projectName,
        string projectURL,
        address developerAddress
    );

    event NFTExchanged(
        address user,
        address nftAddress,
        uint256 nftId,
        uint256 amount,
        uint256 fee
    );

    event CCBurned(
        address user,
        uint256 amountBurned,
        uint256 nftIdBurned
    );

    // Errores personalizados
    error NotOwner();
    error InsufficientCC(uint256 available, uint256 required);

    // Constructor que inicializa el contrato
    constructor() {
        owner = msg.sender; // El propietario es quien despliega el contrato
        climateCoin = new ClimateCoin(INITIAL_SUPPLY); // Desplegamos el token ClimateCoin
    }

    // Modificador para restringir el acceso solo al propietario
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    // Función para actualizar el porcentaje de fees (solo el propietario puede cambiarlo)
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        feePercentage = newFeePercentage;
    }

    // Función para intercambiar un NFT por ClimateCoins
    function exchangeNFTForCC(address nftAddress, uint256 nftId) external {
        IERC721 nftContract = IERC721(nftAddress);

        // Verificamos que el usuario es dueño del NFT
        require(nftContract.ownerOf(nftId) == msg.sender, "No eres el propietario del NFT");

        // Transferimos el NFT al contrato
        nftContract.transferFrom(msg.sender, address(this), nftId);

        uint256 amount = 100 * (10 ** 18); // Valor fijo del NFT
        uint256 fee = (amount * feePercentage) / 100;
        uint256 finalAmount = amount - fee;

        // Transferimos las fees al propietario del contrato
        require(climateCoin.transfer(owner, fee), "Fallo en la transferencia de fees");

        // Transferimos los ClimateCoins restantes al usuario
        require(climateCoin.transfer(msg.sender, finalAmount), "Fallo en la transferencia de ClimateCoins");

        // Emitimos un evento para registrar la transacción
        emit NFTExchanged(msg.sender, nftAddress, nftId, finalAmount, fee);
    }

    // Función para quemar ClimateCoins y un NFT
    function burnCCAndNFT(
        address nftAddress,
        uint256 nftId,
        uint256 ccAmount
    ) external {
        IERC721 nftContract = IERC721(nftAddress);

        // Verificamos que el usuario sea el dueño del NFT
        require(nftContract.ownerOf(nftId) == msg.sender, "No eres el propietario del NFT");

        // Verificamos que el usuario tiene suficientes ClimateCoins
        uint256 userBalance = climateCoin.balanceOf(msg.sender);
        if (userBalance < ccAmount) {
            revert InsufficientCC(userBalance, ccAmount);
        }

        // Transferimos los ClimateCoins al contrato
        require(climateCoin.transferFrom(msg.sender, address(this), ccAmount), "Fallo en la transferencia de ClimateCoins");

        // Quemamos el NFT enviándolo a la dirección 0x0
        nftContract.transferFrom(msg.sender, address(0), nftId);

        // Emitimos un evento para registrar la quema
        emit CCBurned(msg.sender, ccAmount, nftId);
    }
}

// Contrato ClimateCoin (ERC-20 básico)
contract ClimateCoin {
    string public name = "ClimateCoin";
    string public symbol = "CC";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "Saldo insuficiente");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balanceOf[from] >= value, "Saldo insuficiente");
        require(allowance[from][msg.sender] >= value, "No autorizado");
        balanceOf[from] -= value;
        allowance[from][msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}

