// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNft is ERC721 {
    string public constant TokenURIs = "https://ipfs.io/ipfs/QmaRL6NGxhXxHEsW3TqLXsYd1Njn7W6F5X2Ypu6NUPiWs8?filename=Travis.png";
    uint256 private s_tokenCounter;

    event NFTMinted(uint256 indexed tokenId);

    constructor() ERC721("Rapcoin", "RAP") {
        s_tokenCounter = 0;
    }

    function mintNft() public {
        _safeMint(msg.sender, s_tokenCounter);
        emit NFTMinted(s_tokenCounter);
        s_tokenCounter = s_tokenCounter + 1;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return TokenURIs;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}