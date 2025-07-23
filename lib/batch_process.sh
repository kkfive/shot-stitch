#!/bin/bash
# batch_process.sh - 批量处理逻辑

# 处理单个视频文件
process_single_video() {
    local video_file="$1"
    local current_index="$2"
    local total_files="$3"
    
    # 设置当前视频文件
    VIDEO_FILE="$video_file"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}处理视频 [$current_index/$total_files]: $(basename "$video_file")${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # 获取视频信息
    if ! get_video_info "$video_file"; then
        echo -e "${RED}跳过文件: $(basename "$video_file") (无法读取视频信息)${NC}"
        return 1
    fi
    
    # 设置输出目录
    setup_output_directory "$video_file"
    
    # 检查输出文件是否已存在（根据设置决定是否跳过）
    if [ -f "$FINAL_OUTPUT" ] && [ "$FORCE_OVERWRITE" != true ]; then
        echo -e "${YELLOW}输出文件已存在，跳过: $FINAL_OUTPUT${NC}"
        echo -e "${YELLOW}使用 --force 参数可强制覆盖${NC}"
        cleanup
        return 2  # 返回2表示跳过
    fi

    if [ -f "$FINAL_OUTPUT" ] && [ "$FORCE_OVERWRITE" = true ]; then
        echo -e "${YELLOW}强制覆盖已存在的文件: $FINAL_OUTPUT${NC}"
    fi
    
    # 截取视频帧
    if ! extract_frames; then
        echo -e "${RED}帧截取失败: $(basename "$video_file")${NC}"
        cleanup
        return 1
    fi
    
    # 生成预览拼接图
    generate_preview_grid
    local grid_result=$?

    if [ $grid_result -eq 2 ]; then
        # 需要分割模式
        echo -e "${YELLOW}启用多图片分割模式...${NC}"
        if ! generate_split_preview "$FINAL_OUTPUT"; then
            echo -e "${RED}分割预览图生成失败: $(basename "$video_file")${NC}"
            cleanup
            return 1
        fi
    elif [ $grid_result -ne 0 ]; then
        # 其他错误
        echo -e "${RED}预览图生成失败: $(basename "$video_file")${NC}"
        cleanup
        return 1
    fi

    # 生成HTML报告（如果启用）
    if [ "$GENERATE_HTML_REPORT" = true ]; then
        generate_html_report "$FINAL_OUTPUT" "$OUTPUT"
    fi

    # 清理临时文件
    cleanup

    echo -e "${GREEN}✓ 成功生成预览图: $FINAL_OUTPUT${NC}"
    return 0
}

# 批量处理视频文件
batch_process_videos() {
    local input_dir="$1"
    
    echo -e "${CYAN}开始批量处理视频文件...${NC}"
    
    # 检测视频文件
    detect_video_files "$input_dir"
    local video_files=("${DETECTED_VIDEO_FILES[@]}")
    local total_files=${#video_files[@]}
    
    if [ $total_files -eq 0 ]; then
        error_exit "未找到视频文件"
    fi
    
    echo -e "${GREEN}找到 $total_files 个视频文件${NC}"
    
    # 处理统计
    local success_count=0
    local failed_count=0
    local skipped_count=0
    local failed_files=()
    local skipped_files=()
    
    # 逐个处理视频文件
    local batch_i
    for ((batch_i=0; batch_i<total_files; batch_i++)); do
        local current_file="${video_files[batch_i]}"
        local current_index=$((batch_i + 1))
        local batch_progress=$((current_index * 100 / total_files))

        echo ""
        echo -e "${CYAN}========================================${NC}"
        echo -e "${CYAN}批量处理进度: $batch_progress% ($current_index/$total_files)${NC}"
        echo -e "${CYAN}========================================${NC}"
        
        local result
        process_single_video "$current_file" "$current_index" "$total_files"
        result=$?

        case $result in
            0)
                # 成功处理
                success_count=$((success_count + 1))
                ;;
            2)
                # 跳过文件
                skipped_count=$((skipped_count + 1))
                skipped_files+=("$(basename "$current_file")")
                ;;
            *)
                # 处理失败
                failed_count=$((failed_count + 1))
                failed_files+=("$(basename "$current_file")")
                ;;
        esac
    done
    
    # 输出处理结果统计
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}批量处理完成${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}成功处理: $success_count 个文件${NC}"

    if [ $skipped_count -gt 0 ]; then
        echo -e "${YELLOW}跳过文件: $skipped_count 个文件（已存在）${NC}"
        echo -e "${YELLOW}跳过文件列表:${NC}"
        for skipped_file in "${skipped_files[@]}"; do
            echo -e "${YELLOW}  - $skipped_file${NC}"
        done
        echo -e "${YELLOW}使用 --force 参数可强制重新生成${NC}"
    fi

    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}处理失败: $failed_count 个文件${NC}"
        echo -e "${RED}失败文件列表:${NC}"
        for failed_file in "${failed_files[@]}"; do
            echo -e "${RED}  - $failed_file${NC}"
        done
    fi

    # 返回值逻辑：只有当有失败文件时才返回1
    if [ $failed_count -gt 0 ]; then
        return 1
    else
        if [ $success_count -gt 0 ]; then
            echo -e "${GREEN}批量处理完成！${NC}"
        else
            echo -e "${YELLOW}没有文件被处理（全部跳过或失败）${NC}"
        fi
        return 0
    fi
}

# 处理单个视频文件（入口函数）
process_video() {
    local video_file="$1"
    
    # 检测是否为单个文件
    if [ -f "$video_file" ]; then
        process_single_video "$video_file" "1" "1"
    else
        error_exit "文件不存在: $video_file"
    fi
}
