#!/bin/bash
while true; do
    # 检查node进程是否存在
    pgrep node > /dev/null
    if [ $? -ne 0 ]; then
        # 如果node进程不存在，输出信息并启动node
        echo "Node进程未运行，正在尝试重新启动..."
        GOEXPERIMENT=arenas go run ./...
        echo "Node进程已启动。"
    else
        # 如果node进程正在运行，输出信息
        echo "Node进程已经在运行中。"
    fi
    # 每次检查后休眠10秒
    sleep 10
done
