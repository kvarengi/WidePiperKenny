// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/utils/math/Math.sol';


import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakeRouter01.sol";
import "./interfaces/IPancakeV2Pair.sol";
import './utils/Counters.sol';


interface IWidePiperTokenInterface is IERC20 {
    function burn(uint256 _amount) external ;
     function mint(address to, uint256 amount) external;
}

contract AssetManager is Ownable {
    using Counters for Counters.Counter;
    using Math for uint256;
    using Math for uint;
    using Math for uint112;
    using Math for uint8;

    Counters.Counter private _nodeId;
    Counters.Counter private _currentBlockNo;

    IWidePiperTokenInterface private widePiperTokenContract;
    IERC20 private toncoinContract;

    IPancakeFactory private pancakeFactoryContract;
    IPancakeRouter01 private pancakeRouterContract;

    IPancakeV2Pair private tonWidePiperPoolContract;
    IPancakeV2Pair private ethWidePiperPoolContract;
    

    address public toncoinAddress;
    address public widePiperTokenAddress;
    address public wethAddress;

    address public tonWidepiperPoolAddress;
    address public ethWidepiperPoolAddress;
    

    //  The time of the next block processing operation
    uint256 public nextBlockTime;
    // the interval between block processing operations
    uint256 public blockInterval= 10 minutes;

     struct Node {
        uint256 id;
        NodeType nodeType;
        address owner;
        uint256 risk;
        uint256 reward;
        uint256 startBlockNo;
        uint8 rounds;
    }


    Node[] private nodes;


    enum NodeType {
        ETH, TON
    }

    constructor(address _toncoinAddress, address _widePiperTokonAddress,address _wethAddress, address _pancakePoolFactory, address _pancakeRouter)Ownable(msg.sender){
        nextBlockTime = block.timestamp + blockInterval;
        widePiperTokenContract = IWidePiperTokenInterface(_widePiperTokonAddress);
        wethAddress = wethAddress;
        toncoinContract = IERC20(_toncoinAddress);
        pancakeRouterContract= IPancakeRouter01(_pancakeRouter);
        pancakeFactoryContract = IPancakeFactory(_pancakePoolFactory);
        toncoinAddress = _toncoinAddress;
        widePiperTokenAddress = _widePiperTokonAddress;
        tonWidepiperPoolAddress = getPool(_toncoinAddress,_widePiperTokonAddress);
        ethWidepiperPoolAddress = getPool(_widePiperTokonAddress, _wethAddress);
        tonWidePiperPoolContract = IPancakeV2Pair(tonWidepiperPoolAddress);
        ethWidePiperPoolContract = IPancakeV2Pair(ethWidepiperPoolAddress);

    }

    // @dev function for creating new ton nodes
    // @param uint256 _risk: amount of toncoin to be wagered;
    // @param uint8 _numRounds: number of rounds the wager should be considered;
    // @param address _owner: address to recive rewards and withdraw deposits to;
    // @note  wagering period has to be restricted to only the first five minutes of the current block
    // so that users cannot simply create nodes seconds before the processing operation is commenced

    function createNode(uint256 _risk, uint8 _numRounds, address _owner, NodeType _nodeType) public {
        // ensure user sends enough ton coin to cover the risk
        //revert if current time minus next block time is less than 5 minutes
        // mint new widepiper tokens and pair with half the deposited tokens
        if(_nodeType == NodeType.TON){
            // calculate amount of new widepiper tokens to mint;
            // how many widepiper tokens should be paired with _risk.tryDiv(2)?
            (, uint256 tonAmount)= _risk.tryDiv(2);
            (,uint256 tonSlippage)=tonAmount.tryDiv(100);// 1% slippage
            (,uint256 minTonAmount)= tonAmount.trySub(tonSlippage);
            (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)=   tonWidePiperPoolContract.getReserves();
            // if reserve0==0 | reserve1== 0: use the initial price to calculate number of tokens to mint
            //else:
            uint widepiperTokensToMintAmt=  pancakeRouterContract.quote(tonAmount, uint(reserve0), uint(reserve1));
            (, uint256 widepiperSlippage)=widepiperTokensToMintAmt.tryDiv(100);
            (,uint minWidepiperTokensToMintAmt)= widepiperTokensToMintAmt.trySub(widepiperSlippage);
            (,uint deadline)= uint(blockTimestampLast).tryAdd(1 minutes);
            //mint required amount of widepiper tokens
            widePiperTokenContract.mint(address(this), widepiperTokensToMintAmt);
            //*** approve widepiperTokens to pair contract
            //*** approve weth to pair contract
            // add minted tokens with _risk.tryDiv(2) to ton-widePiper lp address
            pancakeRouterContract.addLiquidity(
                    toncoinAddress,
                    widePiperTokenAddress,
                    uint(tonAmount),
                    widepiperTokensToMintAmt,
                    uint(minTonAmount),
                    minWidepiperTokensToMintAmt,
                    address(this),
                    deadline
            );



        }
        if(_nodeType == NodeType.ETH){
            // calculate amount of new widepiper tokens to mint;
             // how many widepiper tokens should be paired with _risk.tryDiv(2)?
            (, uint256 wethAmount)= _risk.tryDiv(2);
            (,uint256 wethSlippage)=wethAmount.tryDiv(100);// 1% slippage
            (,uint256 minWethAmount)= wethAmount.trySub(wethSlippage);
            (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)=   ethWidePiperPoolContract.getReserves();
            // if reserve0==0 | reserve1== 0: use the initial price to calculate number of tokens to mint
            //else:
            uint widepiperTokensToMintAmt=  pancakeRouterContract.quote(wethAmount, uint(reserve0), uint(reserve1));
            (, uint256 widepiperSlippage)=widepiperTokensToMintAmt.tryDiv(100);
            (,uint minWidepiperTokensToMintAmt)= widepiperTokensToMintAmt.trySub(widepiperSlippage);
            (,uint deadline)= uint(blockTimestampLast).tryAdd(1 minutes);
            //mint required amount of widepiper tokens
            widePiperTokenContract.mint(address(this), widepiperTokensToMintAmt);
            //*** approve widepiperTokens to pair contract
            //*** approve weth to pair contract
            // add minted tokens with _risk.tryDiv(2) to ton-widePiper lp address
            pancakeRouterContract.addLiquidityETH(                   
                    widePiperTokenAddress,                    
                    widepiperTokensToMintAmt,                    
                    minWidepiperTokensToMintAmt,
                    uint(minWethAmount),
                    address(this),
                    deadline
            );
            // add minted tokens with _risk.tryDiv(2) to eth-widePiper lp address
            
        }

        // create and store new node a new TonNode with the given parameters
         Node memory newNode = Node(
            _nodeId.current(),
            _nodeType,
            _owner,
            _risk,
            0,
            _currentBlockNo.current(),
            _numRounds
        );

        nodes.push(newNode);
        _nodeId.increment();

        


    }

    function processBlock() public {
        _currentBlockNo.increment();
    }

    // private functions
    function getPool(address _tokenA, address _tokenB) private returns(address){
        address poolAddress = pancakeFactoryContract.getPair(_tokenA, _tokenB);
        if(poolAddress == address(0)){
            poolAddress = pancakeFactoryContract.createPair(_tokenA,_tokenB);
        }
        return poolAddress;
    }


    // view/read functions
    function getCurrentBlockNumber() public view returns(uint256){
        return _currentBlockNo.current();
    }

}