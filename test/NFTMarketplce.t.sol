// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MockNFT} from "../src/MockNFT.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public nftMarketplace;
    MockNFT public mockNFT;

    function setUp() public {
        nftMarketplace = new NFTMarketplace();
        mockNFT = new MockNFT();
    }
    receive() external payable {}

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

    // cancel list

    function test_CancelListing_OwnerCheck() public {
        address seller = makeAddr("seller");
        vm.startPrank(seller);

        mockNFT.mint();
        uint256 currentId = mockNFT.currentTokenId();
        mockNFT.approve(address(nftMarketplace), currentId);
        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);

        vm.stopPrank();

        vm.prank(makeAddr("fack"));
        vm.expectRevert("You are not the seller");
        nftMarketplace.cancelListing(address(mockNFT), currentId);
    }

    function test_CancelListing_check_isListed() public {
        address seller = makeAddr("seller");
        vm.startPrank(seller);

        mockNFT.mint();
        uint256 currentId = mockNFT.currentTokenId();
        mockNFT.approve(address(nftMarketplace), currentId);
        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);
        nftMarketplace.cancelListing(address(mockNFT), currentId);

        vm.expectRevert("Not listed");
        nftMarketplace.cancelListing(address(mockNFT), currentId);
        vm.stopPrank();
    }

    function test_CancelListing_Success() public {
        address seller = makeAddr("seller");
        vm.startPrank(seller);

        mockNFT.mint();
        uint256 currentId = mockNFT.currentTokenId();
        mockNFT.approve(address(nftMarketplace), currentId);
        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);

        nftMarketplace.cancelListing(address(mockNFT), currentId);
        vm.stopPrank();

        (, , , , bool isListed) = nftMarketplace.listings(
            address(mockNFT),
            currentId
        );

        assertFalse(isListed);
    }

    // buy NFT

    function test_buyNFT_success() public {
        address seller = makeAddr("seller");
        address buyer = makeAddr("buyer");
        vm.startPrank(seller);
        mockNFT.mint();
        uint256 currentId = mockNFT.currentTokenId();
        mockNFT.approve(address(nftMarketplace), currentId);
        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);
        vm.stopPrank();

        // buy
        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);

        uint256 initialBalance = buyer.balance;
        nftMarketplace.buyNFT{value: 2 ether}(address(mockNFT), currentId);
        uint256 currentBalance = buyer.balance;
        vm.stopPrank();

        (
            address listedSeller,
            address nftContract,
            uint256 listedTokenId,
            uint256 listedPrice,
            bool isListed
        ) = nftMarketplace.listings(address(mockNFT), currentId);

        assertEq(nftContract, address(0));
        assertEq(listedSeller, address(0));
        assertEq(listedTokenId, 0);
        assertEq(listedPrice, 0);
        assertFalse(isListed);

        // 🔒 ESSENTIAL COMPREHENSIVE FINANCIAL & ASSET CHECKS:

        assertEq(currentBalance, initialBalance - 1 ether);
        assertEq(mockNFT.ownerOf(currentId), buyer);
        assertEq(seller.balance, 0.975 ether);
        assertEq(nftMarketplace.accumulatedFees(), 0.025 ether);
    }

    function test_updatePlatformFee_exceed_check() public {
        vm.expectRevert("Fee cannot exceed 10%");
        nftMarketplace.updatePlatformFee(2000);
    }

    function test_updatePlatformFee_fake_owner() public {
        address fakeOwner = makeAddr("fakeOwner");
        vm.prank(fakeOwner);

        vm.expectRevert();
        nftMarketplace.updatePlatformFee(1000);
    }

    function test_updatePlatformFee_success() public {
        uint256 newBps = 500;
        nftMarketplace.updatePlatformFee(newBps);
        uint256 platformFeeBps = nftMarketplace.platformFeeBps();

        assertEq(platformFeeBps, newBps);
    }

    function test_withdraw_success() public {
        address seller = makeAddr("seller");
        address buyer = makeAddr("buyer");

        vm.startPrank(seller);
        mockNFT.mint();
        uint256 currentId = mockNFT.currentTokenId();
        mockNFT.approve(address(nftMarketplace), currentId);
        nftMarketplace.listNFT(address(mockNFT), currentId, 1 ether);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);
        nftMarketplace.buyNFT{value: 2 ether}(address(mockNFT), currentId);
        vm.stopPrank();

        uint256 ownerInitialBalance = address(this).balance;
        nftMarketplace.withdrawFees();

        assertEq(nftMarketplace.accumulatedFees(), 0);
        assertEq(address(this).balance, ownerInitialBalance + 0.025 ether);
    }
}
