// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC721Metadata} from "openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {Base64} from "openzeppelin/utils/Base64.sol";
import {strings} from "solidity-stringutils/strings.sol";

interface ITargetNft {
    function initialize(IERC721Metadata _origin_nft, address _mirror_hub) external;
    function mint_to(address to, uint256 origin_tokenId) external;
}

interface ICryptopunksData {
    function punkAttributes(uint16 index) external view returns (string memory text);
    function punkImageSvg(uint16 index) external view returns (string memory svg);
}

contract MirrorNft is ERC721("MirrorNft", "M721"), ITargetNft {
    using strings for *;

    address public constant CryptoPunks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    ICryptopunksData public constant CryptopunksData = ICryptopunksData(0x16F5A35647D6F03D5D3da7b35409D65ba03aF3B2);

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

    function _get_CryptoPunks_attributes(uint256 origin_tokenId) internal view returns (string[] memory) {
        string memory attributes = CryptopunksData.punkAttributes(uint16(origin_tokenId));
        strings.slice memory s = attributes.toSlice();
        strings.slice memory delim = ", ".toSlice();
        string[] memory parts = new string[](s.count(delim) + 1);
        for (uint256 i = 0; i < parts.length; i++) {
            parts[i] = s.split(delim).toString();
        }
        return parts;
    }

    function _CryptoPunks_tokenURI(uint256 origin_tokenId) internal view returns (string memory) {
        // attributes_json_string
        string[] memory attributes = _get_CryptoPunks_attributes(origin_tokenId);
        string memory attributes_json_string = '"attributes":[';
        for (uint256 i = 0; i < attributes.length; i++) {
            attributes_json_string =
                string.concat(attributes_json_string, '{"trait_type":"attribute","value":"', attributes[i], '"}');
            if (i != attributes.length - 1) {
                attributes_json_string = string.concat(attributes_json_string, ",");
            }
        }
        attributes_json_string = string.concat(attributes_json_string, "]");

        // image: svg base64
        // data:image/svg+xml;utf8,<svg
        strings.slice memory svg = CryptopunksData.punkImageSvg(uint16(origin_tokenId)).toSlice();
        svg.split(",".toSlice());
        string memory svg_base64 = string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(svg.toString())));

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        "{",
                        '"name":"CryptoPunks #',
                        Strings.toString(origin_tokenId),
                        '",',
                        '"image":"',
                        svg_base64,
                        '",',
                        attributes_json_string,
                        "}"
                    )
                )
            )
        );
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721: invalid token ID");
        uint256 origin_tokenId = id_map[tokenId];
        if (address(origin_nft) == CryptoPunks) {
            return _CryptoPunks_tokenURI(origin_tokenId);
        } else {
            return origin_nft.tokenURI(origin_tokenId);
        }
    }

    function mint_to(address to, uint256 origin_tokenId) external only_mirrorhub {
        current_tokenId++;
        _safeMint(to, current_tokenId);
        id_map[current_tokenId] = origin_tokenId;
    }
}
