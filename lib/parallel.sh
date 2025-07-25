#!/bin/bash
# parallel.sh - 并行处理功能

# 并行截取单个帧
extract_single_frame_parallel() {
    local frame_time="$1"
    local frame_index="$2"
    local temp_dir="$3"
    local video_file="$4"
    local scale_filter="$5"
    local quality="$6"
    local video_filename="$7"
    local format="$8"

    local temp_frame_file="$temp_dir/${video_filename}_temp_$(printf "%04d" $frame_index).$format"
    local output_file="$temp_dir/${video_filename}_$(printf "%04d" $frame_index).$format"
    
    # 计算实际的视频时间点（加上跳过的开头时间）
    local actual_time=$((frame_time + ${EFFECTIVE_START_TIME:-0}))

    # 截取原始帧（使用实际时间点）
    ffmpeg -ss $actual_time -i "$video_file" -vframes 1 $scale_filter -q:v $quality "$temp_frame_file" -y &> /dev/null

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
        
        # 输出成功标记
        echo "SUCCESS:$frame_index"
    else
        echo "FAILED:$frame_index"
    fi
}

# 并行时间模式帧截取
extract_frames_time_parallel() {
    echo -e "${YELLOW}开始并行截取视频帧...${NC}"
    echo -e "${CYAN}使用 $PARALLEL_JOBS 个并行进程${NC}"

    local frame_count=0
    
    # 设置缩放参数
    local scale_filter
    scale_filter=$(setup_scale_filter)
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 参数配置无效，无法继续处理${NC}"
        return 1
    fi
    
    # 计算总帧数和时间点
    local total_frames=$(((DURATION + INTERVAL - 1) / INTERVAL))
    local frame_times=()
    local frame_time
    for ((frame_time=0; frame_time<DURATION; frame_time+=INTERVAL)); do
        frame_times+=("$frame_time")
    done
    
    echo "预计截取 ${#frame_times[@]} 帧"
    
    # 创建作业队列
    local job_queue=()
    local frame_index=0
    for frame_time in "${frame_times[@]}"; do
        job_queue+=("$frame_time:$frame_index")
        frame_index=$((frame_index + 1))
    done
    
    # 并行处理
    local completed_jobs=0
    local active_jobs=0
    local job_index=0
    local pids=()
    local results_file="$TEMP_DIR/parallel_results.txt"
    
    # 清空结果文件
    > "$results_file"
    
    echo "开始并行处理..."
    
    while [ $completed_jobs -lt ${#job_queue[@]} ] || [ $active_jobs -gt 0 ]; do
        # 启动新作业（如果有空闲槽位和待处理作业）
        while [ $active_jobs -lt $PARALLEL_JOBS ] && [ $job_index -lt ${#job_queue[@]} ]; do
            local job="${job_queue[$job_index]}"
            local frame_time="${job%:*}"
            local frame_idx="${job#*:}"
            
            # 启动后台作业
            (
                extract_single_frame_parallel "$frame_time" "$frame_idx" "$TEMP_DIR" "$VIDEO_FILE" "$scale_filter" "$QUALITY" "$VIDEO_FILENAME" "$FORMAT"
            ) >> "$results_file" &
            
            pids+=($!)
            active_jobs=$((active_jobs + 1))
            job_index=$((job_index + 1))
        done
        
        # 检查已完成的作业
        local new_pids=()
        for pid in "${pids[@]}"; do
            if ! kill -0 $pid 2>/dev/null; then
                # 作业已完成
                wait $pid
                active_jobs=$((active_jobs - 1))
                completed_jobs=$((completed_jobs + 1))
                
                # 更新进度
                show_progress $completed_jobs ${#job_queue[@]} "帧截取进度"
            else
                new_pids+=($pid)
            fi
        done
        pids=("${new_pids[@]}")
        
        # 短暂休眠避免CPU占用过高
        sleep 0.1
    done
    
    printf "\r帧截取进度: 100%% (%d/%d)\n" $completed_jobs $completed_jobs
    
    # 统计成功和失败的帧
    local success_count=$(grep -c "SUCCESS:" "$results_file" 2>/dev/null || echo 0)
    local failed_count=$(grep -c "FAILED:" "$results_file" 2>/dev/null || echo 0)

    # 确保变量是数字并移除换行符
    success_count=$(echo "$success_count" | tr -d '\n' | tr -d ' ')
    failed_count=$(echo "$failed_count" | tr -d '\n' | tr -d ' ')
    success_count=${success_count:-0}
    failed_count=${failed_count:-0}

    echo -e "${GREEN}成功截取 $success_count 帧${NC}"
    if [ "$failed_count" -gt 0 ] 2>/dev/null; then
        echo -e "${YELLOW}失败 $failed_count 帧${NC}"
    fi
    
    # 清理结果文件
    rm -f "$results_file"
}

# 并行场景检测模式帧截取
extract_frames_scene_parallel() {
    echo -e "${YELLOW}开始场景检测并行截取视频帧...${NC}"
    
    # 执行自适应场景检测
    if ! detect_scene_changes_adaptive "$VIDEO_FILE" "$SCENE_THRESHOLD"; then
        echo -e "${YELLOW}场景检测失败，回退到时间间隔模式${NC}"
        extract_frames_time_parallel
        return $?
    fi
    
    # 计算场景检测时间点
    calculate_scene_timepoints "$DURATION" "$MIN_INTERVAL" "$MAX_INTERVAL"

    local timepoints=("${SCENE_TIMEPOINTS[@]}")
    echo "预计截取 ${#timepoints[@]} 帧"
    echo -e "${CYAN}使用 $PARALLEL_JOBS 个并行进程${NC}"
    
    # 设置缩放参数
    local scale_filter
    scale_filter=$(setup_scale_filter)
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 参数配置无效，无法继续处理${NC}"
        return 1
    fi

    # 创建作业队列
    local job_queue=()
    local frame_index=0
    for frame_time in "${timepoints[@]}"; do
        job_queue+=("$frame_time:$frame_index")
        frame_index=$((frame_index + 1))
    done
    
    # 并行处理（复用时间模式的并行逻辑）
    local completed_jobs=0
    local active_jobs=0
    local job_index=0
    local pids=()
    local results_file="$TEMP_DIR/parallel_results.txt"
    
    # 清空结果文件
    > "$results_file"
    
    echo "开始并行处理..."
    
    while [ $completed_jobs -lt ${#job_queue[@]} ] || [ $active_jobs -gt 0 ]; do
        # 启动新作业
        while [ $active_jobs -lt $PARALLEL_JOBS ] && [ $job_index -lt ${#job_queue[@]} ]; do
            local job="${job_queue[$job_index]}"
            local frame_time="${job%:*}"
            local frame_idx="${job#*:}"
            
            # 启动后台作业
            (
                extract_single_frame_parallel "$frame_time" "$frame_idx" "$TEMP_DIR" "$VIDEO_FILE" "$scale_filter" "$QUALITY" "$VIDEO_FILENAME" "$FORMAT"
            ) >> "$results_file" &
            
            pids+=($!)
            active_jobs=$((active_jobs + 1))
            job_index=$((job_index + 1))
        done
        
        # 检查已完成的作业
        local new_pids=()
        for pid in "${pids[@]}"; do
            if ! kill -0 $pid 2>/dev/null; then
                wait $pid
                active_jobs=$((active_jobs - 1))
                completed_jobs=$((completed_jobs + 1))
                
                # 更新进度
                show_progress $completed_jobs ${#job_queue[@]} "帧截取进度"
            else
                new_pids+=($pid)
            fi
        done
        pids=("${new_pids[@]}")
        
        sleep 0.1
    done
    
    printf "\r帧截取进度: 100%% (%d/%d)\n" $completed_jobs $completed_jobs
    
    # 统计结果
    local success_count=$(grep -c "SUCCESS:" "$results_file" 2>/dev/null || echo 0)
    local failed_count=$(grep -c "FAILED:" "$results_file" 2>/dev/null || echo 0)

    # 确保变量是数字并移除换行符
    success_count=$(echo "$success_count" | tr -d '\n' | tr -d ' ')
    failed_count=$(echo "$failed_count" | tr -d '\n' | tr -d ' ')
    success_count=${success_count:-0}
    failed_count=${failed_count:-0}

    echo -e "${GREEN}成功截取 $success_count 帧${NC}"
    if [ "$failed_count" -gt 0 ] 2>/dev/null; then
        echo -e "${YELLOW}失败 $failed_count 帧${NC}"
    fi
    
    # 清理结果文件
    rm -f "$results_file"
    
    return 0
}
