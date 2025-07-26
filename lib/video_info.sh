#!/bin/bash
# video_info.sh - 视频信息获取和处理

# 获取视频信息
get_video_info() {
    local video_file="$1"
    
    # 获取基本视频信息
    DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null | cut -d. -f1)
    VIDEO_WIDTH=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width -of csv=p=0 "$video_file" 2>/dev/null)
    VIDEO_HEIGHT=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=height -of csv=p=0 "$video_file" 2>/dev/null)
    
    # 获取文件大小
    FILE_SIZE=$(stat -f%z "$video_file" 2>/dev/null || stat -c%s "$video_file" 2>/dev/null)
    
    # 获取码率 (kbps)
    BITRATE=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=bit_rate -of csv=p=0 "$video_file" 2>/dev/null)
    if [ -z "$BITRATE" ] || [ "$BITRATE" = "N/A" ]; then
        # 如果无法获取视频流码率，尝试获取总码率
        BITRATE=$(ffprobe -v quiet -show_entries format=bit_rate -of csv=p=0 "$video_file" 2>/dev/null)
    fi
    
    # 获取标题元信息
    VIDEO_TITLE=$(ffprobe -v quiet -show_entries format_tags=title -of csv=p=0 "$video_file" 2>/dev/null)
    
    # 获取文件名（不含扩展名和含扩展名）
    VIDEO_FULL_FILENAME=$(basename "$video_file")
    VIDEO_FILENAME="${VIDEO_FULL_FILENAME%.*}"

    # 检查文件名是否包含URL编码，如果是则解码
    if [[ "$VIDEO_FULL_FILENAME" =~ %[0-9A-Fa-f]{2} ]]; then
        VIDEO_FULL_FILENAME_DECODED=$(url_decode "$VIDEO_FULL_FILENAME")
        VIDEO_FILENAME_DECODED="${VIDEO_FULL_FILENAME_DECODED%.*}"
        echo -e "${YELLOW}检测到URL编码的文件名，已解码:${NC}"
        echo "  原始: $VIDEO_FULL_FILENAME"
        echo "  解码: $VIDEO_FULL_FILENAME_DECODED"
        # 使用解码后的文件名用于显示
        VIDEO_FULL_FILENAME_DISPLAY="$VIDEO_FULL_FILENAME_DECODED"
        VIDEO_FILENAME_DISPLAY="$VIDEO_FILENAME_DECODED"
    else
        VIDEO_FULL_FILENAME_DISPLAY="$VIDEO_FULL_FILENAME"
        VIDEO_FILENAME_DISPLAY="$VIDEO_FILENAME"
    fi
    
    # 生成时间
    GENERATION_TIME=$(date "+%Y-%m-%d %H:%M:%S")

    # 计算有效时长（考虑跳过时间）
    calculate_effective_duration
    
    # 检查是否成功获取基本信息
    if [ -z "$DURATION" ] || [ -z "$VIDEO_WIDTH" ] || [ -z "$VIDEO_HEIGHT" ]; then
        echo -e "${RED}错误: 无法读取视频文件信息: $(basename "$video_file")${NC}"
        return 1
    fi
    
    # 格式化文件大小
    if [ -n "$FILE_SIZE" ]; then
        if [ $FILE_SIZE -gt 1073741824 ]; then
            FILE_SIZE_FORMATTED="$(echo "scale=2; $FILE_SIZE/1073741824" | bc)GB"
        elif [ $FILE_SIZE -gt 1048576 ]; then
            FILE_SIZE_FORMATTED="$(echo "scale=2; $FILE_SIZE/1048576" | bc)MB"
        else
            FILE_SIZE_FORMATTED="$(echo "scale=2; $FILE_SIZE/1024" | bc)KB"
        fi
    else
        FILE_SIZE_FORMATTED="未知"
    fi
    
    # 格式化码率
    if [ -n "$BITRATE" ] && [ "$BITRATE" != "N/A" ] && [ "$BITRATE" -gt 0 ] 2>/dev/null; then
        BITRATE_FORMATTED="$(echo "scale=0; $BITRATE/1000" | bc)kbps"
    else
        BITRATE_FORMATTED="未知"
    fi
    
    # 格式化时长
    local hours=$((DURATION / 3600))
    local minutes=$(((DURATION % 3600) / 60))
    local seconds=$((DURATION % 60))
    DURATION_FORMATTED=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)
    
    echo -e "${GREEN}视频信息:${NC}"
    echo "  文件名: $VIDEO_FILENAME_DISPLAY"
    echo "  时长: $DURATION_FORMATTED (${DURATION}秒)"
    echo "  分辨率: ${VIDEO_WIDTH}x${VIDEO_HEIGHT}"
    echo "  文件大小: $FILE_SIZE_FORMATTED"
    echo "  码率: $BITRATE_FORMATTED"
    if [ -n "$VIDEO_TITLE" ] && [ "$VIDEO_TITLE" != "N/A" ]; then
        echo "  标题: $VIDEO_TITLE"
    fi
    return 0
}

# 格式化时间（秒转换为HH:MM:SS）
format_time() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# 格式化时长
format_duration() {
    local seconds="$1"
    echo "$(format_time $seconds) (${seconds}秒)"
}

# 计算有效时长（考虑跳过时间）
calculate_effective_duration() {
    # 原始时长
    ORIGINAL_DURATION="$DURATION"

    # 计算有效时长
    local effective_duration=$((DURATION - SKIP_START - SKIP_END))

    # 验证有效时长
    if [ $effective_duration -le 0 ]; then
        echo -e "${RED}错误: 跳过时间过长，有效时长为负数或零${NC}"
        echo -e "${YELLOW}原始时长: ${DURATION}秒，跳过开头: ${SKIP_START}秒，跳过结尾: ${SKIP_END}秒${NC}"
        exit 1
    fi

    # 更新时长变量
    DURATION="$effective_duration"
    EFFECTIVE_START_TIME="${SKIP_START:-0}"
    EFFECTIVE_END_TIME=$((ORIGINAL_DURATION - SKIP_END))

    # 如果有跳过时间，显示信息
    if [ "$SKIP_START" -gt 0 ] || [ "$SKIP_END" -gt 0 ]; then
        echo -e "${CYAN}时间范围调整:${NC}"
        echo "  原始时长: $(format_duration $ORIGINAL_DURATION)"
        echo "  跳过开头: ${SKIP_START}秒"
        echo "  跳过结尾: ${SKIP_END}秒"
        echo "  有效时长: $(format_duration $DURATION)"
        echo "  处理范围: $(format_time $EFFECTIVE_START_TIME) - $(format_time $EFFECTIVE_END_TIME)"
    fi
}

# 设置输出目录
setup_output_dir() {
    local video_dir=$(dirname "$VIDEO_FILE")
    
    # 临时目录放在与视频同目录下
    TEMP_DIR="$video_dir/.video_preview_tmp_$$"
    mkdir -p "$TEMP_DIR"
    
    # 最终输出目录（与视频文件同目录）
    if [ -z "$OUTPUT" ]; then
        OUTPUT="$video_dir"
    fi
    
    # 最终输出文件名（使用新的命名规则）
    FINAL_OUTPUT=$(generate_output_filename "$VIDEO_FILENAME" "$OUTPUT" "$FORMAT")
    
    echo -e "${GREEN}临时目录: $TEMP_DIR${NC}"
    echo -e "${GREEN}输出文件: $FINAL_OUTPUT${NC}"
}
