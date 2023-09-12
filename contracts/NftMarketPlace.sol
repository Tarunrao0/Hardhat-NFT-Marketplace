//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract  NftMarketPlace is ReentrancyGuard {
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

    event ItemBought (
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled (
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

//Mappings
// NFT Contract Address --> NFT token ID --> Listing
    mapping (address => mapping (uint256 => Listing)) private s_listings;
// Seller address --> Amount earned
    mapping (address => uint256) private s_proceeds;

//errors
    error NftMarketPlace__PriceMustBeAboveZero();
    error NftMarketPlace__NotApproved();
    error NftMarketPlace__AlreadyListed(address nftAddress, uint256 tokenId);
    error NftMarketPlace__NotOwner();
    error NftMarketPlace__NotListed(address nftAddress, uint256 tokenId);
    error NftMarketPlace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price );
    error NftMarketPlace__NoProceeds();
    error NftMarketPlace__TransferFailed();
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
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0){
            revert NftMarketPlace__AlreadyListed(nftAddress, tokenId);
        }
        _;    
   }
    // Making sure only the Owner can use the NFT contract
   modifier isOwner(address nftAddress, uint256 tokenId, address spender){
       IERC721 nft = IERC721(nftAddress);
       address owner = nft.ownerOf(tokenId);
       if( spender != owner) {
        revert NftMarketPlace__NotOwner();
       }
       _;
   }

   // Need Listed NFTs to buy!!
   modifier isListed(address nftAddress, uint256 tokenId){
    Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0){
            revert NftMarketPlace__NotListed(nftAddress, tokenId);
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
function listItem(
    address nftAddress,
    uint256 tokenId,
    uint256 price
   ) external 
    notListed(nftAddress, tokenId, msg.sender) 
    isOwner(nftAddress, tokenId, msg.sender){
        if (price <= 0){
            revert NftMarketPlace__PriceMustBeAboveZero();
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
        revert NftMarketPlace__NotApproved();
    }
    s_listings[nftAddress][tokenId] = Listing (price, msg.sender);
    emit ItemListed (msg.sender, nftAddress, tokenId, price);
   }
   /**
    * 
    * @param nftAddress : address of the contract minting the NFTs
    * @param tokenId : ID number of the NFT
    * 1) check if they sent enough ETH else revert
    * 2) update the balance of the seller
    * 3) Delete the listing
    * 4) Transfer the NFT from the seller to the sender 
    */
   /**
    * IMP : Reentrancy Attacks
    * basically if you havent reset the balance of the account before withdrawing 
    * an attacker could withdraw before the balance resets
    * 
    * FIX : 
    * 1) call the reset balance before withdrawing (or)
    * 2) Openzeppelin comes with a method of locking the function while the withdrawal takes place using a modifier
    * ex : status = _ENTERED;
    *       _;
    *      status = _NOT_ENTERED;
    * And use a bool inside the function to be able to withdraw only if it isnt locked
    */
function buyItem (address nftAddress, uint256 tokenId) 
   external 
   payable
   nonReentrant
   isListed(nftAddress, tokenId) {
        Listing memory listedItems = s_listings[nftAddress][tokenId];
        if (msg.value < listedItems.price ) {
            revert NftMarketPlace__PriceNotMet(nftAddress, tokenId, listedItems.price);
        }
        //Sending the money to the user ❌
        //Have them withdraw the money ✅
        //They can just withdraw their total amount from the s_proceeds data structure
        s_proceeds[listedItems.seller] = s_proceeds[listedItems.seller] + msg.value;
        delete (s_listings[nftAddress][tokenId]);
        IERC721(nftAddress).safeTransferFrom (listedItems.seller, msg.sender, tokenId);
        //check to make sure the NFT was transferred
        emit ItemBought( msg.sender, nftAddress, tokenId, listedItems.price);

}

function cancelListing ( address nftAddress, uint256 tokenId ) 
    external
    isOwner (nftAddress, tokenId, msg.sender)
    isListed ( nftAddress, tokenId )
{
    delete (s_listings[nftAddress][tokenId]);
    emit ItemCanceled (msg.sender, nftAddress, tokenId );
}

function updateListing (
    address nftAddress,
    uint256 tokenId,
    uint256 newPrice
) external
  isOwner (nftAddress, tokenId, msg.sender)
  isListed ( nftAddress, tokenId )
{   
    if (newPrice <= 0){
        revert NftMarketPlace__PriceMustBeAboveZero();
    }
    s_listings[nftAddress][tokenId].price = newPrice;
    emit ItemListed (msg.sender, nftAddress, tokenId, newPrice);
}

function withdrawProceeds () external {
    uint256 proceeds = s_proceeds[msg.sender];
    if ( proceeds <= 0) {
        revert NftMarketPlace__NoProceeds();
    }
    s_proceeds[msg.sender] = 0; //preventing a reentrancy attack by calling the state changes first
    ( bool success, ) = payable (msg.sender).call {value: proceeds}("");
    if (!success ) {
        revert NftMarketPlace__TransferFailed();
    }
}

    ///////////////////////
    // Getter Functions //
   //////////////////////

    function getListing ( address nftAddress, uint256 tokenId )
        external
        view
        returns (Listing memory)
    {
        return s_listings [nftAddress][tokenId];
    }

    function getProceeds (address seller) external view returns (uint256) {
        return s_proceeds [seller];
    }
}