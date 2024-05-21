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

# 安装GVM
bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
source /root/.gvm/scripts/gvm

gvm install go1.4 -B
gvm use go1.4
export GOROOT_BOOTSTRAP=$GOROOT
gvm install go1.17.13
gvm use go1.17.13
export GOROOT_BOOTSTRAP=$GOROOT
gvm install go1.20.2
gvm use go1.20.2

# 克隆仓库
git clone https://github.com/quilibriumnetwork/ceremonyclient

# 进入ceremonyclient/node目录
cd ceremonyclient/node 

# 赋予执行权限
chmod +x poor_mans_cd.sh

# 创建一个screen会话并运行命令
screen -dmS Quili bash -c './poor_mans_cd.sh'

}



# 节点安装功能
function install_node_service() {

# 检查是否以root用户执行脚本
if [ "$(id -u)" != "0" ]; then
   echo "该脚本必须以root权限运行" 1>&2
   exit 1
fi

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

# 安装GVM
bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
source /root/.gvm/scripts/gvm

gvm install go1.4 -B
gvm use go1.4
export GOROOT_BOOTSTRAP=$GOROOT
gvm install go1.17.13
gvm use go1.17.13
export GOROOT_BOOTSTRAP=$GOROOT
gvm install go1.20.2
gvm use go1.20.2

# 克隆仓库
git clone https://github.com/quilibriumnetwork/ceremonyclient

# 进入ceremonyclient/node目录
cd ceremonyclient/node 

# 构建服务
GOEXPERIMENT=arenas go install ./...

# 写入服务
sudo tee /lib/systemd/system/ceremonyclient.service > /dev/null <<EOF
[Unit]
Description=Ceremony Client GO App Service

[Service]
Type=simple
Restart=always
RestartSec=5S
WorkingDirectory=/root/ceremonyclient/node
Environment=GOEXPERIMENT=arenas
ExecStart=/root/.gvm/pkgsets/go1.20.2/global/bin/node ./...

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable ceremonyclient
sudo systemctl start ceremonyclient

# 完成安装提示
echo ====================================== 安装完成 =========================================

}


# 查看服务版本状态
function check_ceremonyclient_service_status() {
    systemctl status ceremonyclient
}

# 服务版本节点日志查询
function view_logs() {
    sudo journalctl -f -u ceremonyclient.service
}

# 查看常规版本节点日志
function check_service_status() {
    screen -r Quili
   
}

# 独立启动
function run_node() {
    screen -dmS Quili bash -c 'source /root/.gvm/scripts/gvm && gvm use go1.20.2 && cd ~/ceremonyclient/node && ./poor_mans_cd.sh'

    echo "=======================已启动quilibrium 挖矿 ========================================="
}

function add_snapshots() {
wget http://94.16.31.160/store.tar.gz
tar -xzf store.tar.gz
cd ~/ceremonyclient/node/.config
rm -rf store
cd ~
mv store ~/ceremonyclient/node/.config

screen -dmS Quili bash -c 'source /root/.gvm/scripts/gvm && gvm use go1.20.2 && cd ~/ceremonyclient/node && ./poor_mans_cd.sh'
   
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
    echo "3. 安装服务版本节点（性能调度没有常规节点积极，可能奖励会更少）"
    echo "4. 查看服务版本节点日志"
    echo "5. 查看服务版本服务状态"
    echo "6. 设置快捷键的功能"    
    echo "================================================================"
    echo "7. 独立启动挖矿（安装好常规节点后搭配使用）"
    echo "8. 下载快照（直接到达41万高度）"
    read -p "请输入选项（1-3）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) check_service_status ;;  
    3) install_node_service ;; 
    4) view_logs ;; 
    5) check_ceremonyclient_service_status ;; 
    6) check_and_set_alias ;;  
    7) run_node ;;
    8) add_snapshots ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
