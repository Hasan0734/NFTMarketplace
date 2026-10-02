// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MockNFT} from "../src/MockNFT.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public nftMarketplace;
    MockNFT public mockNFT;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isListed;
    }

    function setUp() public {
        nftMarketplace = new NFTMarketplace();
        mockNFT = new MockNFT();
    }

    function test_ListNFTPrice() public {
        address seller = makeAddr("seller");
        vm.startPrank(seller);
        mockNFT.mint();

        uint256 currentId = mockNFT.currentTokenId();
        mockNFT.approve(address(nftMarketplace), currentId);

        vm.expectRevert("Price must be > 0");
        nftMarketplace.listNFT(address(mockNFT), currentId, 0 ether);
        vm.stopPrank();
    }

    function test_ListNFTDoubleListing() public {
        address seller = makeAddr("seller");
        vm.startPrank(seller);
        mockNFT.mint();

        uint256 currentId = mockNFT.currentTokenId();
        mockNFT.approve(address(nftMarketplace), currentId);
        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);

        vm.expectRevert("NFT is already listed");
        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);
        vm.stopPrank();
    }

    function test_ListNFTIsOwner() public {
        address seller = makeAddr("seller");
        address robber = makeAddr("robber");

        vm.prank(seller);
        mockNFT.mint();
        uint256 currentId = mockNFT.currentTokenId();

        vm.prank(robber);
        vm.expectRevert("You are not the owner of this token.");
        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);
    }

    function test_NFTMaketApprove() public {
        address seller = makeAddr("seller");
        vm.startPrank(seller);
        mockNFT.mint();
        uint256 currentId = mockNFT.currentTokenId();
        vm.expectRevert("Marketplace not approved");
        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);
        vm.stopPrank();
    }

    function test_ListNFT_Success() public {
        address seller = makeAddr("seller");
        vm.startPrank(seller);
        mockNFT.mint();
        uint256 currentId = mockNFT.currentTokenId();
        mockNFT.approve(address(nftMarketplace), currentId);

        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);

        (
            address listedSeller,
            ,
            uint256 tokenId,
            uint256 price,
            bool isListed
        ) = nftMarketplace.listings(address(mockNFT), currentId);
        assertEq(tokenId, currentId);
        assertEq(listedSeller, seller);
        assertEq(price, 1 ether);
        assertTrue(isListed);
    }


    function test_CancelListing_Success () {
        
    }
}
