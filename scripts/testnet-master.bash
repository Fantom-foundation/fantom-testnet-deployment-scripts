#!/usr/bin/env bash

set -euo pipefail

declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
declare -r parent_dir="${DIR%/*}";

declare -ar nodes=('172.31.6.65' '172.31.8.33' '172.31.5.183' '172.31.3.125' '172.31.1.84');

declare -r go_lachesis_service_file='dag1.service';
declare -r evm_service_file='go-evm.service'

function deploy() {
  printf 'Deploying testnet%d [%s]:\n' "$1" "${nodes[$1]}";

  # Config
  rsync -avz "$parent_dir"/scripts/testnet.bash testnet"$1":/home/ubuntu/go/src/github.com/SamuelMarks/dag1/scripts/;
  rsync -avz "$parent_dir"/testnet/dag1_data_dir testnet"$1":/mnt/data/ --rsync-path='sudo rsync';
  ssh testnet"$1" "mkdir -p ~/.evm/eth" | sed "s/^/[${nodes[$1]}] /";
  rsync -avz "$parent_dir"/testnet/genesis.json testnet"$1":/home/ubuntu/.evm/eth/;

  # Lachesis
  declare -r go_lachesis='dag1';
  declare -r lachesis_dir='/home/ubuntu/go/src/github.com/SamuelMarks/'"$go_lachesis";
  env -i PATH="$PATH" DATAL_DIR='/mnt/data' BUILD_DIR="$lachesis_dir/build" NODE="$1" NODE_ADDR="${nodes[$1]}" envsubst < "$parent_dir"/dag1.tpl.service > "$parent_dir"/"$go_lachesis_service_file"."$1";
  rsync -avz "$parent_dir"/"$go_lachesis_service_file"."$1" testnet"$1":/mnt/data/"$go_lachesis_service_file";
  ssh testnet"$1" "cd $lachesis_dir; git pull && make clean vendor build; sudo mv /mnt/data/$go_lachesis_service_file /lib/systemd/system/;
  sudo systemctl daemon-reload && ( sudo systemctl stop $go_lachesis 2>/dev/null; sudo systemctl start $go_lachesis; )" | sed "s/^/[${nodes[$1]}] /";

  # EVM
  declare -r go_evm='go-evm';
  declare -r evm_dir='/home/ubuntu/go/src/github.com/SamuelMarks/'"$go_evm";
  env -i PATH="$PATH" BUILD_DIR="$evm_dir/build" NODE="$1" NODE_ADDR="${nodes[$1]}" envsubst < "$parent_dir"/go-evm.tpl.service > "$parent_dir"/"$evm_service_file"."$1";
  rsync -avz "$parent_dir"/"$evm_service_file"."$1" testnet"$1":/mnt/data/"$evm_service_file";
  ssh testnet"$1" "cd $evm_dir; git pull && make clean vendor build; sudo mv /mnt/data/$evm_service_file /lib/systemd/system/; sudo systemctl daemon-reload && ( sudo systemctl stop $go_evm 2>/dev/null; sudo systemctl start $go_evm )" | sed "s/^/[${nodes[$1]}] /";
}

function init() {
  ssh testnet"$1" 'if ! $(df -h | grep -q /mnt/data); then sudo rm -rfv /mnt/data; sleep 1s && ( export ssd=`lsblk | grep 1.8T | sed -e "s/\s.*$//"` ; echo $ssd ; sudo mkfs -t ext4 /dev/$ssd; sudo mkdir /mnt/data; sudo mount /dev/$ssd /mnt/data; sudo chown -R ubuntu:ubuntu /mnt/data/ ); fi';
}

for i in "${!nodes[@]}"; do
    init "$i" && deploy "$i" &
done
