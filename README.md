# Launchpad contracts

## How does it work?

We have two contracts:

- LaunchpadMaster is the contract users who want to deploy a presale have to interact with. It deploys presale contracts and keeps track of them.
- LaunchpadChild is the presale contract deployed by LaunchpadMaster. It is the contract users who want to buy from the presale interact with.

The structure with two contracts mitigates risk by separating each presale from each other, preventing any reantrancy or other hacks from funny tokens.

If we need to make an update of LaunchpadMaster, we can pause it (no one can launch after), deploy a new one using the current `saleId`.

The workflow for the user is the following:

1. Interact with `LaunchpadMaster.createPresale()` to start a presale. This will deploy a `LaunchpadChild()` contract and return its address. The LaunchpadChild address can be recovered with its `saleId`, in `saleIdToAddress` (and vice-versa).
    - Side note: the presale owner should submit at this point the list of whiteslisted addresses. Those addresses will be stored off-chain and a signature will be generated for it. See signer_code folder for the signature-generation code (doesn't work yet).
2. The creator of the presale needs now to send the tokens to the presale address. Of course, excluding the contract from fees is needed.
3. He can finalize the sale with `LaunchpadChild.finalizeSale()`. This will check enough tokens were sent to the contract.
4. When the `WLstartTime`, whitelisted apes can start doing their things. If they are whitelisted, we can submit the signature tied to their address to `LaunchpadChild.buyTokensWhitelist()`, along with some juicy BNBs.
5. When the `startTime` comes, the war begins and anyone (anybots?) can buy from the presale using `LaunchpadChild.buyTokensPublic()`, along with some BNBs.
6. Now comes the claiming. **To claim the tokens, get the BNB and add the liquidity, the presale owner needs to call `LaunchpadChild.endSaleAllowClaim()`.**. Note that he can do it whenever he wants, after the softcap (50% of HC) has been reached. This will prevent users from buying more tokens.
7. Users can claim using `LaunchpadChild.claimTokens()`.

Questions you may have:
- What happens if the sale appears to have a problem, and I don't want people to be able to buy?
    - You can call `abortSale()`, this will stop everything. **Only works if you didn't end the sale (see 6.)**. Then users can `claimStaleEth()` to get the money back, and insult the dev in the chat.
- What happens if the sale didn't reach softcap?
- - If the sale didn't reach softcap and we have passed the saleEnd time, you can call `claimStaleEth()`.
- What happens if the sale reached softcap and dev didn't end it?
    - If dev had a stroke seeing his hardcap of 10,000 BNBs being reached, his hungry village has 24h to find his ledger password and end the sale. After this, users can `claimStaleEth()`. Ofc, we can change 24h to another param.

## Maths - how do we compute parameters?
### Inputs (saleInputs array):
- tokenTotalAmount : total amount of tokens sold
- listingTokensPerOneEth: How many tokens per eth should added to liquidity, when we add it?
- liquidityShareBP: If we raise 100 ETH, how many should go to liquidity, in basis points (divide by 10,000).
- hardcap : max eth that can be raised.
- startTime : when does the public sale starts
- endTime : when does the sale ends

### Computed variables:
- softcap: harcap / 2 (see telegram discussions about this)
- saleTokensPerOneEth : how many tokens do a user get for 1 Eth bought
    - saleTokensPerOneEth = ((tokenTotalAmount * (10_000 - liquidityShareBP)) / 10_000) / hardcap
- tokenAmountForLiquidity : How many tokens are actually for liquidity if we reach HC
    - tokenAmountForLiquidity = (tokenTotalAmount * liquidityShareBP) / 10_000;

## How to deploy?
We use [eth-brownie](https://eth-brownie.readthedocs.io/en/stable/install.html), python's marvelous framework for EVM chains.

You may need to [add](https://eth-brownie.readthedocs.io/en/stable/account-management.html?highlight=accounts%20new#importing-from-a-private-key) your wallet first. Also, you should download the OpenZeppelin [package](https://eth-brownie.readthedocs.io/en/stable/package-manager.html#examples):
```bash
brownie pm install OpenZeppelin/openzeppelin-contracts@4.3.2
```
and link it in your [config](https://eth-brownie.readthedocs.io/en/stable/config.html) file:
```yaml
remappings:
    - "@openzeppelin=OpenZeppelin/openzeppelin-contracts@4.3.2"
````

- Test: `brownie test --network bsc-main-fork -i`
- Deploy: `brownie run scripts/deploy.py -i --network [your_network_here]`


## Roadmap (dev, do something!)

Tests seem to pass, so we should have a working version ready for the website integration.
What I need to do now:

[x] Write basic documentation in the git readme, explaining how to deploy, how it works and so on...

[x] Test the whitelist/write the JS code to generate the signatures and test against it

[x] Clean a bit the code

[x] Add the liquidity unlock (should be quite easy) and tests

[?] Add the capacity to see all sales from an user, while allowing to update contracts