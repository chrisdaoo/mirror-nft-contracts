// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import "forge-std/Test.sol";
import "../src/MirrorHub.sol";
import "../src/Nft.sol";
import "../src/NotNft.sol";

contract MirrorHubHarness is MirrorHub {
    function exposed_mirror_to(IERC721Metadata origin_nft, uint256 origin_tokenId, address to) external {
        _mirror_to(origin_nft, origin_tokenId, to);
    }
}

contract MirrorHubTest is ERC721TokenReceiver, Test {
    MirrorHubHarness public mirror_hub;

    address public constant CryptoPunks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;

    error NotIERC721();
    error OriginTokenIdNotExist();

    event NewMirrorNft(IERC721Metadata indexed origin_nft);
    event Mirror(IERC721Metadata indexed origin_nft, uint256 indexed origin_tokenId, address indexed to);

    function setUp() public {
        mirror_hub = new MirrorHubHarness();
    }

    function test_mirror_simple() public {
        Nft origin_nft = new Nft("AAA", "AAA");
        origin_nft.mint(address(this), 1);

        vm.expectEmit(true, true, true, true);
        emit Mirror(origin_nft, 1, address(this));
        mirror_hub.mirror(origin_nft, 1);
    }

    function test_RevertIf_OriginTokenIdNotExist() public {
        Nft origin_nft = new Nft("AAA", "AAA");
        origin_nft.mint(address(this), 1);

        vm.expectRevert(OriginTokenIdNotExist.selector);
        mirror_hub.mirror(origin_nft, 2);
    }

    function test_mirror_to() public {
        Nft origin_nft = new Nft("AAA", "AAA");
        origin_nft.mint(address(this), 1);

        vm.expectEmit(true, true, true, true);
        emit NewMirrorNft(origin_nft);
        vm.expectEmit(true, true, true, true);
        emit Mirror(origin_nft, 1, address(0x1234));
        mirror_hub.exposed_mirror_to(origin_nft, 1, address(0x1234));
    }

    function test_RevertIf_OriginNftIsEOA() public {
        Nft origin_nft = Nft(address(0x1234));
        vm.expectRevert(NotIERC721.selector);
        mirror_hub.mirror(origin_nft, 1);
    }

    function test_RevertIf_OriginNftIsNotNft() public {
        NotNft origin_nft = new NotNft();
        vm.expectRevert(NotIERC721.selector);
        mirror_hub.mirror(IERC721Metadata(address(origin_nft)), 1);
    }

    function test_real_nft_mirror() public {
        vm.createSelectFork("https://cloudflare-eth.com/", 17623295);
        MirrorHub _mirror_hub = new MirrorHubHarness();

        IERC721Metadata origin_nft = IERC721Metadata(0xED5AF388653567Af2F388E6224dC7C4b3241C544);
        _mirror_hub.mirror(origin_nft, 2);

        ITargetNftERC721 target_nft = _mirror_hub.nft_map(origin_nft);

        assertEq(target_nft.balanceOf(address(this)), 1);
        assertEq(target_nft.ownerOf(1), address(this));

        assertEq(target_nft.name(), origin_nft.name());
        assertEq(target_nft.symbol(), origin_nft.symbol());
        assertEq(target_nft.tokenURI(1), origin_nft.tokenURI(2));
    }

    function test_mirror_cryptopunks() public {
        vm.createSelectFork("https://cloudflare-eth.com/", 17623295);
        MirrorHub _mirror_hub = new MirrorHubHarness();

        IERC721Metadata origin_nft = IERC721Metadata(CryptoPunks);
        _mirror_hub.mirror(origin_nft, 100);
        ITargetNftERC721 target_nft = _mirror_hub.nft_map(origin_nft);

        assertEq(target_nft.name(), origin_nft.name());
        assertEq(target_nft.symbol(), origin_nft.symbol());

        // console2.log(target_nft.tokenURI(1));
    }
}
