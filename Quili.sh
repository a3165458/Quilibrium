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

# 节点安装功能
function install_node() {


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

# 更新并升级Ubuntu软件包
sudo apt update && sudo apt -y upgrade 

# 安装wget、screen和git等组件
sudo apt install git ufw bison screen binutils gcc make bsdmainutils cpulimit gawk -y

# 下载并安装gvm
bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
source /root/.gvm/scripts/gvm

# 获取系统架构
ARCH=$(uname -m)

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


git clone -b release-cdn https://git.dadunode.com/smeb_y/ceremonyclient.git

# 进入ceremonyclient/node目录
cd ceremonyclient/node 


# 创建一个screen会话并运行命令
screen -dmS Quili bash -c './node-1.4.21.1-linux-amd64'

echo ====================================== 安装完成 请退出脚本使用screen 命令或者使用查看日志功能查询状态=========================================

}


# 节点安装功能
function install_node_mac() {
# 安装 Homebrew 包管理器（如果尚未安装）
if ! command -v brew &> /dev/null; then
    echo "Homebrew 未安装。正在安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 更新 Homebrew 并安装必要的软件包
brew update
brew install wget git screen bison gcc make

# 安装 gvm
bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
source $HOME/.gvm/scripts/gvm

# 获取系统架构
ARCH=$(uname -m)

# 安装并使用 go1.4 作为 bootstrap
gvm install go1.4 -B
gvm use go1.4
export GOROOT_BOOTSTRAP=$GOROOT

# 根据系统架构安装相应的 Go 版本
if [ "$ARCH" = "x86_64" ]; then
  gvm install go1.17.13
  gvm use go1.17.13
  export GOROOT_BOOTSTRAP=$GOROOT

  gvm install go1.20.2
  gvm use go1.20.2
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  gvm install go1.17.13 -B
  gvm use go1.17.13
  export GOROOT_BOOTSTRAP=$GOROOT

  gvm install go1.20.2 -B
  gvm use go1.20.2
else
  echo "无法支持的版本: $ARCH"
  exit 1
fi

# 克隆仓库
git clone -b release-cdn https://git.dadunode.com/smeb_y/ceremonyclient.git

# 进入 ceremonyclient/node 目录
cd ceremonyclient/node 


# 创建一个 screen 会话并运行命令
screen -dmS Quili bash -c './node-1.4.21.1-linux-arm64'


echo ====================================== 安装完成 请退出脚本使用screen 命令或者使用查看日志功能查询状态 =========================================

}

# 查看常规版本节点日志
function check_service_status() {
    screen -r Quili
   
}

# 独立启动
function run_node() {
    screen -dmS Quili bash -c "source /root/.gvm/scripts/gvm && gvm use go1.20.2 && cd ~/ceremonyclient/node && ./release_autorun.sh"

    echo "=======================已启动quilibrium 挖矿 请退出脚本使用screen 命令或者使用查看日志功能查询状态========================================="
}

function add_snapshots() {
apt install unzip -y
rm -r $HOME/ceremonyclient/node/.config/store && wget -qO- https://snapshots.cherryservers.com/quilibrium/store.zip > /tmp/store.zip && unzip -j -o /tmp/store.zip -d $HOME/ceremonyclient/node/.config/store && rm /tmp/store.zip

screen -dmS Quili bash -c 'source /root/.gvm/scripts/gvm && gvm use go1.20.2 && cd ~/ceremonyclient/node && ./node-1.4.21.1-linux-arm64'
   
}

function backup_set() {
mkdir -p ~/backup
cat ~/ceremonyclient/node/.config/config.yml > ~/backup/config.txt
cat ~/ceremonyclient/node/.config/keys.yml > ~/backup/keys.txt

echo "=======================备份完成，请执行cd ~/backup 查看备份文件========================================="

}

function check_balance() {
cd ~/ceremonyclient/node
version="1.4.21.1"
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

function unlock_performance() {
cd ~/ceremonyclient/node 

echo "请选择要切换的版本："
echo "1. 限制CPU50%性能版本"
echo "2. CPU性能拉满版本"
read -p "请输入选项(1或2): " version_choice

if [ "$version_choice" -eq 1 ]; then
  git switch release-cdn
elif [ "$version_choice" -eq 2 ]; then
  git switch release-non-datacenter
else
  echo "无效的选项，退出脚本。"
  exit 1
fi

# 赋予执行权限
chmod +x release_autorun.sh

# 创建一个screen会话并运行命令
screen -dmS Quili bash -c './node-1.4.21.1-linux-arm64'


echo "=======================已解锁CPU性能限制并启动quilibrium 挖矿请退出脚本使用screen 命令或者使用查看日志功能查询状态========================================="

}


# 升级节点版本
function update_node() {
    cd ~/ceremonyclient/node
    git remote set-url origin https://source.quilibrium.com/quilibrium/ceremonyclient.git
    git pull
    git switch release-cdn
    echo "节点已升级。请运行脚本独立启动挖矿功能启动节点。"
}

function update_node_contabo() {
    sudo sh -c 'echo "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf'
    cd ~/ceremonyclient/node
    git remote set-url origin https://source.quilibrium.com/quilibrium/ceremonyclient.git
    git pull
    git switch release-cdn
    echo "节点已升级。请运行脚本独立启动挖矿功能启动节点。"
}

# 更新本脚本
function update_script() {
    SCRIPT_URL="https://raw.githubusercontent.com/a3165458/Quilibrium/main/Quili.sh"
    curl -o $SCRIPT_PATH $SCRIPT_URL
    chmod +x $SCRIPT_PATH
    echo "脚本已更新。请退出脚本后，执行bash Quili.sh 重新运行此脚本。"
}

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

sudo sh -c 'echo "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf'

# 更新并升级Ubuntu软件包
sudo apt update && sudo apt -y upgrade 

# 安装wget、screen和git等组件
sudo apt install git ufw bison screen binutils gcc make bsdmainutils cpulimit gawk -y

# 下载并安装gvm
bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
source /root/.gvm/scripts/gvm

# 获取系统架构
ARCH=$(uname -m)

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


git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git

# 进入ceremonyclient/node目录
cd ceremonyclient/node 

git switch release-cdn


# 赋予执行权限
chmod +x release_autorun.sh

# 创建一个screen会话并运行命令
screen -dmS Quili bash -c './node-1.4.21.1-linux-arm64'

}

function setup_grpc() {
    wget --no-cache -O - https://raw.githubusercontent.com/lamat1111/quilibriumscripts/master/tools/qnode_gRPC_calls_setup.sh | bash

    echo "gRPC 安装后，等待约30分钟生效"
}

function update_new() {
mkdir -p ~/scripts && \
wget -O ~/scripts/qnode_service_change_autorun_to_bin.sh "https://raw.githubusercontent.com/lamat1111/QuilibriumScripts/main/tools/qnode_service_change_autorun_to_bin.sh" && \
chmod +x ~/scripts/qnode_service_change_autorun_to_bin.sh && \
~/scripts/qnode_service_change_autorun_to_bin.sh
}

# 主菜单
function main_menu() {
    clear
    echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，免费开源，请勿相信收费"
    echo "================================================================"
    echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
    echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
    echo "请选择要执行的操作:"
    echo "1. 安装常规节点"
    echo "2. 查看节点日志"
    echo "3. Mac 节点安装"
    echo "8. 更新本脚本"
    echo "9. 加载快照"
    echo "10. 升级节点程序版本"
    echo "11. 安装常规节点(针对contabo)"
    echo "12. 升级节点程序版本(针对contabo)"
    echo "13. 安装grpc"
    echo "14. 升级2.0(截至10.13日，2.0还未正式开始挖矿，请根据实际情况确认呢是否升级)"
    echo "=======================单独使用功能============================="
    echo "4. 独立启动挖矿（安装好常规节点后搭配使用）"
    echo "=========================备份功能================================"
    echo "5. 备份文件"
    echo "=========================收米查询================================"
    echo "6. 查询余额(需要先安装grpc)"
    
    read -p "请输入选项（1-14）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) check_service_status ;;  
    3) install_node_mac ;; 
    4) run_node ;;
    5) backup_set ;;
    6) check_balance ;;
    8) update_script ;;
    9) add_snapshots ;;
    10) update_node ;;
    11) install_node_contabo ;;
    12) update_node_contabo ;;
    13) setup_grpc ;;
    14) update_new ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
