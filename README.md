# A Implementation of ERC721A for Cairo

A implementation of Chiru Labs' ERC721A written in Cairo for [StarkNet](https://starkware.co/product/starknet/), a decentralized ZK Rollup.


### Usage
> ## ⚠️ WARNING! ⚠️
> 
> This repository contains highly experimental code.
> Expect rapid iteration.
> **Use at your own risk.**


### First time?
The following steps are tested by me in both Windows (Intel x64 CPU) and Linux (ARMv8 CPU) environments.

> I am not sure these steps should work in the Apple M1 computer. 

1. Clone the repo and enter the directory.
2. Create a python virtual environment

```bash
python3 -m venv ~/env
source env/bin/activate 
```

3. Follow the instructions at StarkNet website. ([Setting up the environment](https://www.cairo-lang.org/docs/quickstart.html#setting-up-the-environment))
4. Install OpenZeppelin Nile

```bash
pip3 install cairo-nile
```

5. Install OpenZeppelin Cairo contract library

```bash
pip3 install openzeppelin-cairo-contracts
```

6. After all the steps above, you will at least have successfully installed 3 packages.

```bash
(env) ~/ERC721A-cairo$ pip3 list
Package                      Version
---------------------------- ---------
cairo-lang                   x.x.x
cairo-nile                   x.x.x
openzeppelin-cairo-contracts x.x.x
```


### Useful Docs
- Cairo: https://www.cairo-lang.org/docs/
- OpenZeppelin Nile: https://github.com/OpenZeppelin/nile
- Cairo library
  - Starkware Labs
    - https://github.com/starkware-libs/cairo-lang/tree/master/src/starkware/cairo
    - https://github.com/starkware-libs/cairo-lang/tree/master/src/starkware/starknet
  - OpenZeppelin: https://github.com/OpenZeppelin/cairo-contracts


### Setup StarkNet Account
1. Create a `.env` file with the following content under the root directory `~/`.

```
PriKey=<random_number>
```

2. Execute the following command

```bash
nile setup <private_key_alias>
```

- Nile will look for an environment variable with the name of <private_key_alias> in the file `.env`.
- Therefore, it would be something like `nile setup PriKey`.


### Compile Cairo contract
```bash
nile compile <path_to_contract>
```
- If the `<path_to_contract>` is an empty string, Nile will automatically compile all contracts under the directory `~/contracts`.


### Deploy Cairo contract
```bash
nile deploy \
--network <network_name> \
<cairo_file_name>
```
- `<network_name>` could be `goerli` or `mainnet`
- `<cairo_file_name>` should be the name of `*.cairo` contract file which is placed under the directory `~/contracts`.


### Interact with Cairo contracts at the StarkNet
```bash
starknet call \
--address <contract_address> \
--abi <contract_ABI_json> \
--function <function_name> \
--network <network_name>
```
- `<network_name>` could be `alpha-goerli` or `alpha-mainnet`