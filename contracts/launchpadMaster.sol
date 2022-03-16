// "SPDX-License-Identifier: MIT"
pragma solidity =0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./launchpadChild.sol";

// V 0.1
// TODO: add pauser
// TODO: add setters
// TODO: add blacklist

contract LaunchpadMaster is Ownable, ReentrancyGuard, Pausable {
  event Deployed(address addr, uint256 salt);

  mapping(uint256 => address) public saleIdToAddress;
  mapping(address => uint256) public addressToSaleId;
  mapping(uint256 => address) public saleToSigner;
  uint256 public currentSaleId;
  uint256 public feesBP; // Fees in basis points (100 = 1%)
  uint256 public startSaleId; // Start of the sale count
  uint256 public deployFee; // Amount to pay to deploy a sale
  address public signer; // who signs for presales
  address payable public feesWallet; // Who gets the fees

  constructor(
    uint256 _feesBP,
    uint256 _startSaleId,
    address _signer,
    address _feesWallet,
    uint256 _deployFee
  ) {
    feesBP = _feesBP;
    feesWallet = payable(_feesWallet);
    currentSaleId = _startSaleId;
    signer = _signer;
    deployFee = _deployFee;
  }

  function createPresale(
    address _token,
    string memory _description,
    string memory _imageUrl,
    // Sale inputs
    // We use an array to solve stackTooDeep error
    uint256[8] memory _saleInputs,
    // uint _tokenTotalAmount,
    // uint _listingTokensPerOneEth,
    // uint _liquidityShareBP,
    // uint _hardcap,
    // uint _startTime,
    // uint _endTime,
    // uint _maxBuyPerUser
    // uint _minBuyPerUser
    // Miscellaneous
    bool _whitelistEnabled,
    uint256 _wlStartTime,
    uint256 _liquidityLockDuration,
    address _router
  ) external payable whenNotPaused nonReentrant returns (address saleAddress) {
    // Basic checks
    require(msg.value >= deployFee, "not enough eth sent");
    require(
      _saleInputs.length == 8,
      "not enough parameters in saleInputs array"
    );

    // New index
    saleToSigner[currentSaleId] = signer;

    // Deploy the contract
    LaunchpadChild deployedSale = new LaunchpadChild(
      _token,
      _description,
      _imageUrl,
      _saleInputs,
      _whitelistEnabled,
      _wlStartTime,
      _liquidityLockDuration,
      _router,
      msg.sender
    );

    // Update the registry
    saleAddress = address(deployedSale);
    saleIdToAddress[currentSaleId] = saleAddress;
    addressToSaleId[saleAddress] = currentSaleId;

    currentSaleId = currentSaleId + 1;

    return (saleAddress);
  }

  function claimFees() external nonReentrant {
    require(msg.sender == feesWallet, "not authorized");
    payable(feesWallet).call{value: address(this).balance}("");
  }

  function setSigner(address _signer) external onlyOwner {
    signer = _signer;
  }

  function setFeesBP(uint _feesBP) external onlyOwner {
    require(_feesBP < 10_000, "too high");
    feesBP = _feesBP;
  }

  function setDeployFee(uint _deployFee) external onlyOwner {
    deployFee = _deployFee;
  }

  receive() external payable {}
}
