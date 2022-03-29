// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./IUniswapV2Router.sol";
import "./IUniswapV2Factory.sol";
import "./ILaunchpadMaster.sol";

// V 0.1
contract LaunchpadChild is ReentrancyGuard, Pausable {
  // Inputs
  uint256 public tokenTotalAmount; // How many tokens are to be sent to the contract
  uint256 public listingTokensPerOneEth; // At which price should the tokens be listed?
  uint256 public liquidityShareBP; // Share of the raised eth to send to liquidity (100 = 1%)
  uint256 public hardcap; // Hardcap for the sale
  uint256 public softcap; // Softcap for the sale
  uint256 public feeBP; // Fees in basis points (100 = 1%)
  uint256 public startTime; // When will the sale start (unix timestamp)
  uint256 public endTime; // When will the sale end (unix timestamp)
  uint256 public wlStartTime; // When does the whitelist start

  // Utils variables
  uint256 public saleTokensPerOneEth; // How much tokens do I get for 1 ETH bought
  uint256 public liquidityUnlockTimestamp; // How long will the liquidity be locked after the sale ends
  uint256 public userVestDuration; // How long will the user need to vest after the sale ends
  uint256 public teamVestDuration; // How long will the team need to vest after the sale ends

  uint256 public maxBuyPerUser; // Max amount in eth allowed to buy
  uint256 public minBuyPerUser; // Min amount in eth allowed to buy
  uint256 public tokenAmountForSale; // How many tokens are actually for sale
  uint256 public tokenAmountForLiquidity; // How many tokens are actually for liquidity

  bool public userVestEnabled; // Are the tokens vested for the users?
  bool public teamVestEnabled; // Are the tokens vested for the team?
  mapping(address => bool) public whitelist;// Instance of the token sold on presale
  bool public whitelistEnabled; // Do we have a whitelist?

  address public deadAddress = 0x000000000000000000000000000000000000dEaD;

  address public signer; // Who is the signer if the whitelist is enabled?
  ILaunchpadMaster public master; // Who is the master?
  // TODO: Remove comment
  // IMasterLaunchpad public master;                 // Who is the creator of the contract?
  IUniswapV2Router02 public router; // UniswapV2-like router used to add liquidity

  // Medatadata
  IERC20 public token; // Instance of the token sold on presale
  uint256 public saleId; // saleId, to identify the sale
  string public name; // Name of the presale
  string public description; // What to show on the front end
  string public imageUrl; // Image url for the front end

  address payable public recipient; // fee benificiary
  address payable public saleInitiator;
  uint256 public totalBuyEth; // Total amount of ETH bought

  bool public saleStarted; // Is sale ready for the launch?
  bool public saleEnded; // Is the sale ended and tokens are ready to be claimed?
  bool public saleAborted; // Allows the dev to abort the sale and the users to get their eth back

  mapping(address => address) public usersVestingWallets; // Vesting wallet of each user (to be confirmed)
  mapping(address => uint256) public userBuyAmount; // Eth pledged by each user

  event Debug(uint256 amount);

  // enum => all the public variables 
  // the variables have to be arrays of their type
  struct SLaunchpadExport {
  // Inputs
  uint256  tokenTotalAmount;
  uint256  listingTokensPerOneEth;
  uint256  liquidityShareBP; 
  uint256  hardcap; 
  uint256  softcap; 
  uint256  feeBP;
  uint256  startTime; 
  uint256  endTime; 
  uint256  wlStartTime; 

  // Utils variables
  uint256  saleTokensPerOneEth;
  uint256  liquidityUnlockTimestamp; 
  uint256  userVestDuration; 
  uint256  teamVestDuration; 

  uint256  maxBuyPerUser;
  uint256  minBuyPerUser; 
  uint256  tokenAmountForSale; 
  uint256  tokenAmountForLiquidity;

  bool  userVestEnabled;
  bool  teamVestEnabled;
  bool  whitelistEnabled; 
  address  signer;
  address  router; 

  // Medatadata
  address  token; 
  uint256  saleId;
  string  name;
  string  description;
  string  imageUrl;

  address   recipient; 
  address   saleInitiator;
  uint256  totalBuyEth; 

  bool  saleStarted; 
  bool  saleEnded; 
  bool  saleAborted;
  }

  function LaunchpadExport() external view returns (SLaunchpadExport memory export) {
    return SLaunchpadExport(
      tokenTotalAmount,
      listingTokensPerOneEth,
      liquidityShareBP,
      hardcap,
      softcap,
      feeBP,
      startTime,
      endTime,
      wlStartTime,
      saleTokensPerOneEth,
      liquidityUnlockTimestamp,
      userVestDuration,
      teamVestDuration,
      maxBuyPerUser,
      minBuyPerUser,
      tokenAmountForSale,
      tokenAmountForLiquidity,
      userVestEnabled,
      teamVestEnabled,
      whitelistEnabled,
      signer,
      address(router),
      address(token),
      saleId,
      name,
      description,
      imageUrl,
      recipient,
      saleInitiator,
      totalBuyEth,
      saleStarted,
      saleEnded,
      saleAborted
    );
  }

  constructor(
    // Metadata
    address _token,
    string memory _name,
    string memory _description,
    string memory _imageUrl,
    // uint _saleId, // use master interface
    // Sale inputs
    // TODO: use an array
    // We use an array to solve stackTooDeep error
    uint256[8] memory _saleInputs,
    // uint _tokenTotalAmount,
    // uint _listingTokensPerOneEth,
    // uint _liquidityShareBP,
    // uint _hardcap,
    // uint _startTime,
    // uint _endTime,
    // Miscellaneous
    bool _whitelistEnabled,
    uint256 _wlStartTime,
    uint256 _liquidityUnlockTimestamp,
    address _router,
    address _saleInitiator
  ) {
    // Metadata
    token = IERC20(_token);
    name = _name;
    description = _description;
    imageUrl = _imageUrl;

    // Sale parameters
    tokenTotalAmount = _saleInputs[0];
    listingTokensPerOneEth = _saleInputs[1];
    liquidityShareBP = _saleInputs[2];
    hardcap = _saleInputs[3];
    startTime = _saleInputs[4];
    endTime = _saleInputs[5];
    maxBuyPerUser = _saleInputs[6];
    minBuyPerUser = _saleInputs[7];

    require(minBuyPerUser < hardcap, "min buy per user is higher than hardcap");

    master = ILaunchpadMaster(msg.sender);
    feeBP = master.feesBP();

    saleTokensPerOneEth =
      ((tokenTotalAmount * (10_000 - liquidityShareBP)) / 10_000) /
      hardcap;

    softcap = hardcap / 2;
    tokenAmountForLiquidity = (tokenTotalAmount * liquidityShareBP) / 10_000;
    tokenAmountForSale = tokenTotalAmount - tokenAmountForLiquidity;

    // basically, Is the amount of ETH reserved for liquidity given the listing price inferior to the amount of ETH raised?
    require(
      tokenAmountForLiquidity / listingTokensPerOneEth <
        ((hardcap * (10_000 - feeBP)) / 10_000),
      "not enough ETH for liquidity, increase listing price or decrease liquidity share"
    );

    
    require(_liquidityUnlockTimestamp > endTime, "you need to set a liquidity unlock starting after the sale");
    liquidityUnlockTimestamp = _liquidityUnlockTimestamp;

    whitelistEnabled = _whitelistEnabled;
    wlStartTime = _wlStartTime;
    require(wlStartTime < startTime);

    saleId = master.currentSaleId();

    if (whitelistEnabled) {
      signer = master.saleToSigner(saleId);
    }

    recipient = payable(master.feesWallet());
    saleInitiator = payable(_saleInitiator);

    router = IUniswapV2Router02(_router);
  }

  // Check if the msg.sender is the user who launched the sale
  modifier onlyInitiator() {
    require(saleInitiator == msg.sender, "caller is not the initiator");
    _;
  }

  // Check if the msg.sender is a contract or not
  modifier notContract() {
    // TODO: change implementation before update solidity PoS
    require(!_isContract(msg.sender), "contract not allowed");
    require(msg.sender == tx.origin, "proxy contract not allowed");
    _;
  }

  // Get the amount of tokens sold so far
  function totalBuyTokens() public view returns (uint256) {
    return (totalBuyEth * saleTokensPerOneEth);
  }

  // Allows the initiator to abort the sale, if claiming hasn't started
  // This will allow users to claim their ETH back
  // Deploy fee will not be reimbursed
  function abortSale() external onlyInitiator {
    require(!saleEnded, "claiming has already started");
    require(!saleAborted, "sale already aborted");
    saleAborted = true;
  }

  // When everything is ready
  function finalizeSale() external onlyInitiator {
    // Additionnal checks just to be safe
    require(!saleAborted, "sale was aborted");
    require(
      token.balanceOf(address(this)) >= tokenTotalAmount,
      "insufficient amount of tokens sent to the address"
    );
    saleStarted = true;
  }

  // Use this function for the general public sale
  function buyTokensPublic()
    external
    payable
    nonReentrant
    whenNotPaused
    notContract
  {
    require(!saleAborted, "sale was aborted");
    require(saleStarted, "sale hasn't been finalized yet");
    require(block.timestamp > startTime, "sale hasn't started yet");
    require(block.timestamp < endTime, "sale has ended");
    require(
      msg.value + userBuyAmount[msg.sender] <= maxBuyPerUser,
      "you're trying to buy too many tokens"
    );
    require(msg.value >= minBuyPerUser, "you're not sending enough");
    require(
      msg.value * saleTokensPerOneEth + totalBuyTokens() <= tokenAmountForSale,
      "there aren't enough tokens left. Try a lower amount"
    );
    require(
      totalBuyEth + msg.value <= hardcap,
      "hardcap is reached. Try a lower amount"
    );

    userBuyAmount[msg.sender] = userBuyAmount[msg.sender] + msg.value;
    totalBuyEth = totalBuyEth + msg.value;
  }

  function setWhitelisted(address[] memory _whitelist, bool isWhitelisted) 
  public
  {
    require(msg.sender == signer, "only the signer can whitelist");

    for (uint i = 0; i < _whitelist.length; i++) {
      whitelist[_whitelist[i]] = isWhitelisted;
    }
  }


  function buyTokensWhitelist(bytes memory signature)
    external
    payable
    nonReentrant
    whenNotPaused
  {
    require(verify(signature, msg.sender, saleId, block.chainid));
    require(whitelistEnabled, "whitelist is not enabled");
    require(whitelist[msg.sender], "you're not whitelisted");

    require(!saleAborted, "sale was aborted");
    require(saleStarted, "sale hasn't been finalized yet");
    require(block.timestamp < endTime, "sale has ended");
    require(block.timestamp > wlStartTime, "sale hasn't started yet");
    require(msg.value + userBuyAmount[msg.sender] <= maxBuyPerUser, "you're trying to buy too many tokens" );
    require(msg.value >= minBuyPerUser, "you're not sending enough");
    require(msg.value * saleTokensPerOneEth + totalBuyTokens() <= tokenAmountForSale, "there aren't enough tokens left. Try a lower amount");
    require(totalBuyEth + msg.value <= hardcap, "hardcap is reached. Try a lower amount");

    userBuyAmount[msg.sender] = userBuyAmount[msg.sender] + msg.value;
    totalBuyEth = totalBuyEth + msg.value;
  }

  // Use this function to close the sale and allow users to claim their tokens
  // This will prevent from buying more, add liquidity to the pool,
  // and send the remaining presale funds to the initiator of the sale
  function endSaleAllowClaim() external onlyInitiator nonReentrant {
    require(!saleAborted, "sale was aborted");
    require(saleStarted, "sale wasn't finalized");
    require(totalBuyEth > softcap, "not enough tokens were sold");
    require(!saleEnded, "sale was already ended");

    saleEnded = true;

    // We add liquidity on the fly
    uint256 ethAmountForLiquidity = totalBuyTokens() / listingTokensPerOneEth;
    uint256 actualTokenAmountForLiquidity = (tokenAmountForLiquidity *
      totalBuyEth) / hardcap;

    token.approve(address(router), actualTokenAmountForLiquidity);
    router.addLiquidityETH{value: ethAmountForLiquidity}(
      address(token),
      actualTokenAmountForLiquidity,
      0,
      0,
      address(this),
      block.timestamp + 1000
    );
    master.feesWallet().call{value: ((totalBuyEth * feeBP) / 10_000)}("");
    saleInitiator.call{value: address(this).balance}("");
  }

  function claimTokens() external nonReentrant {
    require(
      !saleAborted,
      "sale was aborted, please use claimStaleEth() function"
    );
    require(userBuyAmount[msg.sender] > 0, "user hasn't any tokens to claim");
    require(saleEnded, "initiator hasn't ended the sale yet");

    uint256 amountToClaim = userBuyAmount[msg.sender] * saleTokensPerOneEth;
    userBuyAmount[msg.sender] = 0;
    emit Debug(amountToClaim);
    token.transfer(msg.sender, amountToClaim);
  }

  // This function allows users to claim the eth provided to a sale if the owner didn't ended it after 24h.
  function claimStaleEth() external nonReentrant {
    require(!saleEnded, "sale has been ended : you can claim");

    // If the sale was aborted, you can claim back your eth
    if (saleAborted) {
      _claimStaleEth();
    }

    // If we didn't reach sofcap after the end of the sale, you can claim back
    if (totalBuyEth < softcap && block.timestamp > endTime) {
      _claimStaleEth();
    }

    // If the owner didn't close a successfull sale after 24h, you can claim back
    if (totalBuyEth > softcap && block.timestamp > endTime + 86400) {
      _claimStaleEth();
    }
  }

  // internal function to claim eth from failed sales
  function _claimStaleEth() private {
    require(userBuyAmount[msg.sender] > 0, "user hasn't any tokens to claim");
    uint256 amountToClaim = userBuyAmount[msg.sender];
    userBuyAmount[msg.sender] = 0;
    msg.sender.call{value: amountToClaim}("");
  }

  function unlockLiquidity() external onlyInitiator {
    require(block.timestamp > liquidityUnlockTimestamp, "too soon");
    IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
    IERC20 lpToken = IERC20(factory.getPair(address(token), router.WETH()));
    lpToken.transfer(saleInitiator, lpToken.balanceOf(address(this)));
  }

  function verify(
    bytes memory signature,
    address _target,
    uint256 _saleId,
    uint256 _chainId
  ) public view returns (bool) {
    uint8 v;
    bytes32 r;
    bytes32 s;

    (v, r, s) = splitSignature(signature);

    bytes32 payloadHash = keccak256(abi.encode(_target, _saleId, _chainId));

    bytes32 messageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", payloadHash)
    );
    return (signer == ecrecover(messageHash, v, r, s));
  }

  function splitSignature(bytes memory sig)
    public
    pure
    returns (
      uint8,
      bytes32,
      bytes32
    )
  {
    require(sig.length == 65);

    bytes32 r;
    bytes32 s;
    uint8 v;

    assembly {
      // first 32 bytes, after the length prefix
      r := mload(add(sig, 32))
      // second 32 bytes
      s := mload(add(sig, 64))
      // final byte (first byte of the next 32 bytes)
      v := byte(0, mload(add(sig, 96)))
    }

    return (v, r, s);
  }

  // Pause the contract, preventing to buy more tokens
  function pause() external onlyInitiator whenNotPaused {
    _pause();
  }

  // Unpause it
  function unpause() external onlyInitiator whenPaused {
    _unpause();
  }

  // Util to check if the sender is an already deployed contract
  function _isContract(address addr) internal view returns (bool) {
    uint256 size;
    assembly {
      size := extcodesize(addr)
    }
    return size > 0;
  }



}
