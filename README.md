# PVE Tools - Proxmox VE 管理工具

基于 pve_source V1.2-Alpha 优化版本，修复了原版的多个 bug 并进行了安全加固。

## 功能列表

### PVE 换源工具
- 1、一键设置 DNS、换源并更新系统
- 2、更换 Proxmox VE 源（中科大/清华/南大）
- 3、更新软件包
- 4、更新系统
- 5、设置系统 DNS
- 6、去除无效订阅源提示

### PVE UI 修改
- 7、修改 PVE 概要信息（CPU/硬盘/UPS 等）
- 8、应用 PVE 暗黑主题

### PVE 高级配置
- 9、配置 PVE IOMMU 与核显直通、核显 SR-IOV

### PVE CPU 工作模式
- 10、配置 CPU 电源管理 P-State 状态
- 11、配置 CPU 工作模式

### 其他工具
- 12、通过 SLAAC 获取 IPv6
- 13、卸载内核及头文件
- 14、设置 PVE 启动内核
- 15、设置 NTP 自动校时服务器
- 16、移除 local-lvm 存储空间
- 17、禁止系统修改网卡名称

## 优化内容

### Bug 修复
- 修复 `ask_user()` 函数变量名拼写错误 (`cme_1` → `cmd_1`)
- 修复 `magenta` 颜色码错误 (31 → 35)
- 清理 shc 编译器留下的文件头痕迹

### 安全加固
- 移除启动时的免责声明协议
- 网络连接测试改为 `ping baidu.com`
- 修复 `ask_user()` 函数参数引用问题

## 使用方法

```bash
# 克隆仓库
git clone https://github.com/yourusername/pve-tools.git
cd pve-tools

# 运行主菜单
./pve_source.sh

# 或直接运行某个功能
./pve_source_1.sh set_DNS          # 设置 DNS
./pve_source_1.sh remove_void_soucre_tips  # 去除订阅提示
./pve_source_3.sh pve_cpumode_menu  # CPU 工作模式
```

## 原始项目

基于 [pve_source](https://bbs.x86pi.cn) V1.2-Alpha 版本提取和优化。

## 许可证

仅供学习研究使用，请遵守原作者的许可协议。
