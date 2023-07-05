// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC165} from "openzeppelin/utils/introspection/IERC165.sol";
import {IERC721Metadata} from "openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";
import {Address} from "openzeppelin/utils/Address.sol";

import {ITargetNft, MirrorNft} from "./MirrorNft.sol";

interface ICryptoPunks {
    function punkIndexToAddress(uint256 tokenId) external view returns (address owner);
}

interface ITargetNftERC721 is ITargetNft, IERC721Metadata {}
 
contract MirrorHub {
    using Address for address;

    // errors
    error NotIERC721();
    error OriginTokenIdNotExist();

    // storage
    address public constant CryptoPunks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    MirrorNft public immutable mirror_nft;
    mapping(IERC721Metadata => ITargetNftERC721) public nft_map;

    // events
    event NewMirrorNft(IERC721Metadata indexed origin_nft);
    event Mirror(IERC721Metadata indexed origin_nft, uint256 indexed origin_tokenId, address indexed to);

    constructor() {
        mirror_nft = new MirrorNft();
    }

	function _check_origin_nft(IERC721Metadata origin_nft) internal view {
		address origin_nft_address = address(origin_nft);
		if(block.chainid != 1 || origin_nft_address != CryptoPunks) {
			if (!origin_nft_address.isContract()) revert NotIERC721();
			try IERC165(origin_nft_address).supportsInterface(0x80ac58cd) returns (bool retval) {
				if (!retval) {
					revert NotIERC721();
				}
			} catch {
				revert NotIERC721();
			}
		}
	}

	function _check_origin_token(IERC721Metadata origin_nft, uint256 origin_tokenId) internal view {
		address origin_nft_address = address(origin_nft);

		function (uint256) external view returns (address) ownerOf_func;
		if(origin_nft_address == CryptoPunks) {
			ownerOf_func = ICryptoPunks(address(origin_nft)).punkIndexToAddress;
		} else {
			ownerOf_func = origin_nft.ownerOf;
		}

		try ownerOf_func(origin_tokenId) returns (address token_owner) {
			if(token_owner == address(0)) revert OriginTokenIdNotExist();
		} catch {
			revert OriginTokenIdNotExist();
		}
	}

    function _mirror_to(IERC721Metadata origin_nft, uint256 origin_tokenId, address to) internal {
        // get target_nft
        ITargetNftERC721 target_nft = nft_map[origin_nft];

        if (address(target_nft) == address(0)) {
            // check origin_nft
			_check_origin_nft(origin_nft);
        }
		// check origin_token
		_check_origin_token(origin_nft, origin_tokenId);

        if (address(target_nft) == address(0)) {
            // deploy target_nft
            target_nft = ITargetNftERC721(Clones.clone(address(mirror_nft)));
            target_nft.initialize(origin_nft, address(this));
            nft_map[origin_nft] = target_nft;

            emit NewMirrorNft(origin_nft);
		}

        target_nft.mint_to(to, origin_tokenId);

        emit Mirror(origin_nft, origin_tokenId, to);
    }

    function mirror(IERC721Metadata origin_nft, uint256 origin_tokenId) external {
        _mirror_to(origin_nft, origin_tokenId, msg.sender);
    }
}
