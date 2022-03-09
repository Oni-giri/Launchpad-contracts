pragma solidity =0.8.7;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
// import "@openzeppelin/contracts/finance/VestingWallet.sol";
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
  uint256 public liquidityLockDuration; // How long will the liquidity be locked after the sale ends
  uint256 public userVestDuration; // How long will the user need to vest after the sale ends
  uint256 public teamVestDuration; // How long will the team need to vest after the sale ends

  uint256 public maxBuyPerUser; // Max amount in eth allowed to buy
  uint256 public minBuyPerUser; // Min amount in eth allowed to buy
  uint256 public tokenAmountForSale; // How many tokens are actually for sale
  uint256 public tokenAmountForLiquidity; // How many tokens are actually for liquidity

  bool public userVestEnabled; // Are the tokens vested for the users?
  bool public teamVestEnabled; // Are the tokens vested for the team?
  bool public whitelistEnabled; // Do we have a whitelist?

  address public deadAddress = 0x000000000000000000000000000000000000dEaD;

  address private signer; // Who is the signer if the whitelist is enabled?
  ILaunchpadMaster private master; // Who is the master?
  // TODO: Remove comment
  // IMasterLaunchpad public master;                 // Who is the creator of the contract?
  IUniswapV2Router02 public router; // UniswapV2-like router used to add liquidity
  IUniswapV2Factory public factory; // UniswapV2-like factory to create the LP

  // Medatadata
  IERC20 public token; // Instance of the token sold on presale
  uint256 public saleId; // saleId, to identify the sale
  string public description; // What to show on the front end
  string public imageUrl; // Image url for the front end

  address payable public recipient; // Who gets the fees?
  address payable public saleInitiator; // Who has started the sale?
  uint256 public totalBuy; // How many tokens were bought so far?

  bool public saleFinalized; // Is sale ready for the launch?
  bool public saleEnded; // Is the sale ended and tokens are ready to be claimed?
  bool public saleAborted; // Allows the dev to abort the sale and the users to get their eth back

  mapping(address => address) public usersVestingWallets; // Vesting wallet of each user (to be confirmed)
  mapping(address => uint256) public userBuyAmount; // Eth pledged by each user

  constructor(
    // Metadata
    address _token,
    string memory _description,
    string memory _imageUrl,
    // uint _saleId, // use master interface
    // Sale inputs
    // TODO: use an array
    // We use an array to solve stackTooDeep error
    uint256[9] memory _saleInputs,
    // uint _tokenTotalAmount,
    // uint _listingTokensPerOneEth,
    // uint _liquidityShareBP,
    // uint _hardcap,
    // uint _feeBP, -- use master interface
    // uint _startTime,
    // uint _endTime,
    // Miscellaneous
    bool _whitelistEnabled,
    uint256 _wlStartTime,
    uint256 _liquidityLockDuration,
    address _router,
    address _saleInitiator
  ) {
    // Metadata
    token = IERC20(_token);
    description = _description;
    imageUrl = _imageUrl;

    // Sale parameters
    tokenTotalAmount = _saleInputs[0];
    listingTokensPerOneEth = _saleInputs[1];
    liquidityShareBP = _saleInputs[2];
    hardcap = _saleInputs[3];
    feeBP = _saleInputs[4];
    startTime = _saleInputs[5];
    endTime = _saleInputs[6];
    maxBuyPerUser = _saleInputs[7];
    minBuyPerUser = _saleInputs[8];

    saleTokensPerOneEth =
      ((tokenTotalAmount * (10_000 - liquidityShareBP)) / 10_000) /
      hardcap;

    softcap = hardcap / 2;
    tokenAmountForLiquidity = (tokenTotalAmount * liquidityShareBP) / 10_000;
    tokenAmountForSale = tokenTotalAmount - tokenAmountForLiquidity;

    // basically, Is the amount of ETH reserved for liquidity given the listing price inferior to the amount of ETH raised?
    require(
      tokenAmountForLiquidity / listingTokensPerOneEth >
        ((hardcap * (10_000 - feeBP)) / 10_000),
      "not enough ETH for liquidity, increase listing price or decrease liquidity share"
    );
    require(
      token.balanceOf(address(this)) == tokenTotalAmount,
      "incorrect amount of tokens sent to the address"
    );

    liquidityLockDuration = _liquidityLockDuration;
    // userVestDuration = userVestDuration;
    // teamVestDuration = userVestDuration;
    // userVestEnabled = userVestDuration == 0 ? false : true;
    // teamVestEnabled = teamVestDuration == 0 ? false : true;

    whitelistEnabled = _whitelistEnabled;
    wlStartTime = _wlStartTime;
    require(wlStartTime < startTime);

    master = ILaunchpadMaster(msg.sender);
    saleId = master.addressToSaleId(address(this));
    signer = master.saleToSigner(saleId);
    recipient = payable(master.feesWallet());
    saleInitiator = payable(_saleInitiator);

    router = IUniswapV2Router02(_router);

    // TODO: Need to add the user vesting wallet when developped
  }

  // TODO: add pauser
  // TODO: add setters

  modifier onlyInitiator() {
    require(saleInitiator == msg.sender, "caller is not the initiator");
    _;
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
    saleFinalized = true;
  }

  function buyTokensPublic() external payable nonReentrant whenNotPaused {
    require(msg.value <= maxBuyPerUser, "you're trying to buy too many tokens");
    require(msg.value >= minBuyPerUser, "you're not sending enough");
    require(
      msg.value * saleTokensPerOneEth + totalBuy <= tokenAmountForSale,
      "there aren't enough tokens left. Try a lower amount"
    );
    require(
      address(this).balance <= hardcap,
      "hardcap is reached. Try a lower amount"
    );
    require(block.timestamp > startTime, "sale hasn't started yet");
    require(block.timestamp < endTime, "sale has ended");
    require(saleFinalized, "sale hasn't been finalized yet");

    userBuyAmount[msg.sender] = msg.value;
    totalBuy = totalBuy + (msg.value * saleTokensPerOneEth);
  }

  function buyTokensWhitelist(bytes memory signature)
    external
    payable
    nonReentrant
    whenNotPaused
  {
    require(verify(signature, msg.sender, saleId, block.chainid));
    require(msg.value <= maxBuyPerUser, "you're trying to buy too many tokens");
    require(msg.value >= minBuyPerUser, "you're not sending enough");
    require(
      msg.value * saleTokensPerOneEth + totalBuy <= tokenAmountForSale,
      "there aren't enough tokens left. Try a lower amount"
    );
    require(
      address(this).balance <= hardcap,
      "hardcap is reached. Try a lower amount"
    );
    require(block.timestamp > wlStartTime, "sale hasn't started yet");
    require(block.timestamp < endTime, "sale has ended");
    require(saleFinalized, "sale hasn't been finalized yet");

    userBuyAmount[msg.sender] = msg.value;
    totalBuy = totalBuy + (msg.value * saleTokensPerOneEth);
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
    bytes32 messageHash = keccak256(abi.encodePacked(_target, _saleId, _chainId));

    return (signer == address(ecrecover(messageHash, v, r, s)));
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

  function claimTokens() external nonReentrant {
    require(block.timestamp > endTime, "sale hasn't ended");
    require(userBuyAmount[msg.sender] > 0, "user hasn't any tokens to claim");
    require(saleEnded, "initiator hasn't ended the sale yet");

    uint256 amountToClaim = userBuyAmount[msg.sender] * saleTokensPerOneEth;
    userBuyAmount[msg.sender] = 0;

    token.transferFrom(address(this), msg.sender, amountToClaim);
  }

  // This function allows users to claim the eth provided to a sale if the owner didn't ended it after 24h.
  function claimStaleEth() external nonReentrant {
    require(!saleEnded, "sale has been ended : you can claim");
    if (!saleAborted) {
      require(
        block.timestamp > endTime + 86400,
        "you need to wait 24h after the end of the sale"
      );
    }
    require(userBuyAmount[msg.sender] > 0, "user hasn't any tokens to claim");

    uint256 amountToClaim = userBuyAmount[msg.sender];
    userBuyAmount[msg.sender] = 0;

    (bool sent, bytes memory data) = msg.sender.call{value: amountToClaim}("");
  }

  // Use this function to close the sale and allow users to claim their tokens
  // This will prevent from buying more, add liquidity to the pool, and send the remaining presale funds to the initiator of the sale
  function endSaleAllowClaim() external onlyInitiator nonReentrant {
    require(!saleAborted, "sale was aborted");
    require(saleFinalized, "sale wasn't finalized");
    require(block.timestamp >= endTime);
    require(
      totalBuy > (tokenTotalAmount * softcap) / hardcap,
      "not enough tokens were sold"
    );

    saleEnded = true;

    // We add liquidity on the fly
    uint256 ethAmountForLiquidity = totalBuy / listingTokensPerOneEth;
    // TODO: Need to test this for overflow risk
    uint256 actualTokenAmountForLiquidity = (tokenAmountForLiquidity *
      totalBuy) / tokenTotalAmount;

    token.approve(address(router), actualTokenAmountForLiquidity);
    router.addLiquidityETH{value: ethAmountForLiquidity}(
      address(token),
      actualTokenAmountForLiquidity,
      0,
      0,
      address(this),
      block.timestamp + 100
    );
  }
}