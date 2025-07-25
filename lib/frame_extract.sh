#!/bin/bash
# frame_extract.sh - 帧提取功能

# 为帧添加时间戳
add_timestamp_to_frame() {
    local input_file="$1"
    local output_file="$2"
    local timestamp="$3"
    
    # 使用全局字体文件路径
    local font_file="$FONT_FILE"
    
    # 检查字体文件是否存在
    if [ ! -f "$font_file" ]; then
        echo -e "${YELLOW}警告: 字体文件不存在 ($font_file)，使用系统默认字体${NC}" >&2
        font_file=""
    fi
    
    # 获取图片尺寸
    local img_width=$(magick identify -format "%w" "$input_file" 2>/dev/null)
    local img_height=$(magick identify -format "%h" "$input_file" 2>/dev/null)
    
    if [ -z "$img_width" ] || [ -z "$img_height" ]; then
        # 如果无法获取尺寸，直接复制文件
        cp "$input_file" "$output_file"
        return
    fi
    
    # 计算字体大小（增加大小，更明显）
    local font_size=$((img_width / 18))
    if [ $font_size -lt 20 ]; then font_size=20; fi
    if [ $font_size -gt 48 ]; then font_size=48; fi
    
    local margin=10
    
    # 构建字体参数
    local font_option=""
    if [ -n "$font_file" ]; then
        font_option="-font $font_file"
    fi
    
    # 添加时间戳到图片
    eval "magick \"$input_file\" \
        $font_option \
        -pointsize $font_size \
        -fill \"white\" \
        -stroke \"black\" \
        -strokewidth 2 \
        -gravity SouthWest \
        -annotate +${margin}+${margin} \"$timestamp\" \
        \"$output_file\""
}

# 场景检测模式截取视频帧
extract_frames_scene() {
    echo -e "${YELLOW}开始场景检测截取视频帧...${NC}"
    
    # 执行自适应场景检测
    if ! detect_scene_changes_adaptive "$VIDEO_FILE" "$SCENE_THRESHOLD"; then
        echo -e "${YELLOW}场景检测失败，回退到时间间隔模式${NC}"
        extract_frames_time
        return $?
    fi
    
    # 计算场景检测时间点
    calculate_scene_timepoints "$DURATION" "$MIN_INTERVAL" "$MAX_INTERVAL"

    local frame_count=0
    local timepoints=("${SCENE_TIMEPOINTS[@]}")
    
    echo "预计截取 ${#timepoints[@]} 帧"
    
    # 设置缩放参数
    local scale_filter
    scale_filter=$(setup_scale_filter)
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 参数配置无效，无法继续处理${NC}"
        return 1
    fi
    
    # 按场景检测时间点截取帧
    local total_timepoints=${#timepoints[@]}
    local current_timepoint=0
    
    for frame_time in "${timepoints[@]}"; do
        local temp_frame_file="$TEMP_DIR/${VIDEO_FILENAME}_temp_$(printf "%04d" $frame_count).$FORMAT"
        local output_file="$TEMP_DIR/${VIDEO_FILENAME}_$(printf "%04d" $frame_count).$FORMAT"
        
        # 显示进度
        current_timepoint=$((current_timepoint + 1))
        show_progress $current_timepoint $total_timepoints "帧截取进度"
        
        # 先截取原始帧
        ffmpeg -ss $frame_time -i "$VIDEO_FILE" -vframes 1 $scale_filter -q:v $QUALITY "$temp_frame_file" -y &> /dev/null
        
        if [ -f "$temp_frame_file" ]; then
            # 格式化时间戳
            local hours=$((frame_time / 3600))
            local minutes=$(((frame_time % 3600) / 60))
            local seconds=$((frame_time % 60))
            local timestamp=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)
            
            # 在帧上添加时间戳
            add_timestamp_to_frame "$temp_frame_file" "$output_file" "$timestamp"
            
            # 删除临时文件
            rm -f "$temp_frame_file"
            
            frame_count=$((frame_count + 1))
        fi
    done
    
    printf "\r帧截取进度: 100%% (%d/%d)\n" $frame_count $frame_count
    echo -e "${GREEN}成功截取 $frame_count 帧${NC}"
    return 0
}

# 时间间隔模式截取视频帧
extract_frames_time() {
    echo -e "${YELLOW}开始截取视频帧...${NC}"

    local frame_count=0

    # 设置缩放参数
    local scale_filter
    scale_filter=$(setup_scale_filter)
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 参数配置无效，无法继续处理${NC}"
        return 1
    fi

    # 计算总帧数（基于有效时长）
    local total_frames=$(((DURATION + INTERVAL - 1) / INTERVAL))
    echo "预计截取 $total_frames 帧"

    # 截取帧到临时目录
    local frame_time
    local current_frame=0
    for ((frame_time=0; frame_time<DURATION; frame_time+=INTERVAL)); do
        # 计算实际的视频时间点（加上跳过的开头时间）
        local actual_time=$((frame_time + ${EFFECTIVE_START_TIME:-0}))
        local temp_frame_file="$TEMP_DIR/${VIDEO_FILENAME}_temp_$(printf "%04d" $current_frame).$FORMAT"
        local output_file="$TEMP_DIR/${VIDEO_FILENAME}_$(printf "%04d" $current_frame).$FORMAT"

        # 先截取原始帧（使用实际时间点）
        ffmpeg -ss $actual_time -i "$VIDEO_FILE" -vframes 1 $scale_filter -q:v $QUALITY "$temp_frame_file" -y &> /dev/null

        if [ -f "$temp_frame_file" ]; then
            # 格式化时间戳（显示实际时间）
            local hours=$((actual_time / 3600))
            local minutes=$(((actual_time % 3600) / 60))
            local seconds=$((actual_time % 60))
            local timestamp=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)

            # 在帧上添加时间戳
            add_timestamp_to_frame "$temp_frame_file" "$output_file" "$timestamp"

            # 删除临时文件
            rm -f "$temp_frame_file"

            frame_count=$((frame_count + 1))
        fi

        # 显示进度
        current_frame=$((current_frame + 1))
        show_progress $current_frame $total_frames "帧截取进度"
    done

    printf "\r帧截取进度: 100%% (%d/%d)\n" $frame_count $frame_count
    echo -e "${GREEN}成功截取 $frame_count 帧${NC}"
}

# 截取视频帧（模式分发）
extract_frames() {
    # 检查是否启用并行处理
    if [ "$ENABLE_PARALLEL_PROCESSING" = true ] && [ "$PARALLEL_JOBS" -gt 1 ]; then
        echo -e "${CYAN}启用并行处理模式 (${PARALLEL_JOBS} 进程)${NC}"
        case "$MODE" in
            "scene")
                extract_frames_scene_parallel
                return $?
                ;;
            "keyframe")
                extract_frames_keyframe_parallel
                return $?
                ;;
            *)
                extract_frames_time_parallel
                return $?
                ;;
        esac
    else
        echo -e "${CYAN}使用串行处理模式${NC}"
        case "$MODE" in
            "scene")
                extract_frames_scene
                return $?
                ;;
            "keyframe")
                extract_frames_keyframe
                return $?
                ;;
            *)
                extract_frames_time
                return $?
                ;;
        esac
    fi
}
