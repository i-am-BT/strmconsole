#!/bin/bash

# =============================================
# 全量更新 STRM 文件脚本（分批处理刮削数据）
# 修复路径包含空格和特殊字符的问题
# =============================================

# 配置变量
CD2_MOUNT="/docker/clouddrive/shared/CloudDrive"
STRM_ROOT="/var/strm_files"
LOG_FILE="/var/log/strm_console/strm_full_$(date +%Y%m%d_%H%M%S).log"
BATCH_SIZE=1000  # 每批处理的电影数量

echo "================================================" | tee "$LOG_FILE"
echo "开始全量更新 STRM 文件 - $(date)" | tee -a "$LOG_FILE"
echo "批次大小: $BATCH_SIZE 部电影" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"

# 检查挂载点是否存在
if [ ! -d "$CD2_MOUNT" ]; then
    echo "❌ 错误: 挂载点 $CD2_MOUNT 不存在" | tee -a "$LOG_FILE"
    echo "请检查 CloudDrive2 服务是否正常运行" | tee -a "$LOG_FILE"
    exit 1
fi

# 检查挂载点是否为空
if [ -z "$(ls -A "$CD2_MOUNT" 2>/dev/null)" ]; then
    echo "❌ 错误: 挂载点为空" | tee -a "$LOG_FILE"
    echo "请检查 CloudDrive2 的 115 网盘挂载配置" | tee -a "$LOG_FILE"
    exit 1
fi

echo "✅ 挂载点检查通过" | tee -a "$LOG_FILE"
echo "挂载点路径: $CD2_MOUNT" | tee -a "$LOG_FILE"
echo "STRM 文件目录: $STRM_ROOT" | tee -a "$LOG_FILE"

# 创建 STRM 根目录
mkdir -p "$STRM_ROOT"
echo "✅ 创建 STRM 目录: $STRM_ROOT" | tee -a "$LOG_FILE"

# 设置安全选项
set -euo pipefail
IFS=$'\n'  # 设置内部字段分隔符为换行符，正确处理包含空格的文件名

# 计数器
video_count=0
batch_count=0
total_batches=0
metadata_count=0
error_count=0

# 临时文件用于存储当前批次的电影目录
BATCH_DIRS_FILE=$(mktemp)
echo "📝 创建临时批次文件: $BATCH_DIRS_FILE" | tee -a "$LOG_FILE"

echo "开始扫描视频文件并分批处理刮削数据..." | tee -a "$LOG_FILE"

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
    
    # 写入 .strm 文件内容（使用 Emby 容器内的路径）
    local container_path="/media/CloudDrive/${relative_path}"
    if echo "$container_path" > "$strm_file"; then
        video_count=$((video_count + 1))
        
        # 记录电影所在目录（用于刮削数据复制）
        local movie_dir=$(dirname "$media_file")
        echo "$movie_dir" >> "$BATCH_DIRS_FILE"
        
        # 每处理100个文件输出一次进度
        if [ $((video_count % 100)) -eq 0 ]; then
            echo "📁 已处理 $video_count 个视频文件..." | tee -a "$LOG_FILE"
        fi
        return 0
    else
        echo "❌ 创建 STRM 文件失败: $strm_file" | tee -a "$LOG_FILE"
        return 1
    fi
}

# 处理刮削数据批次
process_metadata_batch() {
    local batch_num="$1"
    echo "================================================" | tee -a "$LOG_FILE"
    echo "🔄 开始处理第 $batch_num 批刮削数据 ($BATCH_SIZE 部电影)..." | tee -a "$LOG_FILE"
    
    local batch_metadata_count=0
    local batch_error_count=0
    
    # 去重并处理每个目录的刮削数据
    sort -u "$BATCH_DIRS_FILE" | while IFS= read -r movie_dir; do
        if [ -n "$movie_dir" ] && [ -d "$movie_dir" ]; then
            # 查找并处理该目录下的所有元数据文件
            while IFS= read -r meta_file; do
                # 获取相对于挂载点的路径
                local relative_meta_path="${meta_file#$CD2_MOUNT/}"
                local target_file="$STRM_ROOT/$relative_meta_path"
                
                # 创建目录
                if ! mkdir -p "$(dirname "$target_file")"; then
                    echo "❌ 创建元数据目录失败: $(dirname "$target_file")" | tee -a "$LOG_FILE"
                    batch_error_count=$((batch_error_count + 1))
                    error_count=$((error_count + 1))
                    continue
                fi
                
                # 尝试创建硬链接（节省空间），失败则复制文件
                if ln "$meta_file" "$target_file" 2>/dev/null; then
                    batch_metadata_count=$((batch_metadata_count + 1))
                    metadata_count=$((metadata_count + 1))
                else
                    # 硬链接失败，使用复制
                    if cp "$meta_file" "$target_file"; then
                        batch_metadata_count=$((batch_metadata_count + 1))
                        metadata_count=$((metadata_count + 1))
                    else
                        batch_error_count=$((batch_error_count + 1))
                        error_count=$((error_count + 1))
                        echo "❌ 复制元数据文件失败: $meta_file" | tee -a "$LOG_FILE"
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
        fi
    done
    
    echo "✅ 第 $batch_num 批刮削数据处理完成" | tee -a "$LOG_FILE"
    echo "  📄 本批处理元数据文件: $batch_metadata_count 个" | tee -a "$LOG_FILE"
    echo "  ❌ 本批处理失败: $batch_error_count 个" | tee -a "$LOG_FILE"
}

# 查找所有视频文件并生成 .strm 文件
while IFS= read -r media_file; do
    if process_media_file "$media_file"; then
        # 每达到批次大小，处理一次刮削数据
        if [ $((video_count % BATCH_SIZE)) -eq 0 ]; then
            batch_count=$((batch_count + 1))
            process_metadata_batch "$batch_count"
            
            # 清空临时文件，准备下一批
            > "$BATCH_DIRS_FILE"
            
            echo "🔄 继续扫描下一批视频文件..." | tee -a "$LOG_FILE"
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
\) 2>/dev/null)

# 处理最后一批不足 BATCH_SIZE 的刮削数据
if [ -s "$BATCH_DIRS_FILE" ]; then
    batch_count=$((batch_count + 1))
    process_metadata_batch "$batch_count"
fi

# 清理临时文件
rm -f "$BATCH_DIRS_FILE"
echo "✅ 清理临时批次文件" | tee -a "$LOG_FILE"

echo "================================================" | tee -a "$LOG_FILE"
echo "🎉 全量更新完成 - $(date)" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"
echo "📊 统计信息:" | tee -a "$LOG_FILE"
echo "  ✅ 成功生成 STRM 文件: $video_count 个" | tee -a "$LOG_FILE"
echo "  ✅ 成功处理元数据文件: $metadata_count 个" | tee -a "$LOG_FILE"
echo "  ❌ 处理失败文件: $error_count 个" | tee -a "$LOG_FILE"
echo "  📦 处理批次: $batch_count 批" | tee -a "$LOG_FILE"
echo "  📂 总处理文件: $((video_count + metadata_count)) 个" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"

# 记录本次全量更新时间
echo "$(date +%Y-%m-%d_%H:%M:%S)" > /docker/last_full_update.txt
echo "⏰ 记录全量更新时间戳" | tee -a "$LOG_FILE"

# 最终检查 STRM 文件总数
total_strm_files=$(find "$STRM_ROOT" -name "*.strm" | wc -l)
echo "🔍 当前 STRM 文件总数: $total_strm_files 个" | tee -a "$LOG_FILE"