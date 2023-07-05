// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC721Metadata} from "openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

interface ITargetNft {
    function initialize(IERC721Metadata _origin_nft, address _mirror_hub) external;
    function mint_to(address to, uint256 origin_tokenId) external;
}

interface IBaseURI {
	function baseURI() external view returns (string memory);
}

contract MirrorNft is ERC721("MirrorNft", "M721"), ITargetNft {
	using Strings for uint256;

    address public constant CryptoPunks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    address public constant WrappedCryptoPunks = 0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6;

    IERC721Metadata public origin_nft;
    address public mirror_hub;
    mapping(uint256 => uint256) public id_map;
    uint256 public current_tokenId;
	bool public is_initialized;

    modifier only_mirrorhub() {
        require(msg.sender == mirror_hub, "Only MirrorHub can call this function.");
        _;
    }

    function initialize(IERC721Metadata _origin_nft, address _mirror_hub) external {
		require(!is_initialized, "has been initialized.");
        origin_nft = _origin_nft;
        mirror_hub = _mirror_hub;
		is_initialized = true;
    }

    function name() public view override returns (string memory) {
        return origin_nft.name();
    }

    function symbol() public view override returns (string memory) {
        return origin_nft.symbol();
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721: invalid token ID");
		if(address(origin_nft) == CryptoPunks) {
			string memory baseURI = IBaseURI(WrappedCryptoPunks).baseURI();
			return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, id_map[tokenId].toString())) : "";
		} else {
			return origin_nft.tokenURI(id_map[tokenId]);
		}
    }

    function mint_to(address to, uint256 origin_tokenId) external only_mirrorhub {
        current_tokenId++;
        _safeMint(to, current_tokenId);
        id_map[current_tokenId] = origin_tokenId;
    }
}
