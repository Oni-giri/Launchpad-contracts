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
  bool public inDeploy; // util var

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
    address _router
  ) external payable whenNotPaused nonReentrant returns (address presaleAddress) {
    // Basic checks
    require(msg.value >= deployFee, "not enough eth sent");
    require(
      _saleInputs.length == 9,
      "not enough parameters in saleInputs array"
    );

    // New index
    currentSaleId = currentSaleId + 1;
    saleToSigner[currentSaleId] = signer;

    // Generating the deploy code
    bytes memory bytecode = abi.encodePacked(
      type(LaunchpadChild).creationCode,
      abi.encode(
        _token,
        _description,
        _imageUrl,
        _saleInputs,
        _whitelistEnabled,
        _wlStartTime,
        _liquidityLockDuration,
        _router
      )
    );

    // Prepping the deploy
    address saleAddress = getAddress(bytecode, currentSaleId);
    IERC20(_token).transferFrom(msg.sender, saleAddress, _saleInputs[0]);
    require(
      IERC20(_token).balanceOf(saleAddress) == _saleInputs[0],
      "you didn't whitelist the sale address"
    );

    // Deploy the contract
    inDeploy = true;
    address deployedAddress = deploy(bytecode, currentSaleId);
    inDeploy = false;
    require(
      saleAddress == deployedAddress,
      "computed address and actual deploy address are not equal"
    );

    // Update the registry
    saleIdToAddress[currentSaleId] = saleAddress;
    addressToSaleId[saleAddress] = currentSaleId;
  }

  function claimFees() external onlyOwner nonReentrant {
    payable(owner()).call{value: address(this).balance}("");
  }

  function getAddress(bytes memory bytecode, uint256 _salt)
    public
    view
    returns (address)
  {
    bytes32 hash = keccak256(
      abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode))
    );

    // NOTE: cast last 20 bytes of hash to address
    return address(uint160(uint256(hash)));
  }

  function deploy(bytes memory bytecode, uint256 _salt)
    public
    payable
    whenNotPaused
    returns (address)
  {
    require(msg.value >= deployFee, "not enough eth sent");
    require(inDeploy, "unauthorized deploy");
    address addr;

    /*
        NOTE: How to call create2

        create2(v, p, n, s)
        create new contract with code at memory p to p + n
        and send v wei
        and return the new address
        where new address = first 20 bytes of keccak256(0xff + address(this) + s + keccak256(mem[p…(p+n)))
              s = big-endian 256-bit value
        */
    assembly {
      addr := create2(
        0, // wei sent with current call
        // Actual code starts after skipping the first 32 bytes
        add(bytecode, 0x20),
        mload(bytecode), // Load the size of code contained in the first 32 bytes
        _salt // Salt from function arguments
      )

      if iszero(extcodesize(addr)) {
        revert(0, 0)
      }
    }

    emit Deployed(addr, _salt);
    return (addr);
  }
}
