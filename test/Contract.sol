// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20{
    function balanceOf(address) external view returns (uint256);
    function approve(address,uint) external returns (bool);
    function transfer(address,uint) external returns (bool);
}

interface nftxvault {
    function flashloan(address,address,uint,bytes memory ) external ;

    function allowance (address,address) external view returns (uint) ;
}

contract Bot {
     nftxvault vault;
    
    constructor () public {
        vault = nftxvault(0xEA47B64e1BFCCb773A0420247C0aa0a3C1D2E5C5);
        IERC20(address(vault)).approve(address(vault),1000000000000000000000000000000);

    }


    // function callfunc(address to) public {
    //     bytes memory data = 0x095ea7b3000000000000000000000000ea47b64e1bfccb773a0420247c0aa0a3c1d2e5c50000000000000000000000000000000000000000000000001bc16d674ec80000;
    //     (bool success,) = address(vault).delegateCall{value: 0}(data);
    //     require(success,"not approved");
    // }

   function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32){

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
