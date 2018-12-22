#!/usr/bin/env bash

shopt -s extglob

nodes=('172.31.24.139' '172.31.22.8' '172.31.29.235' '172.31.30.77' '172.31.25.228')

declare -r service_file='go-lachesis.service'

for i in $(seq 0 4); do
  echo Node"$i":

  scp scripts/testnet.bash testnet"$i":go/src/github.com/Fantom-foundation/go-lachesis/scripts/
  scp -r testnet/lachesis_data_dir testnet"$i":/mnt/data/
  ssh -t testnet"$i" "mkdir -p ~/.evm/eth"
  scp -r testnet/genesis.json testnet"$i":.evm/eth/

  # Service setup
  env -i PATH="$PATH" BUILD_DIR='/home/ubuntu/go/src/github.com/Fantom-foundation/go-lachesis' NODE="$i" NODE_ADDR="${nodes[$i]}" envsubst < go-lachesis.tpl.service > "$service_file"
  scp "$service_file" testnet"$i":/tmp/go-lachesis.service
  ssh -X testnet"$i" 'sudo mv /tmp/go-lachesis.service /lib/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl start go-lachesis'

  # EVM
  ssh -X testnet"$i" "cd go/src/github.com/Fantom-foundation/go-evm; screen -d -m build/evm run --proxy=${nodes[$i]}:9000"
done

# Previous solution (to go-lachesis service)
# ssh -X testnet"$i" "cd go/src/github.com/Fantom-foundation/go-lachesis; rm -rf /mnt/data/lachesis_data_dir/$i/badger/ ; BUILD_DIR="$PWD" DATAL_DIR=/mnt/data node=0 node_addr=172.31.24.139 screen -d -m ./scripts/testnet.bash"
