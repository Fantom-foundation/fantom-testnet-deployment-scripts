Fantom Foundation Testnet deployment
------------------------------------
Bash scripts for deploying Fantom testnet.

Requirements:

 - Bash
 - rsync
 - Go (tested with 1.12.5; but should work older and newer also)
 - [batch-ethkey](https://github.com/SamuelMarks/batch-ethkey) with: `go get -u github.com/SamuelMarks/batch-ethkey`
 - `testnet0`, `testnet1`, `testnet2`, `testnet3`, `testnet4` nodes should be provisioned and SSH connection parameters to these nodes should be specified, e.g.: in the `~/.ssh/config` file, on the machine where this script is executing.

Sample entry for `testnet0`, stored in `~/.ssh/config`:

```
 Host testnet0
    IdentityFile PEM_FILE_LOCATION_HERE
    LogLevel FATAL
    HostName PUBLIC_IP_ADDRESS_HERE
    IdentitiesOnly yes
    PasswordAuthentication no
    UserKnownHostsFile /dev/null
    User ubuntu
    StrictHostKeyChecking yes
    Port 22
```

## Deployment

Before deployment you need modify `scripts/testnet-master.sh` scripts as follow:

* In `nodes` array list IP-addresses of all nodes of testnet which would be used in inter node communications,
currently they are grey addreses of AWS instances used in deployment:

```bash
declare -ar nodes=('172.31.6.65' '172.31.8.33' '172.31.5.183' '172.31.3.125' '172.31.1.84');
```

* In `port` variable specify the base port of DAG1 consensus:
```bash
declare -ri port=12000
```

Then execute `scripts/testnet-master.sh` which generates configuration files for all nodes, including `genesis.json` and `peers.json`,
copy that configuration to every node listed and starts services for DAG1 consensus and go-evm.

-----------------------

NB: `init()` function in `scripts/testnet-master.sh` is specific for hardware parameters used in current testnet deployment and should be adjusted accordingly when these parameters changes.
