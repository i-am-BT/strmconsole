#!/bin/bash

# =============================================
# 仅刮削数据复制脚本
# 修复路径包含空格和特殊字符的问题
# =============================================

# 配置变量
CD2_MOUNT="/docker/clouddrive/shared/CloudDrive"
STRM_ROOT="/var/strm_files"
LOG_FILE="/var/log/strm_console/strm_full_$(date +%Y%m%d_%H%M%S).log"
BATCH_SIZE=500  # 每批处理的目录数量

echo "================================================" | tee "$LOG_FILE"
echo "开始刮削数据复制 - $(date)" | tee -a "$LOG_FILE"
echo "批次大小: $BATCH_SIZE 个目录" | tee -a "$LOG_FILE"
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
dir_count=0
metadata_count=0
error_count=0
batch_count=0

# 临时文件用于存储当前批次的目录
BATCH_DIRS_FILE=$(mktemp)
echo "📝 创建临时批次文件: $BATCH_DIRS_FILE" | tee -a "$LOG_FILE"

echo "开始扫描视频目录并分批处理刮削数据..." | tee -a "$LOG_FILE"

# 处理单个目录的元数据
process_movie_dir() {
    local movie_dir="$1"
    
    while IFS= read -r meta_file; do
        # 获取相对于挂载点的路径
        local relative_meta_path="${meta_file#$CD2_MOUNT/}"
        local target_file="$STRM_ROOT/$relative_meta_path"
        
        # 创建目录
        if ! mkdir -p "$(dirname "$target_file")"; then
            echo "❌ 创建元数据目录失败: $(dirname "$target_file")" | tee -a "$LOG_FILE"
            return 1
        fi
        
        # 尝试创建硬链接（节省空间），失败则复制文件
        if ln "$meta_file" "$target_file" 2>/dev/null; then
            metadata_count=$((metadata_count + 1))
            return 0
        else
            # 硬链接失败，使用复制
            if cp "$meta_file" "$target_file"; then
                metadata_count=$((metadata_count + 1))
                return 0
            else
                echo "❌ 复制元数据文件失败: $meta_file" | tee -a "$LOG_FILE"
                return 1
            fi
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
}

# 处理刮削数据批次
process_metadata_batch() {
    local batch_num="$1"
    echo "================================================" | tee -a "$LOG_FILE"
    echo "🔄 开始处理第 $batch_num 批刮削数据 ($BATCH_SIZE 个目录)..." | tee -a "$LOG_FILE"
    
    local batch_metadata_count=0
    local batch_error_count=0
    
    while IFS= read -r movie_dir; do
        if [ -n "$movie_dir" ] && [ -d "$movie_dir" ]; then
            if process_movie_dir "$movie_dir"; then
                batch_metadata_count=$((batch_metadata_count + 1))
            else
                batch_error_count=$((batch_error_count + 1))
                error_count=$((error_count + 1))
            fi
        fi
    done < "$BATCH_DIRS_FILE"
    
    echo "✅ 第 $batch_num 批刮削数据处理完成" | tee -a "$LOG_FILE"
    echo "  📄 本批处理元数据文件: $batch_metadata_count 个" | tee -a "$LOG_FILE"
    echo "  ❌ 本批处理失败: $batch_error_count 个" | tee -a "$LOG_FILE"
}

# 查找所有视频文件所在的目录，并去重处理
while IFS= read -r movie_dir; do
    dir_count=$((dir_count + 1))
    echo "$movie_dir" >> "$BATCH_DIRS_FILE"
    
    # 每处理100个目录输出一次进度
    if [ $((dir_count % 100)) -eq 0 ]; then
        echo "📂 已扫描 $dir_count 个视频目录..." | tee -a "$LOG_FILE"
    fi
    
    # 每达到批次大小，处理一次刮削数据
    if [ $((dir_count % BATCH_SIZE)) -eq 0 ]; then
        batch_count=$((batch_count + 1))
        process_metadata_batch "$batch_count"
        
        # 清空临时文件，准备下一批
        > "$BATCH_DIRS_FILE"
        
        echo "🔄 继续扫描下一批视频目录..." | tee -a "$LOG_FILE"
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
\) -exec dirname {} \; 2>/dev/null | sort -u)

# 处理最后一批不足 BATCH_SIZE 的刮削数据
if [ -s "$BATCH_DIRS_FILE" ]; then
    batch_count=$((batch_count + 1))
    process_metadata_batch "$batch_count"
fi

# 清理临时文件
rm -f "$BATCH_DIRS_FILE"
echo "✅ 清理临时批次文件" | tee -a "$LOG_FILE"

echo "================================================" | tee -a "$LOG_FILE"
echo "🎉 刮削数据复制完成 - $(date)" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"
echo "📊 统计信息:" | tee -a "$LOG_FILE"
echo "  ✅ 扫描视频目录: $dir_count 个" | tee -a "$LOG_FILE"
echo "  ✅ 成功处理元数据文件: $metadata_count 个" | tee -a "$LOG_FILE"
echo "  ❌ 处理失败文件: $error_count 个" | tee -a "$LOG_FILE"
echo "  📦 处理批次: $batch_count 批" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"