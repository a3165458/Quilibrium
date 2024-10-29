#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Quili.sh"

# 自动设置快捷键的功能
function check_and_set_alias() {
    local alias_name="quili"
    local profile_file="$HOME/.profile"

    # 检查快捷键是否已经设置
    if ! grep -q "$alias_name" "$profile_file"; then
        echo "设置快捷键 '$alias_name' 到 $profile_file"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$profile_file"
        # 添加提醒用户激活快捷键的信息
        echo "快捷键 '$alias_name' 已设置。请运行 'source $profile_file' 来激活快捷键，或重新登录。"
    else
        # 如果快捷键已经设置，提供一个提示信息
        echo "快捷键 '$alias_name' 已经设置在 $profile_file。"
        echo "如果快捷键不起作用，请尝试运行 'source $profile_file' 或重新登录。"
    fi
}

# Qclient 安装功能
function install_qclient() {
    echo "正在更新 QCLIENT..."

    # 基本 URL
    BASE_URL="https://releases.quilibrium.com"

    # 获取系统架构
    ARCH=$(uname -m)
    OS=$(uname -s)

    # 根据系统架构设置 Qclient 二进制文件名
    if [ "$OS" = "Linux" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            QCLIENT_BINARY="qclient-latest-linux-amd64"
        elif [ "$ARCH" = "aarch64" ]; then
            QCLIENT_BINARY="qclient-latest-linux-arm64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
    elif [ "$OS" = "Darwin" ]; then
        if [ "$ARCH" = "arm64" ]; then
            QCLIENT_BINARY="qclient-latest-darwin-arm64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
    else
        echo "Unsupported operating system: $OS"
        exit 1
    fi

    # 确保目录存在
    mkdir -p "$HOME/ceremonyclient/client"

    # 下载 Qclient 二进制文件及其 dgst 和签名文件
    cd "$HOME/ceremonyclient/client"
    curl -L -o "$QCLIENT_BINARY" "$BASE_URL/$QCLIENT_BINARY" --fail --silent
    curl -L -o "$QCLIENT_BINARY.dgst" "$BASE_URL/$QCLIENT_BINARY.dgst" --fail --silent

    # 下载所有相关的签名文件
    for i in {1..20}; do
        curl -L -o "$QCLIENT_BINARY.dgst.sig.$i" "$BASE_URL/$QCLIENT_BINARY.dgst.sig.$i" --fail --silent
    done

    # 赋予执行权限
    chmod +x "$QCLIENT_BINARY"

    echo "✅ QCLIENT 安装完成。"
}

# 节点安装功能
function install_node() {
    # 增加swap空间
    sudo mkdir /swap
    sudo fallocate -l 24G /swap/swapfile
    sudo chmod 600 /swap/swapfile
    sudo mkswap /swap/swapfile
    sudo swapon /swap/swapfile
    echo '/swap/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab

    # 向/etc/sysctl.conf文件追加内容
    echo -e "\n# 自定义最大接收和发送缓冲区大小" | sudo tee -a /etc/sysctl.conf
    echo "net.core.rmem_max=600000000" | sudo tee -a /etc/sysctl.conf
    echo "net.core.wmem_max=600000000" | sudo tee -a /etc/sysctl.conf

    echo "配置已添加到/etc/sysctl.conf"

    # 重新加载sysctl配置以应用更改
    sudo sysctl -p

    echo "sysctl配置已重新加载"

    # 更新并升级Ubuntu软件包
    sudo apt update && sudo apt -y upgrade 

    # 安装wget、screen和git等组件
    sudo apt install git ufw bison screen binutils gcc make bsdmainutils cpulimit gawk -y

    # 下载并安装gvm
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    source /root/.gvm/scripts/gvm

    # 获取系统架构
    ARCH=$(uname -m)
    OS=$(uname -s)

    # 安装并使用go1.4作为bootstrap
    gvm install go1.4 -B
    gvm use go1.4
    export GOROOT_BOOTSTRAP=$GOROOT

    # 根据系统架构安装相应的Go版本
    if [ "$ARCH" = "x86_64" ]; then
        gvm install go1.17.13
        gvm use go1.17.13
        export GOROOT_BOOTSTRAP=$GOROOT

        gvm install go1.20.2
        gvm use go1.20.2
    elif [ "$ARCH" = "aarch64" ]; then
        gvm install go1.17.13 -B
        gvm use go1.17.13
        export GOROOT_BOOTSTRAP=$GOROOT

        gvm install go1.20.2 -B
        gvm use go1.20.2
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi

    # 获取最新节点版本
    NODE_VERSION=$(curl -s https://releases.quilibrium.com/release | grep -E "^node-[0-9]+(\.[0-9]+)*" | grep -v "dgst" | sed 's/^node-//' | cut -d '-' -f 1 | head -n 1)
    echo "最新节点版本: $NODE_VERSION"

    # 确保目录存在
    mkdir -p "$HOME/ceremonyclient/node"

    # 根据操作系统和架构设置节点二进制文件名
    if [ "$OS" = "Linux" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            NODE_BINARY="node-$NODE_VERSION-linux-amd64"
        elif [ "$ARCH" = "aarch64" ]; then
            NODE_BINARY="node-$NODE_VERSION-linux-arm64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
    elif [ "$OS" = "Darwin" ]; then
        if [ "$ARCH" = "arm64" ]; then
            NODE_BINARY="node-$NODE_VERSION-darwin-arm64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
    else
        echo "Unsupported operating system: $OS"
        exit 1
    fi

    # 下载节点二进制文件及其dgst和签名文件
    cd "$HOME/ceremonyclient/node"
    curl -L -o "$NODE_BINARY" "https://releases.quilibrium.com/$NODE_BINARY" --fail --silent
    curl -L -o "$NODE_BINARY.dgst" "https://releases.quilibrium.com/$NODE_BINARY.dgst" --fail --silent

    # 下载所有相关的签名文件
    for i in {2,6,7,8,12,13,16}; do
        curl -L -o "$NODE_BINARY.dgst.sig.$i" "https://releases.quilibrium.com/$NODE_BINARY.dgst.sig.$i" --fail --silent
    done

    # 赋予执行权限
    chmod +x "$NODE_BINARY"

    # 启动节点
    screen -dmS Quili bash -c "./$NODE_BINARY"

    # 安装 Qclient
    install_qclient

    echo "====================================== 安装完成 请退出脚本使用screen 命令或者使用查看日志功能查询状态 ======================================"
}

# 安装节点（针对contabo）
function install_node_contabo() {
    # 增加swap空间
    sudo mkdir /swap
    sudo fallocate -l 24G /swap/swapfile
    sudo chmod 600 /swap/swapfile
    sudo mkswap /swap/swapfile
    sudo swapon /swap/swapfile
    echo '/swap/swapfile swap swap defaults 0 0' >> /etc/fstab

    # 向/etc/sysctl.conf文件追加内容
    echo -e "\n# 自定义最大接收和发送缓冲区大小" >> /etc/sysctl.conf
    echo "net.core.rmem_max=600000000" >> /etc/sysctl.conf
    echo "net.core.wmem_max=600000000" >> /etc/sysctl.conf

    echo "配置已添加到/etc/sysctl.conf"

    # 重新加载sysctl配置以应用更改
    sysctl -p

    echo "sysctl配置已重新加载"

    # 配置DNS
    sudo sh -c 'echo "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf'

    # 更新并升级Ubuntu软件包
    sudo apt update && sudo apt -y upgrade 

    # 安装wget、screen和git等组件
    sudo apt install git ufw bison screen binutils gcc make bsdmainutils cpulimit gawk -y

    # 下载并安装gvm
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    source /root/.gvm/scripts/gvm

    # 获取最新节点版本
    NODE_VERSION=$(curl -s https://releases.quilibrium.com/release | grep -E "^node-[0-9]+(\.[0-9]+)*" | grep -v "dgst" | sed 's/^node-//' | cut -d '-' -f 1 | head -n 1)
    echo "最新节点版本: $NODE_VERSION"

    # 确保目录存在
    mkdir -p "$HOME/ceremonyclient/node"

    # 根据操作系统和架构设置节点二进制文件名
    if [ "$OS" = "Linux" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            NODE_BINARY="node-$NODE_VERSION-linux-amd64"
        elif [ "$ARCH" = "aarch64" ]; then
            NODE_BINARY="node-$NODE_VERSION-linux-arm64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
    elif [ "$OS" = "Darwin" ]; then
        if [ "$ARCH" = "arm64" ]; then
            NODE_BINARY="node-$NODE_VERSION-darwin-arm64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
    else
        echo "Unsupported operating system: $OS"
        exit 1
    fi

    # 下载节点二进制文件及其dgst和签名文件
    cd "$HOME/ceremonyclient/node"
    curl -L -o "$NODE_BINARY" "https://releases.quilibrium.com/$NODE_BINARY" --fail --silent
    curl -L -o "$NODE_BINARY.dgst" "https://releases.quilibrium.com/$NODE_BINARY.dgst" --fail --silent

    # 下载所有相关的签名文件
    for i in {2,6,7,8,12,13,16}; do
        curl -L -o "$NODE_BINARY.dgst.sig.$i" "https://releases.quilibrium.com/$NODE_BINARY.dgst.sig.$i" --fail --silent
    done

    # 赋予执行权限
    chmod +x "$NODE_BINARY"

    # 启动节点
    screen -dmS Quili bash -c "./$NODE_BINARY"

    # 安装 Qclient
    install_qclient

    echo "====================================== 安装完成 请退出脚本使用screen 命令或者使用查看日志功能查询状态 ======================================"
}

# 独立启动
function run_node() {
    # 获取系统架构
    ARCH=$(uname -m)
    OS=$(uname -s)

    # 获取最新节点版本
    NODE_VERSION=$(curl -s https://releases.quilibrium.com/release | grep -E "^node-[0-9]+(\.[0-9]+)*" | grep -v "dgst" | sed 's/^node-//' | cut -d '-' -f 1 | head -n 1)
    echo "最新节点版本: $NODE_VERSION"

    # 根据操作系统和架构设置节点二进制文件名
    if [ "$OS" = "Linux" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            NODE_BINARY="node-$NODE_VERSION-linux-amd64"
        elif [ "$ARCH" = "aarch64" ]; then
            NODE_BINARY="node-$NODE_VERSION-linux-arm64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
    elif [ "$OS" = "Darwin" ]; then
        if [ "$ARCH" = "arm64" ]; then
            NODE_BINARY="node-$NODE_VERSION-darwin-arm64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
    else
        echo "Unsupported operating system: $OS"
        exit 1
    fi

    # 进入节点目录
    cd ~/ceremonyclient/node

    # 启动节点
    screen -dmS Quili bash -c "./$NODE_BINARY"

    echo "=======================已启动quilibrium 挖矿 请退出脚本使用screen 命令或者使用查看日志功能查询状态========================================="
}

# 查看常规版本节点日志
function check_service_status() {
    screen -r Quili
}

# 备份设置
function backup_set() {
    mkdir -p ~/backup
    cp -r ~/ceremonyclient/node/.config ~/backup

    echo "=======================备份完成，请执行cd ~/backup 查看备份文件========================================="
}

# 查询余额
function check_balance() {
    cd ~/ceremonyclient/node
    version=$(curl -s https://releases.quilibrium.com/release | grep -E "^node-[0-9]+(\.[0-9]+)*" | grep -v "dgst" | sed 's/^node-//' | cut -d '-' -f 1 | head -n 1)
    binary="node-$version"

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ $(uname -m) == "aarch64"* ]]; then
            binary="$binary-linux-arm64"
        else
            binary="$binary-linux-amd64"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        binary="$binary-darwin-arm64"
    else
        echo "unsupported OS for releases, please build from source"
        exit 1
    fi

    ./$binary --node-info
}

# 更新节点（针对contabo）
function update_node_contabo() {
    # 配置DNS
    sudo sh -c 'echo "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf'
    
    # 调用常规节点安装逻辑
    install_node_contabo
}

# 更新本脚本
function update_script() {
    SCRIPT_URL="https://raw.githubusercontent.com/a3165458/Quilibrium/main/Quili.sh"
    curl -o $SCRIPT_PATH $SCRIPT_URL
    chmod +x $SCRIPT_PATH
    echo "脚本已更新。请退出脚本后，执行bash Quili.sh 重新运行此脚本。"
}

function claim_guide() {
    echo "https://x.com/oxbaboon/status/1850850401148633506"
    echo "请注意qclient 版本会更新，请根据实际qclient版本启动"
    
}

# 主菜单
function main_menu() {
    clear
    echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，免费开源，请勿相信收费"
    echo "================================================================"
    echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
    echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
    echo "请选择要执行的操作:"
    echo "1. 安装常规节点（2.0版本）"
    echo "2. 查看节点日志"
    echo "3. 安装常规节点（1.4.21版本）"
    echo "8. 更新本脚本"
    echo "11. 安装常规节点(针对contabo)"
    echo "12. 升级节点程序版本(针对contabo)"
    echo "13. 安装grpc"
    echo "14. 老版本1.4.21升级2.0(截至10.24日，2.0已正式开始挖矿)"
    echo "=======================单独使用功能============================="
    echo "4. 独立启动挖矿（适合安装成功后，中途退出后再启动）"
    echo "=========================备份功能================================"
    echo "5. 备份文件"
    echo "=========================收米查询================================"
    echo "6. 查询余额(需要先安装grpc)"
    echo "15. 提币教程"
    
    read -p "请输入选项（1-15）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) check_service_status ;;  
    3) install_node_1.4.21 ;; 
    4) run_node ;;
    5) backup_set ;;
    6) check_balance ;;
    8) update_script ;;
    11) install_node_contabo ;;
    12) update_node_contabo ;;
    13) setup_grpc ;;
    14) update_new ;;
    15)claim_guide ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
