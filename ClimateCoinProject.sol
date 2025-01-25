// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";

// Contrato principal de gestión de ClimateCoin
contract GestionClimateCoin {
    // Variable para almacenar el propietario del contrato
    address public owner;

    // Instancia del contrato ClimateCoin
    ERC20 public climateCoin;

    // Variables para gestionar las fees
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

    // Errores 
    error NotOwner();
    error InsufficientCC(uint256 available, uint256 required);

    // Constructor que inicializa el contrato
    constructor(ERC20 _climateCoin) {
        owner = msg.sender; // El propietario es quien despliega el contrato
        climateCoin = _climateCoin; // Asignamos la instancia del ClimateCoin
    }

    // Función para actualizar el porcentaje de fees (solo el propietario puede cambiarlo)
    function setFeePercentage(uint256 newFeePercentage) external {
        // Verificamos que el remitente es el propietario
        if (msg.sender != owner) {
            revert("Solo el propietario puede ejecutar esta funcion");
        }
        feePercentage = newFeePercentage;
    }

    // Función para intercambiar un NFT por ClimateCoins
    function exchangeNFTForCC(address nftAddress, uint256 nftId) external {
        ERC721 nftContract = ERC721(nftAddress);

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
        ERC721 nftContract = ERC721(nftAddress);

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
