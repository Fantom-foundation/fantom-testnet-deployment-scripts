Fantom Foundation Testnet deployment
------------------------------------

requirements: 

 * batch-ethkey, see [how to install it](https://github.com/SamuelMarks/batch-ethkey)
 * testnet0, testnet1, ..., testnet$n nodes should be provisioned and SSH connection parameters to these nodes should be specified in ~/.ssh/config file on the machine where this script is executing. Sample entry for testnet0 is as follow:

```
 Host testnet0
    IdentityFile /home/offscale/.ssh/devbox-shared.pem
    LogLevel FATAL
    HostName 10.10.10.14
    IdentitiesOnly yes
    PasswordAuthentication no
    UserKnownHostsFile /dev/null
    User ubuntu
    StrictHostKeyChecking no
    Port 22
```

Deployment
----------

Before deployment you need modify `scripts/testnet-master.sh` scripts as follow:

* In `nodes` array list IP-addresses of all nodes of testnet which would be used in inter node communications,
currently they are grey addreses of AWS instances used in deployment:

```
declare -ar nodes=('172.31.6.65' '172.31.8.33' '172.31.5.183' '172.31.3.125' '172.31.1.84');
```

* In `port` variable specify the base port of DAG1 consensus:
```
declare -ri port=12000
```

Then execute `scripts/testnet-master.sh` which generates configuration files for all nodes, including `genesis.json` and `peers.json`,
copy that configuration to every node listed and starts services for DAG1 consensus and go-evm.

-----------------------

NB: `init()` function in `scripts/testnet-master.sh` is specific for hardware parameters used in current testnet deployment and should be adjusted accordingly when these parameters changes.
