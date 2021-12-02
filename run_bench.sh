#!/bin/bash

#メイン処理
rm -f "$1"/err_war.txt
for ((i = 0; i < ${#low_level_runtime[@]}; i++)) {
    rm -f "$1"/${low_level_runtime[i]}.txt
    if [ "$1" = "lifecycle" ]; then
        #コンテナの1連のライフサイクルをfor文で繰り返す
        for ((j = 0; j < ${container_num}; j++)) {
            echo $(($j+1))"cycle" >> lifecycle/${low_level_runtime[i]}.txt
            echo "create" >> lifecycle/${low_level_runtime[i]}.txt
            time -p (docker create -t --runtime=${low_level_runtime[i]} --name=${low_level_runtime[i]}$j ${container_image} > /dev/null) &>> lifecycle/${low_level_runtime[i]}.txt
            wait $!
            echo "start" >> lifecycle/${low_level_runtime[i]}.txt
            time -p (docker start ${low_level_runtime[i]}$j > /dev/null) &>> lifecycle/${low_level_runtime[i]}.txt
            wait $!
            echo "stop" >> lifecycle/${low_level_runtime[i]}.txt
            time -p (docker stop ${low_level_runtime[i]}$j > /dev/null) &>> lifecycle/${low_level_runtime[i]}.txt
            wait $!
            echo "remove" >> lifecycle/${low_level_runtime[i]}.txt
            time -p (docker rm ${low_level_runtime[i]}$j > /dev/null) &>> lifecycle/${low_level_runtime[i]}.txt
            wait $!
            echo "" >> lifecycle/${low_level_runtime[i]}.txt
            sleep 3
        }
    elif [ "$1" = "resource_memory" ]; then
        free -s 1 -m > resource_memory/${low_level_runtime[i]}.txt &
        #コンテナの起動
        for ((j = 0; j < ${container_num}; j++)) {
            docker run -td --runtime=${low_level_runtime[i]} --name=${low_level_runtime[i]}$j ${container_image} > /dev/null
        }
        #freeコマンドをkill
        ps_result=($(ps -C free))
        ps_id=${ps_result[4]}
        kill ${ps_id}
        #コンテナの削除
        for ((j = 0; j < ${container_num}; j++)) {
            docker stop ${low_level_runtime[i]}$j > /dev/null
            docker rm ${low_level_runtime[i]}$j > /dev/null
        }
        sleep 3
    elif [ "$1" = "file_rnd_read" ] ||  [ "$1" = "file_seq_read" ]; then
        for ((j = 0; j < ${container_num}; j++)) {
            docker run --runtime=${low_level_runtime[i]} --name=${low_level_runtime[i]}$j paipoi/sysbench_"$(uname -p)" sh -c "sysbench --test=fileio prepare && sysbench --test=fileio --file-test-mode=$container_image --num-threads=1 run" >> "$1"/${low_level_runtime[i]}.txt 2>> "$1"/err_war.txt
            docker stop ${low_level_runtime[i]}$j > /dev/null && docker rm ${low_level_runtime[i]}$j > /dev/null
            sleep 3
        }
    elif [ "$1" = "network" ]; then
        docker run -d --runtime=${low_level_runtime[i]} --name=${low_level_runtime[i]} --ip=172.17.0.2 paipoi/iperf_"$(uname -p)" -s > /dev/null
        sleep 5 #runscは起動が遅いようなのでsleepを間に挟む
        for ((j = 0; j < ${container_num}; j++)) {
            iperf -f M -c 172.17.0.2 >> "$1"/${low_level_runtime[i]}.txt 2>> "$1"/err_war.txt
            sleep 3         
        }
        docker stop ${low_level_runtime[i]} > /dev/null && docker rm ${low_level_runtime[i]} > /dev/null
    else
        for ((j = 0; j < ${container_num}; j++)) {
            docker run --runtime=${low_level_runtime[i]} --name=${low_level_runtime[i]}$j ${container_image} >> "$1"/${low_level_runtime[i]}.txt 2>> "$1"/err_war.txt
            docker stop ${low_level_runtime[i]}$j > /dev/null && docker rm ${low_level_runtime[i]}$j > /dev/null
            sleep 3
        }
    fi
    echo ${low_level_runtime[i]} " Finish"
}

#このあと、pythonでグラフ描画処理
python3 make_graph.py "$1" ${container_num} ${low_level_runtime[@]}
