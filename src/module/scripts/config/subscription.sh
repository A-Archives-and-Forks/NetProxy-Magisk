#!/system/bin/sh

#############################################################################
# 订阅管理脚本
# 功能: add/update/remove/list 订阅
#############################################################################

set -e

readonly MODDIR="$(cd "$(dirname "$0")/../.." && pwd)"
readonly OUTBOUNDS_DIR="$MODDIR/config/xray/outbounds"
readonly LOG_FILE="$MODDIR/logs/subscription.log"


#######################################
# 记录日志
#######################################
log() {
    local level="${1:-INFO}"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

#######################################
# 显示帮助
#######################################
show_help() {
    cat << EOF
用法: $0 <命令> [参数]

命令:
    add <name> <url>    添加订阅
    update <name>       更新指定订阅
    update-all          更新所有订阅
    remove <name>       删除订阅
    list                列出所有订阅

示例:
    $0 add "机场A" "https://example.com/sub"
    $0 update "机场A"
    $0 remove "机场A"
EOF
    exit 0
}

#######################################
# 清理文件名
#######################################
sanitize_name() {
    echo "$1" | sed 's/[\/\\:*?"<>| ]/_/g'
}

#######################################
# 添加订阅
#######################################
cmd_add() {
    local name="$1"
    local url="$2"
    
    if [ -z "$name" ] || [ -z "$url" ]; then
        echo "错误: 请提供订阅名称和URL"
        exit 1
    fi
    
    local safe_name=$(sanitize_name "$name")
    local sub_dir="$OUTBOUNDS_DIR/sub_$safe_name"
    
    if [ -d "$sub_dir" ]; then
        echo "错误: 订阅 '$name' 已存在"
        exit 1
    fi
    
    mkdir -p "$sub_dir"
    
    # 保存元信息
    cat > "$sub_dir/_meta.json" << EOF
{
  "name": "$name",
  "url": "$url",
  "updated": "$(date -Iseconds)"
}
EOF
    
    # 下载并解析节点
    update_subscription "$name" "$url" "$sub_dir"
    
    echo "订阅 '$name' 添加成功"
}

#######################################
# 更新订阅
#######################################
cmd_update() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo "错误: 请提供订阅名称"
        exit 1
    fi
    
    local safe_name=$(sanitize_name "$name")
    local sub_dir="$OUTBOUNDS_DIR/sub_$safe_name"
    local meta_file="$sub_dir/_meta.json"
    
    if [ ! -f "$meta_file" ]; then
        echo "错误: 订阅 '$name' 不存在"
        exit 1
    fi
    
    # 读取 URL
    local url=$(grep -o '"url": *"[^"]*"' "$meta_file" | sed 's/"url": *"\([^"]*\)"/\1/')
    
    # 清空旧节点(保留 _meta.json)
    find "$sub_dir" -name "*.json" ! -name "_meta.json" -delete
    
    # 更新节点
    update_subscription "$name" "$url" "$sub_dir"
    
    # 更新时间戳
    local temp_meta=$(cat "$meta_file")
    echo "$temp_meta" | sed "s/\"updated\": *\"[^\"]*\"/\"updated\": \"$(date -Iseconds)\"/" > "$meta_file"
    
    echo "订阅 '$name' 更新成功"
}

#######################################
# 更新所有订阅
#######################################
cmd_update_all() {
    local count=0
    for sub_dir in "$OUTBOUNDS_DIR"/sub_*; do
        [ -d "$sub_dir" ] || continue
        local meta_file="$sub_dir/_meta.json"
        [ -f "$meta_file" ] || continue
        
        local name=$(grep -o '"name": *"[^"]*"' "$meta_file" | sed 's/"name": *"\([^"]*\)"/\1/')
        echo "更新订阅: $name"
        cmd_update "$name"
        count=$((count + 1))
    done
    
    echo "已更新 $count 个订阅"
}

#######################################
# 删除订阅
#######################################
cmd_remove() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo "错误: 请提供订阅名称"
        exit 1
    fi
    
    local safe_name=$(sanitize_name "$name")
    local sub_dir="$OUTBOUNDS_DIR/sub_$safe_name"
    
    if [ ! -d "$sub_dir" ]; then
        echo "错误: 订阅 '$name' 不存在"
        exit 1
    fi
    
    rm -rf "$sub_dir"
    echo "订阅 '$name' 已删除"
}

#######################################
# 列出订阅
#######################################
cmd_list() {
    echo "订阅列表:"
    for sub_dir in "$OUTBOUNDS_DIR"/sub_*; do
        [ -d "$sub_dir" ] || continue
        local meta_file="$sub_dir/_meta.json"
        [ -f "$meta_file" ] || continue
        
        local name=$(grep -o '"name": *"[^"]*"' "$meta_file" | sed 's/"name": *"\([^"]*\)"/\1/')
        local updated=$(grep -o '"updated": *"[^"]*"' "$meta_file" | sed 's/"updated": *"\([^"]*\)"/\1/')
        local node_count=$(find "$sub_dir" -name "*.json" ! -name "_meta.json" | wc -l)
        
        echo "  - $name ($node_count 节点, 更新于 $updated)"
    done
}

#######################################
# 下载并解析订阅
#######################################
update_subscription() {
    local name="$1"
    local url="$2"
    local sub_dir="$3"
    
    log "INFO" "========== 开始更新订阅 =========="
    log "DEBUG" "订阅名称: $name"
    log "DEBUG" "URL: $url"
    log "DEBUG" "目标目录: $sub_dir"
    

    # 使用 curl 下载订阅内容 (Clash UA)
    local tmp_file="$sub_dir/fetch.tmp"

    log "INFO" "正在下载订阅内容 (User-Agent: Clash/1.19.18)..."
    if curl -L -k -s --connect-timeout 30 --retry 3 \
        -H "User-Agent: Clash/1.0" \
        -o "$tmp_file" \
        "$url" >> "$LOG_FILE" 2>&1; then

        log "INFO" "下载成功，开始解析..."

        # 使用 proxylink 解析
        # -file: 本地文件
        # -format xray: 输出 xray 格式
        # -dir: 输出目录
        if "$MODDIR/bin/proxylink" -file "$tmp_file" -insecure -dns -format xray -dir "$sub_dir" >> "$LOG_FILE" 2>&1; then
             rm -f "$tmp_file"
             log "INFO" "订阅更新完成"
             echo "已导入节点"
        else
             rm -f "$tmp_file"
             log "ERROR" "订阅解析失败"
             echo "错误: 订阅解析失败，请查看日志"
             exit 1
        fi
    else
         rm -f "$tmp_file"
         log "ERROR" "订阅下载失败"
         echo "错误: 订阅下载失败"
         exit 1
    fi
}

#######################################
# 主程序
#######################################
case "${1:-}" in
    add)
        cmd_add "$2" "$3"
        ;;
    update)
        cmd_update "$2"
        ;;
    update-all)
        cmd_update_all
        ;;
    remove)
        cmd_remove "$2"
        ;;
    list)
        cmd_list
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        echo "错误: 未知命令 '$1'"
        show_help
        ;;
esac
