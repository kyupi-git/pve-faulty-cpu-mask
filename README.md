# pve-faulty-cpu-mask
<div align="center">

![Proxmox VE](https://img.shields.io/badge/Proxmox%20VE-7.x%20%7C%208.x%20%7C%209.x-orange)
![License](https://img.shields.io/badge/License-MIT-blue)
![Bash](https://img.shields.io/badge/Bash-4.0+-green)

**Proxmox VE Intelligent CPU Core Masking Tool**  
**Proxmox VE 智能 CPU 核心屏蔽工具**

</div>

---

## 📖 English Documentation

### Overview
`pve-faulty-cpu-mask` is a production-grade bash script designed for Proxmox VE systems. It provides a safe, reliable way to disable faulty or unstable physical CPU cores while preserving system stability. The tool automatically handles hyper-threading, protects boot cores across multi-socket systems, and ensures changes persist across reboots using properly configured systemd services.

### Core Features
- ✅ **Hyper-Threading Aware** - Automatically disables all sibling logical CPUs when disabling a physical core
- ✅ **Boot Core Protection** - Never allows disabling boot core 0 on any socket (0, 0:0, 1:0, 2:0, etc.)
- ✅ **Persistent Across Reboots** - Changes survive reboots via systemd services with proper execution ordering
- ✅ **MCE Hardware Fault Detection** - Auto-detects faulty cores from Machine Check Exception logs
- ✅ **Full Multi-Socket Support** - Works on single and multi-socket systems with intelligent core ID resolution
- ✅ **Kernel Conflict Detection** - Warns about conflicting kernel parameters (isolcpus, nohz_full, rcu_nocbs, irqaffinity)
- ✅ **Complete Restore Functionality** - Full uninstall and restore functionality for all masked cores
- ✅ **Systemd Optimized** - No dependency cycles, proper early-boot execution ordering
- ✅ **Discontiguous CPU Support** - Properly handles non-contiguous CPU numbering on NUMA systems
- ✅ **Unified Core Resolution** - Intelligent socket prefix auto-completion for multi-socket systems
- ✅ **Robust Error Handling** - Graceful handling of user input interrupts and edge cases
- ✅ **Strict Mode Execution** - Runs with `set -euo pipefail` for maximum reliability
- ✅ **Input Validation** - Strict numeric validation for core IDs
- ✅ **Bilingual Interface** - English and Simplified Chinese with automatic system language detection
- ✅ **Accurate CPU State Detection** - Verifies actual CPU online status, not just service file existence
- ✅ **Log File Safety** - Checks directory existence and writability, sets secure 600 permissions on log files
- ✅ **Safe Sed Delimiters** - Uses safe delimiters to avoid conflicts with multi-socket core IDs

### Quick Start
```bash
# Download the script
wget https://raw.githubusercontent.com/kyupi-git/pve-faulty-cpu-mask/main/cpu-mask.sh

# Make it executable
chmod +x cpu-mask.sh

# Run as root
sudo ./cpu-mask.sh
```

### Usage Guide
1. **Select Language** - English / 简体中文 with automatic system language detection
2. **Choose Operation**:
   - Option 1: Disable CPU Physical Cores
   - Option 2: Restore All CPUs & Remove All Masks
3. **When Disabling Cores**:
   - CPU topology is automatically detected and displayed
   - Faulty cores are auto-detected from MCE logs (requires `mcelog` package)
   - Enter physical core IDs (comma-separated for multiple cores)
   - Multi-socket systems: plain numbers automatically resolve across all sockets

### System Requirements
- Proxmox VE 7.x, 8.x, or 9.x
- Bash 4.0 or higher
- Root privileges
- `lscpu` command (preinstalled on Proxmox VE)
- Optional: `mcelog` package for hardware fault detection

### Technical Implementation
1. **Topology Detection**: Uses `lscpu -e` to accurately map physical cores to logical CPUs
2. **Global Associative Arrays**: Uses `declare -gA` for proper global scope array handling
3. **Unified Core Resolution**: Centralized core ID resolution works consistently across all input paths
4. **Input Validation**: Protects all boot cores with strict numeric validation for core IDs
5. **Service Isolation**: Creates individual systemd services for each disabled core
6. **Safe Execution Order**: Disables hyper-threads from highest to lowest logical ID
7. **Early Boot Execution**: Services run before `basic.target` during system startup
8. **Strict Error Mode**: Executes with `set -euo pipefail` for reliable error handling
9. **Accurate State Detection**: Verifies actual CPU online state before skipping disable operations

### Systemd Service Configuration
Each disabled core gets its own systemd service:
- Runs after `sysinit.target`, `systemd-modules-load.target`, `systemd-sysctl.target`, `local-fs.target`
- Executes **before** `basic.target` to ensure CPUs are disabled before services start
- Attached to `basic.target` to avoid service dependency cycles
- `RemainAfterExit=yes` for proper oneshot service behavior
- `ConditionPathExists` ensures sysfs is available
- 30-second timeout for slow storage compatibility

---

## 📖 中文文档

### 概述
`pve-faulty-cpu-mask` 是专为 Proxmox VE 系统设计的生产级 Bash 脚本。它提供安全、可靠的方式来禁用故障或不稳定的物理 CPU 核心，同时保持系统稳定性。该工具自动处理超线程、保护多路系统中所有 socket 的引导核心，并通过正确配置的 systemd 服务确保更改在重启后仍然生效。

### 核心功能
- ✅ **超线程感知** - 禁用物理核心时自动禁用所有兄弟逻辑 CPU
- ✅ **引导核心保护** - 永远不允许禁用任何 socket 上的引导核心 0（0、0:0、1:0、2:0等）
- ✅ **重启持久化** - 通过正确执行顺序的 systemd 服务确保重启后仍然生效
- ✅ **MCE 硬件故障检测** - 从机器检查异常日志自动检测故障核心
- ✅ **完整多路 CPU 支持** - 支持单路和多路 CPU 系统，智能核心 ID 解析
- ✅ **内核冲突检测** - 警告冲突的内核参数（isolcpus、nohz_full、rcu_nocbs、irqaffinity）
- ✅ **完整恢复功能** - 完整的卸载和恢复所有屏蔽核心功能
- ✅ **Systemd 优化** - 无依赖循环，正确的开机早期执行顺序
- ✅ **非连续 CPU 支持** - 正确处理 NUMA 系统中非连续的 CPU 编号
- ✅ **统一核心解析** - 多路系统智能自动补全 socket 前缀
- ✅ **健壮的错误处理** - 优雅处理用户输入中断和各种边界情况
- ✅ **严格执行模式** - 使用 `set -euo pipefail` 确保最大可靠性
- ✅ **输入验证** - 核心编号严格数字验证
- ✅ **双语界面** - 英文和简体中文，自动检测系统语言
- ✅ **精确 CPU 状态检测** - 验证实际 CPU 在线状态，而非仅检查服务文件是否存在
- ✅ **日志文件安全** - 检查目录存在性和可写性，设置安全的 600 权限
- ✅ **安全分隔符** - 使用安全分隔符避免与多路 CPU 核心 ID 冲突

### 快速开始
```bash
# 下载脚本
wget https://raw.githubusercontent.com/kyupi-git/pve-faulty-cpu-mask/main/cpu-mask.sh

# 添加执行权限
chmod +x cpu-mask.sh

# 使用 root 用户运行
sudo ./cpu-mask.sh
```

### 使用方法
1. **选择语言** - English / 简体中文，自动检测系统语言
2. **选择操作**:
   - 选项 1: 屏蔽 CPU 物理核心
   - 选项 2: 取消所有 CPU 屏蔽并恢复所有核心
3. **屏蔽核心时**:
   - 自动检测并显示 CPU 拓扑结构
   - 自动检测 MCE 日志中的故障核心（需安装 `mcelog` 软件包）
   - 输入物理核心编号（多个核心用逗号分隔）
   - 多路 CPU 系统：输入纯数字自动在所有 socket 中解析

### 系统要求
- Proxmox VE 7.x、8.x 或 9.x
- Bash 4.0 或更高版本
- Root 权限
- `lscpu` 命令（Proxmox VE 默认预装）
- 可选: `mcelog` 软件包用于硬件故障检测

### 技术实现
1. **拓扑检测**: 使用 `lscpu -e` 精确映射物理核心到逻辑 CPU
2. **全局关联数组**: 使用 `declare -gA` 确保正确的全局作用域数组处理
3. **统一核心解析**: 集中式核心 ID 解析，在所有输入路径一致工作
4. **输入验证**: 保护所有引导核心，严格验证核心编号格式和用户输入
5. **服务隔离**: 为每个禁用的核心创建独立的 systemd 服务
6. **安全执行顺序**: 从高到低逻辑 ID 顺序禁用超线程
7. **开机早期执行**: 服务在 `basic.target` 之前运行，确保服务启动前完成
8. **严格错误模式**: 使用 `set -euo pipefail` 确保可靠的错误处理
9. **精确状态检测**: 跳过禁用操作前验证实际 CPU 在线状态

### Systemd 服务配置
每个被禁用的核心都有独立的 systemd 服务：
- 在 `sysinit.target`、`systemd-modules-load.target`、`systemd-sysctl.target`、`local-fs.target` 之后运行
- 在 `basic.target` **之前** 执行，确保服务启动前 CPU 已禁用
- 挂载到 `basic.target` 避免服务依赖循环
- `RemainAfterExit=yes` 确保 oneshot 服务行为正确
- `ConditionPathExists` 确保执行前 sysfs 可用
- 30 秒超时适配慢速存储

---

## ⚠️ Important Notes | 重要提示

### English
- **Always test in a non-production environment first**
- Boot core 0 on ANY socket can NEVER be disabled
- Adjust VM CPU counts after disabling cores
- VMs with more cores than available will fail to start

### 中文
- **请务必先在非生产环境测试**
- 任何 socket 上的引导核心 0 永远不能被禁用
- 禁用核心后请调整虚拟机的 CPU 核心数
- 配置为超过剩余核心数的虚拟机可能无法启动

---

## 📄 License | 许可证

MIT License - See [LICENSE](LICENSE) file for details.
