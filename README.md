# Walnut Starter Contracts

![walnut banner](assets/walnut_banner.png)

### Overview
A starter repository to get you started with using `stype`. The app is centered
around a walnut with a secret number inside. 

Every time you shake the walnut, this number increments. Every time you hit the 
walnut, the shell gets closer to cracking. You can only look at the number once 
the shell is cracked.

### Usage
Run the following command to run the tests:
```bash
$ sforge test
```

Run the following command to deploy the contract:
```bash
$ sforge script script/Walnut.s.sol:WalnutScript \
      --rpc-url <your_rpc_url> \
      --private-key <your_private_key>
```
