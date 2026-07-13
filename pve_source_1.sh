#!/usr/bin/bash

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

initVar

# 更换 Proxmox 软件源
pveDebianCodename_menu() {
    while :
    do
        echoContent skyBlue "\n进度  $1/${totalProgress} : 选择 Proxmox Debian 版本"
        echoContent red "\n=============================================================="
        echoContent yellow "1、Proxmox VE 7"
        echoContent yellow "2、Proxmox VE 8"
        echoContent yellow "0、跳过"
        echoContent red "=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "1、当前 Proxmox VE 版本为 $proxmox_ver"
        echoContent yellow "2、若选择的 Proxmox VE 版本高于当前版本, 则换源后会更新系统；"
        echoContent yellow "3、不要选择低于当前 Proxmox VE 的版本, 强行降级可能会产生难以预料的后果；\n"
        echoContent red "=============================================================="
        read -r -p "请选择 : " pveDebianCodename
        case ${pveDebianCodename} in
            1)
                debian_code="bullseye"
                pve_mainver="7"
                break
                ;;
            2)
                debian_code="bookworm"
                pve_mainver="8"
                break
                ;;
            0)
                break
                ;;
            *)
                echoContent red " ---> 选择错误"
                ;;
        esac
    done
}

# 更换 Proxmox 软件源
pveSoftSource_menu() {
    pveSoftSource() {
        local domian_url="$1"
        local debian_code="$2"
        echo "deb "https://${domian_url}" ${debian_code} pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
        echoContent green " ---> 更换 Proxmox 软件源完成"

        # 删除 Proxmox 企业源
        if [ -f /etc/apt/sources.list.d/pve-enterprise.list* ]; then
            rm -rf /etc/apt/sources.list.d/pve-enterprise.list*
            echoContent green " ---> 删除 Proxmox 企业源完成"
        fi

        if [ ! -f '/etc/apt/trusted.gpg.d/proxmox-release-'${debian_code}'.gpg' ]; then
            curl -sSf -f https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/proxmox-release-${debian_code}.gpg &> /dev/null && {
                #echoContent green " ---> 服务器访问成功, 开始下载软件源加密软件......"
                wget -qc -t 5 https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/proxmox-release-${debian_code}.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-${debian_code}.gpg
            } || {
                echoContent red " ---> 服务器访问失败, 无法下载软件源加密软件, 请检查网络后重试"
            }
            if [ -f '/etc/apt/trusted.gpg.d/proxmox-release-'${debian_code}'.gpg' ]; then
                echoContent green " ---> 软件源加密软件下载完成"
            fi
        fi
    }

    if [ $pveauto = "ON" ]; then
        domian_url="mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve"
        pveSoftSource ${domian_url} ${debian_code}
    else
        while :
        do
            echoContent skyBlue "\n进度  $1/${totalProgress} : 更换 Proxmox 软件源"
            echoContent red "\n=============================================================="
            echoContent yellow "1、中国科技大学源"
            echoContent yellow "2、清华大学源"
            echoContent yellow "3、南京大学源"
            echoContent yellow "0、跳过"
            echoContent red "=============================================================="
            read -r -p "请选择 : " pveSoftNewSource
            case ${pveSoftNewSource} in
                1)
                    domian_url="mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve"
                    pveSoftSource ${domian_url} ${debian_code}
                    break
                    ;;
                2)
                    domian_url="mirrors.tuna.tsinghua.edu.cn/proxmox/debian"
                    pveSoftSource ${domian_url} ${debian_code}
                    break
                    ;;
                3)
                    domian_url="mirrors.nju.edu.cn/proxmox/debian"
                    pveSoftSource ${domian_url} ${debian_code}
                    break
                    ;;
                0)
                    break
                    ;;
                *)
                    echoContent red " ---> 选择错误"
                    ;;
            esac
        done
    fi
}

# 更换 Proxmox Debian 源
pveDebianSource_menu() {
    pveDebianSource() {
        local domian_url="$1"
        local debian_code="$2"
        local non_free='non-free'
        if [ $debian_code = "bookworm" ]; then
            non_free='non-free non-free-firmware'
        fi
        cat >/etc/apt/sources.list<<EOF
deb https://${domian_url}/debian/ ${debian_code} main contrib ${non_free}
deb https://${domian_url}/debian/ ${debian_code}-updates main contrib ${non_free}
deb https://${domian_url}/debian/ ${debian_code}-backports main contrib ${non_free}
deb https://${domian_url}/debian-security ${debian_code}-security main contrib ${non_free}
deb-src https://${domian_url}/debian/ ${debian_code} main contrib ${non_free}
deb-src https://${domian_url}/debian/ ${debian_code}-updates main contrib ${non_free}
deb-src https://${domian_url}/debian/ ${debian_code}-backports main contrib ${non_free}
deb-src https://${domian_url}/debian-security ${debian_code}-security main contrib ${non_free}
EOF
        echoContent green " ---> 更换 Proxmox Debian 源完成"
    }

    if [ $pveauto = "ON" ]; then
        domian_url="mirrors.tuna.tsinghua.edu.cn"
        pveDebianSource ${domian_url} ${debian_code}
    else
        while :
        do
            echoContent skyBlue "\n进度  $1/${totalProgress} : 更换 Proxmox Debian 源"
            echoContent red "\n=============================================================="
            echoContent yellow "1、中国科技大学源"
            echoContent yellow "2、清华大学源"
            echoContent yellow "3、南京大学源"
            echoContent yellow "4、阿里云源"
            echoContent yellow "5、腾讯云源"
            echoContent yellow "6、华为源"
            echoContent yellow "7、网易源"
            echoContent yellow "0、跳过"
            echoContent red "=============================================================="
            read -r -p "请选择 : " pveDebianNewSource
            case ${pveDebianNewSource} in
                1)
                    domian_url="mirrors.tuna.tsinghua.edu.cn"
                    pveDebianSource ${domian_url} ${debian_code}
                    break
                    ;;
                2)
                    domian_url="mirrors.tuna.tsinghua.edu.cn"
                    pveDebianSource ${domian_url} ${debian_code}
                    break
                    ;;
                3)
                    domian_url="mirrors.nju.edu.cn"
                    pveDebianSource ${domian_url} ${debian_code}
                    break
                    ;;
                4)
                    domian_url="mirrors.aliyun.com"
                    pveDebianSource ${domian_url} ${debian_code}
                    break
                    ;;
                5)
                    domian_url="mirrors.cloud.tencent.com"
                    pveDebianSource ${domian_url} ${debian_code}
                    break
                    ;;
                6)
                    domian_url="repo.huaweicloud.com"
                    pveDebianSource ${domian_url} ${debian_code}
                    break
                    ;;
                7)
                    domian_url="mirrors.163.com"
                    pveDebianSource ${domian_url} ${debian_code}
                    break
                    ;;
                0)
                    break
                    ;;
                *)
                    echoContent red " ---> 选择错误"
                    ;;
            esac
        done
    fi
}

# 更换 Proxmox Ceph 源
pveCephSource() {
    if [ $pveauto = "ON" ]; then
        rm -rf /etc/apt/sources.list.d/ceph.list
        domian_url="mirrors.tuna.tsinghua.edu.cn"
        sed -i.bak "s#http://[^\]\+/debian#https://$domian_url/proxmox/debian#g" /usr/share/perl5/PVE/CLI/pveceph.pm
        echoContent green " ---> 更换 Proxmox Ceph 源完成"
    else
        while :
        do
            echoContent skyBlue "\n功能  $1/${totalProgress} : 更换 Proxmox Ceph 源"
            echoContent red "\n=============================================================="
            echoContent yellow "1、中国科技大学源"
            echoContent red "=============================================================="
            read -r -p "请选择 : " pveCephNewSource
            case ${pveCephNewSource} in
                1)
                    rm -rf /etc/apt/sources.list.d/ceph.list
                    domian_url="mirrors.tuna.tsinghua.edu.cn"
                    sed -i.bak "s#http://[^\]\+/debian#https://$domian_url/proxmox/debian#g" /usr/share/perl5/PVE/CLI/pveceph.pm
                    echoContent green " ---> 更换 Proxmox Ceph 源完成"
                    break
                    ;;
                *)
                    echoContent red " ---> 选择错误"
                    ;;
            esac
        done
    fi
}

# 更换 Proxmox LXC 仓库源
pveLXCSource() {
    if [ $pveauto = "ON" ]; then
        domian_url="mirrors.tuna.tsinghua.edu.cn"
    else
        while :
        do
            echoContent skyBlue "\n进度  $1/${totalProgress} : 更换 Proxmox LXC 仓库源"
            echoContent red "\n=============================================================="
            echoContent yellow "1、中国科技大学源"
            echoContent yellow "2、清华大学源"
            echoContent yellow "3、南京大学源"
            echoContent red "=============================================================="
            read -r -p "请选择 : " pveLXCNewSource
            case ${pveLXCNewSource} in
                1)
                    domian_url="mirrors.tuna.tsinghua.edu.cn"
                    break
                    ;;
                2)
                    domian_url="mirrors.tuna.tsinghua.edu.cn"
                    break
                    ;;
                3)
                    domian_url="mirrors.nju.edu.cn"
                    break
                    ;;
                *)
                    echoContent red " ---> 选择错误"
                    ;;
            esac
        done
    fi

    sed -i.bak "s#http://[^\]\+/images#https://$domian_url/proxmox/images#g" /usr/share/perl5/PVE/APLInfo.pm
    wget -O /var/lib/pve-manager/apl-info/$domian_url https://$domian_url/proxmox/images/aplinfo-pve-$pve_mainver.dat
    systemctl restart pvedaemon
    echoContent green " ---> 更换 Proxmox LXC 仓库源完成"
}


# 设置 DNS
set_DNS() {
    echoContent skyBlue "\n进度  $i/${totalProgress} : 设置 Proxmox 系统 DNS"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "DNS 错误会导致系统更新失败等网络问题\n"

    echoContent red "=============================================================="

    local DNS=""
    local tmp=""
    local content="$(cat /etc/resolv.conf | grep search)"
    for i in {1..3};do
        while :
        do
            read -r -p "请输入 DNS$i (输入 skip 跳过) : " pve_IPEnter
            case ${pve_IPEnter} in
                skip)
                    eval DNS$i=""
                    echoContent red " ---> DNS$i 跳过输入"
                    break
                    ;;
                *)
                    VALID_CHECK=$(echo ${pve_IPEnter}|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
                    if echo ${pve_IPEnter}|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null; then
                        if [ ${VALID_CHECK:-no} == "yes" ]; then
                            eval DNS$i=${pve_IPEnter}
                            echoContent green " ---> DNS$i：${pve_IPEnter}"
                            break
                        else
                            echoContent red " ---> DNS$i IP 地址错误, 请重新输入"
                        fi
                    else
                        echoContent red " ---> DNS$i IP 格式错误, 请重新输入"
                    fi
                    ;;
            esac
        done

        if [ -n "$(eval echo \$DNS$i)" ]; then
            tmp="nameserver \$DNS$i"
            DNS="$DNS'\n'$tmp"
        fi
    done

    if [ -n "$DNS" ]; then
        content="$content$DNS"
        eval echo -e "$content" > /etc/resolv.conf
    fi
    echoContent green " ---> DNS 设置完成"
}

# 去除无效订阅源提示
remove_void_soucre_tips() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 去除无效订阅源提示"
    sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    systemctl restart pveproxy

    echoContent green " ---> 去除无效订阅源提示完成, 请使用 Shift + F5 手动刷新 PVE Web 页面"
}

pveAuto() {
    local pveauto="ON"
    #设置 DNS
    echoContent skyBlue "\n进度  1/${totalProgress} : 设置 Proxmox VE 的系统 DNS\n"

    echoContent red "==============================================================\n"
    echoContent skyBlue "            DNS1 223.6.6.6"
    echoContent skyBlue "            DNS2 223.5.5.5"
    echoContent skyBlue "            DNS3 1.1.1.1\n"

    echoContent red "=============================================================="
    local content="$(cat /etc/resolv.conf | grep search)"
    cat >/etc/resolv.conf<<EOF
${content}
nameserver 223.6.6.6
nameserver 223.5.5.5
nameserver 1.1.1.1
EOF
    echoContent green " ---> DNS 设置完成"

    # 更换 Proxmox 软件源
    pveDebianCodename_menu 2
    pveSoftSource_menu

    # 更换 Proxmox Debian 源
    pveDebianSource_menu

    # 更换 Proxmox Ceph 源
    pveCephSource

    # 更换 Proxmox LXC 仓库源
    pveLXCSource

    # 更新系统
    echoContent skyBlue "\n进度  3/${totalProgress} : 更新系统"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "首次更新或此前长期未更新系统, 将花费较长时间, 请耐心等待"

    echoContent red "=============================================================="
    while :
    do
        read -r -p '是否显示详细日志 (Y/n。升级系统必须选 Y/y, 交互过程键入 Enter)？ : ' answer
        case $answer in
            [Yy])
                ${dpkgconfigure}
                ${update}
                ${distupgrade}
                break
                ;;
            [Nn])
                ${dpkgconfigure} > /dev/null 2>&1
                ${update} > /dev/null 2>&1
                ${distupgrade} > /dev/null 2>&1
                echoContent green " ---> 系统更新完成"
                break
                ;;
            *)
                echoContent red " ---> 选择错误"
                ;;
        esac
    done
}

# 一键设置 DNS、换源并更新系统确认菜单
pveAuto_menu() {
    echoContent skyBlue "\n功能 1/${totalProgress} : 一键设置 DNS、换源并更新系统"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "1、当前 Proxmox VE 版本为 $proxmox_ver"
    echoContent yellow "2、使用本功能会将系统(包括内核)升级到最新版\n"

    echoContent red "=============================================================="
    while :
    do
        read -r -p '是否开始一键设置 DNS、换源并更新系统 (Y/n)？ : ' pveAutochoose
        case $pveAutochoose in
            [Yy])
                totalProgress=3
                pveAuto && case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            [Nn])
                ./pve_source menu
                break
                ;;
            *)
                echoContent red " ---> 选择错误"
                ;;
        esac
    done
}

# 更换源
change_source_menu() {
    while :
    do
        echoContent skyBlue "\n功能 1/${totalProgress} : 更换软件源"
        echoContent red "\n=============================================================="
        echoContent yellow "1、更换 PVE 软件源 + Debian 源"
        echoContent yellow "2、更换 PVE Ceph 源"
        echoContent yellow "3、更换 PVE LXC 仓库源"
        echoContent yellow "0、返回"
        echoContent red "=============================================================="
        read -r -p "请选择 : " selectNewSource
        case ${selectNewSource} in
            1)
                totalProgress=3
                pveDebianCodename_menu 1 && pveSoftSource_menu 2 && pveDebianSource_menu 3
                ${dpkgconfigure}
                ${update}
                echoContent green " ---> 更新数据库完成"
                case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            2)
                totalProgress=1
                pveCephSource 1 && case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            3)
                totalProgress=1
                pveLXCSource 1 && case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            *)
                ./pve_source menu
                break
                ;;
        esac
    done
}

case $1 in
    pveAuto_menu)
        totalProgress=1
        pveAuto_menu
        ;;
    change_source_menu)
        totalProgress=2
        change_source_menu
        echoContent green " ---> 请执行 apt update 同步更新数据库"
        ;;
    upgrade)
        echoContent skyBlue "\n功能  1/${totalProgress} : 更新软件包"
        ${dpkgconfigure} && ${update} && ${upgrade}
        echoContent green " ---> 软件包更新完成"
        case_read '主菜单' 'pve_source' 'menu'
        ;;
    distupgrade)
        echoContent skyBlue "\n功能  1/${totalProgress} : 更新系统"
        ${dpkgconfigure} && ${update} && ${distupgrade}
        echoContent green " ---> 系统更新完成"
        case_read '主菜单' 'pve_source' 'menu'
        ;;
    set_DNS)
        totalProgress=3
        set_DNS
        case_read '主菜单' 'pve_source' 'menu'
        ;;
    remove_void_soucre_tips)
        totalProgress=1
        remove_void_soucre_tips 1
        case_read '主菜单' 'pve_source' 'menu'
        ;;
    *)
        echoContent red " ---> 打开错误, 请通过 pve_source 使用本工具。"
        ;;
esac

/root/pve_source_1
/dev/null
