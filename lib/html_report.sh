#!/bin/bash
# html_report.sh - HTML报告生成功能

# HTML模板定义（兼容旧版bash）

# 获取HTML模板（兼容旧版bash）
get_html_template() {
    local theme="$1"

    case "$theme" in
        "modern")
            cat << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{TITLE}}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            line-height: 1.6; color: #333; background: #f5f7fa;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; padding: 40px 0; text-align: center; margin-bottom: 30px;
            border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { font-size: 1.2em; opacity: 0.9; }
        .info-grid {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px; margin-bottom: 30px;
        }
        .info-card {
            background: white; padding: 25px; border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.08); border-left: 4px solid #667eea;
        }
        .info-card h3 { color: #667eea; margin-bottom: 15px; font-size: 1.3em; }
        .info-item { margin-bottom: 10px; display: flex; justify-content: space-between; }
        .info-label { font-weight: 600; color: #555; }
        .info-value { color: #333; }
        .preview-section {
            background: white; padding: 30px; border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.08); text-align: center;
        }
        .preview-section h2 { color: #667eea; margin-bottom: 20px; font-size: 1.8em; }
        .preview-image {
            max-width: 100%; height: auto; border-radius: 8px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1); margin-bottom: 20px;
        }
        .stats-grid {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px; margin-top: 20px;
        }
        .stat-item {
            background: #f8f9fa; padding: 15px; border-radius: 8px; text-align: center;
        }
        .stat-number { font-size: 2em; font-weight: bold; color: #667eea; }
        .stat-label { color: #666; font-size: 0.9em; }
        .footer {
            text-align: center; margin-top: 40px; padding: 20px;
            color: #666; font-size: 0.9em;
        }
        @media (max-width: 768px) {
            .container { padding: 10px; }
            .header h1 { font-size: 2em; }
            .info-grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>{{TITLE}}</h1>
            <p>视频预览图生成报告</p>
        </div>

        <div class="info-grid">
            <div class="info-card">
                <h3>📹 视频信息</h3>
                {{VIDEO_INFO}}
            </div>
            <div class="info-card">
                <h3>⚙️ 生成参数</h3>
                {{GENERATION_PARAMS}}
            </div>
            <div class="info-card">
                <h3>📊 处理统计</h3>
                {{PROCESSING_STATS}}
            </div>
        </div>

        <div class="preview-section">
            <h2>🖼️ 预览图</h2>
            <img src="{{IMAGE_PATH}}" alt="视频预览图" class="preview-image">

            <div class="stats-grid">
                <div class="stat-item">
                    <div class="stat-number">{{FRAME_COUNT}}</div>
                    <div class="stat-label">截取帧数</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">{{PROCESSING_TIME}}</div>
                    <div class="stat-label">处理时间</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">{{FILE_SIZE}}</div>
                    <div class="stat-label">文件大小</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">{{IMAGE_DIMENSIONS}}</div>
                    <div class="stat-label">图片尺寸</div>
                </div>
            </div>
        </div>

        <div class="footer">
            <p>生成时间: {{GENERATION_TIME}} | 工具版本: Video Preview Generator v3.1</p>
        </div>
    </div>
</body>
</html>
EOF
            ;;
        "simple")
            cat << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{TITLE}}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        .header { border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 30px; }
        .info-section { margin-bottom: 30px; }
        .info-section h3 { color: #333; border-left: 4px solid #007acc; padding-left: 10px; }
        .info-table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        .info-table td { padding: 8px; border-bottom: 1px solid #eee; }
        .info-table td:first-child { font-weight: bold; width: 150px; }
        .preview-image { max-width: 100%; height: auto; border: 1px solid #ddd; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>{{TITLE}}</h1>
        <p>视频预览图生成报告</p>
    </div>

    <div class="info-section">
        <h3>视频信息</h3>
        <table class="info-table">{{VIDEO_INFO}}</table>
    </div>

    <div class="info-section">
        <h3>生成参数</h3>
        <table class="info-table">{{GENERATION_PARAMS}}</table>
    </div>

    <div class="info-section">
        <h3>处理统计</h3>
        <table class="info-table">{{PROCESSING_STATS}}</table>
    </div>

    <div class="info-section">
        <h3>预览图</h3>
        <img src="{{IMAGE_PATH}}" alt="视频预览图" class="preview-image">
    </div>

    <div class="footer">
        <p>生成时间: {{GENERATION_TIME}} | 工具版本: Video Preview Generator v3.1</p>
    </div>
</body>
</html>
EOF
            ;;
        *)
            # 默认使用modern主题
            get_html_template "modern"
            ;;
    esac
}

# 生成信息表格内容
generate_info_content() {
    local content_type="$1"
    local theme="$2"

    case "$content_type" in
        "video_info")
            if [ "$theme" = "modern" ]; then
                cat << EOF
                <div class="info-item"><span class="info-label">文件名:</span><span class="info-value">$VIDEO_FILENAME</span></div>
                <div class="info-item"><span class="info-label">时长:</span><span class="info-value">$DURATION_FORMATTED</span></div>
                <div class="info-item"><span class="info-label">分辨率:</span><span class="info-value">${VIDEO_WIDTH}x${VIDEO_HEIGHT}</span></div>
                <div class="info-item"><span class="info-label">文件大小:</span><span class="info-value">$FILE_SIZE_FORMATTED</span></div>
                <div class="info-item"><span class="info-label">码率:</span><span class="info-value">$BITRATE_FORMATTED</span></div>
EOF
            else
                cat << EOF
                <tr><td>文件名</td><td>$VIDEO_FILENAME</td></tr>
                <tr><td>时长</td><td>$DURATION_FORMATTED</td></tr>
                <tr><td>分辨率</td><td>${VIDEO_WIDTH}x${VIDEO_HEIGHT}</td></tr>
                <tr><td>文件大小</td><td>$FILE_SIZE_FORMATTED</td></tr>
                <tr><td>码率</td><td>$BITRATE_FORMATTED</td></tr>
EOF
            fi
            ;;
        "generation_params")
            local mode_desc=""
            case "$MODE" in
                "smart") mode_desc="智能模式(${MIN_INTERVAL}-${MAX_INTERVAL}s, 敏感度${SCENE_THRESHOLD})" ;;
                "keyframe") mode_desc="关键帧模式(最小间隔${KEYFRAME_MIN_INTERVAL}s)" ;;
                *) mode_desc="时间模式(间隔${INTERVAL}s)" ;;
            esac

            local parallel_info=""
            if [ "$ENABLE_PARALLEL_PROCESSING" = true ] && [ "$PARALLEL_JOBS" -gt 1 ]; then
                parallel_info="并行处理(${PARALLEL_JOBS}进程)"
            else
                parallel_info="串行处理"
            fi

            if [ "$theme" = "modern" ]; then
                cat << EOF
                <div class="info-item"><span class="info-label">截图模式:</span><span class="info-value">$mode_desc</span></div>
                <div class="info-item"><span class="info-label">列数:</span><span class="info-value">${COLUMN}列</span></div>
                <div class="info-item"><span class="info-label">间距:</span><span class="info-value">${GAP}px</span></div>
                <div class="info-item"><span class="info-label">图片质量:</span><span class="info-value">${QUALITY}</span></div>
                <div class="info-item"><span class="info-label">输出格式:</span><span class="info-value">$(echo "$FORMAT" | tr '[:lower:]' '[:upper:]')</span></div>
                <div class="info-item"><span class="info-label">处理方式:</span><span class="info-value">$parallel_info</span></div>
EOF
            else
                cat << EOF
                <tr><td>截图模式</td><td>$mode_desc</td></tr>
                <tr><td>列数</td><td>${COLUMN}列</td></tr>
                <tr><td>间距</td><td>${GAP}px</td></tr>
                <tr><td>图片质量</td><td>${QUALITY}</td></tr>
                <tr><td>输出格式</td><td>$(echo "$FORMAT" | tr '[:lower:]' '[:upper:]')</td></tr>
                <tr><td>处理方式</td><td>$parallel_info</td></tr>
EOF
            fi
            ;;
        "processing_stats")
            local processing_time="计算中..."
            if [ -n "$PROCESSING_START_TIME" ]; then
                local end_time=$(date +%s)
                local duration=$((end_time - PROCESSING_START_TIME))
                processing_time="${duration}秒"
            fi

            if [ "$theme" = "modern" ]; then
                cat << EOF
                <div class="info-item"><span class="info-label">截取帧数:</span><span class="info-value">$FRAME_COUNT 帧</span></div>
                <div class="info-item"><span class="info-label">处理时间:</span><span class="info-value">$processing_time</span></div>
                <div class="info-item"><span class="info-label">生成时间:</span><span class="info-value">$GENERATION_TIME</span></div>
EOF
            else
                cat << EOF
                <tr><td>截取帧数</td><td>$FRAME_COUNT 帧</td></tr>
                <tr><td>处理时间</td><td>$processing_time</td></tr>
                <tr><td>生成时间</td><td>$GENERATION_TIME</td></tr>
EOF
            fi
            ;;
    esac
}

# 生成HTML报告（使用模板系统）
generate_html_report() {
    local image_file="$1"
    local output_dir="$2"

    if [ "$GENERATE_HTML_REPORT" != true ]; then
        return 0
    fi

    echo -e "${YELLOW}生成HTML报告...${NC}"

    # 生成HTML文件名
    local html_filename="${VIDEO_FILENAME}_report.html"
    local html_file="$output_dir/$html_filename"
    local image_filename=$(basename "$image_file")

    # 设置处理开始时间（如果还没设置）
    if [ -z "$PROCESSING_START_TIME" ]; then
        PROCESSING_START_TIME=$(date +%s)
    fi

    # 获取图片信息
    local image_size=""
    if command -v identify &> /dev/null; then
        image_size=$(identify -format "%wx%h" "$image_file" 2>/dev/null || echo "未知")
    else
        image_size="未知"
    fi

    local image_file_size=""
    if [ -f "$image_file" ]; then
        if command -v stat &> /dev/null; then
            local size_bytes=$(stat -f%z "$image_file" 2>/dev/null || stat -c%s "$image_file" 2>/dev/null || echo 0)
            image_file_size=$(format_file_size $size_bytes)
        else
            image_file_size="未知"
        fi
    fi

    # 计算处理时间
    local processing_time="计算中..."
    if [ -n "$PROCESSING_START_TIME" ]; then
        local end_time=$(date +%s)
        local duration=$((end_time - PROCESSING_START_TIME))
        processing_time="${duration}秒"
    fi

    # 生成时间
    local generation_time=$(date "+%Y-%m-%d %H:%M:%S")

    # 设置默认主题
    local theme="${HTML_THEME:-modern}"

    # 获取HTML模板
    local html_template=$(get_html_template "$theme")

    if [ -z "$html_template" ]; then
        echo -e "${YELLOW}警告: 未知的HTML主题 '$theme'，使用默认主题${NC}"
        theme="modern"
        html_template=$(get_html_template "$theme")
    fi

    # 生成内容
    local video_info_content=$(generate_info_content "video_info" "$theme")
    local generation_params_content=$(generate_info_content "generation_params" "$theme")
    local processing_stats_content=$(generate_info_content "processing_stats" "$theme")

    # 替换模板变量
    html_template="${html_template//\{\{TITLE\}\}/$HTML_TITLE}"
    html_template="${html_template//\{\{VIDEO_INFO\}\}/$video_info_content}"
    html_template="${html_template//\{\{GENERATION_PARAMS\}\}/$generation_params_content}"
    html_template="${html_template//\{\{PROCESSING_STATS\}\}/$processing_stats_content}"
    html_template="${html_template//\{\{IMAGE_PATH\}\}/$image_filename}"
    html_template="${html_template//\{\{FRAME_COUNT\}\}/${FRAME_COUNT:-0}}"
    html_template="${html_template//\{\{PROCESSING_TIME\}\}/$processing_time}"
    html_template="${html_template//\{\{FILE_SIZE\}\}/$image_file_size}"
    html_template="${html_template//\{\{IMAGE_DIMENSIONS\}\}/$image_size}"
    html_template="${html_template//\{\{GENERATION_TIME\}\}/$generation_time}"

    # 写入HTML文件
    echo "$html_template" > "$html_file"

    echo -e "${GREEN}HTML报告生成完成: $html_file${NC}"
}
