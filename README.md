Tests seem to pass, so we should have a working version ready for the website integration.
What I need to do now:

- Write basic documentation in the git readme, explaining how to deploy, how it works and so on...

- Add helpers for computation of inputs (hardcap, token price, share to add to liquidity, etc...) - it's done in the contract already, but maybe you'll want them? Or I can just add it to the docs

- Test the whitelist/write the JS code to generate the signatures and test against it

- Clean a bit the code

- Add the liquidity unlock (should be quite easy) and tests

- Add the capacity to see all sales from an user, while allowing to update contracts