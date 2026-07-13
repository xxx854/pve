#!/bin/bash

# 功能1: 一键设置 DNS、换源并更新系统
# 基于清华镜像源

set -e

# 颜色输出
green() { echo -e "\033[32m$*\033[0m"; }
red() { echo -e "\033[31m$*\033[0m"; }
blue() { echo -e "\033[1;36m$*\033[0m"; }

echo ""
blue "=========================================================="
blue "  功能1: 一键设置 DNS、换源并更新系统"
blue "=========================================================="
echo ""

# 步骤1: 设置 DNS
green "[1/7] 设置 DNS..."
cat > /etc/resolv.conf <<EOF
search lan
nameserver 223.6.6.6
nameserver 223.5.5.5
nameserver 1.1.1.1
EOF
green "      DNS 设置完成: 223.6.6.6, 223.5.5.5, 1.1.1.1"

# 步骤2: 更换 PVE 源
green "[2/7] 更换 PVE 源为清华源..."
echo "deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
rm -rf /etc/apt/sources.list.d/pve-enterprise.list* 2>/dev/null || true
green "      PVE 源更换完成"

# 步骤3: 更换 Debian 源
green "[3/7] 更换 Debian 源为清华源..."
cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
green "      Debian 源更换完成"

# 步骤4: 更换 Ceph 源
green "[4/7] 更换 Ceph 源为清华源..."
rm -f /etc/apt/sources.list.d/ceph.list 2>/dev/null || true
sed -i.bak "s#https://enterprise.proxmox.com/debian/ceph-quincy#https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/ceph-quincy#g" /usr/share/perl5/PVE/CLI/pveceph.pm 2>/dev/null || true
green "      Ceph 源更换完成"

# 步骤5: 更换 LXC 源
green "[5/7] 更换 LXC 源为清华源..."
sed -i.bak "s#http://download.proxmox.com/images#https://mirrors.tuna.tsinghua.edu.cn/proxmox/images#g" /usr/share/perl5/PVE/APLInfo.pm 2>/dev/null || true
green "      LXC 源更换完成"

# 步骤6: 更新软件包列表
green "[6/7] 更新软件包列表..."
apt update

# 步骤7: 升级系统
green "[7/7] 升级系统..."
green "      首次更新可能需要较长时间，请耐心等待..."
apt upgrade -y

echo ""
green "=========================================================="
green "  功能1 执行完成!"
green "=========================================================="
echo ""

# 显示最终配置
green "当前配置:"
green "  DNS: $(grep nameserver /etc/resolv.conf | tr '\n' ' ')"
green "  PVE 源: $(cat /etc/apt/sources.list.d/pve-no-subscription.list)"
green "  Debian 源: $(head -1 /etc/apt/sources.list)"
green "  Ceph 源: 已修改 pveceph.pm"
green "  LXC 源: 已修改 APLInfo.pm"
echo ""