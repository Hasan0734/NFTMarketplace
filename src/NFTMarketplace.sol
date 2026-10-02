// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ReentrancyGuard, Ownable {
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isListed;
    }

    // address public owner;

    uint256 public platformFeeBps = 250;
    uint256 public accumulatedFees;

    mapping(address => mapping(uint256 => Listing)) public listings;

    event NFTListed(address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTListingCanceled(address indexed seller, address indexed nftContract, uint256 tokenId);
    event NFTSold(
        address indexed buyer, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeWithdrawal(address indexed owner, uint256 accumulatedFees);

    constructor() Ownable(msg.sender) {}

    function listNFT(address _nftContract, uint256 _tokenId, uint256 _price) external {
        require(_price > 0, "Price must be > 0");
        require(msg.sender == IERC721(_nftContract).ownerOf(_tokenId), "You are not the owner of this token.");
        require(
            IERC721(_nftContract).isApprovedForAll(msg.sender, address(this))
                || IERC721(_nftContract).getApproved(_tokenId) == address(this),
            "Marketplace not approved"
        );
        require(!listings[_nftContract][_tokenId].isListed, "NFT is already listed");

        listings[_nftContract][_tokenId] =
            Listing({seller: msg.sender, nftContract: _nftContract, tokenId: _tokenId, price: _price, isListed: true});

        emit NFTListed(msg.sender, _nftContract, _tokenId, _price);
    }

    function cancelListing(address _nftContract, uint256 _tokenId) external {
        Listing storage listing = listings[_nftContract][_tokenId];

        require(listing.isListed, "Not listed");
        require(listing.seller == msg.sender, "You are not the seller");

        listing.isListed = false;

        emit NFTListingCanceled(msg.sender, _nftContract, _tokenId);
    }

    function buyNFT(address _nftContract, uint256 _tokenId) external payable nonReentrant {
        Listing storage listing = listings[_nftContract][_tokenId];

        require(listing.isListed, "Not listed");
        require(msg.value >= listing.price, "Not enough ether");
        require(IERC721(_nftContract).ownerOf(_tokenId) == listing.seller, "Seller no longer owns the NFT");

        listing.isListed = false;

        address seller = listing.seller;
        uint256 price = listing.price;

        // calc fees

        uint256 feeAmount = (price * platformFeeBps) / 10000;
        uint256 sellerPayout = price - feeAmount;
        accumulatedFees += feeAmount;

        IERC721(_nftContract).safeTransferFrom(seller, msg.sender, _tokenId);

        (bool success,) = seller.call{value: sellerPayout}("");
        require(success, "Seller payment failed");

        if (msg.value > price) {
            (bool refundSuccess,) = msg.sender.call{value: msg.value - price}("");
            require(refundSuccess, "Refund failed");
        }
        delete listings[_nftContract][_tokenId];
        emit NFTSold(msg.sender, seller, _nftContract, _tokenId, price);
    }

    function updatePlatformFee(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= 1000, "Fee cannot exceed 10%");
        emit FeeUpdated(platformFeeBps, _newFeeBps);
        platformFeeBps = _newFeeBps;
    }

    function withdrawFees() external onlyOwner {
        uint256 revenue = accumulatedFees;
        require(revenue > 0, "No fees to withdraw");
        accumulatedFees = 0;
        (bool success,) = msg.sender.call{value: revenue}("");
        require(success, "Fee withdrawal failed");
        emit FeeWithdrawal(msg.sender, revenue);
    }
}
