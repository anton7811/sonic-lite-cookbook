#!/bin/bash

declare -A SW_IPS=(
    [1]=192.168.1.1
    [2]=192.168.1.2
    [3]=192.168.1.3
    [4]=192.168.1.4
)

DST_PATH=/home/admin/config_db_mlag.json

for SW in 1 2 3 4; do
    scp config_db_${SW}_mlag.json admin@${SW_IPS[${SW}]}:$DST_PATH
    ssh admin@${SW_IPS[${SW}]} "sudo config load $DST_PATH -y"
done