#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Proxmox VE CPU Core Masking Tool
# Safe and reliable way to disable faulty physical CPU cores
# with hyper-threading awareness and systemd persistence
#
set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
LOG_FILE="/var/log/disable-cpu.log"
LOG_DATE_FMT='+%Y-%m-%d %H:%M:%S'

load_lang_zh() {
    MSG_BANNER_TITLE="Proxmox VE 智能 CPU 核心屏蔽工具"
    MSG_BANNER_SUB="自动检测超线程 | 批量屏蔽 | 保护系统核心 0"
    MSG_MENU_TITLE="请选择操作："
    MSG_MENU_OPT1="1) 屏蔽 CPU 物理核心"
    MSG_MENU_OPT2="2) 取消所有 CPU 屏蔽并恢复所有核心"
    MSG_MENU_PROMPT="请输入选项 (1/2): "
    MSG_ERR_INVALID_OPT="错误：请输入有效选项 (1/2)"
    
    MSG_LANG_SELECT="请选择语言 / Select Language:"
    MSG_LANG_OPT1="1) 简体中文"
    MSG_LANG_OPT2="2) English"
    MSG_LANG_DEFAULT="直接回车使用默认语言 (默认/Default: %s)"
    MSG_LANG_INVALID="输入无效，使用默认语言"
    
    MSG_WARN_KERNEL_CONFLICT="警告：检测到内核 CPU 隔离参数：%s"
    MSG_WARN_KERNEL_CONFLICT2="这些参数与本脚本功能冲突，可能导致系统不稳定"
    MSG_PROMPT_CONTINUE="是否继续执行？(y/N) "
    
    MSG_ERR_CORE0="错误：物理核心 0 为系统引导核心，禁止屏蔽！"
    MSG_ERR_INVALID_NUM="错误：%s 不是有效核心编号"
    MSG_ERR_CORE_NOT_EXIST="错误：物理核心 %s 不存在"
    
    MSG_INFO_DETECT_MCE="正在检测 CPU 硬件故障日志(MCE)..."
    MSG_INFO_MCE_NOT_INSTALL="提示：未安装 mcelog，无法检测硬件故障，请执行：apt install -y mcelog"
    MSG_INFO_NO_FAULT="未检测到 CPU 硬件故障记录"
    MSG_INFO_CORE0_SKIP="检测到的故障核心为引导核心，已自动跳过"
    MSG_WARN_FAULTY_CORES="⚠️  检测到硬件故障的物理核心：%s"
    MSG_PROMPT_AUTO_DISABLE="是否自动屏蔽所有故障核心？(y/N) "
    MSG_SUCCESS_ALL_FAULTY_DISABLED="✅ 所有故障核心屏蔽完成"
    MSG_INFO_RECOMMEND_MANUAL="推荐手动输入屏蔽：%s"
    
    MSG_INFO_CORE_ALREADY_DISABLED="物理核心 %s 已经被屏蔽，跳过"
    MSG_INFO_PROCESSING_CORE="处理物理核心 %s ，逻辑 CPU：%s"
    MSG_SUCCESS_CORE_DISABLED="✓ 物理核心 %s 屏蔽成功"
    
    MSG_LOG_START="开始下线物理核心 %s"
    MSG_LOG_FINISH="操作完成 | 当前在线 CPU: %s"
    MSG_LOG_ERROR="操作失败：无法下线 CPU %s"
    
    MSG_INFO_NO_MASK_SERVICE="未检测到已启用的 CPU 屏蔽服务"
    MSG_INFO_FOUND_MASK_SERVICES="检测到以下已启用的 CPU 屏蔽服务："
    MSG_PROMPT_CONFIRM_UNINSTALL="确定要永久取消所有屏蔽并恢复所有 CPU？(y/N) "
    MSG_INFO_UNINSTALL_CANCELLED="操作已取消"
    MSG_INFO_RESTORING="正在恢复所有 CPU 核心..."
    MSG_SUCCESS_UNINSTALL_DONE="已永久取消所有屏蔽，所有 CPU 已恢复正常"
    
    MSG_INFO_DETECT_TOPO="正在检测 CPU 拓扑结构..."
    MSG_TITLE_CORE_MAPPING="物理核心与逻辑核心 对应关系："
    MSG_FMT_CORE_MAPPING="  物理核心 %s: 逻辑核心 %s"
    
    MSG_INFO_INPUT_RULE="输入规则：可输入单个核心 或 逗号分隔多个核心（如 2,6,8）"
    MSG_WARN_CORE0_FORBIDDEN="重要提醒：引导核心 0 禁止屏蔽"
    MSG_PROMPT_INPUT_CORE="请输入要屏蔽的物理核心编号: "
    
    MSG_TITLE_FINISH="✅ 所有操作执行完成"
    MSG_INFO_CURRENT_ONLINE="当前在线 CPU：%s"
    MSG_TITLE_NOTICE="重要提醒："
    MSG_NOTICE_VM_CPU="请调整所有虚拟机的 CPU 核心数，确保不超过当前可用 CPU 数量"
    MSG_NOTICE_VM_FAIL="配置为超过剩余核心数的虚拟机可能无法启动"
    MSG_NOTICE_RESTORE="恢复命令：重新运行本脚本选择选项 2 即可"
    
    MSG_ERR_NOT_ROOT="错误：必须使用 root 用户执行"
    MSG_ERR_NO_LSCPU="错误：未找到 lscpu 命令"
    MSG_INFO_NO_INPUT="未指定核心，退出"
}

load_lang_en() {
    MSG_BANNER_TITLE="Proxmox VE Intelligent CPU Core Shield"
    MSG_BANNER_SUB="Auto HT Detection | Batch Masking | Boot Core 0 Protection"
    MSG_MENU_TITLE="Please select an operation:"
    MSG_MENU_OPT1="1) Disable CPU Physical Cores"
    MSG_MENU_OPT2="2) Restore All CPUs & Remove All Masks"
    MSG_MENU_PROMPT="Enter your choice (1/2): "
    MSG_ERR_INVALID_OPT="Error: Please enter a valid option (1/2)"
    
    MSG_LANG_SELECT="Select Language / 请选择语言:"
    MSG_LANG_OPT1="1) 简体中文"
    MSG_LANG_OPT2="2) English"
    MSG_LANG_DEFAULT="Press Enter to use default (Default: %s)"
    MSG_LANG_INVALID="Invalid input, using default language"
    
    MSG_WARN_KERNEL_CONFLICT="Warning: Detected kernel CPU isolation params: %s"
    MSG_WARN_KERNEL_CONFLICT2="These params conflict with this tool and may cause instability"
    MSG_PROMPT_CONTINUE="Continue? (y/N) "
    
    MSG_ERR_CORE0="Error: Boot core 0 cannot be disabled!"
    MSG_ERR_INVALID_NUM="Error: %s is not a valid core ID"
    MSG_ERR_CORE_NOT_EXIST="Error: Physical core %s does not exist"
    
    MSG_INFO_DETECT_MCE="Detecting CPU hardware fault logs (MCE)..."
    MSG_INFO_MCE_NOT_INSTALL="Tip: mcelog not installed. Install with: apt install -y mcelog"
    MSG_INFO_NO_FAULT="No CPU hardware fault records found"
    MSG_INFO_CORE0_SKIP="Faulty core is boot core, skipped automatically"
    MSG_WARN_FAULTY_CORES="⚠️  Detected faulty physical cores: %s"
    MSG_PROMPT_AUTO_DISABLE="Automatically disable all faulty cores? (y/N) "
    MSG_SUCCESS_ALL_FAULTY_DISABLED="✅ All faulty cores disabled successfully"
    MSG_INFO_RECOMMEND_MANUAL="Recommended manual input: %s"
    
    MSG_INFO_CORE_ALREADY_DISABLED="Physical core %s is already disabled, skipped"
    MSG_INFO_PROCESSING_CORE="Processing physical core %s, logical CPUs: %s"
    MSG_SUCCESS_CORE_DISABLED="✓ Physical core %s disabled successfully"
    
    MSG_LOG_START="Start disabling physical core %s"
    MSG_LOG_FINISH="Operation completed | Current online CPUs: %s"
    MSG_LOG_ERROR="Operation failed: cannot disable CPU %s"
    
    MSG_INFO_NO_MASK_SERVICE="No enabled CPU masking services found"
    MSG_INFO_FOUND_MASK_SERVICES="Found enabled CPU masking services:"
    MSG_PROMPT_CONFIRM_UNINSTALL="Permanently remove all masks and restore all CPUs? (y/N) "
    MSG_INFO_UNINSTALL_CANCELLED="Operation cancelled"
    MSG_INFO_RESTORING="Restoring all CPU cores..."
    MSG_SUCCESS_UNINSTALL_DONE="All masks removed, all CPUs restored successfully"
    
    MSG_INFO_DETECT_TOPO="Detecting CPU topology..."
    MSG_TITLE_CORE_MAPPING="Physical core to logical CPU mapping:"
    MSG_FMT_CORE_MAPPING="  Core %s: Logical CPUs%s"
    
    MSG_INFO_INPUT_RULE="Rule: single core or multiple cores separated by commas (e.g. 2,6,8)"
    MSG_WARN_CORE0_FORBIDDEN="Important: Boot core 0 cannot be disabled"
    MSG_PROMPT_INPUT_CORE="Enter physical core IDs to disable: "
    
    MSG_TITLE_FINISH="✅ All operations completed"
    MSG_INFO_CURRENT_ONLINE="Current online CPUs: %s"
    MSG_TITLE_NOTICE="Important Notice:"
    MSG_NOTICE_VM_CPU="Adjust VM CPU counts to match available CPUs"
    MSG_NOTICE_VM_FAIL="VMs with more cores than available will fail to start"
    MSG_NOTICE_RESTORE="To restore: re-run this script and select option 2"
    
    MSG_ERR_NOT_ROOT="Error: Must be executed as root"
    MSG_ERR_NO_LSCPU="Error: lscpu command not found"
    MSG_INFO_NO_INPUT="No cores specified, exiting"
}

# Language detection and selection
DEFAULT_LANG="en"
[[ "${LANG:-}" =~ [Zz][Hh] ]] && DEFAULT_LANG="zh"

[ "$DEFAULT_LANG" = "zh" ] && load_lang_zh || load_lang_en

echo -e "${GREEN}=============================================${NC}"
echo -e "$MSG_LANG_SELECT"
echo -e "$MSG_LANG_OPT1"
echo -e "$MSG_LANG_OPT2"
printf "$MSG_LANG_DEFAULT\n" "$DEFAULT_LANG"
lang_choice=""
read -p "" lang_choice || true
echo ""

if [ "${lang_choice:-}" = "1" ]; then
    load_lang_zh
elif [ "${lang_choice:-}" = "2" ]; then
    load_lang_en
elif [ -n "${lang_choice:-}" ]; then
    echo -e "${YELLOW}${MSG_LANG_INVALID}${NC}"
    echo ""
fi

# Root check
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}${MSG_ERR_NOT_ROOT}${NC}"
    exit 1
fi

# Initialize log file (after root check to ensure permission)
# Ensure log file is writable before proceeding
if [ -d "$(dirname "$LOG_FILE")" ] && [ -w "$(dirname "$LOG_FILE")" ]; then
    touch "$LOG_FILE" 2>/dev/null
    # Set safe permissions - only root can read/write
    chmod 600 "$LOG_FILE" 2>/dev/null || true
fi

# lscpu check
if ! command -v lscpu > /dev/null 2>&1; then
    echo -e "${RED}${MSG_ERR_NO_LSCPU}${NC}"
    exit 1
fi

check_kernel_conflicts() {
    local cmdline
    cmdline=$(cat /proc/cmdline)
    local -a conflicts=()
    
    if [[ $cmdline == *isolcpus* ]]; then conflicts+=("isolcpus"); fi
    if [[ $cmdline == *nohz_full* ]]; then conflicts+=("nohz_full"); fi
    if [[ $cmdline == *rcu_nocbs* ]]; then conflicts+=("rcu_nocbs"); fi
    if [[ $cmdline == *irqaffinity* ]]; then conflicts+=("irqaffinity"); fi
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        printf "${YELLOW}${MSG_WARN_KERNEL_CONFLICT}${NC}\n" "${conflicts[*]}"
        echo -e "${YELLOW}${MSG_WARN_KERNEL_CONFLICT2}${NC}"
        local REPLY=""
        read -p "$MSG_PROMPT_CONTINUE" -n 1 -r REPLY || true
        echo ""
        [[ ! ${REPLY:-} =~ ^[Yy]$ ]] && exit 0
    fi
}

validate_core() {
    local core="$1"
    core=$(echo "$core" | xargs)
    
    # Core 0 protection - covers all sockets: "0", "0:0", "1:0", "2:0", etc.
    if [ "$core" = "0" ] || [[ "$core" =~ ^[0-9]+:0$ ]]; then
        echo -e "${RED}${MSG_ERR_CORE0}${NC}"
        return 1
    fi
    
    # Validate numeric format (strict - no leading zeros, proper socket:core format)
    if ! [[ "$core" =~ ^[1-9][0-9]*$ ]] && ! [[ "$core" =~ ^[0-9]+:[1-9][0-9]*$ ]]; then
        printf "${RED}${MSG_ERR_INVALID_NUM}${NC}\n" "$core"
        return 1
    fi
    
    return 0
}

resolve_core_id() {
    local core="$1"
    core=$(echo "$core" | xargs)
    
    # If already has socket format or single socket, return as-is
    if [[ "$core" =~ : ]] || [ "$socket_count" -eq 1 ]; then
        echo "$core"
        return 0
    fi
    
    # Multi-socket: try all sockets to find a match
    for s in $(seq 0 $((socket_count - 1))); do
        try_core="${s}:${core}"
        if [[ -n "${core_to_cpus[$try_core]:-}" ]]; then
            echo "$try_core"
            return 0
        fi
    done
    
    # No match found - return original
    echo "$core"
}

detect_faulty_cpu_from_mce() {
    echo -e "${YELLOW}${MSG_INFO_DETECT_MCE}${NC}"
    
    local -a faulty_cpus=()
    local -A seen_cpus
    
    # Source 1: dmesg kernel buffer (primary, most reliable for recent crashes)
    if command -v dmesg > /dev/null 2>&1; then
        while read -r cpu; do
            [ -n "$cpu" ] && [ -z "${seen_cpus[$cpu]:-}" ] && {
                seen_cpus[$cpu]=1
                faulty_cpus+=("$cpu")
            }
        done < <(dmesg 2>/dev/null | awk '
            /CPU/ && /Hardware Error|Machine Check|mce:/ {
                for(i=1; i<=NF; i++) {
                    if($i ~ /^CPU[0-9]+:$/) {
                        gsub(/CPU|:/, "", $i)
                        print $i
                    } else if($i ~ /^CPU[0-9]+$/) {
                        gsub(/CPU/, "", $i)
                        print $i
                    } else if($i == "CPU" && $(i+1) ~ /^[0-9]+:?$/) {
                        gsub(/:/, "", $(i+1))
                        print $(i+1)
                    }
                }
            }
        ' | sort -n | uniq)
    fi
    
    # Source 2: pstore (crash logs from previous boots)
    if [ -d /sys/fs/pstore ]; then
        while read -r cpu; do
            [ -n "$cpu" ] && [ -z "${seen_cpus[$cpu]:-}" ] && {
                seen_cpus[$cpu]=1
                faulty_cpus+=("$cpu")
            }
        done < <(cat /sys/fs/pstore/* 2>/dev/null | awk '
            /CPU/ && /Hardware Error|Machine Check|mce:/ {
                for(i=1; i<=NF; i++) {
                    if($i ~ /^CPU[0-9]+:$/) {
                        gsub(/CPU|:/, "", $i)
                        print $i
                    } else if($i ~ /^CPU[0-9]+$/) {
                        gsub(/CPU/, "", $i)
                        print $i
                    } else if($i == "CPU" && $(i+1) ~ /^[0-9]+:?$/) {
                        gsub(/:/, "", $(i+1))
                        print $(i+1)
                    }
                }
            }
        ' | sort -n | uniq)
    fi
    
    # Source 3: mcelog log files (fallback for systems with mcelog daemon)
    if command -v mcelog > /dev/null 2>&1; then
        local -a mce_logs=("/var/log/mcelog" "/var/log/mcelog.log" "/var/log/messages")
        for log in "${mce_logs[@]}"; do
            [ -f "$log" ] && [ -s "$log" ] || continue
            while read -r cpu; do
                [ -n "$cpu" ] && [ -z "${seen_cpus[$cpu]:-}" ] && {
                    seen_cpus[$cpu]=1
                    faulty_cpus+=("$cpu")
                }
            done < <(awk '
                /CPU/ {
                    for(i=1; i<=NF; i++) {
                        if($i ~ /^CPU[0-9]+:$/) {
                            gsub(/CPU|:/, "", $i)
                            print $i
                        } else if($i ~ /^CPU[0-9]+$/) {
                            gsub(/CPU/, "", $i)
                            print $i
                        } else if($i == "CPU" && $(i+1) ~ /^[0-9]+:?$/) {
                            gsub(/:/, "", $(i+1))
                            print $(i+1)
                        }
                    }
                }
                /STATUS/ && /MCi?_STATUS/ {
                    for(i=1; i<=NF; i++) {
                        if($i ~ /^CPU[0-9]+/) {
                            gsub(/CPU|,|:,.*/, "", $i)
                            print $i
                        }
                    }
                }
            ' "$log" 2>/dev/null | sort -n | uniq)
        done
    fi
    
    # No sources found at all
    if [ ${#faulty_cpus[@]} -eq 0 ] && ! command -v dmesg > /dev/null 2>&1 && ! command -v mcelog > /dev/null 2>&1; then
        echo -e "${YELLOW}${MSG_INFO_MCE_NOT_INSTALL}${NC}"
        echo ""
        return
    fi
    
    if [ ${#faulty_cpus[@]} -eq 0 ]; then
        echo -e "${GREEN}${MSG_INFO_NO_FAULT}${NC}"
        echo ""
        return
    fi
    
    # Map logical CPUs to physical cores
    local -A seen_cores
    local -a filtered_cores=()
    for cpu in "${faulty_cpus[@]}"; do
        local phy_core="${cpu_to_core[$cpu]:-}"
        if [ -z "$phy_core" ]; then continue; fi
        # Skip all boot cores
        if [ "$phy_core" = "0" ] || [[ "$phy_core" =~ ^[0-9]+:0$ ]]; then continue; fi
        if [ -z "${seen_cores[$phy_core]:-}" ]; then
            seen_cores[$phy_core]=1
            filtered_cores+=("$phy_core")
        fi
    done
    
    if [ ${#filtered_cores[@]} -eq 0 ]; then
        echo -e "${GREEN}${MSG_INFO_CORE0_SKIP}${NC}"
        echo ""
        return
    fi
    
    # Display detected faulty cores and offer auto-disable
    printf "${RED}${MSG_WARN_FAULTY_CORES}${NC}\n" "${filtered_cores[*]}"
    local REPLY=""
    read -p "$MSG_PROMPT_AUTO_DISABLE" -n 1 -r REPLY || true
    echo ""
    
    if [[ ${REPLY:-} =~ ^[Yy]$ ]]; then
        for core in "${filtered_cores[@]}"; do
            disable_single_core "$core"
        done
        echo -e "${GREEN}${MSG_SUCCESS_ALL_FAULTY_DISABLED}${NC}"
        return
    fi
    
    printf "${YELLOW}${MSG_INFO_RECOMMEND_MANUAL}${NC}\n" "${filtered_cores[*]}"
    echo ""
}

disable_single_core() {
    local target_core="$1"
    target_core=$(echo "$target_core" | xargs)
    
    # Auto-resolve core ID for multi-socket systems
    target_core=$(resolve_core_id "$target_core")
    
    validate_core "$target_core" || return 1
    
    # Verify core exists in our topology
    if [[ -z "${core_to_cpus[$target_core]:-}" ]]; then
        printf "${RED}${MSG_ERR_CORE_NOT_EXIST}${NC}\n" "$target_core"
        return 1
    fi
    
    # Generate service-friendly ID
    local service_core_id=${target_core//:/-}
    local SERVICE_NAME="disable-cpu-core-${service_core_id}.service"
    local SCRIPT_NAME="disable-cpu-core-${service_core_id}.sh"
    local SCRIPT_PATH="/usr/sbin/${SCRIPT_NAME}"
    local SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
    
    # Skip if already disabled (check both service existence AND actual CPU offline state)
    local core_already_disabled=1
    if [ -f "$SERVICE_PATH" ]; then
        # Verify if CPUs are actually offline
        for cpu in ${core_to_cpus[$target_core]}; do
            local online_file="/sys/devices/system/cpu/cpu${cpu}/online"
            if [ -f "$online_file" ] && [ "$(cat "$online_file" 2>/dev/null || echo "1")" = "1" ]; then
                core_already_disabled=0
                break
            fi
        done
    else
        core_already_disabled=0
    fi
    
    if [ $core_already_disabled -eq 1 ]; then
        printf "${YELLOW}${MSG_INFO_CORE_ALREADY_DISABLED}${NC}\n" "$target_core"
        return 0
    fi
    
    local -a target_cpus
    target_cpus=(${core_to_cpus[$target_core]})
    printf "${YELLOW}${MSG_INFO_PROCESSING_CORE}${NC}\n" "$target_core" "${target_cpus[*]}"
    
    # Sort CPUs in descending order (disable higher-numbered HT siblings first)
    local -a sorted_cpus
    sorted_cpus=($(printf "%s\n" "${target_cpus[@]}" | sort -nr))
    
    # Generate persistent disable script - expand config variables at generation time
    cat > "$SCRIPT_PATH" << EOF
#!/bin/bash
set -euo pipefail
LOG_FILE="$LOG_FILE"
LOG_DATE_FMT='$LOG_DATE_FMT'
EOF
    
    # Add disable commands for each logical CPU
    for cpu in "${sorted_cpus[@]}"; do
        cat >> "$SCRIPT_PATH" << 'EOF'
echo "$(date "$LOG_DATE_FMT") Start disabling logical CPU CPUID (physical core COREID)" >> "$LOG_FILE" || true
ONLINE_FILE="/sys/devices/system/cpu/cpuCPUID/online"
if [ -f "$ONLINE_FILE" ] && [ "$(cat "$ONLINE_FILE")" = "1" ]; then
    if echo 0 > "$ONLINE_FILE" 2>/dev/null; then
        echo "$(date "$LOG_DATE_FMT") Successfully disabled CPU CPUID" >> "$LOG_FILE" || true
    else
        echo "$(date "$LOG_DATE_FMT") Warning: failed to disable CPU CPUID" >> "$LOG_FILE" || true
    fi
else
    echo "$(date "$LOG_DATE_FMT") CPU CPUID is already offline or not available" >> "$LOG_FILE" || true
fi
sleep 0.3
EOF
        # Replace placeholders with actual values (safer than variable expansion in heredoc)
        # Use | as delimiter to avoid conflicts with : in multi-socket core IDs
        sed -i "s|CPUID|$cpu|g; s|COREID|$target_core|g" "$SCRIPT_PATH"
    done
    
    cat >> "$SCRIPT_PATH" << 'SCRIPT_EOF'
ONLINE=$(cat /sys/devices/system/cpu/online)
echo "$(date "$LOG_DATE_FMT") Operation completed | Current online CPUs: $ONLINE" >> "$LOG_FILE" || true
exit 0
SCRIPT_EOF
    
    chmod 755 "$SCRIPT_PATH"
    
    # Create systemd service unit
    cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Disable Physical CPU Core $target_core
Documentation=https://github.com/kyupi-git/pve-faulty-cpu-mask
After=sysinit.target systemd-modules-load.target systemd-sysctl.target local-fs.target
Before=basic.target
DefaultDependencies=no
ConditionPathExists=/sys/devices/system/cpu/online
RequiresMountsFor=/sys

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
User=root
Group=root
TimeoutSec=30
RemainAfterExit=yes

[Install]
WantedBy=basic.target
EOF
    
    systemctl daemon-reload
    if ! systemctl enable --now "$SERVICE_NAME" 2>/dev/null; then
        printf "${RED}${MSG_LOG_ERROR}${NC}\n" "$target_core"
        # Cleanup created files
        rm -f "$SERVICE_PATH" "$SCRIPT_PATH"
        systemctl daemon-reload
        return 1
    fi
    
    printf "${GREEN}${MSG_SUCCESS_CORE_DISABLED}${NC}\n" "$target_core"
}

uninstall_core() {
    # Temporarily disable strict error checking to ensure complete execution
    # This is critical for restore operations - we want ALL CPUs restored even if some steps fail
    set +e
    
    local -a services
    # Handle nullglob safely with explicit restore
    local restore_nullglob=0
    shopt -q nullglob || restore_nullglob=1
    shopt -s nullglob
    services=(/etc/systemd/system/disable-cpu-core-*.service)
    [ $restore_nullglob -eq 1 ] && shopt -u nullglob
    
    # Show service status info
    if [ ${#services[@]} -gt 0 ]; then
        echo -e "${YELLOW}${MSG_INFO_FOUND_MASK_SERVICES}${NC}"
        for service in "${services[@]}"; do
            echo "  - $(basename "$service")"
        done
    else
        echo -e "${YELLOW}${MSG_INFO_NO_MASK_SERVICE}${NC}"
    fi
    echo ""
    
    # Always ask for confirmation - we will restore CPUs regardless of service existence
    local REPLY=""
    echo -n "$MSG_PROMPT_CONFIRM_UNINSTALL"
    read -r REPLY || REPLY=""  # Robust handling for non-interactive environments
    # Default to NO for safety (prevent accidental restore in non-interactive environments)
    if [[ ! ${REPLY:-} =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}${MSG_INFO_UNINSTALL_CANCELLED}${NC}"
        set -e
        return 0
    fi
    
    echo -e "${YELLOW}${MSG_INFO_RESTORING}${NC}"
    
    # Step 1: FIRST restore ALL CPUs to online state (MOST IMPORTANT)
    # Restore CPUs BEFORE removing services to guarantee they come online
    local cpu cpu_max online_file restored_count=0 failed_count=0 already_online=0
    
    # Get highest possible CPU number with robust error handling
    cpu_max=255  # Safe default fallback
    if [ -f /sys/devices/system/cpu/possible ]; then
        # Format: "0-15" or "0-3,8-11"
        local possible
        possible=$(cat /sys/devices/system/cpu/possible 2>/dev/null || echo "0-255")
        # Extract maximum CPU number - fail-safe parsing
        local parsed_max
        parsed_max=$(echo "$possible" | tr ',' '\n' | awk -F'-' '{print $NF}' | sort -nr 2>/dev/null | head -n1 2>/dev/null)
        if [[ -n "$parsed_max" && "$parsed_max" =~ ^[0-9]+$ ]]; then
            cpu_max="$parsed_max"
        fi
    fi
    
    # Iterate through ALL possible CPUs (0 to cpu_max)
    # IMPORTANT: Restore in ASCENDING order (cpu0, cpu1, cpu2...)
    # This ensures physical cores are restored before their hyper-thread siblings
    for cpu in $(seq 0 "$cpu_max" 2>/dev/null || seq 0 255); do
        online_file="/sys/devices/system/cpu/cpu${cpu}/online"
        if [ -f "$online_file" ]; then
            # Check current state
            local current_state
            current_state=$(cat "$online_file" 2>/dev/null || echo "1")
            if [ "$current_state" = "1" ]; then
                already_online=$((already_online + 1))
                continue
            fi
            
            # Try to bring CPU online with retry mechanism
            local success=0
            for retry in 1 2 3; do
                echo 1 > "$online_file" 2>/dev/null
                # Give CPU more time to come online
                sleep 0.3
                # Verify the CPU actually came online
                local verify_state
                verify_state=$(cat "$online_file" 2>/dev/null || echo "0")
                if [ "$verify_state" = "1" ]; then
                    success=1
                    break
                fi
                sleep 0.2
            done
            
            if [ $success -eq 1 ]; then
                restored_count=$((restored_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        fi
    done
    
    # Step 2: AFTER CPUs are restored - stop, disable and remove all services
    if [ ${#services[@]} -gt 0 ]; then
        for service in "${services[@]}"; do
            local service_name
            service_name=$(basename "$service")
            systemctl stop "$service_name" 2>/dev/null || true
            systemctl disable "$service_name" 2>/dev/null || true
            rm -f "$service" 2>/dev/null || true
            rm -f "/usr/sbin/${service_name%.service}.sh" 2>/dev/null || true
        done
        systemctl daemon-reload 2>/dev/null || true
        sleep 0.5
    fi
    
    # Log restore completion
    echo "$(date "$LOG_DATE_FMT") All CPU cores restored: $restored_count online, $failed_count failed, $already_online already online" >> "$LOG_FILE" 2>/dev/null || true
    
    # Show restore summary
    echo ""
    if [ $restored_count -gt 0 ]; then
        echo -e "${GREEN}  ✓ Successfully restored $restored_count CPU(s) online${NC}"
    fi
    if [ $already_online -gt 0 ]; then
        echo -e "${GREEN}  ✓ $already_online CPU(s) already online${NC}"
    fi
    if [ $failed_count -gt 0 ]; then
        echo -e "${YELLOW}  ⚠ $failed_count CPU(s) may require a reboot to fully restore${NC}"
    fi
    echo ""
    
    echo -e "${GREEN}${MSG_SUCCESS_UNINSTALL_DONE}${NC}"
    
    # Re-enable strict error checking
    set -e
    return 0
}

# Main banner
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}${MSG_BANNER_TITLE}${NC}"
echo -e "${GREEN}${MSG_BANNER_SUB}${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""

# Main menu
echo -e "$MSG_MENU_TITLE"
echo -e "$MSG_MENU_OPT1"
echo -e "$MSG_MENU_OPT2"
choice=""
read -p "$MSG_MENU_PROMPT" choice || true
echo ""

if [ "${choice:-}" = "2" ]; then
    uninstall_core
    exit 0
elif [ "${choice:-}" != "1" ]; then
    echo -e "${RED}${MSG_ERR_INVALID_OPT}${NC}"
    exit 1
fi

# Check for potential kernel conflicts
check_kernel_conflicts

# Detect CPU topology using lscpu extended output
echo -e "$MSG_INFO_DETECT_TOPO"
declare -gA core_to_cpus    # Maps physical core ID -> list of logical CPU IDs
declare -gA cpu_to_core     # Maps logical CPU ID -> physical core ID
socket_count=1

while read -r cpu socket core; do
    core_id="${socket}:${core}"
    core_to_cpus[$core_id]+=" $cpu"
    cpu_to_core[$cpu]="$core_id"
done < <(lscpu -e=cpu,socket,core 2>/dev/null | awk 'NR>1 {print $1,$2,$3}')

for key in "${!core_to_cpus[@]}"; do
    core_to_cpus[$key]=$(echo "${core_to_cpus[$key]}" | xargs)
done

socket_count=$(printf "%s\n" "${!core_to_cpus[@]}" | awk -F: '{print $1}' | sort -u | wc -l)

if [ "$socket_count" -eq 1 ]; then
    # Single socket system - simplify core IDs by removing socket prefix
    declare -gA new_core_map
    declare -gA new_cpu_map
    
    for key in "${!core_to_cpus[@]}"; do
        num_id=${key#*:}
        new_core_map[$num_id]="${core_to_cpus[$key]}"
        for cpu in ${core_to_cpus[$key]}; do
            new_cpu_map[$cpu]="$num_id"
        done
    done
    
    # Use simplified mappings
    unset core_to_cpus cpu_to_core
    declare -gA core_to_cpus
    declare -gA cpu_to_core
    
    for key in "${!new_core_map[@]}"; do
        core_to_cpus[$key]="${new_core_map[$key]}"
    done
    
    for key in "${!new_cpu_map[@]}"; do
        cpu_to_core[$key]="${new_cpu_map[$key]}"
    done
    
    unset new_core_map new_cpu_map
fi

echo -e "${GREEN}${MSG_TITLE_CORE_MAPPING}${NC}"
for core in $(printf "%s\n" "${!core_to_cpus[@]}" | sort -t: -k1,1n -k2,2n); do
    printf "${MSG_FMT_CORE_MAPPING}\n" "$core" " ${core_to_cpus[$core]}"
done
echo ""

detect_faulty_cpu_from_mce

echo -e "${YELLOW}${MSG_INFO_INPUT_RULE}${NC}"
echo -e "${YELLOW}${MSG_WARN_CORE0_FORBIDDEN}${NC}"
target_input=""
read -p "$MSG_PROMPT_INPUT_CORE" target_input || true

if [ -z "${target_input:-}" ]; then
    echo -e "${YELLOW}${MSG_INFO_NO_INPUT}${NC}"
    exit 0
fi

declare -a target_cores
OLD_IFS=$IFS
IFS=',' read -ra target_cores <<< "$target_input"
IFS=$OLD_IFS

for core in "${target_cores[@]}"; do
    # Skip empty entries
    [ -z "$core" ] && continue
    core=$(echo "$core" | xargs)
    disable_single_core "$core"
done

echo -e "\n${GREEN}=============================================${NC}"
echo -e "${GREEN}${MSG_TITLE_FINISH}${NC}"
printf "${MSG_INFO_CURRENT_ONLINE}\n" "$(cat /sys/devices/system/cpu/online)"
echo -e "${GREEN}=============================================${NC}"

echo -e "\n${YELLOW}${MSG_TITLE_NOTICE}${NC}"
echo -e "$MSG_NOTICE_VM_CPU"
echo -e "$MSG_NOTICE_VM_FAIL"
echo -e "\n$MSG_NOTICE_RESTORE"
