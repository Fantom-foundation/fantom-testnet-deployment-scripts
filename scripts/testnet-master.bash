#!/usr/bin/env bash -euo pipefail

declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
declare -r parent_dir="${DIR%/*}";

declare -ar nodes=('172.31.17.72' '172.31.24.196' '172.31.24.231' '172.31.31.228' '172.31.16.109');

declare -r go_lachesis_service_file='go-lachesis.service';
declare -r evm_service_file='go-evm.service'

function deploy() {
  printf 'Deploying testnet%d [%s]:\n' "$1" "${nodes[$1]}";

  # Config
  rsync -avz "$parent_dir"/scripts/testnet.bash testnet"$1":/home/ubuntu/go/src/github.com/Fantom-foundation/go-lachesis/scripts/;
  rsync -avz "$parent_dir"/testnet/lachesis_data_dir testnet"$1":/mnt/data/ --rsync-path='sudo rsync';
  ssh testnet"$1" "mkdir -p ~/.evm/eth" | sed "s/^/[${nodes[$1]}] /";
  rsync -avz "$parent_dir"/testnet/genesis.json testnet"$1":/home/ubuntu/.evm/eth/;

  # Lachesis
  declare -r go_lachesis='go-lachesis';
  declare -r lachesis_dir='/home/ubuntu/go/src/github.com/Fantom-foundation/'"$go_lachesis";
  env -i PATH="$PATH" DATAL_DIR='/mnt/data' BUILD_DIR="$lachesis_dir/build" NODE="$1" NODE_ADDR="${nodes[$1]}" envsubst < "$parent_dir"/go-lachesis.tpl.service > "$parent_dir"/"$go_lachesis_service_file"."$1";
  rsync -avz "$parent_dir"/"$go_lachesis_service_file"."$1" testnet"$1":/mnt/data/"$go_lachesis_service_file";
  ssh testnet"$1" "cd $lachesis_dir; [ -f build/lachesis ] || make vendor build; sudo mv /mnt/data/$go_lachesis_service_file /lib/systemd/system/;
  sudo systemctl daemon-reload && ( sudo systemctl stop $go_lachesis 2>/dev/null; sudo systemctl start $go_lachesis; )" | sed "s/^/[${nodes[$1]}] /";

  # EVM
  declare -r go_evm='go-evm';
  declare -r evm_dir='/home/ubuntu/go/src/github.com/Fantom-foundation/'"$go_evm";
  env -i PATH="$PATH" BUILD_DIR="$evm_dir/build" NODE="$1" NODE_ADDR="${nodes[$1]}" envsubst < "$parent_dir"/go-evm.tpl.service > "$parent_dir"/"$evm_service_file"."$1";
  rsync -avz "$parent_dir"/"$evm_service_file"."$1" testnet"$1":/mnt/data/"$evm_service_file";
  ssh testnet"$1" "cd $evm_dir; [ -f evm ] || make vendor build; sudo mv /mnt/data/$evm_service_file /lib/systemd/system/; sudo systemctl daemon-reload && ( sudo systemctl stop $go_evm 2>/dev/null; sudo systemctl start $go_evm )" | sed "s/^/[${nodes[$1]}] /";
}

function init() {
  ssh testnet"$1" 'if ! $(df -h | grep -q /mnt/data); then sudo rm -rfv /mnt/data; sleep 1s && ( export ssd=`lsblk | grep 1.8T | sed -e "s/\s.*$//"` ; echo $ssd ; sudo mkfs -t ext4 /dev/$ssd; sudo mkdir /mnt/data; sudo mount /dev/$ssd /mnt/data; sudo chown -R ubuntu:ubuntu /mnt/data/ ); fi';
}

for i in "${!nodes[@]}"; do
    init "$i" && deploy "$i" &
done
