pragma solidity =0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20WithFees is ERC20 {

    mapping(address => bool) excludedFromFees;

    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }

    function _transfer(
        address from,
        address to,
       uint256 amount
    ) internal override {
        uint amountToSend;
        uint amountToBurn;
        if(excludedFromFees[from] || excludedFromFees[to]) {
            super._transfer(from, to, amount);
        } else {
            amountToSend = amount * 90 / 100;
            amountToBurn = amount - amountToBurn;
        }

        super._transfer(from, to, amountToSend);
        super._transfer(from, to, amountToBurn);
       
    }
}