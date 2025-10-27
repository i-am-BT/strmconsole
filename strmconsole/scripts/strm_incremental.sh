#!/bin/bash

# =============================================
# 增量更新 STRM 文件脚本
# 修复路径包含空格和特殊字符的问题
# =============================================

# 配置变量
CD2_MOUNT="/docker/clouddrive/shared/CloudDrive"
STRM_ROOT="/var/strm_files"
LOG_FILE="/var/log/strm_console/strm_full_$(date +%Y%m%d_%H%M%S).log"
LAST_UPDATE_FILE="/docker/last_full_update.txt"

echo "================================================" | tee "$LOG_FILE"
echo "开始增量更新 STRM 文件 - $(date)" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"

# 检查挂载点
if [ ! -d "$CD2_MOUNT" ] || [ -z "$(ls -A "$CD2_MOUNT" 2>/dev/null)" ]; then
    echo "❌ 错误: 挂载点异常" | tee -a "$LOG_FILE"
    exit 1
fi

# 检查上次全量更新时间
if [ ! -f "$LAST_UPDATE_FILE" ]; then
    echo "⚠️ 警告: 未找到上次全量更新时间戳，将处理所有文件" | tee -a "$LOG_FILE"
    LAST_UPDATE_FILE="/dev/null"  # 如果不存在时间戳文件，处理所有文件
else
    LAST_UPDATE=$(cat "$LAST_UPDATE_FILE")
    echo "📅 上次全量更新时间: $LAST_UPDATE" | tee -a "$LOG_FILE"
fi

# 创建 STRM 根目录
mkdir -p "$STRM_ROOT"

# 设置安全选项
set -euo pipefail
IFS=$'\n'  # 设置内部字段分隔符为换行符，正确处理包含空格的文件名

# 计数器
video_count=0
metadata_count=0
error_count=0

echo "开始扫描自上次更新后的视频文件..." | tee -a "$LOG_FILE"

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
        echo "✅ 创建 STRM: $(basename "$strm_file")" | tee -a "$LOG_FILE"
        
        # 同时复制该文件的元数据
        local movie_dir=$(dirname "$media_file")
        while IFS= read -r meta_file; do
            local relative_meta_path="${meta_file#$CD2_MOUNT/}"
            local target_file="$STRM_ROOT/$relative_meta_path"
            
            if ! mkdir -p "$(dirname "$target_file")"; then
                echo "❌ 创建元数据目录失败: $(dirname "$target_file")" | tee -a "$LOG_FILE"
                error_count=$((error_count + 1))
                continue
            fi
            
            if ln "$meta_file" "$target_file" 2>/dev/null || cp "$meta_file" "$target_file"; then
                metadata_count=$((metadata_count + 1))
            else
                error_count=$((error_count + 1))
                echo "❌ 复制元数据失败: $meta_file" | tee -a "$LOG_FILE"
            fi
        done < <(find "$movie_dir" -maxdepth 1 -type f \( \
            -iname "*.nfo" -o \
            -iname "*.jpg" -o \
            -iname "*.jpeg" -o \
            -iname "*.png" -o \
            -iname "*.tbn" -o \
            -iname "folder.jpg" -o \
            -iname "poster.jpg" -o \
            -iname "fanart.jpg" -o \
            -iname "backdrop.jpg" \
        \) 2>/dev/null || true)
        
        return 0
    else
        echo "❌ 创建 STRM 失败: $strm_file" | tee -a "$LOG_FILE"
        return 1
    fi
}

# 查找自上次更新后新增或修改的视频文件
while IFS= read -r media_file; do
    if process_media_file "$media_file"; then
        # 每处理10个文件输出一次进度
        if [ $((video_count % 10)) -eq 0 ]; then
            echo "📁 已处理 $video_count 个视频文件..." | tee -a "$LOG_FILE"
        fi
    else
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
\) -newer "$LAST_UPDATE_FILE" 2>/dev/null)

echo "================================================" | tee -a "$LOG_FILE"
echo "🎉 增量更新完成 - $(date)" | tee -a "$LOG_FILE"
echo "📊 统计信息:" | tee -a "$LOG_FILE"
echo "  ✅ 成功生成 STRM 文件: $video_count 个" | tee -a "$LOG_FILE"
echo "  ✅ 成功处理元数据文件: $metadata_count 个" | tee -a "$LOG_FILE"
echo "  ❌ 处理失败文件: $error_count 个" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"

# 记录本次增量更新时间
echo "$(date +%Y-%m-%d_%H:%M:%S)" > /docker/last_incremental_update.txt