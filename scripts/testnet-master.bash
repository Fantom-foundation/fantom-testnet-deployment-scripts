#!/usr/bin/env bash -euo pipefail

declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
declare -r parent_dir="${DIR%/*}";

declare -ar nodes=('172.31.24.139' '172.31.22.8' '172.31.29.235' '172.31.30.77' '172.31.25.228');

declare -r go_lachesis_service_file='go-lachesis.service';
declare -r evm_service_file='go-evm.service'

function deploy() {
  printf 'Deploying testnet%d [%s]:\n' "$1" "${nodes[$1]}";

  # Config
  rsync -avz "$parent_dir"/scripts/testnet.bash testnet"$1":/home/ubuntu/go/src/github.com/Fantom-foundation/go-lachesis/scripts/;
  rsync -avz "$parent_dir"/testnet/lachesis_data_dir testnet"$1":/mnt/data/ --rsync-path='sudo rsync';
  ssh testnet"$1" "mkdir -p ~/.evm/eth";
  rsync -avz "$parent_dir"/testnet/genesis.json testnet"$1":/home/ubuntu/.evm/eth/;

  # Lachesis
  declare -r go_lachesis='go-lachesis';
  env -i PATH="$PATH" DATAL_DIR='/mnt/data' BUILD_DIR='/home/ubuntu/go/src/github.com/Fantom-foundation/'"$go_lachesis" NODE="$1" NODE_ADDR="${nodes[$1]}" envsubst < "$parent_dir"/go-lachesis.tpl.service > "$parent_dir"/"$go_lachesis_service_file";
  rsync -avz "$parent_dir"/"$go_lachesis_service_file" testnet"$1":/tmp/go-lachesis.service;
  ssh testnet"$1" "sudo mv /tmp/$go_lachesis.service /lib/systemd/system/; sudo systemctl daemon-reload && ( sudo systemctl stop $go_lachesis 2>/dev/null; sudo systemctl start $go_lachesis; )";

  # EVM
  declare -r go_evm='go-evm';
  env -i PATH="$PATH" BUILD_DIR='/home/ubuntu/go/src/github.com/Fantom-foundation/'"$go_evm" NODE="$1" NODE_ADDR="${nodes[$1]}" envsubst < "$parent_dir"/evm.tpl.service > "$parent_dir"/"$evm_service_file";
  rsync -avz "$parent_dir"/"$evm_service_file" testnet"$1":/tmp/"$evm_service_file";
  ssh testnet"$1" "cd go/src/github.com/Fantom-foundation/$go_evm; [ -f build/evm ] || make build; sudo mv /tmp/$go_evm.service /lib/systemd/system/; sudo systemctl daemon-reload && ( sudo systemctl stop $go_evm 2>/dev/null; sudo systemctl start $go_evm )";
}

for i in "${!nodes[@]}"; do
  deploy "$i" &
done
