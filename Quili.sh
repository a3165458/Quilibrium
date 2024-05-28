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
sudo apt install git ufw bison screen binutils gcc make bsdmainutils -y

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

# 克隆仓库
git clone https://github.com/quilibriumnetwork/ceremonyclient

# 构建Qclient
cd ceremonyclient/client
GOEXPERIMENT=arenas go build -o qclient main.go
sudo cp $HOME/ceremonyclient/client/qclient /usr/local/bin

# 进入ceremonyclient/node目录
cd #HOME
cd ceremonyclient/node 
git switch release

# 赋予执行权限
chmod +x release_autorun.sh

# 创建一个screen会话并运行命令
screen -dmS Quili bash -c './release_autorun.sh'

echo ====================================== 安装完成 =========================================

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
git clone https://github.com/quilibriumnetwork/ceremonyclient


# 构建 Qclient
cd ceremonyclient/client
GOEXPERIMENT=arenas go build -o qclient main.go
sudo cp $HOME/ceremonyclient/client/qclient /usr/local/bin

# 进入 ceremonyclient/node 目录
cd #HOME
cd ceremonyclient/node
git switch release

# 赋予执行权限
chmod +x release_autorun.sh

# 创建一个 screen 会话并运行命令
screen -dmS Quili bash -c './release_autorun.sh'

echo ====================================== 安装完成 =========================================

}

# 查看常规版本节点日志
function check_service_status() {
    screen -r Quili
   
}

# 独立启动
function run_node() {
    screen -dmS Quili bash -c 'source /root/.gvm/scripts/gvm && gvm use go1.20.2 && cd ~/ceremonyclient/node && ./release_autorun.sh'

    echo "=======================已启动quilibrium 挖矿 请使用screen 命令查询状态========================================="
}

function add_snapshots() {
wget http://94.16.31.160/store.tar.gz
tar -xzf store.tar.gz
cd ~/ceremonyclient/node/.config
rm -rf store
cd ~
mv store ~/ceremonyclient/node/.config

screen -dmS Quili bash -c 'source /root/.gvm/scripts/gvm && gvm use go1.20.2 && cd ~/ceremonyclient/node && ./release_autorun.sh'
   
}

function backup_set() {
mkdir -p ~/backup
cat ~/ceremonyclient/node/.config/config.yml > ~/backup/config.txt
cat ~/ceremonyclient/node/.config/keys.yml > ~/backup/keys.txt

echo "=======================备份完成，请执行cd ~/backup 查看备份文件========================================="

}

function check_balance() {
qclient token balance

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
    echo "2. 查看常规版本节点日志"
    echo "3. Mac 常规节点安装"
    echo "=======================单独使用功能============================="
    echo "4. 独立启动挖矿（安装好常规节点后搭配使用）"
    echo "=========================备份功能================================"
    echo "5. 备份文件"
    echo "=========================收米查询================================"
    echo "6. 查询余额"
    read -p "请输入选项（1-6）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) check_service_status ;;  
    3) install_node_mac ;; 
    4) run_node ;;
    5) backup_set ;;
    6) check_balance ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
