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

# 当前 grub 参数
grub_default_cur() {
    cat /etc/default/grub | grep -E "^GRUB_CMDLINE_LINUX_DEFAULT" | sed 's|.*"\(.*\)".*|\1|'
}

# PVE IOMMU 相关
pve_IOMMU_initial() {
    # 核显及核显音频的设备 ID
    gpu_id="$(lspci -nn|grep -E 'VGA compatible controller' | sed -r 's/.*\[(\w{4}):(\w{4})\].*/\1:\2/')"
    audio_id="$(lspci -nn|grep -E 'Audio device' | head -n 1 | sed -r 's/.*\[(\w{4}):(\w{4})\].*/\1:\2/')"

    # 核显及核显音频的总线地址
    iGPU_adr="$(lspci -D -nn|grep 'VGA compatible controller'|head -n 1|awk '{print $1}')"
    iAudio_adr="$(lspci -D -nn|grep 'Audio device'|head -n 1|awk '{print $1}')"

    # 识别 CPU 平台
    intel_cpu_gen=""
    black_array=()
    black_remove_array=('blacklist i915' 'blacklist amdgpu' 'blacklist snd_hda_intel' 'options vfio_iommu_type1 allow_unsafe_interrupts=1')
    cpu_platform="$(lscpu | grep 'Model name' | grep -E 'Intel|AMD')"
    case $cpu_platform in
        *Intel*)
            cpu_manufacturer="intel"
            read -r -p '是否是 11 代及以后的 CPU (Y/n)？ : ' choose
            case $choose in
                [Yy])
                    intel_cpu_gen="11+"
                    vfio_arg="options vfio-pci ids=$gpu_id,$audio_id"
                    black_array=('blacklist i915')
                    ;;
                [Nn])
                    vfio_arg="options vfio-pci ids=$gpu_id,$audio_id disable_vga=1"
                    black_array=('blacklist i915' 'blacklist snd_hda_intel' 'options vfio_iommu_type1 allow_unsafe_interrupts=1')
                    ;;
                *)
                    echo -e "不支持的 CPU 平台, 正在终止运行......"
                    sleep 5
                    case_read '主菜单' 'pve_source' 'menu'
                    menu
                    ;;
            esac
            ;;
        *AMD*)
            cpu_manufacturer="amd"
            vfio_arg="options vfio-pci ids=$gpu_id,$audio_id disable_idle_d3=1"
            black_array=('blacklist amdgpu' 'blacklist snd_hda_intel')
            ;;
        *)
            cpu_manufacturer=""
            echo -e "不支持的 CPU 平台, 正在终止运行......"
            sleep 5
            case_read '主菜单' 'pve_source' 'menu'
            ;;
    esac

    # 默认 grub 参数
    grub_default='quiet'

    # 默认 kernel_cmdline 参数
    kernel_cmdline_default="root=ZFS=rpool/ROOT/pve-1 boot=zfs"

    # PVE 版本适配核显直通参数
    if version_ge $proxmox_main_ver 7.2; then
        gpu_iommu_arg="initcall_blacklist=sysfb_init"
    else
        gpu_iommu_arg="video=efifb:off,vesafb:off"
    fi

    # 开启 IOMMU 的 grub 参数
    if [ "${intel_cpu_gen}" = "11+" ]; then
        # 开启 IOMMU 的 grub 参数
        grub_default_iommu="quiet intel_iommu=on"

        # 开启 IOMMU 的 grub 参数, 支持核显直通
        grub_default_iommu_gpu="$grub_default_iommu"

        # 开启 Intel 核显 SR-IOV 的 grub 参数
        grub_default_sr_iov="quiet ${cpu_manufacturer}_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7"

        # 开启 IOMMU 的 kernel_cmdline 参数
        kernel_cmdline_iommu="root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet ${cpu_manufacturer}_iommu=on iommu=pt"
    elif [ $cpu_manufacturer = "intel" ]; then
        # 开启 IOMMU 的 grub 参数
        grub_default_iommu="quiet ${cpu_manufacturer}_iommu=on pcie_acs_override=downstream,multifunction"

        # 开启 IOMMU 及核显直通的 grub 参数
        grub_default_iommu_gpu="quiet ${cpu_manufacturer}_iommu=on $gpu_iommu_arg pcie_acs_override=downstream,multifunction"

        # 开启 IOMMU 的 kernel_cmdline 参数
        kernel_cmdline_iommu="root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet ${cpu_manufacturer}_iommu=on"
    elif [ -n "$cpu_manufacturer" ]; then
        # 开启 IOMMU 的 grub 参数
        grub_default_iommu="quiet ${cpu_manufacturer}_iommu=on iommu=pt pcie_acs_override=downstream,multifunction"

        # 开启 IOMMU 及核显直通的 grub 参数
        grub_default_iommu_gpu="quiet ${cpu_manufacturer}_iommu=on iommu=pt $gpu_iommu_arg pcie_acs_override=downstream,multifunction"

        # 开启 IOMMU 的 kernel_cmdline 参数
        kernel_cmdline_iommu="root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet ${cpu_manufacturer}_iommu=on iommu=pt"
    fi
}

# 修改 grub 引导文件
mod_grub() {
    local grub_arg="$1"
    local currentProgress="$2"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 修改 grub 引导文件"
    # 修改 grub 引导文件
    sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT/ s/\".*\"/\"$grub_arg\"/" /etc/default/grub
    echoContent green " ---> grub 引导文件修改完成"

    # 更新 grub 引导配置
    echoContent skyBlue "\n进度 $[currentProgress+1]/${totalProgress} : 更新 grub 引导配置"
    update-grub
    echoContent green " ---> grub 引导配置更新完成"
}

# 修改 grub 引导文件
mod_kernel_cmdline() {
    if [[ -f /etc/kernel/cmdline && `grep -c "^$kernel_cmdline_default" "/etc/kernel/cmdline"` -gt '0' ]]; then
        if [[ `grep -c "^$1$" "/etc/kernel/cmdline"` -eq '0' ]]; then
            echo "$1" > /etc/kernel/cmdline
            proxmox-boot-tool refresh
        fi
    fi
}

# 更新 initramfs (初始化 RAM 系统)
update_initramfs() {
    local currentProgress="$1"

    # 更新 initramfs (初始化 RAM 系统)
    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 更新 initramfs (初始化 RAM 系统)"
    update-initramfs -u -k all
    echoContent green " ---> initramfs (初始化 RAM 系统)更新完成"
}

# 更新 PCI 设备 ID
update_pciids() {
    local currentProgress="$1"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 更新 PVE 设备 ID 数据库"
    read -r -p '是否更新 (Y/n, 默认Nn, 跳过更新)？ : ' choose
    case ${choose} in
        [Yy])
            update-pciids
            echoContent green " ---> 更新完成"
            ;;
        *)
            echoContent green " ---> 跳过更新"
            ;;
    esac
}

# 更新 PVE 系统的 Intel 核显固件
update_intel_gpu_firmware() {
    local currentProgress="$1"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 更新 PVE 系统的 Intel 核显固件(首次启用 SR-IOV, 建议更新)"
    read -r -p '是否更新 (Y/n, 默认Nn, 跳过更新)？ : ' choose
    case ${choose} in
        [Yy])
            curl -sSf -f https://github.com/intel-gpu/intel-gpu-firmware/ &> /dev/null && {
                echoContent green " ---> GitHub 连通正常"
                echoContent skyBlue "\n进度  $[currentProgress+1]/${totalProgress} : 开始更新固件"
                install_software 'git' 'git'
                if [ -n $(which git) ]; then
                    git clone https://github.com/intel-gpu/intel-gpu-firmware.git /tmp/intel-gpu-firmware > /dev/null 2>&1
                    if [ -d /tmp/intel-gpu-firmware/ ]; then
                        mkdir -p /lib/firmware/updates/i915/
                        cp -rf /tmp/intel-gpu-firmware/firmware/*.bin /lib/firmware/updates/i915/
                        echoContent green " ---> PVE 系统的 Intel 核显固件更新完成"
                        rm -rf /tmp/intel-gpu-firmware
                    else
                        echoContent red " ---> PVE 系统的 Intel 核显固件更新失败, 请检查网络后重试"
                    fi
                fi
            } || {
                echoContent red " ---> 无法连通 GitHub , 请检查网络后重试"
            }
            ;;
        *)
            echoContent green " ---> 跳过更新"
            ;;
    esac
}

# 添加 IOMMU 模块
Enable_IOMMU_modules() {
    local iommu_type="$1"
    local currentProgress="$2"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 配置 vfio 模块"
    for i in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
        if [ `grep -c ".*$i$" "/etc/modules"` -ne '0' ];then
            sed -i "s/.*$i$/$i/" /etc/modules
        elif [ `grep -c "^$i$" "/etc/modules"` -eq '0' ];then
            echo "$i" >> /etc/modules
        fi
    done
    echoContent green " ---> vfio 预载模块配置完成"

    echoContent skyBlue "\n进度 $[currentProgress+1]/${totalProgress} : 修改设备黑名单及 vfio 配置文件"
    if [ "$iommu_type" = "iommu_gpu" ]; then
        for i in "${black_remove_array[@]}"; do
            if [ `grep -c ".*$i$" "/etc/modprobe.d/pve-blacklist.conf"` -ne '0' ];then
                sed -i "/$i/d" /etc/modprobe.d/pve-blacklist.conf
            fi
        done
        for i in "${black_array[@]}"; do
            if [ `grep -c ".*$i$" "/etc/modprobe.d/pve-blacklist.conf"` -ne '0' ];then
                sed -i "s/.*$i$/blacklist $i/" /etc/modprobe.d/pve-blacklist.conf
            elif [ `grep -c "^$i$" "/etc/modprobe.d/pve-blacklist.conf"` -eq '0' ];then
                echo "$i" >> /etc/modprobe.d/pve-blacklist.conf
            fi
        done
        echoContent green " ---> 设备黑名单配置完成"

        echoContent skyBlue "\n进度 $[currentProgress+2]/${totalProgress} : 将核显设备 ID 强行绑定 vfio 模块"
        echoContent red "\n=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "1、某些核显需要强行绑定才能直通；"
        echoContent yellow "2、绑定后, PVE 启动后将在核显初始化前卡屏, 无法进入终端界面\n"

        echoContent red "=============================================================="
        read -r -p '是否强行绑定 (Y/n)？ : ' choose
        case ${choose} in
            [Nn])
                if [ -f '/etc/modprobe.d/vfio.conf' ]; then
                    if [ `grep -Ec "${gpu_id}|${audio_id}" "/etc/modprobe.d/vfio.conf"` -ne '0' ];then
                        sed -i "/'$gpu_id'/d" /etc/modprobe.d/vfio.conf
                        echoContent green " ---> 清除残余 vfio 配置文件"
                    fi
                else
                    echoContent green " ---> 未将核显设备 ID 绑定至 vfio 模块"
                fi
                ;;
            *)
                echo $vfio_arg > /etc/modprobe.d/vfio.conf
                echoContent green " ---> vfio 配置文件配置完成"
                ;;
        esac
    else
        for i in "${black_remove_array[@]}"; do
            if [ `grep -c ".*$i$" "/etc/modprobe.d/pve-blacklist.conf"` -ne '0' ];then
                sed -i "/$i/d" /etc/modprobe.d/pve-blacklist.conf
            fi
        done
        echoContent green " ---> 设备黑名单配置完成"

        if [ -f '/etc/modprobe.d/vfio.conf' ]; then
            if [ `grep -Ec "${gpu_id}|${audio_id}" "/etc/modprobe.d/vfio.conf"` -ne '0' ];then
                sed -i "/'$gpu_id'/d" /etc/modprobe.d/vfio.conf
                echoContent green " ---> 已清除 vfio 配置文件"
            fi
        fi
    fi
}

# 禁用 IOMMU 模块
Disable_IOMMU_modules() {
    local currentProgress="$1"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 配置 vfio 模块"
    if [ `grep -Ec "^vfio$|^vfio_iommu_type1$|^vfio_pci$|^vfio_virqfd$|" "/etc/modules"` -ne '0' ];then
        for i in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
            if [ `grep -c "^$i$" "/etc/modules"` -ne '0' ];then
                sed -i "/^$i$/ s/^/# /" /etc/modules
            fi
        done
        echoContent green " ---> 已取消 vfio 模块加载配置"
    fi

    echoContent skyBlue "\n进度 $[currentProgress+1]/${totalProgress} : 修改设备黑名单及 vfio 配置文件"
    for i in "${black_array[@]}"; do
        if [ `grep -c ".*$i$" "/etc/modprobe.d/pve-blacklist.conf"` -ne '0' ];then
            sed -i "/$i/d" /etc/modprobe.d/pve-blacklist.conf
        fi
    done

    if [ -f '/etc/modprobe.d/vfio.conf' ]; then
        if [ `grep -Ec "${gpu_id}|${audio_id}" "/etc/modprobe.d/vfio.conf"` -ne '0' ];then
            sed -i "/'$gpu_id'/d" /etc/modprobe.d/vfio.conf
            echoContent green " ---> 已清除 vfio 配置文件"
        fi
    fi
}

# PVE IOMMU 开关
pve_IOMMU_switch() {
    local switch="$1"
    local totalProgress="$2"
    local currentProgress="$3"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 配置 PVE 的 IOMMU"
    case ${switch} in
        iommu)
            # 开启 IOMMU
            grub_arg="$grub_default_iommu"
            mod_grub "${grub_arg}" "$[currentProgress+1]"
            mod_kernel_cmdline "$kernel_cmdline_iommu"

            Enable_IOMMU_modules "${switch}" "$[currentProgress+3]"
            update_initramfs "$[currentProgress+5]"
            update_pciids "$[currentProgress+6]"
            ;;
        iommu_gpu)
            # 开启 IOMMU+核显直通
            grub_arg="$grub_default_iommu_gpu"
            mod_grub "${grub_arg}" "$[currentProgress+1]"
            mod_kernel_cmdline "$kernel_cmdline_iommu"

            Enable_IOMMU_modules "${switch}" "$[currentProgress+3]"
            update_initramfs "$[currentProgress+6]"
            update_pciids "$[currentProgress+7]"
            ;;
        off)
            # 恢复非直通状态, 关闭 IOMMU
            grub_arg="$grub_default"
            mod_grub "${grub_arg}" "$[currentProgress+1]"
            mod_kernel_cmdline "$kernel_cmdline_default"

            Disable_IOMMU_modules "$[currentProgress+3]"
            Disable_gpu_sr_iov_modules
            update_initramfs "$[currentProgress+5]"
            ;;
    esac
}

# 添加 sysfs 模块
Enable_gpu_sr_iov_modules() {
    local currentProgress="$1"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 设置最大虚拟 GPU 数量"
    while :
    do
        local num=""
        read -r -p '设置最大虚拟 GPU 数量 (输入正整数 | Enter - 最大 7 个): ' choose
        if [ -z "${choose}" ]; then
            num="7"
            break
        elif [[ ${choose} -gt 0 ]]; then
            num="${choose}"
            break
        else
            echo " ---> 输入错误, 请重新输入"
        fi
    done

    if [ -n "${num}" ]; then
        # 安装 sysfsutils
        install_software 'systool' 'sysfsutils'

        # 写入 sysfs.conf 配置文件
        echo "devices/pci0000:00/${iGPU_adr}/sriov_numvfs = $num" > /etc/sysfs.conf
        echoContent green " ---> sysfs 配置文件修改完成"
    fi
}

# 禁用 sysfs 模块
Disable_gpu_sr_iov_modules() {
    if [ -f '/etc/sysfs.conf' ]; then
        if [ `grep -c "${iGPU_adr}" "/etc/sysfs.conf"` -ne '0' ]; then
            sed -i "/$iGPU_adr/d" /etc/sysfs.conf
            echoContent green " ---> 已清除 sysfs 配置"
        fi
    fi
}

# 设置 Intel 核显 SR-IOV
pve_intel_gpu_sr_iov_switch() {
    local switch="$1"
    local totalProgress="$2"
    local currentProgress="$3"

    if [ $cpu_manufacturer = "intel" ]; then
        echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 配置 Intel 核显 SR-IOV"
        case ${switch} in
            on)
                grub_arg="$grub_default_sr_iov"
                mod_grub "${grub_arg}" "$[currentProgress+1]"

                Enable_gpu_sr_iov_modules "$[currentProgress+3]"
                Disable_IOMMU_modules "$[currentProgress+4]"
                update_initramfs "$[currentProgress+6]"
                update_pciids "$[currentProgress+7]"
                update_intel_gpu_firmware "$[currentProgress+8]"
                ;;
            off)
                grub_arg="$(grub_default_cur | sed 's|.*"\(.*\)".*|\1|; s|[ ]\?i915.enable_guc[^ ]\+[ ]\?||; s|[ ]\?i915.max_vfs[^ ]\+[ ]\?||')"
                mod_grub "${grub_arg}" "$[currentProgress+1]"

                Disable_gpu_sr_iov_modules
                update_initramfs "$[currentProgress+3]"
                ;;
        esac
    else
        echo -e "不支持的 CPU 平台, 正在终止运行......"
        sleep 5
        case_read '主菜单' 'pve_source' 'menu'
    fi
}

# PVE 直通向导初始化
pve_Passthough_initial() {
    # 虚拟机节点
    vm_list=`qm list | grep -v VMID | awk '{print $1,$2}' | awk '{printf("%d、%s\n",NR,$0)}'`

    # 核显及核显音频的相关参数
    gpu_audio_device=`lspci -nn | grep -E 'VGA compatible controller|Audio device' | awk '{printf("%d、0000:%s\n",NR,$0)}'`
    gpu_audio_device_num=`echo "${gpu_audio_device}" | wc -l`
    gpu_audio_list=`echo "${gpu_audio_device}" | sed -e '/VGA compatible controller/i # 核心显卡' -e '/Audio device/i # 核心音频'`
    gpu_device=`lspci -nn | grep -E 'VGA compatible controller' | awk '{printf("%d、0000:%s\n",NR,$0)}'`
    gpu_list=`echo "${gpu_device}" | sed '/VGA compatible controller/i # 核心显卡'`
    audio_device=`lspci -nn | grep -E 'Audio device' | head -n 1 | awk '{printf("%d、0000:%s\n",NR,$0)}'`
    audio_list=`echo "${audio_device}" | sed '/Audio device/i # 核心音频'`

    # 识别 CPU 平台
    intel_cpu_gen=""
    cpu_platform="$(lscpu | grep 'Model name' | grep -E 'Intel|AMD')"
    case $cpu_platform in
        *Intel*)
            cpu_manufacturer="intel"
            ;;
        *AMD*)
            cpu_manufacturer="amd"
            ;;
        *)
            cpu_manufacturer="unsupported"
            echo -e "不支持的 CPU 平台, 正在终止运行......"
            sleep 5
            case_read '主菜单' 'pve_source' 'menu'
            ;;
    esac
}

# PVE 选择节点
pve_Node() {
    local totalProgress="$1"
    local currentProgress="$2"

    while :
    do
        echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 选择 PVE 虚拟机节点"
        echoContent red "=============================================================="
        echoContent yellow "${vm_list}"
        echoContent red "=============================================================="

        read -r -p "请选择虚拟机节点: " pve_NodeChoose
        vmid=$(echo "$vm_list" | grep "^${pve_NodeChoose}" | sed -E "s/^${pve_NodeChoose}、([^ ]*).*/\1/")
        if [ -n "$vmid" ]; then
            echoContent green " ---> 虚拟机节点：${vmid}"
            break
        else
            echoContent red " ---> 虚拟机节点选择错误, 请重新输入"
        fi
    done
}

# PVE 选择核心显卡
pve_iGPU() {
    local totalProgress="$1"
    local currentProgress="$2"

    while :
    do
        echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 选择核心显卡"
        echoContent red "\n=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "1、Intel J4125 核显直通需要针对核心显卡配置扩展参数, 本步骤应跳过"
        echoContent yellow "2、AMD Ryzen 7 及其他 Intel 等设备本步骤必须选中\n"

        echoContent red "=============================================================="
        echoContent yellow "${gpu_list}"
        echoContent red "=============================================================="

        read -r -p "请选择序号 (输入 skip 跳过) : " pve_iGPUChoose
        case ${pve_iGPUChoose} in
            skip)
                iGPU_adr=""
                echoContent green " ---> 跳过"
                break
                ;;
            *)
                if [ -n "${pve_iGPUChoose}" ]; then
                    iGPU_adr="$(echo "${gpu_list}" | grep "^${pve_iGPUChoose}" | sed -E "s/^${pve_iGPUChoose}.([^ ]*).*/\1/")"
                    echoContent green " ---> 设备总线：${iGPU_adr}"
                    break
                else
                    echoContent red " ---> 序号选择错误, 请重新输入"
                fi
                ;;
        esac
    done
}

# PVE 选择核心音频
pve_iAudio() {
    local totalProgress="$1"
    local currentProgress="$2"

    while :
    do
        echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 选择核心音频"
        echoContent red "=============================================================="
        echoContent yellow "${audio_list}"
        echoContent red "=============================================================="

        read -r -p "请选择序号 (输入 skip 跳过) : " pve_iAudioChoose
        case ${pve_iAudioChoose} in
            skip)
                iAudio_adr=""
                echoContent green " ---> 跳过"
                break
                ;;
            *)
                if [ -n "${pve_iAudioChoose}" ]; then
                    iAudio_adr="$(echo "${audio_list}" | grep "^${pve_iAudioChoose}" | sed -E "s/^${pve_iAudioChoose}.([^ ]*).*/\1/")"
                    echoContent green " ---> 设备总线：${iAudio_adr}"
                    break
                else
                    echoContent red " ---> 序号选择错误, 请重新输入"
                fi
                ;;
        esac
    done
}

# PVE 选择 vbios
pve_vbios() {
    local totalProgress="$1"
    local currentProgress="$2"
    local rom_path_name="$3"
    local rom_path_name_fullname="$4"
    local original_path="$5"

    romfile[$rom_path_name]=""

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : ${rom_path_name} 文件路径"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "1、手动输入 ${rom_path_name} 文件的绝对路径, 例如：/root/${rom_path_name_fullname}"
    echoContent yellow "2、如果 ${rom_path_name} 文件已经存在于 ${original_path}, 只需输入 ${rom_path_name} 完整文件名称"
    echoContent red "\n=============================================================="

    while :
    do
        read -r -p "请输入 (输入 skip 跳过) : " pve_vBiosEnter
        case ${pve_vBiosEnter} in
            skip)
                romfile[$rom_path_name]=""
                echoContent green " ---> 跳过"
                break
                ;;
            *)
                romfile[$rom_path_name]="${pve_vBiosEnter}"
                if [[ "${romfile[$rom_path_name]}" =~ "/" && -f "${romfile[$rom_path_name]}" && `version_lt ${proxmox_main_ver} '8.0.9'` ]]; then
                    echoContent green " ---> ${rom_path_name} 文件路径：${romfile[$rom_path_name]}"
                    break
                elif [[ -f "${original_path}/${romfile[$rom_path_name]}" ]]; then
                    echoContent green " ---> ${rom_path_name} 文件名称：${romfile[$rom_path_name]}"
                    break
                else
                    echoContent red " ---> ${rom_path_name} 文件路径输入有误, 请重新输入"
                fi
                ;;
        esac
    done
}

hostpci0_hostpci1_args() {
    local hostpci0_hostpci1_delete_type="$1"
    local vga_args="$2"
    local x_vga_args="$3"
    local rom1_args="$4"
    local rom2_args="$5"

    if [[ -n "${iGPU_adr}" ]]; then
        hostpci0="$iGPU_adr${vga_args}${x_vga_args}${rom1_args}"
    else
        hostpci0=""
    fi

    if [[ -n "${iAudio_adr}" ]]; then
        hostpci1="$iAudio_adr${rom2_args}"
    else
        hostpci1=""
    fi

    case $hostpci0_hostpci1_delete_type in
        0)
            hostpci0="-delete hostpci0"
            ;;
        1)
            hostpci1="-delete hostpci1"
            ;;
        all)
            hostpci0="-delete hostpci0"
            hostpci1="-delete hostpci1"
            ;;
    esac
}

# PVE 核心显卡直通向导
pve_GPU_Passthough_SR_IOV_Option() {
    for i in args bios machine vga hostpci0 hostpci1; do
        local $i=""
    done

    pve_Passthough_initial

    if [ $cpu_manufacturer = "intel" ]; then
        cpu="host"
    elif [ $cpu_manufacturer = "amd" ]; then
        cpu="host,hidden=1"
    fi

    declare -A romfile

    while :
    do
        echoContent skyBlue "\n功能 1/1 : 选择核显直通或 SR-IOV 方案"
        echoContent red "=============================================================="
        echoContent yellow "1、SR-IOV 方案                            # 适用于 Intel 的 11 代及以后核显 SR-IOV"
        echoContent yellow "2、无 vbios 方案                          # 适用于早期核显简单直通"
        echoContent yellow "3、单 vbios 方案                          # 适用于 J4125"
        echoContent yellow "4、单 vbios 方案                          # 适用于 AMD 5000 及 Intel 早期的核显"
        echoContent yellow "5、OVMF + vbios 方案                      # 适用于 AMD 及 Intel 的 11 代及以后核显"
        echoContent yellow "6、idg(或 vbios) + gop 方案               # 适用于 AMD 及 Intel 的 11 代及以后核显"
        echoContent yellow "7、idg(或 vbios) + gop 合成单 rom 文件方案 # 适用于 AMD 及 Intel 的 11 代及以后核显"
        echoContent yellow "8、自定义方案"
        echoContent yellow "0、返回"
        echoContent red "=============================================================="

        read -r -p "请选择虚拟机节点:  (输入 skip 跳过) " pve_GPU_Passthough_SR_IOV_Option_Choose
        case $pve_GPU_Passthough_SR_IOV_Option_Choose in
            1)
                pve_Node 3 1
                pve_iGPU 3 2
                pve_iAudio 3 3
                bios="ovmf"
                vga="none"
                args="-delete args"
                hostpci0_hostpci1_args '' '' ',x-vga=1'
                break
                ;;
            2)
                pve_Node 4 1
                pve_iGPU 4 2
                pve_iAudio 4 3
                pve_vbios 4 4 'vbios' 'vbios.bin' '/usr/share/kvm'
                hostpci0_hostpci1_args '' ',pcie=1' '' ",romfile=${romfile[vbios]}"
                break
                ;;
            3)
                pve_Node 4 1
                pve_iGPU 4 2
                pve_iAudio 4 3
                pve_vbios 4 4 'vbios' 'vbios.bin' '/usr/share/kvm'
                if [[ -n "${romfile[vbios]}" ]]; then
                    romfile_args=",romfile=${romfile[vbios]}"
                fi
                args='-device vfio-pci,host=00:02.0,addr=0x02,x-igd-gms=1'${romfile_args}''
                bios="seabios"
                machine="-delete machine"
                vga="none"
                hostpci0_hostpci1_args 0
                break
                ;;
            4)
                pve_Node 4 1
                pve_iGPU 4 2
                pve_iAudio 4 3
                pve_vbios 4 4 'vbios' 'vbios.bin' '/usr/share/kvm'
                bios="seabios"
                vga="none"
                args="-delete args"
                machine="q35"
                hostpci0_hostpci1_args '' ',pcie=1' ',x-vga=1' ",romfile=${romfile[vbios]}"
                break
                ;;
            5)
                pve_Node 5 1
                pve_iGPU 5 2
                pve_iAudio 5 3
                pve_vbios 5 4 'vbios' 'vbios.bin' '/usr/share/kvm'
                pve_vbios 5 5 'OVMF' 'OVMF_CODE.fd' '/usr/share/kvm'
                if [ $cpu_manufacturer = "intel" ]; then
                    if [[ -n "${romfile[OVMF]}" ]]; then
                        romfile_OVMF_args="-bios ${romfile[OVMF]} "
                    fi
                    args=''${romfile_OVMF_args}'-set device.hostpci0.addr=02.0 -set device.hostpci0.x-igd-gms=1 -set device.hostpci0.x-igd-opregion=on'
                    bios="-delete bios"
                    machine="-delete machine"
                    hostpci0_hostpci1_args '' ',legacy-igd=1' '' ",romfile=${romfile[vbios]}"
                elif [ $cpu_manufacturer = "amd" ]; then
                    if [[ -n "${romfile[OVMF]}" ]]; then
                        args='-bios '${romfile[OVMF]}''
                    else
                        args="-delete args"
                    fi
                    bios="ovmf"
                    machine="q35"
                    hostpci0_hostpci1_args '' ',pcie=1' ',x-vga=1' ",romfile=${romfile[vbios]}"
                fi
                vga="none"
                break
                ;;
            6)
                pve_Node 5 1
                pve_iGPU 5 2
                pve_iAudio 5 3
                pve_vbios 5 4 'igd' 'igd.rom' '/usr/share/kvm'
                pve_vbios 5 5 'Gop' 'Gop.rom' '/usr/share/kvm'
                if [ $cpu_manufacturer = "intel" ]; then
                    args='-set device.hostpci0.addr=02.0 -set device.hostpci0.x-igd-gms=0x2 -set device.hostpci0.x-igd-opregion=on'
                    machine="-delete machine"
                    hostpci0_hostpci1_args '' ',legacy-igd=1' '' ",romfile=${romfile[igd]}" ",romfile=${romfile[Gop]}"
                elif [ $cpu_manufacturer = "amd" ]; then
                    args=''
                    machine="q35"
                    hostpci0_hostpci1_args '' ',pcie=1' '' ",romfile=${romfile[igd]}" ",romfile=${romfile[Gop]}"
                fi
                bios="ovmf"
                vga="none"
                break
                ;;
            7)
                pve_Node 4 1
                pve_iGPU 4 2
                pve_iAudio 4 3
                pve_vbios 4 4 'rom' 'vbios.rom' '/usr/share/kvm'
                if [ $cpu_manufacturer = "intel" ]; then
                    args='-set device.hostpci0.addr=02.0 -set device.hostpci0.x-igd-gms=0x2 -set device.hostpci0.x-igd-opregion=on'
                    machine="-delete machine"
                    hostpci0_hostpci1_args '' ',legacy-igd=1' '' ",romfile=${romfile[rom]}"
                elif [ $cpu_manufacturer = "amd" ]; then
                    args=''
                    machine="q35"
                    hostpci0_hostpci1_args '' ',pcie=1' '' ",romfile=${romfile[rom]}"
                fi
                bios="ovmf"
                vga="none"
                break
                ;;
            8)
                pve_Node 6 1
                pve_iGPU 6 2
                pve_iAudio 6 3
                pve_BIOS 6 4
                pve_QEMU 6 5
                pve_Disport 6 6
                hostpci0_hostpci1_args
                break
                ;;
            0)
                pve_IOMMU_menu
                break
                ;;
            *)
                echoContent red " ---> 选择错误, 请重新输入"
                ;;
        esac
    done

    for i in cpu bios vga machine hostpci0 hostpci1; do
        if [[ "$(eval echo \$$i)" = "-delete $i" && `qm config $vmid | grep -Ec "^$i"` -ne '0' ]]; then
            eval ${i}_config='$(eval echo -delete $i)'
        elif [[ -n "$(eval echo \$$i)" && "$(eval echo \$$i)" != "-delete $i" ]]; then
            eval ${i}_config='$(eval echo -$i \$$i)'
        else
            eval ${i}_config=''
        fi
    done

    if [[ ${cpu_config} || ${bios_config} || ${vga_config} || ${machine_config} || ${hostpci0_config} || ${hostpci1_config} ]]; then
        qm set $vmid ${cpu_config} ${bios_config} ${vga_config} ${machine_config} ${hostpci0_config} ${hostpci1_config}
        echoContent green " ---> 虚拟机直通配置完成"
    fi

    if [[ ${args} = "-delete args" && `qm config $vmid | grep -Ec "^args"` -ne '0' ]]; then
        qm set $vmid -delete args
        echoContent green " ---> 虚拟机 ${vmid} 配置扩展参数设置完成"
    elif [[ -n ${args} && ${args} != "-delete args" ]]; then
        qm set $vmid -args "${args}"
        echoContent green " ---> 虚拟机 ${vmid} 配置扩展参数设置完成"
    fi
}

# 其他功能
pve_BIOS() {
    local totalProgress="$1"
    local currentProgress="$2"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : BIOS 类型"
    echoContent red "\n=============================================================="
    echoContent yellow "1、SeaBIOS (Legacy)"
    echoContent yellow "2、OVMF (UEFI)"
    echoContent yellow "3、跳过"
    echoContent red "=============================================================="
    while :
    do
        read -r -p "请选择序号 : " pve_BiosChoose
        case ${pve_BiosChoose} in
            1)
                bios="seabios"
                echoContent green " ---> BIOS 类型：${bios}"
                break
                ;;
            2)
                bios="ovmf"
                echoContent green " ---> BIOS 类型：${bios}"
                break
                ;;
            3)
                bios=""
                echoContent green " ---> 跳过"
                break
                ;;
            *)
                echoContent red " ---> 序号选择错误, 请重新输入"
                ;;
        esac
    done
}

# 设置 PVE QEMU 计算机类型
pve_QEMU() {
    local totalProgress="$1"
    local currentProgress="$2"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : QEMU 计算机类型"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "1、使用 vbios 直通核显输出到显示器, Intel 11 代及以上通常选择 i440fx"
    echoContent yellow "2、使用 vbios 直通核显 SR-IOV, Intel 11 代及以上通常选择 q35"
    echoContent red "\n=============================================================="
    echoContent yellow "1、q35"
    echoContent yellow "2、i440fx"
    echoContent yellow "3、跳过"
    echoContent red "=============================================================="
    while :
    do
        read -r -p "请选择 : " pve_MachineChoose
        case ${pve_MachineChoose} in
            1)
                machine="q35"
                echoContent green " ---> QEMU 计算机类型：q35"
                break
                ;;
            2)
                machine="pc"
                echoContent green " ---> QEMU 计算机类型：i440fx"
                break
                ;;
            3)
                machine=""
                echoContent green " ---> 跳过"
                break
                ;;
            *)
                echoContent red " ---> QEMU 计算机类型选择错误, 请重新输入"
                ;;
        esac
    done
}

# 设置 PVE 显示设备
pve_Disport() {
    local totalProgress="$1"
    local currentProgress="$2"

    echoContent skyBlue "\n进度 ${currentProgress}/${totalProgress} : 显示设备"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "1、使用 vbios 直通核显输出到显示器, 通常需要禁用虚拟机显示设备\n"
    echoContent red "\n=============================================================="
    echoContent yellow "1、禁用"
    echoContent yellow "2、SPCIE"
    echoContent yellow "3、VirtIO-GPU"
    echoContent yellow "4、跳过"
    echoContent red "=============================================================="
    while :
    do
        read -r -p "请选择 : " pve_VGAChoose
        case ${pve_VGAChoose} in
            1)
                vga="none"
                echoContent green " ---> 虚拟机显示设备：禁用"
                break
                ;;
            2)
                vga="qxl"
                echoContent green " ---> 虚拟机显示设备：SPCIE"
                break
                ;;
            3)
                vga="virtio"
                echoContent green " ---> 虚拟机显示设备：VirtIO-GPU"
                break
                ;;
            4)
                vga=""
                echoContent green " ---> 跳过"
                break
                ;;
            *)
                echoContent red " ---> 虚拟机显示设备选择错误, 请重新输入"
                ;;
        esac
    done
}

# 配置虚拟机扩展参数
pve_args() {
    # 虚拟机节点
    vm_list=`qm list | grep -v VMID | awk '{print $1,$2}' | awk '{printf("%d.\t%s\n",NR,$0)}'`
    while :
    do
        echoContent skyBlue "\n功能 1/${totalProgress} : 配置虚拟机扩展参数"
        echoContent red "\n=============================================================="
        echoContent skyBlue "\n进度 1/${totalProgress} : 选择 PVE 虚拟机节点"
        echoContent red "=============================================================="
        echoContent yellow "${vm_list}"
        echoContent red "=============================================================="

        read -r -p "请选择虚拟机节点 : " pve_NodeChoose
        vmid=$(echo "$vm_list" | grep "^${pve_NodeChoose}" | sed -E "s/^${pve_NodeChoose}.([^ ]*).*/\1/")
        if [ -n "$vmid" ]; then
            echoContent green " ---> 虚拟机节点：${vmid}"
            break
        else
            echoContent red " ---> 虚拟机节点选择错误, 请重新输入"
        fi
    done

    while :
    do
        echoContent skyBlue "\n进度 2/${totalProgress} : 输入虚拟机配置扩展参数"
        read -r -p "请输入虚拟机配置扩展参数 (输入 skip 跳过) : " pve_argsEnter
        case ${pve_argsEnter} in
            skip)
                args=""
                echoContent green " ---> 跳过"
                break
                ;;
            *)
                args="${pve_argsEnter}"
                qm set $vmid -args "$args"
                echoContent green " ---> 虚拟机 ${vmid} 配置扩展参数设置完成"
                break
                ;;
        esac
    done
}

#配置群晖虚拟 USB 引导扩展参数
pve_Synology() {
    # 虚拟机节点
    vm_list=`qm list | grep -v VMID | awk '{print $1,$2}' | awk '{printf("%d.\t%s\n",NR,$0)}'`

    while :
    do
        echoContent skyBlue "\n功能 1/${totalProgress} : 选择 PVE 虚拟群晖节点"
        echoContent red "=============================================================="
        echoContent yellow "${vm_list}"
        echoContent red "=============================================================="

        read -r -p "请选择虚拟机节点 : " pve_SynologyChoose
        vmid=$(echo "$vm_list" | grep "^${pve_SynologyChoose}" | sed -E "s/^${pve_SynologyChoose}.([^ ]*).*/\1/")
        if [ -n "$vmid" ]; then
            echoContent green " ---> 虚拟机节点：${vmid}"
            break
        else
            echoContent red " ---> 虚拟机节点选择错误, 请重新输入"
        fi
    done

    echoContent skyBlue "\n进度 2/${totalProgress} : 群晖引导文件(img)路径"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "1、手动输入 img 文件的绝对路径, 例如：/var/lib/vz/template/iso/DS918_7.x.img"
    echoContent yellow "2、如果 img 文件已经存在于 /root/Synology.img, 只需输入 Synology.img 文件名称"
    echoContent yellow "3、设置完成后请自行删除此前已导入引导的虚拟磁盘或取消虚拟磁盘的引导选项\n"

    echoContent red "=============================================================="
    while :
    do
        read -r -p "请输入 (输入 skip 跳过) : " pve_imgEnter
        case ${pve_imgEnter} in
            skip)
                imgfile=""
                echoContent green " ---> 跳过"
                break
                ;;
            *)
                imgfile="${pve_imgEnter}"
                if [[ "${imgfile}" =~ "/" && -f "${imgfile}" ]]; then
                    echoContent green " ---> img 文件路径：${imgfile}"
                    break
                elif [[ -f "/root/${imgfile}" ]]; then
                    echoContent green " ---> img 文件名称：${imgfile}"
                    break
                else
                    echoContent red " ---> img 文件路径输入有误, 请重新输入"
                fi
                ;;
        esac
    done

    if [[ -n "${imgfile}" ]]; then
        args="-device 'qemu-xhci,addr=0x18' -drive 'id=synoboot,file=${imgfile},if=none,format=raw' -device 'usb-storage,id=synoboot,drive=synoboot,bootindex=1'"
        qm set $vmid -args "$args"
        echoContent green " ---> 虚拟机 ${vmid} 配置扩展参数设置完成"
    fi
}

# PVE IOMMU 选项菜单
pve_IOMMU_menu() {
    while :
    do
        echoContent skyBlue "\n功能 1/${totalProgress} : PVE 直通设置"
        echoContent red "=============================================================="
        echoContent skyBlue "----------------------PVE  系统直通配置-----------------------"
        echoContent yellow "1、开启 IOMMU"
        echoContent yellow "2、开启 IOMMU 及核显直通"
        echoContent yellow "3、开启 Intel 核显 SR-IOV"
        echoContent yellow "  注：1、仅支持 Intel 部分 CPU"
        echoContent yellow "      2、需 6.1 及以上版本内核"
        echoContent yellow "      3、需配合 i915-sriov-dkms 驱动启用"
        echoContent yellow "4、关闭 Intel 核显 SR-IOV"
        echoContent yellow "5、恢复默认"
        echoContent skyBlue "----------------------PVE 虚拟机直通配置----------------------"
        echoContent yellow "6、虚拟机核显直通或 SR-IOV 向导"
        echoContent yellow "7、虚拟机扩展参数配置"
        echoContent yellow "8、群晖虚拟 USB 引导扩展参数配置"
        echoContent yellow "0、返回"
        echoContent red "=============================================================="

        read -r -p "请选择 : " pve_IOMMUChoose
        case ${pve_IOMMUChoose} in
            1)
                # 开启 IOMMU
                pve_IOMMU_initial
                pve_IOMMU_switch iommu 7 1
                echoContent green " ---> 开启 IOMMU 设置完毕, 重启系统后生效" && ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
                break
                ;;
            2)
                # 开启 IOMMU 及核显直通
                pve_IOMMU_initial
                pve_IOMMU_switch iommu_gpu 8 1
                echoContent green " ---> 开启 IOMMU 及核显直通设置完毕, 重启系统后生效" && ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
                break
                ;;
            3)
                # 开启 Intel 核显 SR-IOV
                pve_IOMMU_initial
                pve_intel_gpu_sr_iov_switch on 10 1
                echoContent green " ---> 开启 Intel 核显 SR-IOV 设置完毕, 重启系统后生效" && ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
                break
                ;;
            4)
                # 关闭 Intel 核显 SR-IOV
                pve_intel_gpu_sr_iov_switch off 3 1
                echoContent green " ---> 关闭 Intel 核显 SR-IOV 设置完毕, 重启系统后生效" && ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
                break
                ;;
            5)
                # 恢复非直通状态, 关闭 IOMMU
                pve_IOMMU_switch off 6 1
                echoContent green " ---> 关闭 IOMMU 设置完毕, 重启系统后生效" && ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
                break
                ;;
            6)
                pve_GPU_Passthough_SR_IOV_Option
                case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            7)
                totalProgress=2
                pve_args
                case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            8)
                totalProgress=2
                pve_Synology
                case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            0)
                ./pve_source menu
                break
                ;;
            *)
                echoContent red " ---> 选择错误"
                ;;
        esac
    done
}

# 切换 PVE CPU 电源管理 P-State 状态
pve_pstate_switch() {
    local switch="$1"
    local totalProgress="$2"
    local currentProgress="$3"
    local grub_array=()
    grub_array=(`grub_default_cur`)

    # 切换 PVE CPU 电源管理 P-State 状态的 grub 参数
    if [[ "${grub_array[@]}" =~ ''$cpu_manufacturer'_pstate' ]]; then
        for i in ${!grub_array[@]}; do
            if [[ "${grub_array[i]}" =~ ""$cpu_manufacturer"_pstate" && "${grub_array[i]}" != ""$cpu_manufacturer"_pstate="$switch"" ]]; then
                if [[ "$switch" = "active" ]];then
                    unset grub_array[i]
                else
                    eval grub_array[i]=''$cpu_manufacturer'_pstate='$switch''
                fi
            fi
        done
    else
        if [[ "$switch" = "passive" || "$switch" = "off" ]];then
            grub_array=("${grub_array[@]:0:1}" ""$cpu_manufacturer"_pstate="$switch"" "${grub_array[@]:1}")
        fi
    fi

    # 切换 PVE CPU 电源管理 P-State 状态的 kernel_cmdline 参数
    kernel_cmdline_pstate="root=ZFS=rpool/ROOT/pve-1 boot=zfs ${grub_array[@]}"

    # 切换 PVE CPU 电源管理 P-State 状态
    grub_arg="${grub_array[@]}"
    mod_grub "${grub_arg}" "$[currentProgress+1]"
    mod_kernel_cmdline "$kernel_cmdline_pstate"
}

# PVE CPU 电源管理 P-State 状态菜单
pve_pstate_menu() {
    pve_Passthough_initial
    while :
    do
        echoContent skyBlue "\n功能 1/${totalProgress} : PVE CPU 电源管理 P-State 状态"
        echoContent red "=============================================================="
        echoContent yellow "1、切换 Passive 消极模式"
        echoContent yellow "2、切换 Off 关闭模式"
        echoContent yellow "3、切换 Active 活动模式(还原默认)"
        echoContent yellow "0、返回"
        echoContent red "\n=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "1、非必要请勿轻易使用本功能；"
        echoContent yellow "2、AMD 平台 Linux 6.x 内核切换 Passive"
        echoContent yellow "    ①解锁低频下限、消除频率限制无效"
        echoContent yellow "    ② 6.5 内核解锁更多的工作模式\n"
        echoContent red "=============================================================="

        read -r -p "请选择 : " pve_pstateChoose
        case ${pve_pstateChoose} in
            1)
                # 切换 Passive
                pve_pstate_switch passive 3 1
                echoContent green " ---> 切换 P-State - Passive 消极模式完毕, 重启系统后生效" && ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
                break
                ;;
            2)
                # 切换 Off
                pve_pstate_switch off 3 1
                echoContent green " ---> 切换 P-State - Off 关闭模式完毕, 重启系统后生效" && ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
                break
                ;;
            3)
                # 切换 Active
                pve_pstate_switch active 3 1
                echoContent green " ---> 切换 P-State - Active 活动模式(还原默认)完毕, 重启系统后生效" && ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
                break
                ;;
            0)
                ./pve_source menu
                break
                ;;
            *)
                echoContent red " ---> 选择错误"
                ;;
        esac
    done
}

# PVE CPU 主频限制
pve_cpufreq_limit() {
    CPUFreqMin_ori=$(lscpu | grep 'min MHz' | awk '{print $NF}')
    CPUFreqMax_ori=$(lscpu | grep 'max MHz' | awk '{print $NF}')
    CPUFreqMin=$(lscpu | grep 'min MHz' | awk '{print $NF}' | awk -F. '{print $1}')
    CPUFreqMax=$(lscpu | grep 'max MHz' | awk '{print $NF}' | awk -F. '{print $1}')
    if [ ${cpu_mode} ]; then
        cur_cpumode="${cpu_mode}"
    else
        cur_cpumode=`check_mode`
    fi
    if [[ ${cur_cpumode} = schedutil || ${cur_cpumode} = powersave ]]; then
        if [ ${cur_cpumode} = schedutil ]; then
            echoContent green " ---> schedutil\t\t调度模式不支持主频限制"
        elif [ ${cur_cpumode} = powersave ]; then
            echoContent green " ---> powersave\t\t节能模式不支持主频限制"
        fi
        CPUFreqLimitdown="${CPUFreqMin_ori}"
        CPUFreqLimitup="${CPUFreqMax_ori}"
        echoContent green " ---> 最低主频：${CPUFreqLimitdown}Mhz"
        echoContent green " ---> 最高主频：${CPUFreqLimitup}Mhz"
    else
        while :
        do
            read -r -p "是否设置 CPU 主频限制 (Y/y-设置 | N/n-恢复默认 | 键入 Enter-保持现状)？ : " pve_CPUFreqLimitask
            case ${pve_CPUFreqLimitask} in
                [Yy])
                    while :
                    do
                        read -r -p "请输入最低主频 (设置区间：[${CPUFreqMin_ori}, ${CPUFreqMax_ori}]Mhz。键入 Enter 跳过设置)？ : " pve_CPUFreqLimitdown
                        if [ -z ${pve_CPUFreqLimitdown} ]; then
                            CPUFreqLimitdown=$(lscpu | grep 'min MHz' | awk '{print $NF}')
                            break
                        else
                            VALID_CHECK=$(echo ${pve_CPUFreqLimitdown}|awk -F. '$1>='${CPUFreqMin}'&&$1<='${CPUFreqMax}'{print "yes"}')
                            if echo ${pve_CPUFreqLimitdown}|grep -E "^[0-9]+\.?[0-9]*$">/dev/null; then
                                if [ ${VALID_CHECK:-no} == "yes" ]; then
                                    CPUFreqLimitdown="${pve_CPUFreqLimitdown}"
                                    break
                                else
                                    echoContent red " ---> CPU 最低主频设置区间错误, 请重新输入"
                                fi
                            else
                                echoContent red " ---> CPU 最低主频设置错误, 请重新输入"
                            fi
                        fi
                    done
                    while :
                    do
                        read -r -p "请输入最高主频 (设置区间：[${CPUFreqMin_ori}, ${CPUFreqMax_ori}]Mhz。键入 Enter 跳过设置)？ : " pve_CPUFreqLimitup
                        if [ -z ${pve_CPUFreqLimitup} ]; then
                            CPUFreqLimitup=$(lscpu | grep 'max MHz' | awk '{print $NF}')
                            break
                        else
                            VALID_CHECK=$(echo ${pve_CPUFreqLimitup}|awk -F. '$1>='${CPUFreqMin}'&&$1<='${CPUFreqMax}'{print "yes"}')
                            if echo ${pve_CPUFreqLimitup}|grep -E "^[0-9]+\.?[0-9]*$">/dev/null; then
                                if [ ${VALID_CHECK:-no} == "yes" ]; then
                                    CPUFreqLimitup="${pve_CPUFreqLimitup}"
                                    break
                                else
                                    echoContent red " ---> CPU 最低主频设置区间错误, 请重新输入"
                                fi
                            else
                                echoContent red " ---> CPU 最高主频设置错误, 请重新输入"
                            fi
                        fi
                    done

                    if [[ -n ${CPUFreqLimitdown} && -n ${CPUFreqLimitup} ]]; then
                        if [ "${CPUFreqLimitdown}" = "${CPUFreqLimitup}" ]; then
                            echoContent green " ---> CPU 锁定主频：${CPUFreqLimitdown}Mhz"
                        else
                            if version_gt ${CPUFreqLimitdown} ${CPUFreqLimitup}; then
                                CPUFreqLimitdown="${pve_CPUFreqLimitup}"
                                CPUFreqLimitup="${pve_CPUFreqLimitdown}"
                            fi
                            echoContent green " ---> 最低主频：${CPUFreqLimitdown}Mhz"
                            echoContent green " ---> 最高主频：${CPUFreqLimitup}Mhz"
                        fi
                    fi
                    break
                    ;;
                [Nn])
                    CPUFreqLimitdown=${CPUFreqMin_ori}
                    CPUFreqLimitup=${CPUFreqMax_ori}
                    echoContent green " ---> 最低主频：${CPUFreqLimitdown}Mhz"
                    echoContent green " ---> 最高主频：${CPUFreqLimitup}Mhz"
                    break
                    ;;
                *)
                    CPUFreqLimitdown=`CPU_scaling_min_freq`
                    CPUFreqLimitup=`CPU_scaling_max_freq`
                    break
                    ;;
            esac
        done
    fi

    content="GOVERNOR=${cur_cpumode}\nMIN_SPEED=${CPUFreqLimitdown}Mhz\nMAX_SPEED=${CPUFreqLimitup}Mhz"
    echo -e "$content" > /etc/default/cpufrequtils
    systemctl restart cpufrequtils
}

# PVE CPU 工作模式设置
pve_cpumode_menu() {
    check_mode() {
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    }

    check_mode_display() {
        check_mode | sed 's/ /\n/g; s/conservative/&\t保守模式/g; s/ondemand/&\t按需模式/g; s/userspace/&\t用户隔离模式/g; s/powersave/&\t节能模式/g; s/performance/&\t性能模式/g; s/schedutil/&\t调度模式/g;'
    }

    local conf="/etc/default/cpufrequtils"
    local code='GOVERNOR='
    local cpu_avaliable_modes_array=($(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors))
    local cpu_avaliable_modes_list="$(echo "${cpu_avaliable_modes_array[@]}" | sed 's/ /\n/g; s/conservative/&\t保守模式/g; s/ondemand/&\t按需模式/g; s/userspace/&\t用户隔离模式/g; s/powersave/&\t节能模式/g; s/performance/&\t性能模式/g; s/schedutil/&\t调度模式/g;' | awk '{printf("%d、%s\n",NR,$0)}')"
    local content

    CPU_scaling_min_freq() {
        awk -v x=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq | awk '{print $NF}') -v y=1000 'BEGIN{printf "%.3f\n",x / y}'
    }

    CPU_scaling_max_freq() {
        awk -v x=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq | awk '{print $NF}') -v y=1000 'BEGIN{printf "%.3f\n",x / y}'
    }

    while :
    do
        echoContent skyBlue "\n功能 1/${totalProgress} : 配置 PVE CPU 工作模式"
        echoContent red "=============================================================="
        echoContent skyBlue "------------------本系统支持的 CPU 工作模式-------------------"
        echoContent yellow "${cpu_avaliable_modes_list}"
        echoContent yellow "S、设置 CPU 主频限制"
        echoContent yellow "0、返回"
        echoContent skyBlue "----------------------当前 CPU 工作模式----------------------"
        echoContent yellow "`check_mode_display`"
        echoContent skyBlue "----------------------当前 CPU 主频区间----------------------"
        echoContent yellow "最低频率：\t`CPU_scaling_min_freq`Mhz"
        echoContent yellow "最高频率：\t`CPU_scaling_max_freq`Mhz"
        echoContent red "=============================================================="
        read -r -p "请选择: " pve_CPUModeChoose
        case ${pve_CPUModeChoose} in
            0)
                ./pve_source menu
                break
                ;;
            S|s)
                install_software 'cpufreq-set' 'cpufrequtils'
                if [ -n $(which cpufreq-set) ]; then
                    pve_cpufreq_limit
                fi
                case_read
                ;;
            *)
                if [ -n "${pve_CPUModeChoose}" ]; then
                    pve_CPUMode="$(echo "${cpu_avaliable_modes_list}" | grep "^${pve_CPUModeChoose}")"
                    if [ -n "${pve_CPUMode}" ]; then
                        cpu_mode="$(echo "${cpu_avaliable_modes_list}" | grep "^${pve_CPUModeChoose}" | sed -E "s/^${pve_CPUModeChoose}.([^\t]*).*/\1/")"
                        mode_display="$(echo "${cpu_mode}" | sed 's/ /\n/g; s/conservative/&\t保守模式/g; s/ondemand/&\t按需模式/g; s/userspace/&\t用户隔离模式/g; s/powersave/&\t节能模式/g; s/performance/&\t性能模式/g; s/schedutil/&\t调度模式/g;')"
                        echoContent green " ---> 设定 CPU 工作模式：${mode_display}"
                        if [ "${cpu_mode}" = `check_mode` > /dev/null 2>&1 ]; then
                            echoContent green " ---> 设定工作模式与原工作模式一致, 不作调整"
                        else
                            install_software 'cpufreq-set' 'cpufrequtils'

                            if [ -n $(which cpufreq-set) ]; then
                                pve_cpufreq_limit
                                echoContent green " ---> 当前 CPU 工作模式：`check_mode_display`"
                            fi
                        fi
                        case_read
                    else
                        echoContent red " ---> 选择错误"
                        case_read
                    fi
                else
                    echoContent red " ---> 选择错误"
                    case_read
                fi
                ;;
        esac
    done
}

# 设置 Proxmox 系统通过 SLAAC 获取 IPv6
# 获取网卡及 IPv6
get_vmbr_ipv6() {
    for i in $(ip addr | awk '{print $2}'| grep vmbr); do
        ip -o -6 addr show vmbr0 | grep -E "inet6 +2" | sed -e 's/^.*inet6 \+\(2[^ ]\+\)\/.*/\t'$i' \1/'
    done
}

# 查看本机的 IPv6
view_vmbr_ipv6() {
    if [ `get_vmbr_ipv6 | wc -l` -gt 0 ]; then
        echoContent green "公网 IPv6 地址：\n`get_vmbr_ipv6`"
    else
        echoContent red "未获取到公网 IPv6"
    fi
}

# 倒计时
countdown() {
    local total_time="$1"
    for i in `seq -w $total_time -1 0`; do
        echo -en "等待 \e[0;31m$i\e[0m 秒...\033[?25l\r"  
        sleep 1;
    done
    echo -en "\033[?25h\033[0m"
}

# 启用 SLAAC 获取 IPv6 配置
Enable_pve_slaac_ipv6() {
    local sysctl_array=('net.ipv6.conf.all.accept_ra' 'net.ipv6.conf.default.accept_ra' 'net.ipv6.conf.vmbr0.accept_ra' 'net.ipv6.conf.all.autoconf' 'net.ipv6.conf.default.autoconf' 'net.ipv6.conf.vmbr0.autoconf')
    local sysctl_args_array=(2 2 2 1 1 1)
    for i in ${!sysctl_array[*]}; do
        if [ `grep -c "^${sysctl_array[i]}.*" "/etc/sysctl.conf"` -ne '0' ];then
            sed -i "s|^\(${sysctl_array[i]}\).*|\1=${sysctl_args_array[i]}|g" /etc/sysctl.conf
        elif [ `grep -c "^$i$" "/etc/sysctl.conf"` -eq '0' ];then
            echo "${sysctl_array[i]}=${sysctl_args_array[i]}" >> /etc/sysctl.conf
        fi
    done
    sysctl -p > /dev/null 2>&1
    echoContent green " ---> 启用 SLAAC 获取 IPv6 配置完成"
    countdown 9
    view_vmbr_ipv6
}

# 禁用 SLAAC 获取 IPv6 配置
Disable_pve_slaac_ipv6() {
    local sysctl_array=('net.ipv6.conf.all.accept_ra' 'net.ipv6.conf.default.accept_ra' 'net.ipv6.conf.vmbr0.accept_ra' 'net.ipv6.conf.all.autoconf' 'net.ipv6.conf.default.autoconf' 'net.ipv6.conf.vmbr0.autoconf')
    for i in ${!sysctl_array[*]}; do
        if [ `grep -c "^${sysctl_array[i]}.*" "/etc/sysctl.conf"` -ne '0' ];then
            sed -i "/^\(${sysctl_array[i]}\).*/d" /etc/sysctl.conf
        fi
    done
    sysctl -p > /dev/null 2>&1
    echoContent green " ---> 禁用 SLAAC 获取 IPv6 配置完成, 重启系统后生效" && ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
    view_vmbr_ipv6
}

# 设置 Proxmox 系统通过 SLAAC 获取 IPv6
pve_slaac_ipv6_menu() {
    local ipv6_array=()

    while :
    do
        echoContent skyBlue "\n功能  1/${totalProgress} : 设置 Proxmox 系统通过 SLAAC 获取 IPv6"
        echoContent red "\n=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "1、需局域网主路由网关开启 DHCPv6 SLAAC(无状态)功能"
        echoContent yellow "2、设置完成后可能需等待数秒至数分钟才能获取公网 IPv6"
        echoContent yellow "3、查看本机 IP 地址命令: ip addr\n"
        echoContent red "=============================================================="
        echoContent yellow "1、启用 SLAAC 获取 IPv6 配置"
        echoContent yellow "2、禁用 SLAAC 获取 IPv6 配置"
        echoContent yellow "3、刷新"
        echoContent yellow "0、返回"
        echoContent red "=============================================================="
        view_vmbr_ipv6
        echoContent red "=============================================================="
        read -r -p "请选择 : " pve_slaac_ipv6_Choose
        case ${pve_slaac_ipv6_Choose} in
            1)
                Enable_pve_slaac_ipv6
                case_read
                ;;
            2)
                Disable_pve_slaac_ipv6
                case_read
                ;;
            3)
                ;;
            0)
                ./pve_source menu
                break
                ;;
            *)
                echoContent red " ---> 选择错误"
                case_read
                ;;
        esac
    done
}

# PVE 卸载内核及头文件
pve_removeotherkernel_menu() {
    kernel_running_based() {
        if [[ -n `uname -r | grep 'pve$'` ]];then
            uname -r | sed -E 's/([0-9]+.[0-9]+)[^-]+[^a-z]+(-\w+)/\1/'
        else
            uname -r | sed -E 's/([0-9]+.[0-9]+)[^-]+[^a-z]+(-\w+)/\1\2/'
        fi
    }

    kernels_headers_all() {
        kernels_headers_uninstall_suggested_array=()
        kernels_headers="$(dpkg --get-selections | grep -E "kernel|headers" | grep -Ev "kernel-helper|linux-headers|default-(kernel|headers)" | awk '{print $1}')"
        kernels_headers_array=(${kernels_headers})
        kernels_headers_list="$(echo -e "${kernels_headers}" | sed 's/'`uname -r`'$/&\t ## 当前运行, 不可卸载/g; s/'^pve-headers$'$/&\t\t\t ## 基础包, 不建议卸载/g; s/'`kernel_running_based`$'$/&\t\t ## 基础包, 不建议卸载/g; s/'build.*'$/&\t ## 自编译包, 不建议卸载/g' | awk '{printf("%d、%s\n",NR,$0)}')"
        kernels_headers_uninstall_suggested_array=($(echo -e "${kernels_headers}" | grep -Ev "`uname -r`|^pve-headers$|`kernel_running_based`$|build"))
        preuninstall_array=()
    }

    while :
    do
        kernels_headers_all
        echoContent skyBlue "\n功能 1/${totalProgress} : 卸载 PVE 内核及头文件"
        echoContent red "\n=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "如果当前运行的内核为测试版或第三方内核, 则官方稳定版内核可能会卸载失败\n"

        echoContent red "=============================================================="
        echoContent skyBlue "------------------已安装的内核及头文件-------------------"
        echoContent yellow "${kernels_headers_list}"
        echoContent yellow "X、一键卸载其他内核及头文件"
        echoContent yellow "0、返回"
        echoContent red "=============================================================="
        read -r -p "请选择 : " pve_RemoveChoose
        case ${pve_RemoveChoose} in
            0)
                ./pve_source menu
                break
                ;;
            X|x)
                preuninstall_array=(${kernels_headers_uninstall_suggested_array[*]})
                if [ ${#preuninstall_array[@]} -gt 0 ]; then
                    dpkg --purge --force-remove-essential ${preuninstall_array[*]}
                    echoContent green " ---> 一键卸载其他内核及头文件完成"
                else
                    echoContent green " ---> 无可卸载的内核或头文件"
                fi
                case_read
                ;;
            *)
                if [ -n "${pve_RemoveChoose}" ]; then
                    pve_RemoveOther="$(echo -e "${kernels_headers_list}" | grep "^${pve_RemoveChoose}")"
                    if [ -n "${pve_RemoveOther}" ]; then
                        if [ -n "$(echo ${pve_RemoveOther} | grep "不可")" ]; then
                            echoContent red " ---> 所选项不可卸载"
                            case_read
                        else
                            local num=$[pve_RemoveChoose - 1]
                            dpkg --purge --force-remove-essential ${kernels_headers_array[num]}
                            echoContent green " ---> 卸载 ${kernels_headers_array[num]} 完成"
                            case_read
                        fi
                    else
                        echoContent red " ---> 选择错误"
                        case_read
                    fi
                else
                    echoContent red " ---> 选择错误"
                    case_read
                fi
                ;;
        esac
    done
}

# PVE 设置启动内核
pve_setbootkernel_menu() {
    kernels_list() {
        Manually_kernels=''
        Automatically_kernels=''
        All_kernels=''
        Pinned_kernel=''
        Manually_kernels="$(proxmox-boot-tool kernel list | sed -n '/Manually selected kernels/,/^$/p;' | grep -Ev 'Manually selected kernels|None|^$')"
        Automatically_kernels="$(proxmox-boot-tool kernel list | sed -n '/Automatically selected kernels/,/^$/p;' | grep -Ev 'Automatically selected kernels|None|^$')"
        All_kernels="$(echo -e "${Manually_kernels}\n${Automatically_kernels}" | grep -Ev '^$')"
        Pinned_kernel="$(proxmox-boot-tool kernel list | sed -n '/Pinned kernel/,/^$/p;' | grep -Ev 'Pinned kernel|None|^$')"
        Pinned_kernel_on_next_boot="$(proxmox-boot-tool kernel list | sed -n '/Kernel pinned on next-boot/,/^$/p;' | grep -Ev 'Kernel pinned on next-boot|None|^$')"
    }

    kernels_array_list() {
        Manually_kernels_array=()
        Automatically_kernels_array=()
        All_kernels_array=()
        kernels_list
        Manually_kernels_array=(${Manually_kernels})
        Automatically_kernels_array=(${Automatically_kernels})
        All_kernels_array=(${All_kernels})
    }

    kernels_Manually_list() {
        if [ -n "$Manually_kernels" ]; then
            echo -e "$Manually_kernels" | awk '{printf("%d、%s\n",NR,$0)}'
        else
            echo -e "无"
        fi
    }

    kernels_Automatically_list() {
        if [ -n "$Automatically_kernels" ]; then
            echo -e "$Automatically_kernels" | awk '{printf("%d、%s\n",NR,$0)}'
        else
            echo -e "无"
        fi
    }

    kernels_All_list() {
        if [ -n "$All_kernels" ]; then
            echo -e "$All_kernels" | awk '{printf("%d、%s\n",NR,$0)}'
        else
            echo -e "无"
        fi
    }

    kernels_Pinned_list() {
        if [ -n "$Pinned_kernel" ]; then
            echo -e "$Pinned_kernel" | awk '{printf("%d、%s\n",NR,$0)}'
        else
            echo -e "无"
        fi
    }

    kernels_Pinned_on_next_boot_list() {
        if [ -n "$Pinned_kernel_on_next_boot" ]; then
            echo -e "$Pinned_kernel_on_next_boot" | awk '{printf("%d、%s\n",NR,$0)}'
        else
            echo -e "无"
        fi
    }

    set_boot_kernel_menu() {
        case $1 in
            Y|y)
                local args='--next-boot'
                ;;
            *)
                local args=''
                ;;
        esac
        while :
        do
            echoContent red "\n=============================================================="
            echoContent skyBlue "---------------------已安装的内核----------------------"
            echoContent yellow "`kernels_All_list`"
            echoContent yellow "0、返回"
            echoContent red "=============================================================="
            read -r -p "请输入内核序号 : " pve_SetBootKernelChoose
            case ${pve_SetBootKernelChoose} in
                0)
                    break
                    ;;
                *)
                    if [ -n "${pve_SetBootKernelChoose}" ]; then
                        pve_SetBootKernel="$(kernels_All_list | grep "^${pve_SetBootKernelChoose}")"
                        if [ -n "${pve_SetBootKernel}" ]; then
                            boot_kernerl_num=$[pve_SetBootKernelChoose - 1]
                            proxmox-boot-tool kernel pin ${All_kernels_array[boot_kernerl_num]} $args
                            break
                        else
                            echoContent red " ---> 选择错误"
                            case_read
                        fi
                    else
                        echoContent red " ---> 选择错误"
                        case_read
                    fi
                    ;;
            esac
        done
    }

    while :
    do
        kernels_array_list
        echoContent skyBlue "\n功能 1/${totalProgress} : 设置 PVE 启动内核"
        echoContent red "\n=============================================================="
        echoContent skyBlue "---------------------自行安装的内核----------------------"
        echoContent yellow "`kernels_Manually_list`"
        echoContent skyBlue "---------------------系统安装的内核----------------------"
        echoContent yellow "`kernels_Automatically_list`"
        echoContent skyBlue "---------------------常用启动的内核----------------------"
        echoContent yellow "`kernels_Pinned_list`"
        echoContent skyBlue "---------------------下次启动的内核----------------------"
        echoContent yellow "`kernels_Pinned_on_next_boot_list`"
        echoContent red "=============================================================="
        echoContent yellow "X、设置常用启动内核\t ## 适用于每次引导系统"
        echoContent yellow "Y、设置下次启动内核\t ## 只用于下次引导系统"
        echoContent yellow "A、取消常用启动内核\t ## 恢复系统设置"
        echoContent yellow "B、取消下次启动内核\t ## 恢复系统设置"
        echoContent yellow "0、返回"
        echoContent red "=============================================================="
        echoContent yellow "# 注意事项\n"
        echoContent yellow "自行安装的内核：第三方或自行编译的内核\n"
        echoContent yellow "第三方内核 : \n"
        echoContent yellow "OpenWrt优化内核: https://github.com/fw867/pve-edge-kernel"
        echoContent yellow "pve-edge-kernel,为PVE提前解锁新内核: https://github.com/fabianishere/pve-edge-kernel"
        echoContent red "=============================================================="
        read -r -p "请选择 : " pve_SetBootKernel_Menu_Choose
        case ${pve_SetBootKernel_Menu_Choose} in
            0)
                ./pve_source menu
                break
                ;;
            X|x|Y|y)
                set_boot_kernel_menu ${pve_SetBootKernel_Menu_Choose}
                ;;
            A|a|B|b)
                case ${pve_SetBootKernel_Menu_Choose} in
                    A|a)
                        local args=''
                        unPinned_kernel="${Pinned_kernel}"
                        ;;
                    B|b)
                        local args='--next-boot'
                        unPinned_kernel="${Pinned_kernel_on_next_boot}"
                        ;;
                esac
                if [ -n ${unPinned_kernel} ]; then
                    proxmox-boot-tool kernel unpin $args
                    echoContent green " ---> 已取消常用启动内核"
                else
                    echoContent red " ---> 选择错误"
                fi
                ;;
            *)
                echoContent red " ---> 选择错误"
                case_read
                ;;
        esac
    done
}

# 一键设置 阿里云 NTP 服务器
PVE_NTP_onekey() {
    echoContent skyBlue "\n进度  1/${totalProgress} : 一键设置 阿里云 NTP 服务器"
    echoContent red "==============================================================\n"

    echoContent skyBlue "            NTP1 ntp.aliyun.com"
    echoContent skyBlue "            NTP2 ntp1.aliyun.com"
    echoContent skyBlue "            NTP3 ntp2.aliyun.com\n"

    echoContent red "=============================================================="
    cat >/etc/chrony/sources.d/ntp.conf<<'EOF'
server ntp.aliyun.com iburst
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
EOF
    systemctl restart chronyd
    echoContent green " ---> NTP 设置完成"
}

# 设置 Proxmox 系统 NTP 服务器
PVE_NTP() {
    echoContent skyBlue "\n进度  1/${totalProgress} : 设置 Proxmox 系统 NTP 服务器"

    local NTP=""
    local tmp=""
    for i in {1..3};do
        while :
        do
            read -r -p "请输入 NTP$i (输入 skip 跳过) : " pve_NTPEnter
            case ${pve_NTPEnter} in
                skip)
                    eval NTP$i=""
                    echoContent red " ---> NTP$i 跳过输入"
                    break
                    ;;
                *)
                    if [ -n ${pve_NTPEnter} ]; then
                        eval NTP$i=${pve_NTPEnter}
                        echoContent green " ---> NTP$i：${pve_NTPEnter}"
                        break
                    else
                        echoContent red " ---> NTP$i 不能为空, 请重新输入"
                    fi
                    ;;
            esac
        done

        if [ -n "$(eval echo \$NTP$i)" ]; then
            tmp="server \$NTP$i iburst"
            NTP="$NTP'\n'$tmp"
        fi
    done

    if [ -n "$NTP" ]; then
        eval echo -e "$NTP" > /etc/chrony/sources.d/ntp.conf
        systemctl restart chronyd
        echoContent green " ---> NTP 设置完成"
    else
        echoContent green " ---> NTP 设置失败"
    fi
}

# 设置 Proxmox 系统 NTP 自动校时服务器
PVE_NTP_menu() {
    echoContent skyBlue "\n功能  $i/${totalProgress} : 设置 Proxmox 系统 NTP 自动校时服务器"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "NTP 网络时间协议服务器将影响PVE系统时间\n"

    echoContent red "=============================================================="
    echoContent yellow "1、一键设置 阿里云 NTP 服务器"
    echoContent yellow "2、设置 Proxmox 系统 NTP 服务器"
    echoContent yellow "3、设置 Proxmox 系统时区"
    echoContent yellow "0、返回"
    echoContent red "=============================================================="
    while :
    do
        read -r -p "请选择 : " pve_NTPChoose
        case ${pve_NTPChoose} in
            1)
                totalProgress=1
                PVE_NTP_onekey && case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            2)
                totalProgress=1
                PVE_NTP && case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            3)
                dpkg-reconfigure tzdata && case_read '主菜单' 'pve_source' 'menu'
                break
                ;;
            0)
                ./pve_source menu
                break
                ;;
            *)
                echoContent red " ---> 选择错误"
                ;;
        esac
    done
}

# 移除 Proxmox 系统 local-lvm 存储空间
PVE_Delete_LVM() {
    echoContent skyBlue "\n功能  1/1 : 移除 Proxmox 系统 local-lvm 存储空间"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "1、移除 local-lvm 后会导致虚拟机及 CT 容器的快照功能失效"
    echoContent yellow "2、移除前需自行关闭并备份各虚拟机、CT 容器等, 谨防移除造成数据丢失"
    echoContent yellow "3、移除后需通过\"数据中心 - 存储\"删除 local-lvm"
    echoContent yellow "4、移除后需通过\"数据中心 - 存储\"增加 local 等其他存储空间的权限内容"
    echoContent yellow "5、移除后如果出现虚拟机或 CT 容器启动失败, 需使用第 2 步备份还原后重试\n"

    echoContent red "=============================================================="
    while :
    do
        read -r -p '是否移除 Proxmox 系统 local-lvm 存储空间 (Y/n)？ : ' PVE_Delete_LVM_choose
        case ${PVE_Delete_LVM_choose} in
            [Yy])
                lvremove pve/data                     #移除local-lvm
                lvextend -l +100%FREE -f pve/root     #将卷组中的空闲空间扩展到根目录
                resize2fs /dev/mapper/pve-root        #刷新扩容根分区
                echoContent green " ---> 请通过\"数据中心-存储\"手动删除无效的 local-lvm , 并编辑 local 或其他存储以增加磁盘映像、容器等内容"
                case_read '主菜单' 'pve_source' 'menu'
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

# 禁止 Proxmox 修改网卡名称
PVE_Disable_Ethernet_Rename() {
    echoContent skyBlue "\n功能  1/1 : 禁止 Proxmox 修改网卡名称"
    echoContent red "\n=============================================================="
    echoContent yellow "# 注意事项\n"
    echoContent yellow "1、本操作具有一定危险性, 可能导致管理口丢失。请慎重使用"
    echoContent yellow "2、修改后重启系统生效, 网卡将使用原始命名 eth0 ~ ethN"
    echoContent yellow "3、重启系统后, 管理口可能变化, 请使用网线试插验证"
    echoContent yellow "4、重启系统后, 通过 \"节点 - 网络\"自行删除已废除的网卡名称\n"

    echoContent red "=============================================================="
    while :
    do
        read -r -p '是否禁止 Proxmox 系统网卡改名, 使用 eth0 ~ ethN 原名 (Y/n)？ : ' PVE_Disable_Ethernet_Renamechoose
        case ${PVE_Disable_Ethernet_Renamechoose} in
            [Yy])
                sed -Ei '/^GRUB_CMDLINE_LINUX=/ s/".*"/"net.ifnames=0 biosdevname=0"/' /etc/default/grub
                update-grub
                sed -Ei '/iface vmbr0/,/bridge-ports/ s/(.*bridge-ports\s+).*/\1eth0/' /etc/network/interfaces
                echoContent green " ---> 禁止 Proxmox 系统网卡改名设置完毕, 重启系统后生效"
                echoContent green " ---> 重启系统后, 请通过\"PVE节点-网络\"手动删除无效的网络设备名称"
                ask_user "是否重启？" "echoContent green \"正在重启......\" && reboot" "echoContent green \"不重启......\""
                case_read '主菜单' 'pve_source' 'menu'
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

case $1 in
    pve_IOMMU_menu)
        totalProgress=6
        pve_IOMMU_menu
        ;;
    pve_pstate_menu)
        totalProgress=1
        pve_pstate_menu
        ;;
    pve_cpumode_menu)
        totalProgress=1
        pve_cpumode_menu
        ;;
    pve_slaac_ipv6_menu)
        totalProgress=1
        pve_slaac_ipv6_menu
        ;;
    pve_removeotherkernel_menu)
        totalProgress=1
        pve_removeotherkernel_menu
        ;;
    pve_setbootkernel_menu)
        totalProgress=1
        pve_setbootkernel_menu
        ;;
    PVE_NTP_menu)
        totalProgress=1
        PVE_NTP_menu
        ;;
    PVE_Delete_LVM)
        totalProgress=1
        PVE_Delete_LVM
        ;;
    PVE_Disable_Ethernet_Rename)
        totalProgress=1
        PVE_Disable_Ethernet_Rename
        ;;
    *)
        echoContent red " ---> 打开错误, 请通过 pve_source 使用本工具。"
        ;;
esac

/root/pve_source_3
/dev/null
