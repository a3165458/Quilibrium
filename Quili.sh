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
# 确定系统架构和操作系统
ARCH=$(uname -m)
OS=$(uname -s)

BASE_URL="https://releases.quilibrium.com"

# 如果未指定，确定 qclient 的最新版本
if [ -z "$QCLIENT_VERSION" ]; then
    QCLIENT_VERSION=$(curl -s "$BASE_URL/qclient-release" | grep -E "^qclient-[0-9]+(\.[0-9]+)*" | sed 's/^qclient-//' | cut -d '-' -f 1 | head -n 1)
    if [ -z "$QCLIENT_VERSION" ]; then
        echo "⚠️ 警告：无法自动确定 Qclient 版本。"
        echo "请检查您的网络设置或尝试手动安装。"
        exit 1
    else
        echo "✅ 最新的 Qclient 版本：$QCLIENT_VERSION"
    fi
else
    echo "✅ 使用指定的 Qclient 版本：$QCLIENT_VERSION"
fi

# 根据架构和操作系统确定节点二进制文件名称
case "$ARCH-$OS" in
    x86_64-Linux) QCLIENT_BINARY="qclient-$QCLIENT_VERSION-linux-amd64" ;;
    x86_64-Darwin) QCLIENT_BINARY="qclient-$QCLIENT_VERSION-darwin-amd64" ;;
    aarch64-Linux) QCLIENT_BINARY="qclient-$QCLIENT_VERSION-linux-arm64" ;;
    aarch64-Darwin) QCLIENT_BINARY="qclient-$QCLIENT_VERSION-darwin-arm64" ;;
    *) 
        echo "❌ 错误：不支持的系统架构 ($ARCH) 或操作系统 ($OS)。"
        exit 1
        ;;
esac

echo "QCLIENT_BINARY 设置为：$QCLIENT_BINARY"

# 如果目录不存在则创建
mkdir -p "$HOME/ceremonyclient/client" && echo "目录创建成功。"

# 切换到下载目录
cd "$HOME/ceremonyclient/client" || { echo "❌ 错误：无法切换到下载目录"; exit 1; }

# 下载文件并覆盖的函数
download_and_overwrite() {
    local url="$1"
    local filename="$2"
    if wget -q -O "$filename" "$url"; then
        echo "✅ 成功下载 $filename"
        return 0
    else
        echo "❌ 错误：下载 $filename 失败"
        return 1
    fi
}

# 下载主二进制文件
echo "正在下载 $QCLIENT_BINARY..."
if download_and_overwrite "$BASE_URL/$QCLIENT_BINARY" "$QCLIENT_BINARY"; then
    chmod +x "$QCLIENT_BINARY"
else
    echo "❌ 下载过程中出错：可能需要手动安装。"
    exit 1
fi

# 下载 .dgst 文件
echo "正在下载 ${QCLIENT_BINARY}.dgst..."
download_and_overwrite "$BASE_URL/${QCLIENT_BINARY}.dgst" "${QCLIENT_BINARY}.dgst"

# 下载签名文件
echo "正在下载签名文件..."
for i in {1..20}; do
    sig_file="${QCLIENT_BINARY}.dgst.sig.${i}"
    if wget -q --spider "$BASE_URL/$sig_file"; then
        download_and_overwrite "$BASE_URL/$sig_file" "$sig_file"
    fi
done

echo "下载过程完成。"
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
    cd $HOME
    git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git
    NODE_VERSION=$(curl -s https://releases.quilibrium.com/release | grep -E "^node-[0-9]+(\.[0-9]+)*" | grep -v "dgst" | sed 's/^node-//' | cut -d '-' -f 1 | head -n 1)
    echo "最新节点版本: $NODE_VERSION"

    # 确保目录存在
    mkdir -p "$HOME/ceremonyclient/node"

    # 检查当前安装的节点版本
    if [ -f "$HOME/ceremonyclient/node/node" ]; then
        CURRENT_VERSION=$("$HOME/ceremonyclient/node/node" --version)
        echo "当前安装的节点版本: $CURRENT_VERSION"

        if [ "$CURRENT_VERSION" == "$NODE_VERSION" ]; then
            echo "节点已是最新版本，无需更新。"
            return
        else
            echo "节点版本不是最新的，正在下载最新版本..."
        fi
    fi

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
    cd $HOME
    git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git
    NODE_VERSION=$(curl -s https://releases.quilibrium.com/release | grep -E "^node-[0-9]+(\.[0-9]+)*" | grep -v "dgst" | sed 's/^node-//' | cut -d '-' -f 1 | head -n 1)
    echo "最新节点版本: $NODE_VERSION"

    # 确保目录存在
    mkdir -p "$HOME/ceremonyclient/node"

    # 检查当前安装的节点版本
    if [ -f "$HOME/ceremonyclient/node/node" ]; then
        CURRENT_VERSION=$("$HOME/ceremonyclient/node/node" --version)
        echo "当前安装的节点版本: $CURRENT_VERSION"

        if [ "$CURRENT_VERSION" == "$NODE_VERSION" ]; then
            echo "节点已是最新版本，无需更新。"
            return
        else
            echo "节点版本不是最新的，正在下载最新版本..."
        fi
    fi

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
    
    
    mkdir -p ~/scripts && \
    wget -O ~/scripts/qnode_service_change_autorun_to_bin.sh "https://raw.githubusercontent.com/lamat1111/QuilibriumScripts/main/tools/qnode_service_change_autorun_to_bin.sh" && \
    chmod +x ~/scripts/qnode_service_change_autorun_to_bin.sh && \
    ~/scripts/qnode_service_change_autorun_to_bin.sh

    wget --no-cache -O - https://raw.githubusercontent.com/lamat1111/QuilibriumScripts/master/qnode_service_update.sh | bash
}

# 更新本脚本
function update_script() {
    SCRIPT_URL="https://raw.githubusercontent.com/a3165458/Quilibrium/main/Quili.sh"
    curl -o $SCRIPT_PATH $SCRIPT_URL
    chmod +x $SCRIPT_PATH
    echo "脚本已更新。请退出脚本后，执行bash Quili.sh 重新运行此脚本。"
}

# 提币教程
function claim_guide() {
    echo "请查阅 https://x.com/oxbaboon/status/1850850401148633506"
    echo "请注意qclient 版本会更新，请根据实际qclient版本启动"
}

function update_new() {
    # 获取系统架构和操作系统
    ARCH=$(uname -m)
    OS=$(uname -s)

    # 根据操作系统和架构设置 OS_ARCH 变量
    if [[ "$OS" == "Linux" ]]; then
        if [[ "$ARCH" == "x86_64" ]]; then
            OS_ARCH="linux-amd64"
        elif [[ "$ARCH" == "aarch64" ]]; then
            OS_ARCH="linux-arm64"
        else
            echo "不支持的 Linux 架构: $ARCH"
            exit 1
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        if [[ "$ARCH" == "arm64" ]]; then
            OS_ARCH="darwin-arm64"
        elif [[ "$ARCH" == "x86_64" ]]; then
            OS_ARCH="darwin-amd64"
        else
            echo "不支持的 macOS 架构: $ARCH"
            exit 1
        fi
    else
        echo "不支持的操作系统: $OS"
        exit 1
    fi

    # 确保节点目录存在
    mkdir -p "$HOME/ceremonyclient/node"

    # 进入节点目录
    cd "$HOME/ceremonyclient/node" || { echo "❌ 无法切换到节点目录"; exit 1; }

    # 定义发布文件的 URL
    RELEASE_FILES_URL="https://releases.quilibrium.com/release"

    # 获取所有相关的发布文件
    RELEASE_FILES=$(curl -s "$RELEASE_FILES_URL" | grep -oE "node-[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?-${OS_ARCH}(\.dgst)?(\.sig\.[0-9]+)?")

    # 下载所有相关的文件
    for file in $RELEASE_FILES; do
        echo "正在下载 $file..."
        wget "https://releases.quilibrium.com/$file" --quiet --show-progress
    done

    # 赋予下载的节点二进制文件执行权限
    chmod +x node-2*

    # 启动节点
    NODE_BINARY=$(ls node-2*)  # 获取最新的节点二进制文件名
    screen -dmS Quili bash -c "./$NODE_BINARY"

    echo "====================================== 节点更新完成，请使用 screen 命令查看状态 ======================================"
}
}


function setup_grpc() {
    wget -O qnode_gRPC_setup.sh https://raw.githubusercontent.com/lamat1111/quilibriumscripts/master/tools/qnode_gRPC_calls_setup.sh && chmod +x qnode_gRPC_setup.sh && ./qnode_gRPC_setup.sh

    echo "gRPC 安装后，等待约30分钟生效"
}

# Qclient 安装功能
function install_qclient() {

# 确定系统架构和操作系统
ARCH=$(uname -m)
OS=$(uname -s)

# 打印架构和操作系统以进行调试
echo "系统架构: $ARCH"
echo "操作系统: $OS"

echo "正在更新 QCLIENT..."

# 基本 URL
BASE_URL="https://releases.quilibrium.com"

# 获取 Qclient 最新版本
QCLIENT_VERSION=$(curl -s "$BASE_URL/qclient-release" | grep -E "^qclient-[0-9]+(\.[0-9]+)*" | sed 's/^qclient-//' | cut -d '-' -f 1 | head -n 1)
if [ -z "$QCLIENT_VERSION" ]; then
    echo "⚠️ 无法自动确定 Qclient 版本。请检查网络连接或手动安装。"
    exit 1
else
    echo "✅ 最新 Qclient 版本: $QCLIENT_VERSION"
fi

# 根据系统架构和操作系统设置 Qclient 二进制文件名
if [ "$ARCH" = "x86_64" ]; then
    if [ "$OS" = "Linux" ]; then
        QCLIENT_BINARY="qclient-$QCLIENT_VERSION-linux-amd64"
    elif [ "$OS" = "Darwin" ]; then
        QCLIENT_BINARY="qclient-$QCLIENT_VERSION-darwin-amd64"
    fi
elif [ "$ARCH" = "aarch64" ]; then
    if [ "$OS" = "Linux" ]; then
        QCLIENT_BINARY="qclient-$QCLIENT_VERSION-linux-arm64"
    elif [ "$OS" = "Darwin" ]; then
        QCLIENT_BINARY="qclient-$QCLIENT_VERSION-darwin-arm64"
    fi
else
    echo "❌ 不支持的系统架构 ($ARCH) 或操作系统 ($OS)。"
    exit 1
fi

echo "QCLIENT_BINARY 设置为: $QCLIENT_BINARY"

# 确保目录存在
mkdir -p "$HOME/ceremonyclient/client"

# 切换到下载目录
cd "$HOME/ceremonyclient/client" || { echo "❌ 无法切换到下载目录"; exit 1; }

# 下载并覆盖文件的函数
download_and_overwrite() {
    local url="$1"
    local filename="$2"
    if wget -q -O "$filename" "$url"; then
        echo "✅ 成功下载 $filename"
        return 0
    else
        echo "❌ 下载 $filename 失败"
        return 1
    fi
}

# 下载主二进制文件
echo "下载 $QCLIENT_BINARY..."
if download_and_overwrite "$BASE_URL/$QCLIENT_BINARY" "$QCLIENT_BINARY"; then
    chmod +x "$QCLIENT_BINARY"
else
    echo "❌ 下载过程中出错：可能需要手动安装。"
    exit 1
fi

# 下载 .dgst 文件
echo "下载 ${QCLIENT_BINARY}.dgst..."
if ! download_and_overwrite "$BASE_URL/${QCLIENT_BINARY}.dgst" "${QCLIENT_BINARY}.dgst"; then
    echo "❌ 下载 .dgst 文件失败。"
    exit 1
fi

# 下载签名文件
echo "下载签名文件..."
for i in {1..20}; do
    sig_file="${QCLIENT_BINARY}.dgst.sig.${i}"
    if wget -q --spider "$BASE_URL/$sig_file"; then
        if ! download_and_overwrite "$BASE_URL/$sig_file" "$sig_file"; then
            echo "❌ 下载签名文件 $sig_file 失败。"
        fi
    fi
done
echo "下载过程完成。"
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
    echo "14. 升级节点程序(截至10.24日，2.0已正式开始挖矿)"
    echo "16. 安装qclient"
    echo "=======================单独使用功能============================="
    echo "4. 独立启动挖矿（适合安装成功后，中途退出后再启动）"
    echo "=========================备份功能================================"
    echo "5. 备份文件"
    echo "=========================收米查询================================"
    echo "6. 查询余额(需要先安装grpc)"
    echo "15. 提币教程"
    
    read -p "请输入选项（1-16）: " OPTION

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
    15) claim_guide ;;
    16) install_qclient ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
