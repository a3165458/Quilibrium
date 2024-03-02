#!/bin/bash


# 检查是否为root用户执行脚本
if [ "$(id -u)" != "0" ]; then
   echo "该脚本必须以root权限运行" 1>&2
   exit 1
fi

# 向 /etc/sysctl.conf 文件追加内容
echo -e "\n# 自定义最大接收和发送缓冲区大小" >> /etc/sysctl.conf
echo "net.core.rmem_max=600000000" >> /etc/sysctl.conf
echo "net.core.wmem_max=600000000" >> /etc/sysctl.conf

echo "配置已添加到 /etc/sysctl.conf"

# 重新加载sysctl配置以应用更改
sysctl -p

echo "sysctl 配置已重新加载"

# Update and Upgrade Ubuntu Packages without any prompts
sudo apt update && sudo apt -y upgrade 

# Install wget, screen, and git without any prompts
sudo apt install git ufw bison screen binutils gcc make -y


# Install GVM
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

# Clone the repository
git clone https://github.com/quilibriumnetwork/ceremonyclient

# Navigate to ceremonyclient/node directory
cd ceremonyclient/node 

# 写入脚本
cat > auto.sh <<EOF
#!/bin/bash
while true
do
	ps -ef | grep "node" | grep -v "grep"
	if [ "$?" -eq 1 ]
		then 
		echo "process has restarting..."
		GOEXPERIMENT=arenas go run ./...
		echo "process has been restarted!"
	else
		echo "process already started!"
	fi
	sleep 10
done
EOF

# 赋予权限
chmod +x auto.sh

# Create a screen session and run the command
screen -dmS Quili bash -c './auto.sh'
