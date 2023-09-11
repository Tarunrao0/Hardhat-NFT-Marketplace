//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract  NFTMarketPlace {
    struct Listing {
        uint256 price;
        address seller;
    }
//Events
    event ItemListed (
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

//Mappings
// NFT Contract Address --> NFT token ID --> Listing
    mapping (address => mapping (uint256 => Listing)) private s_listings;

//errors
    error NFTMarketPlace__PriceMustBeAboveZero();
    error NFTMarketPlace__NotApproved();
    error NFTMarketPlace__AlreadyListed(address nftAddress, uint256 tokenId);
    error NFTMarketPlace__NotOwner();
    error NFTMarketPlace__NotListed(address nftAddress, uint256 tokenId);
/**
 * We're gonna need a couple of functions
 * 1. `listItem`: List the NFTs on the marketplace
 * 2. `buyItem` : Buy the NFTs
 * 3. `cancelItem` : Cancel a listing
 * 4. `updateListing` : Update the Price
 * 5. `withdrawProceeds` : Withdraw payments for my bought NFTs
 */
    ///////////////
    // Modifier //
   //////////////

   //gotta make sure we're not re-listing NFTs

   modifier notListed(address nftAddress, uint256 tokenId, address owner) {
        Listing memory listing = s_listings[nftAddress][tokenId]
        if (listing.price > 0){
            revert NFTMarketPlace__AlreadyListed(nftAddress, tokenId);
        }
        _;    
   }
    // Making sure only the Owner can use the NFT contract
   modifier isOwner(address nftAddress, uint256 tokenId, address spender){
       IERC721 nft = IERC721(nftAddress);
       address owner = nft.ownerOf(tokenId)
       if( spender != owner) {
        revert NFTMarketPlace__NotOwner();
       }
       _;
   }

   // Need Listed NFTs to buy!!
   modifier isListed(address nftAddress, uint256 tokenId){
    Listing memory listing = s_listings[nftAddress][tokenId]
        if (listing.price <= 0){
            revert NFTMarketPlace__NotListed(nftAddress, tokenId);
        }
        _;
   }
   
    /////////////////////
    // Main Functions //
   //////////////////// 

    /**
     * 1) Check if the NFT is already Listed
     * 2) Check if the contract belongs to the Owner
     * 3) Check if it costs 0 or below 0 if yes return error
     * 4) Update the mapping
     */
   function listItems(
    address nftAddress,
    uint256 tokenId,
    uint256 price
   ) external 
    notListed(nftAddress, tokenId, msg.sender) 
    isOwner(nftAddress, tokenId, msg.sender){
        if (price <= 0){
            revert NFTMarketPlace__PriceMustBeAboveZero();
        }
    /**
     * The basic way would be to let the contract "hold" the NFT, but that wouldnt be not so gas effecient
     * Another way would be to let the Owner pass approval to the marketplace to sell their NFTs
     * approval can also be withdrawn.
     */
    // using a function getApproved from openzeppelin!
    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     * returns address
     */
    IERC721 nft = IERC721(nftAddress);
    if (nft.getApproved(tokenId) != address(this)) {
        revert NFTMarketPlace__NotApproved();
    }
    s_listings[nftAddress][tokenId] = Listing (price, msg.sender);
    emit ItemListed (msg.sender, nftAddress, tokenId, price);
   }

   function buyItem (address nftAddress, uint256 tokenId) 
   external 
   payable
   isListed(nftAddress, tokenId) {

   }
}