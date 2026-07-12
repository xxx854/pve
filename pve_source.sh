#!/usr/bin/bash

export Script_Version="V1.2-Alpha"
export Script_Build="20231128-001"

# 系统环境变量
export LANG=en_US.UTF-8

echoContent() {
    case $1 in
    # 红色
    "red")
        # shellcheck disable=SC2154
        ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        # 天蓝色
    "skyBlue")
        ${echoType} "\033[1;36m${printN}$2 \033[0m"
        ;;
        # 绿色
    "green")
        ${echoType} "\033[32m${printN}$2 \033[0m"
        ;;
        # 白色
    "white")
        ${echoType} "\033[37m${printN}$2 \033[0m"
        ;;
    "magenta")
        ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        # 黄色
    "yellow")
        ${echoType} "\033[33m${printN}$2 \033[0m"
        ;;
    esac
}

#定义输出颜色的功能
# 红色
rmsg() { echo -e "\033[31m$*\033[0m"; }
# 绿色
gmsg() { echo -e "\033[32m$*\033[0m"; }
# 黄色
ymsg() { echo -e "\033[33m$*\033[0m"; }
# 蓝色
bmsg() { echo -e "\033[34m$*\033[0m"; }
# 紫色
pmsg() { echo -e "\033[35m$*\033[0m"; }
# 青色
bgmsg() { echo -e "\033[36m$*\033[0m"; }
# 青色(高亮)
bglsg() { echo -e "\033[1;36m$*\033[0m"; }
# 青色(下划线)
bgumsg() { echo -e "\033[4;36m$*\033[0m"; }
# 白色
wmsg() { echo -e "\033[37m$*\033[0m"; }

# 连接性测试
network_connectivity() {
    if ping -c 1 -W 3 baidu.com &>/dev/null; then
        echoContent green "网络连通性：已连接互联网"
    else
        echoContent red "网络连通性：未连接互联网。请注意网络配置及 DNS "
    fi
}

# 初始化全局变量
initVar() {
    installType='apt -y install'
    reinstallType='apt -y reinstall'
    removeType='apt -y remove'
    update="apt update"
    upgrade="apt upgrade -y"
    distupgrade="apt dist-upgrade -y"
    dpkgconfigure="dpkg --configure -a"

    updateReleaseInfoChange='apt-get --allow-releaseinfo-change update'
    autoremoveType='apt -y autoremove'
    echoType='echo -e'

    # 安装总进度
    totalProgress=1

    # 运行模式
    Auto="No"
    pveauto="OFF"

    # 版本判断
    pveVersionJudge
}

# 进度条
process_line() {
    i=0
    str='#'
    ch=('|' '\' '-' '/')
    index=0
    while [ $i -le 50 ]
    do
        printf "$1：[%-50s][%d%%][%c]\r" $str $(($i*2)) ${ch[$index]}
        str+='#'
        let i++
        let index=i%4
        sleep 0.05
    done
    printf "\n"
}

# 安装软件
install_software() {
    local tool="$1"
    local soft="$2"
    if [ -z $(which ${tool}) ]; then
        ${updateReleaseInfoChange} > /dev/null 2>&1
        echoContent green " ---> 安装 ${soft}"
        process_line '进度'
        ${installType} ${soft} > /dev/null 2>&1
        if [ -z $(which ${tool}) ]; then
            echoContent red " ---> ${soft} 安装失败, 请检查 PVE 软件源及网络的连通性、DNS有效性后重试"
        else
            echoContent green " ---> ${soft} 安装完成"
        fi
    fi
}

# 卸载软件
remove_software() {
    local tool="$1"
    local soft="$2"
    if [ ! -z $(which ${tool}) ]; then
        echoContent green " ---> 卸载 ${soft}"
        process_line '进度'
        ${removeType} ${soft} > /dev/null 2>&1
        if [ -n $(which ${tool}) ]; then
            echoContent red " ---> ${soft} 卸载失败"
        else
            echoContent green " ---> ${soft} 卸载完成"
        fi
    fi
}

# Proxmox 版本判断
pveVersionJudge() {
    # 读取当前 PVE 版本号
    proxmox_ver="$(pveversion -v | grep proxmox-ve | awk '{print $2}')"
    proxmox_main_ver="${proxmox_ver%%-*}"

    # 版本号比较
    function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
    function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
    function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
    function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
}

# 键入提示
case_read() {
    read -r -p $'\x0a(按键 Ctrl + C 终止运行脚本, 键入任意值返回'$1') : ' choose
    case $choose in
        *)
            echoContent white ""
            if [ -f "$2" ]; then
                chmod +x "$2" && ./$2 $3
            fi
            ;;
    esac
}

# 交互 (Y/n) 询问
ask_user() {
    local prompt="$1"
    local yes_cmd="$2"
    local no_cmd="$3"
    while true; do
        read -r -p "$prompt (Y/n) : " answer
        case $answer in
            [Yy]) eval "$yes_cmd" && break;;
            [Nn]) eval "$no_cmd" && break;;
            *) echoContent red " ---> 选择错误";;
        esac
    done
}


# 通用免责声明

# 主菜单
menu() {
    cd "$HOME" || exit
    while :
    do
        echoContent red "\n"
        echoContent red "\n=============================================================="
        echoContent green '          _______       ___       ____ __
         / ____/ |     / / |     / / //_/
        / /    | | /| / /| | /| / / ,<
       / /___  | |/ |/ / | |/ |/ / /| |
       \____/  |__/|__/  |__/|__/_/ |_| ———— pve_source 小工具'
        echoContent red "\n==============================================================\n"
        echoContent green "版本 : $Script_Version"
        echoContent green "Build : $Script_Build\n"
        echoContent green "作者 : Jazz\n"
        echoContent green "鸣谢 : Weilbyte(PVE 暗黑主题)"
        echoContent green "       GitHub：https://github.com/Weilbyte/PVEDiscordDark\n"
        echoContent green "       gangqizai(Intel 核显直通)"
        echoContent green "       GitHub：https://github.com/gangqizai/igd\n"
        echoContent green "       strongtz(Intel 核显 SR-IOV)"
        echoContent green "       GitHub：https://github.com/strongtz/i915-sriov-dkms"
        echoContent red "\n==============================================================\n\n"
        echoContent skyBlue "-------------------------PVE 换源工具-------------------------"
        echoContent yellow "1、一键设置 DNS、换源并更新系统"
        echoContent yellow "2、更换 Proxmox VE 源"
        echoContent yellow "3、更新软件包"
        echoContent yellow "4、更新系统"
        echoContent yellow "5、设置系统 DNS"
        echoContent yellow "6、去除无效订阅源提示"
        echoContent skyBlue "-------------------------PVE  UI 修改-------------------------"
        echoContent yellow "7、修改 PVE 概要信息"
        echoContent yellow "8、应用 PVE 暗黑主题"
        echoContent skyBlue "-------------------------PVE 高级配置-------------------------"
        echoContent yellow "9、配置 PVE IOMMU 与核显直通、核显 SR-IOV, 群晖 虚拟 USB 引导等"
        echoContent skyBlue "-----------------------PVE CPU 工作模式-----------------------"
        echoContent yellow "10、配置 CPU 电源管理 P-State 状态"
        echoContent yellow "11、配置 CPU 工作模式"
        echoContent skyBlue "-------------------------  其他工具  -------------------------"
        echoContent yellow "12、通过 SLAAC 获取 IPv6"
        echoContent yellow "13、卸载内核(Kernels)及头文件(Headers)"
        echoContent yellow "14、设置 PVE 启动内核"
        echoContent yellow "15、设置 NTP 自动校时服务器"
        echoContent yellow "16、移除 local-lvm 存储空间(危险操作！)"
        echoContent yellow "17、禁止系统修改网卡名称, 使用 eth0 ~ ethN 原名(风险操作！)"
        echoContent skyBlue "-------------------------  网络连通性  -------------------------"
        network_connectivity
        echoContent red "--------------------------------------------------------------"
        echoContent yellow "Ctrl+C : 退出"
        echoContent red "=============================================================="
        read -r -p "请选择 : " selectInstallType
        case ${selectInstallType} in
            1)
                ./pve_source_1 pveAuto_menu
                ;;
            2)
                ./pve_source_1 change_source_menu
                ;;
            3)
                ./pve_source_1 upgrade
                ;;
            4)
                ./pve_source_1 distupgrade
                ;;
            5)
                ./pve_source_1 set_DNS
                ;;
            6)
                ./pve_source_1 remove_void_soucre_tips
                ;;
            7)
                ./pve_source_2 pveInfo_menu
                ;;
            8)
                ./pve_source_2 PVEDiscordDark_menu
                ;;
            9)
                ./pve_source_3 pve_IOMMU_menu
                ;;
            10)
                ./pve_source_3 pve_pstate_menu
                ;;
            11)
                ./pve_source_3 pve_cpumode_menu
                ;;
            12)
                ./pve_source_3 pve_slaac_ipv6_menu
                ;;
            13)
                ./pve_source_3 pve_removeotherkernel_menu
                ;;
            14)
                ./pve_source_3 pve_setbootkernel_menu
                ;;
            15)
                ./pve_source_3 PVE_NTP_menu
                ;;
            16)
                ./pve_source_3 PVE_Delete_LVM
                ;;
            17)
                ./pve_source_3 PVE_Disable_Ethernet_Rename
                ;;
            *)
                echoContent red " ---> 选择错误"
                case_read '主菜单' 'pve_source' 'menu'
                ;;
        esac
    done
}

initVar

case $1 in
    menu)
        menu
        ;;
    *)
        export TOP_PID=$$
        echo $TOP_PID
        menu
        ;;
esac

/root/pve_source
/dev/null
