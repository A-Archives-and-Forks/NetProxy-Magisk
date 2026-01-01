#!/system/bin/sh
set -e
set -u

readonly MODDIR="$(cd "$(dirname "$0")/../.." && pwd)"
readonly LOG_FILE="$MODDIR/logs/service.log"
readonly XRAY_BIN="$MODDIR/bin/xray"
readonly MODULE_CONF="$MODDIR/config/module.conf"
readonly XRAY_LOG_FILE="$MODDIR/logs/xray.log"
readonly CONFDIR="$MODDIR/config/xray/confdir"
readonly OUTBOUNDS_DIR="$MODDIR/config/xray/outbounds"
readonly API_SERVER="127.0.0.1:8080"
# TProxy 配置文件
readonly TPROXY_CONF="$MODDIR/config/tproxy.conf"
# 运行时配置快照（启动时复制，停止时使用）
readonly TPROXY_RUNTIME_CONF="$MODDIR/logs/.tproxy_runtime.conf"

# 默认配置值
QUICK_START=0
CURRENT_CONFIG=""

#######################################
# 加载模块配置
#######################################
load_module_config() {
    if [ -f "$MODULE_CONF" ]; then
        # shellcheck source=/dev/null
        . "$MODULE_CONF"
    fi
}

# 根据运行环境设置 busybox 路径
if [ -f "/data/adb/ksu/bin/busybox" ]; then
    BUSYBOX="/data/adb/ksu/bin/busybox"
elif [ -f "/data/adb/ap/bin/busybox" ]; then
    BUSYBOX="/data/adb/ap/bin/busybox"
elif [ -f "/data/adb/magisk/busybox" ]; then
    BUSYBOX="/data/adb/magisk/busybox"
else
    BUSYBOX="busybox"
fi

#######################################
# 记录日志
# Arguments:
#   $1 - 日志级别
#   $2 - 日志消息
#######################################
log() {
    local level="${1:-INFO}"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

#######################################
# 错误退出
# Arguments:
#   $1 - 错误消息
#   $2 - 退出码（可选，默认1）
#######################################
die() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

#######################################
# 从 module.conf 获取配置路径
# Returns:
#   配置文件路径
#######################################
get_config_path() {
    if [ ! -f "$MODULE_CONF" ]; then
        die "模块配置文件不存在: $MODULE_CONF" 1
    fi
    
    local config_path
    config_path=$(grep '^CURRENT_CONFIG=' "$MODULE_CONF" | cut -d'"' -f2)
    
    if [ -z "$config_path" ]; then
        die "无法从模块配置解析配置路径" 1
    fi
    
    echo "$config_path"
}






#######################################
# 检查 Xray 是否已运行
# Returns:
#   0 运行中, 1 未运行
#######################################
is_xray_running() {
    pgrep -f "^$XRAY_BIN" >/dev/null 2>&1
}

#######################################
# 检查当前是否处于直连模式（proxy 出站不存在）
# Returns:
#   0 处于直连模式, 1 有 proxy 出站
#######################################
is_direct_mode() {
    # 通过 API 列出出站，检查 proxy 是否存在
    if "$XRAY_BIN" api lso --server="$API_SERVER" 2>/dev/null | grep -q '"tag": "proxy"'; then
        return 1  # proxy 存在，不是直连模式
    fi
    return 0  # proxy 不存在，是直连模式
}

#######################################
# 快速启动 - 通过 API 添加 proxy 出站
# Returns:
#   0 成功, 1 失败
#######################################
quick_start() {
    log "INFO" "========== 快速启动模式 =========="
    
    # 获取配置文件路径
    local config_file
    config_file=$(get_config_path)
    
    if [ ! -f "$config_file" ]; then
        log "ERROR" "配置文件不存在: $config_file"
        return 1
    fi
    
    # 通过 API 添加 proxy 出站
    log "INFO" "通过 API 添加 proxy 出站: $config_file"
    if "$XRAY_BIN" api ado --server="$API_SERVER" "$config_file"; then
        log "INFO" "proxy 出站添加成功"
    else
        log "ERROR" "proxy 出站添加失败"
        return 1
    fi
    
    log "INFO" "========== 快速启动完成 =========="
    return 0
}

#######################################
# 启动 Xray 服务
#######################################
start_xray() {
    local outbound_config
    
    log "INFO" "========== 开始启动 Xray 服务 =========="
    
    # 获取出站配置文件路径
    outbound_config=$(get_config_path)
    
    if [ ! -f "$outbound_config" ]; then
        die "出站配置文件不存在: $outbound_config" 1
    fi
    
    # 检查 confdir 目录
    if [ ! -d "$CONFDIR" ]; then
        die "confdir 目录不存在: $CONFDIR" 1
    fi
    
    log "INFO" "使用模块化配置: confdir=$CONFDIR"
    log "INFO" "使用出站配置: $outbound_config"
    
    # 启动 Xray 进程（使用 root:net_admin 运行）
    nohup "$BUSYBOX" setuidgid root:net_admin "$XRAY_BIN" run -confdir "$CONFDIR" -config "$outbound_config" > "$XRAY_LOG_FILE" 2>&1 &
    local xray_pid=$!
    
    log "INFO" "Xray 进程已启动, PID: $xray_pid"
    
    # 等待进程稳定
    sleep 1
    
    # 验证进程是否仍在运行
    if ! kill -0 "$xray_pid" 2>/dev/null; then
        die "Xray 进程启动后立即退出，请检查配置" 1
    fi
    
    # 复制 tproxy 配置快照（用于停止时正确清理）
    log "INFO" "保存 TProxy 配置快照..."
    cp -f "$TPROXY_CONF" "$TPROXY_RUNTIME_CONF"
    
    # 启用 TProxy 规则
    "$MODDIR/scripts/network/tproxy.sh" start
    
    log "INFO" "========== Xray 服务启动完成 =========="
}

#######################################
# 启动 Xray 服务（入口）
#######################################
main() {
    # 加载配置
    load_module_config
    
    # 检查 Xray 是否已在运行
    if is_xray_running; then
        # 快速启动模式：Xray 运行中且处于直连模式，添加回 proxy 出站
        if [ "$QUICK_START" = "1" ] && is_direct_mode; then
            if quick_start; then
                return 0
            fi
            log "WARN" "快速启动失败，但 Xray 已在运行"
            return 0
        fi
        log "WARN" "Xray 已在运行，跳过启动"
        return 0
    fi
    
    # 完整启动
    start_xray
}

# 主流程
main
