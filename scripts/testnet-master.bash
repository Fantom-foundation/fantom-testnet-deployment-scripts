#!/usr/bin/env bash

set -euo pipefail

#
# The script to bootstrap Fantom Foundation testnet
#
# The nodes array contains the list of addresses of nodes used for inter node communications
# currently they are grey addreses of AWS instances ised in deployment
# To access these instances testnet0, testnet1, ..., testnet$n ($n number of nodes) aliases
# should be specified in ~/.ssh/config file and the machine where this script is running
# should be abble to access these instances whithout specifying additional parameters on command line
# (i.e. all connnection parameters should be in ~/.ssh/config file)
#
# batch-ethkey is required, see how to install it here: https://github.com/SamuelMarks/batch-ethkey
#
declare -ar nodes=('172.31.6.65' '172.31.8.33' '172.31.5.183' '172.31.3.125' '172.31.1.84');
declare -ri port=12000

declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
declare -r parent_dir="${DIR%/*}";
declare -r go_lachesis_service_file='dag1.service';
declare -r evm_service_file='go-evm.service'
declare -r go_lachesis_branch='master'
declare -r evm_branch="${BRANCH:-master}"

function deploy() {
  declare -r go_lachesis='dag1';
  declare -r go_evm='go-evm';
  declare -r lachesis_dir='/home/ubuntu/go/src/github.com/SamuelMarks/'"$go_lachesis";
  declare -r evm_dir='/home/ubuntu/go/src/github.com/SamuelMarks/'"$go_evm";

  printf 'Deploying testnet%d [%s]:\n' "$1" "${nodes[$1]}";

  # stop services if they are running
  ssh testnet"$1" "sudo systemctl stop $go_evm 2>/dev/null"
  ssh testnet"$1" "sudo systemctl stop $go_lachesis 2>/dev/null"
  
  # Config
  rsync -avz "$parent_dir"/scripts/testnet.bash testnet"$1":/home/ubuntu/go/src/github.com/SamuelMarks/dag1/scripts/;
  ssh testnet"$1" "sudo rm -rf /mnt/data/dag1_data_dir /mnt/data/evm ; mkdir -p /mnt/data/dag1_data_dir /mnt/data/evm; rm -rf ~/.evm ; ln -sf /mnt/data/evm ~/.evm";
  rsync -avz "$parent_dir"/testnet/"$1"/ testnet"$1":/mnt/data/dag1_data_dir --rsync-path='sudo rsync';
  ssh testnet"$1" "ln -sf /mnt/data/dag1_data_dir/eth  /mnt/data/evm/eth";
  #  ssh testnet"$1" "mkdir -p ~/.evm/eth" | sed "s/^/[${nodes[$1]}] /";
  ssh testnet"$1" "mv ~/.evm/eth/evml.toml ~/.evm/; ";
  rsync -avz "$parent_dir"/testnet/genesis.json testnet"$1":/home/ubuntu/.evm/eth/;
  rsync -avz "$parent_dir"/testnet/peers.json testnet"$1":/mnt/data/dag1_data_dir/;

  # Lachesis
  env -i PATH="$PATH" DATAL_DIR='/mnt/data' BUILD_DIR="$lachesis_dir/build" NODE="$1" NODE_ADDR="${nodes[$1]}" envsubst < "$parent_dir"/dag1.tpl.service > "$parent_dir"/"$go_lachesis_service_file"."$1";
  rsync -avz "$parent_dir"/"$go_lachesis_service_file"."$1" testnet"$1":/mnt/data/"$go_lachesis_service_file";
  ssh testnet"$1" "cd $lachesis_dir; git clean -fd && git checkout $go_lachesis_branch && git pull && make clean vendor proto build; sudo mv /mnt/data/$go_lachesis_service_file /lib/systemd/system/;
  sudo systemctl daemon-reload && ( sudo systemctl start $go_lachesis; )" | sed "s/^/[${nodes[$1]}] /";

  # EVM
  env -i PATH="$PATH" BUILD_DIR="$evm_dir/build" NODE="$1" NODE_ADDR="${nodes[$1]}" envsubst < "$parent_dir"/go-evm.tpl.service > "$parent_dir"/"$evm_service_file"."$1";
  rsync -avz "$parent_dir"/"$evm_service_file"."$1" testnet"$1":/mnt/data/"$evm_service_file";
  ssh testnet"$1" "cd $evm_dir; git clean -fd && git checkout $evm_branch && git pull && make clean vendor build; sudo mv /mnt/data/$evm_service_file /lib/systemd/system/; sudo systemctl daemon-reload && ( sudo systemctl start $go_evm )" | sed "s/^/[${nodes[$1]}] /";
}

function init() {
    ssh testnet"$1" 'if ! $(df -h | grep -q /mnt/data); then sudo rm -rfv /mnt/data; sleep 1s && ( export ssd=`lsblk | grep 1.8T | sed -e "s/\s.*$//"` ; echo $ssd ; sudo mkfs -t ext4 /dev/$ssd; sudo mkdir /mnt/data; sudo mount /dev/$ssd /mnt/data; sudo chown -R ubuntu:ubuntu /mnt/data/ ); fi';
    # slash down existing badger db for dag1; a temporary solution for consensus crash on startup with existing database
    ssh testnet"$1" "if [ -d /mnt/data/dag1_data_dir/badger_db ]; then sudo rm -rf /mnt/data/dag1_data_dir/badger_db; fi";
    ssh testnet"$1" 'sudo apt install -y protobuf-compiler golang-goprotobuf-dev && sudo ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime && date';
    ssh testnet"$1" "if [ ! -f /etc/logrotate-fantom.conf ]; then cat <<EOT | sudo tee /etc/logrotate-fantom.conf
/var/log/syslog
{
	rotate 14
	compress
	maxsize 500M
	postrotate
		/usr/lib/rsyslog/rsyslog-rotate
	endscript
}
EOT
sudo cp /etc/cron.daily/logrotate /etc/cron.hourly/ && sudo sed -i 's/logrotate.conf/logrotate-fantom.conf/' /etc/cron.hourly/logrotate && sudo service rsyslog rotate ; fi"
}


declare -ra hosts=("${nodes[@]/#/-host }")

rm -rf testnet
batch-ethkey -dir ./testnet -n ${#nodes[@]} -evm ${hosts[@]/%/:$port} -network 127.0.0.1

# use these commands for debug ona single node
#init "0" && deploy "0"
#exit

for i in "${!nodes[@]}"; do
    init "$i" && deploy "$i" &
done
