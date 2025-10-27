#!/bin/bash

# =============================================
# 仅STRM扫描脚本
# 修复路径包含空格和特殊字符的问题
# =============================================

# 配置变量
CD2_MOUNT="/docker/clouddrive/shared/CloudDrive"
STRM_ROOT="/var/strm_files"
LOG_FILE="/var/log/strm_console/strm_full_$(date +%Y%m%d_%H%M%S).log"

echo "================================================" | tee "$LOG_FILE"
echo "开始仅STRM扫描 - $(date)" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"

# 检查挂载点
if [ ! -d "$CD2_MOUNT" ] || [ -z "$(ls -A "$CD2_MOUNT" 2>/dev/null)" ]; then
    echo "❌ 错误: 挂载点异常" | tee -a "$LOG_FILE"
    exit 1
fi

# 创建 STRM 根目录
mkdir -p "$STRM_ROOT"

# 设置安全选项
set -euo pipefail
IFS=$'\n'  # 设置内部字段分隔符为换行符，正确处理包含空格的文件名

# 计数器
video_count=0
error_count=0

echo "开始扫描视频文件并生成STRM文件..." | tee -a "$LOG_FILE"

# 使用更安全的方式处理文件路径
process_media_file() {
    local media_file="$1"
    
    # 获取相对于挂载点的路径
    local relative_path="${media_file#$CD2_MOUNT/}"
    
    # 生成对应的 .strm 文件路径
    local strm_file="$STRM_ROOT/${relative_path%.*}.strm"
    
    # 创建目录（使用引号确保路径安全）
    if ! mkdir -p "$(dirname "$strm_file")"; then
        echo "❌ 创建目录失败: $(dirname "$strm_file")" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # 写入 .strm 文件内容
    local container_path="/media/CloudDrive/${relative_path}"
    if echo "$container_path" > "$strm_file"; then
        video_count=$((video_count + 1))
        
        # 每处理100个文件输出一次进度
        if [ $((video_count % 100)) -eq 0 ]; then
            echo "📁 已处理 $video_count 个视频文件..." | tee -a "$LOG_FILE"
        fi
        return 0
    else
        echo "❌ 创建 STRM 失败: $strm_file" | tee -a "$LOG_FILE"
        return 1
    fi
}

# 查找所有视频文件并生成 .strm 文件
while IFS= read -r media_file; do
    if ! process_media_file "$media_file"; then
        error_count=$((error_count + 1))
    fi
done < <(find "$CD2_MOUNT" -type f \( \
    -iname "*.mp4" -o \
    -iname "*.mkv" -o \
    -iname "*.avi" -o \
    -iname "*.mov" -o \
    -iname "*.wmv" -o \
    -iname "*.flv" -o \
    -iname "*.webm" -o \
    -iname "*.ts" -o \
    -iname "*.m2ts" -o \
    -iname "*.iso" \
\) 2>/dev/null)

echo "================================================" | tee -a "$LOG_FILE"
echo "🎉 仅STRM扫描完成 - $(date)" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"
echo "📊 统计信息:" | tee -a "$LOG_FILE"
echo "  ✅ 成功生成 STRM 文件: $video_count 个" | tee -a "$LOG_FILE"
echo "  ❌ 处理失败文件: $error_count 个" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"

# 记录本次扫描时间
echo "$(date +%Y-%m-%d_%H:%M:%S)" > /docker/last_scan_only_update.txt