#!/bin/bash
# core.sh - 核心变量和工具函数

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 简化的日志函数（替代logger.sh）
log_debug() {
    [ "${DEBUG_MODE:-false}" = "true" ] && echo -e "${CYAN}[DEBUG] $1${NC}" >&2
}

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}" >&2
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

log_fatal() {
    echo -e "${RED}[FATAL] $1${NC}" >&2
}

# 简化的错误退出函数
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    log_fatal "$message"

    # 确保在退出前清理资源
    cleanup
    exit "$exit_code"
}

# 基础文件路径验证（替代security.sh的核心功能）
validate_file_path() {
    local file_path="$1"
    local context="$2"

    # 检查路径是否为空
    if [ -z "$file_path" ]; then
        log_error "文件路径为空 ($context)"
        return 1
    fi

    # 检查路径遍历攻击
    if [[ "$file_path" =~ \.\./|\.\.\\ ]]; then
        log_error "检测到路径遍历攻击尝试: $file_path ($context)"
        return 1
    fi

    return 0
}

# 简化的性能监控函数（替代performance.sh的核心功能）
start_timer() {
    local timer_name="${1:-default}"
    # 使用declare替代eval，更安全
    declare -g "TIMER_START_$timer_name=$(date +%s)"
}

end_timer() {
    local timer_name="${1:-default}"
    local start_var="TIMER_START_$timer_name"
    local start_time="${!start_var}"

    if [ -n "$start_time" ]; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_info "计时器 '$timer_name': ${duration}秒"
        return $duration
    else
        log_warn "计时器 '$timer_name' 未启动"
        return 0
    fi
}

# 输出管理函数（合并自output_manager.sh）
setup_temp_directory() {
    local video_file="$1"
    local video_dir=$(dirname "$video_file")

    # 验证视频目录路径
    if ! validate_file_path "$video_dir" "video directory"; then
        error_exit "视频目录路径无效: $video_dir"
    fi

    # 检查目录是否可写
    if [ ! -w "$video_dir" ]; then
        error_exit "视频目录不可写: $video_dir"
    fi

    # 临时目录放在与视频同目录下，使用更安全的命名
    TEMP_DIR="$video_dir/.video_preview_tmp_$$_$(date +%s)"

    # 确保临时目录不存在（避免冲突）
    if [ -e "$TEMP_DIR" ]; then
        error_exit "临时目录已存在: $TEMP_DIR"
    fi

    if ! mkdir -p "$TEMP_DIR"; then
        error_exit "无法创建临时目录: $TEMP_DIR"
    fi

    log_info "临时目录: $TEMP_DIR"
}

setup_output_directory() {
    local video_file="$1"

    # 首先设置临时目录
    setup_temp_directory "$video_file"

    if [ -n "$OUTPUT_DIR" ]; then
        # 用户指定了输出目录
        local video_name=$(basename "$video_file" | sed 's/\.[^.]*$//')
        mkdir -p "$OUTPUT_DIR/$video_name"
        FINAL_OUTPUT_DIR="$OUTPUT_DIR/$video_name"
    else
        # 使用默认输出目录（视频同目录）
        FINAL_OUTPUT_DIR=$(dirname "$video_file")
    fi

    # 设置最终输出文件路径
    FINAL_OUTPUT=$(generate_output_filename "$VIDEO_FILENAME" "$FINAL_OUTPUT_DIR" "$FORMAT")

    # 清理已存在的小图片文件夹（如果启用保留功能）
    cleanup_existing_frames_dir

    log_info "输出目录: $FINAL_OUTPUT_DIR"
}

# 全局变量
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
VIDEO_FILE=""
INPUT_PATH=""
TEMP_DIR=""
FINAL_OUTPUT=""

# 视频信息变量
DURATION=""
VIDEO_WIDTH=""
VIDEO_HEIGHT=""
FILE_SIZE=""
BITRATE=""
VIDEO_TITLE=""
VIDEO_FILENAME=""
VIDEO_FULL_FILENAME=""
GENERATION_TIME=""
FILE_SIZE_FORMATTED=""
BITRATE_FORMATTED=""
DURATION_FORMATTED=""

# 注意：场景检测和关键帧检测的全局变量在各自模块中定义
# SCENE_TIMES=() 在 lib/scene_detect.sh 中定义
# KEYFRAME_TIMES=() 在 lib/keyframe.sh 中定义
# SCENE_TIMEPOINTS=() 在 lib/scene_detect.sh 中定义

# 文件命名和覆盖选项
FORCE_OVERWRITE=false
USE_PARAMETER_SUFFIX=false
KEEP_FRAMES=false

# 支持的视频格式
VIDEO_EXTENSIONS=("mp4" "avi" "mkv" "mov" "wmv" "flv" "webm" "m4v" "3gp" "ogv" "ts" "mts")

# URL解码函数
url_decode() {
    local encoded="$1"
    # 使用printf进行URL解码
    printf '%b' "${encoded//%/\\x}"
}

# 加载配置文件
load_config() {
    local config_file="$1"

    if [ -f "$config_file" ]; then
        echo -e "${YELLOW}加载配置文件: $config_file${NC}"

        # 安全地加载配置文件
        while IFS='=' read -r key value; do
            # 跳过注释和空行
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue

            # 移除前后空格和注释
            key=$(echo "$key" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/#.*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"//' | sed 's/"$//')

            # 设置配置变量
            case $key in
                DEFAULT_INTERVAL) DEFAULT_INTERVAL="$value" ;;
                DEFAULT_QUALITY) DEFAULT_QUALITY="$value" ;;
                DEFAULT_COLUMN) DEFAULT_COLUMN="$value" ;;
                DEFAULT_MODE) DEFAULT_MODE="$value" ;;
                DEFAULT_MIN_INTERVAL) DEFAULT_MIN_INTERVAL="$value" ;;
                DEFAULT_MAX_INTERVAL) DEFAULT_MAX_INTERVAL="$value" ;;
                DEFAULT_SCENE_THRESHOLD) DEFAULT_SCENE_THRESHOLD="$value" ;;
                DEFAULT_FONT_FILE) DEFAULT_FONT_FILE="$value" ;;
                FORCE_OVERWRITE) FORCE_OVERWRITE="$value" ;;
                USE_PARAMETER_SUFFIX)
                    # 只有用户没有通过命令行启用参数后缀时才使用配置文件的值
                    if [ "$SUFFIX_ENABLED_BY_USER" != true ]; then
                        USE_PARAMETER_SUFFIX="$value"
                    fi
                    ;;
                FORCE_OVERWRITE)
                    # 只有用户没有通过命令行启用强制覆盖时才使用配置文件的值
                    if [ "$FORCE_ENABLED_BY_USER" != true ]; then
                        FORCE_OVERWRITE="$value"
                    fi
                    ;;
                MAX_IMAGE_DIMENSION) MAX_IMAGE_DIMENSION="$value" ;;
                DEFAULT_GAP) DEFAULT_GAP="$value" ;;
                DEFAULT_FORMAT) DEFAULT_FORMAT="$value" ;;
                GENERATE_HTML_REPORT)
                    # 只有用户没有通过命令行启用HTML报告时才使用配置文件的值
                    if [ "$HTML_REPORT_ENABLED_BY_USER" != true ]; then
                        GENERATE_HTML_REPORT="$value"
                    fi
                    ;;
                HTML_TITLE)
                    if [ -z "$HTML_TITLE" ]; then
                        HTML_TITLE="$value"
                    fi
                    ;;
                HTML_THEME)
                    if [ -z "$HTML_THEME" ]; then
                        HTML_THEME="$value"
                    fi
                    ;;
                ENABLE_PARALLEL_PROCESSING)
                    # 只有用户没有通过命令行禁用并行处理时才使用配置文件的值
                    if [ "$PARALLEL_DISABLED_BY_USER" != true ]; then
                        ENABLE_PARALLEL_PROCESSING="$value"
                    fi
                    ;;
                DEFAULT_PARALLEL_JOBS) DEFAULT_PARALLEL_JOBS="$value" ;;
                ENABLE_KEYFRAME_DETECTION) ENABLE_KEYFRAME_DETECTION="$value" ;;
                DEFAULT_KEYFRAME_MIN_INTERVAL) DEFAULT_KEYFRAME_MIN_INTERVAL="$value" ;;
                DEFAULT_MAX_FRAMES_PER_PART) DEFAULT_MAX_FRAMES_PER_PART="$value" ;;
            esac
        done < "$config_file"

        echo -e "${GREEN}配置文件加载完成${NC}"
    else
        echo -e "${YELLOW}配置文件不存在，使用默认设置: $config_file${NC}"
    fi
}

# 注意：load_config函数已被load_and_validate_config替代，但保留以兼容性

# 全局进程跟踪数组
declare -a BACKGROUND_PIDS=()

# 添加后台进程到跟踪列表
track_background_process() {
    local pid="$1"
    if [ -n "$pid" ]; then
        BACKGROUND_PIDS+=("$pid")
    fi
}

# 清理所有后台进程
cleanup_background_processes() {
    local pid
    for pid in "${BACKGROUND_PIDS[@]}"; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log_debug "清理后台进程: $pid"
            kill -TERM "$pid" 2>/dev/null
            # 给进程一些时间优雅退出
            sleep 1
            # 如果还在运行，强制杀死
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null
            fi
        fi
    done
    BACKGROUND_PIDS=()
}

# 清理已存在的小图片文件夹
cleanup_existing_frames_dir() {
    if [ "$KEEP_FRAMES" != true ] || [ -z "$VIDEO_FILENAME" ] || [ -z "$FINAL_OUTPUT_DIR" ]; then
        return 0
    fi

    local frames_dir="${FINAL_OUTPUT_DIR}/${VIDEO_FILENAME}_frames"

    if [ -d "$frames_dir" ]; then
        log_debug "清理已存在的小图片文件夹: $frames_dir"
        echo -e "${YELLOW}🧹 清理已存在的小图片文件夹: $(basename "$frames_dir")${NC}"

        if rm -rf "$frames_dir"; then
            log_debug "成功清理小图片文件夹"
        else
            log_debug "清理小图片文件夹失败"
            echo -e "${YELLOW}⚠️ 清理小图片文件夹失败，可能会包含之前的产物${NC}"
        fi
    fi
}

# 保留小图片到指定文件夹
preserve_frame_images() {
    if [ "$KEEP_FRAMES" != true ] || [ -z "$TEMP_DIR" ] || [ ! -d "$TEMP_DIR" ] || [ -z "$VIDEO_FILENAME" ]; then
        return 0
    fi

    # 创建保存小图片的文件夹（与视频文件同名）
    local frames_dir="${FINAL_OUTPUT_DIR}/${VIDEO_FILENAME}_frames"

    log_debug "保留小图片到: $frames_dir"

    # 创建目录
    if ! mkdir -p "$frames_dir"; then
        log_debug "无法创建小图片保存目录: $frames_dir"
        return 1
    fi

    # 查找并移动小图片文件（排除最终输出文件）
    local moved_count=0
    local frame_pattern="${TEMP_DIR}/${VIDEO_FILENAME}_*"

    for frame_file in $frame_pattern; do
        if [ -f "$frame_file" ]; then
            local frame_name=$(basename "$frame_file")
            # 排除最终输出文件和临时文件
            if [[ "$frame_name" != *"_temp."* ]] && [[ "$frame_name" != *"_header_"* ]] && [[ "$frame_name" != *"_grid_"* ]]; then
                if mv "$frame_file" "$frames_dir/"; then
                    moved_count=$((moved_count + 1))
                    log_debug "移动小图片: $frame_name"
                fi
            fi
        fi
    done

    if [ $moved_count -gt 0 ]; then
        echo -e "${GREEN}✓ 已保留 $moved_count 张小图片到: $frames_dir${NC}"
    else
        log_debug "未找到需要保留的小图片"
        # 如果没有文件被移动，删除空目录
        rmdir "$frames_dir" 2>/dev/null
    fi
}

# 清理函数
cleanup() {
    log_debug "开始清理资源..."

    # 清理后台进程
    cleanup_background_processes

    # 保留小图片（如果启用）
    preserve_frame_images

    # 清理临时目录
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log_debug "清理临时目录: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi

    log_debug "资源清理完成"
}

# 注意：error_exit函数已在文件开头定义

# 检查命令是否存在并获取版本信息
check_command() {
    local cmd="$1"
    local name="$2"
    local min_version="$3"

    if ! command -v "$cmd" &> /dev/null; then
        error_exit "$name 未安装。请先安装 $name"
    fi

    # 获取版本信息（如果提供了最小版本要求）
    if [ -n "$min_version" ]; then
        local version=""
        case "$cmd" in
            "ffmpeg"|"ffprobe")
                version=$(ffmpeg -version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
                ;;
            "magick")
                version=$(magick -version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
                ;;
        esac

        if [ -n "$version" ]; then
            log_debug "$name 版本: $version"
        fi
    fi
}

# 检查依赖
check_dependencies() {
    echo -e "${YELLOW}检查依赖...${NC}"

    # 检查必需的命令
    check_command "ffmpeg" "FFmpeg"
    check_command "ffprobe" "FFprobe"
    check_command "magick" "ImageMagick"

    # bc是可选的，如果没有会使用awk作为替代
    if ! command -v "bc" &> /dev/null; then
        log_warn "bc 未安装，将使用 awk 进行数学计算"
        if ! command -v "awk" &> /dev/null; then
            error_exit "bc 和 awk 都未安装，至少需要其中一个进行数学计算"
        fi
    fi

    echo -e "${GREEN}依赖检查完成${NC}"
}

# 检测视频文件
detect_video_files() {
    local input_path="$1"
    local video_files=()
    
    if [ -f "$input_path" ]; then
        # 单个文件
        local ext="${input_path##*.}"
        ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
        
        local is_video=false
        for video_ext in "${VIDEO_EXTENSIONS[@]}"; do
            if [ "$ext" = "$video_ext" ]; then
                is_video=true
                break
            fi
        done
        
        if [ "$is_video" = true ]; then
            video_files=("$input_path")
        else
            error_exit "不支持的文件格式: .$ext"
        fi
    elif [ -d "$input_path" ]; then
        # 目录批量处理
        echo -e "${YELLOW}扫描目录中的视频文件...${NC}"
        
        for ext in "${VIDEO_EXTENSIONS[@]}"; do
            while IFS= read -r -d '' file; do
                video_files+=("$file")
            done < <(find "$input_path" -maxdepth 1 -type f -iname "*.${ext}" -print0 2>/dev/null)
        done
        
        if [ ${#video_files[@]} -eq 0 ]; then
            error_exit "在目录 $input_path 中未找到支持的视频文件"
        fi
        
        # 按文件名排序
        IFS=$'\n' video_files=($(sort <<<"${video_files[*]}"))
        unset IFS
        
        echo -e "${GREEN}找到 ${#video_files[@]} 个视频文件${NC}"
    else
        error_exit "输入路径不存在: $input_path"
    fi
    
    # 输出到全局数组
    DETECTED_VIDEO_FILES=("${video_files[@]}")
}

# 检测CPU核心数
detect_cpu_cores() {
    local cores=4  # 默认值

    # macOS
    if command -v sysctl &> /dev/null; then
        cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
    # Linux
    elif [ -f /proc/cpuinfo ]; then
        cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 4)
    # 其他系统
    elif command -v nproc &> /dev/null; then
        cores=$(nproc 2>/dev/null || echo 4)
    fi

    # 确保至少为1，最多为8（避免过多进程）
    if [ "$cores" -lt 1 ]; then cores=1; fi
    if [ "$cores" -gt 8 ]; then cores=8; fi

    echo "$cores"
}

# 格式化文件大小
format_file_size() {
    local size_bytes="$1"

    if [ "$size_bytes" -lt 1024 ]; then
        echo "${size_bytes}B"
    elif [ "$size_bytes" -lt 1048576 ]; then
        echo "$((size_bytes / 1024))KB"
    elif [ "$size_bytes" -lt 1073741824 ]; then
        echo "$((size_bytes / 1048576))MB"
    else
        echo "$((size_bytes / 1073741824))GB"
    fi
}

# 智能计算最优宽度
calculate_optimal_width() {
    local video_width="$1"
    local video_height="$2"
    local column="$3"
    local gap="$4"
    local format="$5"

    # 根据格式设置最大宽度限制
    local max_width=65535
    case "$format" in
        "webp") max_width=16383 ;;
        *) max_width=65535 ;;
    esac

    # 设置合理的限制（避免质量和性能问题）
    local min_frame_width=400  # 最小单帧宽度
    local max_columns=20       # 最大列数限制

    # 检查列数限制
    if [ "$column" -gt "$max_columns" ]; then
        echo -e "${RED}错误: 列数过多($column)，最大支持${max_columns}列${NC}" >&2
        echo -e "${YELLOW}原因: 过多列数会导致ImageMagick处理问题和质量下降${NC}" >&2
        echo -e "${YELLOW}建议: 使用较少列数以获得更好的效果${NC}" >&2
        return 1
    fi

    # 计算总间距宽度
    local total_gap_width=$((gap * (column - 1)))

    # 计算每个小图的最大允许宽度
    local max_frame_width=$(((max_width - total_gap_width) / column))

    # 检查是否会导致单帧过小
    if [ "$max_frame_width" -lt "$min_frame_width" ]; then
        echo -e "${RED}错误: 列数过多($column)，单帧宽度将小于${min_frame_width}px，会导致质量问题${NC}" >&2
        echo -e "${YELLOW}建议: 减少列数或使用更大的格式限制${NC}" >&2
        return 1
    fi

    # 如果原始宽度小于等于最大允许宽度，使用原始宽度
    if [ "$video_width" -le "$max_frame_width" ]; then
        echo "$video_width"
        return 0
    fi

    # 否则使用最大允许宽度
    echo "$max_frame_width"
}

# 设置缩放参数（智能计算）
setup_scale_filter() {
    local scale_filter=""

    if [ -n "$WIDTH" ]; then
        # 用户指定了宽度，直接使用
        scale_filter="-vf scale=${WIDTH}:-1"
        echo "使用用户指定宽度: ${WIDTH}px" >&2
    else
        # 智能计算最优宽度
        local optimal_width=$(calculate_optimal_width "$VIDEO_WIDTH" "$VIDEO_HEIGHT" "$COLUMN" "$GAP" "$FORMAT")
        local calc_result=$?

        if [ $calc_result -ne 0 ] || [ -z "$optimal_width" ]; then
            # 计算失败，返回错误
            echo "" >&2  # 返回空的scale_filter
            return 1
        fi

        if [ "$optimal_width" -eq "$VIDEO_WIDTH" ]; then
            echo "使用视频原始分辨率: ${VIDEO_WIDTH}x${VIDEO_HEIGHT}" >&2
        else
            WIDTH="$optimal_width"
            scale_filter="-vf scale=${WIDTH}:-1"

            # 计算最终拼接图宽度
            local final_width=$((WIDTH * COLUMN + GAP * (COLUMN - 1)))
            echo "智能调整宽度: ${WIDTH}px (单帧) → ${final_width}px (拼接图)" >&2
            echo "原因: 原始宽度${VIDEO_WIDTH}px × ${COLUMN}列 + 间距会超出${FORMAT}格式限制" >&2
        fi

        # 对于大文件的建议
        local file_size=$(stat -f%z "$VIDEO_FILE" 2>/dev/null || stat -c%s "$VIDEO_FILE" 2>/dev/null || echo 0)
        if [ "$file_size" -gt 2147483648 ] && [ "$COLUMN" -gt 2 ]; then
            echo -e "${YELLOW}提示: 检测到大文件($(format_file_size $file_size))，建议使用较少列数以提高处理速度${NC}" >&2
        fi
    fi

    echo "$scale_filter"
}

# 处理时间点数组（通用函数，兼容旧版bash）
# 参数：输入时间点数组名，最小间隔，输出数组名
process_timepoints() {
    # 注意：旧版bash不支持nameref，暂时禁用此函数
    # 各模块直接实现时间点处理逻辑
    return 0
}

# 显示进度条（通用函数）
show_progress() {
    local current="$1"
    local total="$2"
    local prefix="$3"

    # 避免除零错误
    if [ "$total" -eq 0 ]; then
        printf "\r%s: 0%% (0/0)" "$prefix"
        return
    fi

    local progress=$((current * 100 / total))

    # 检测CI环境，使用不同的显示方式
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
        # CI环境：使用换行输出
        echo "$prefix: $progress% ($current/$total)"
    else
        # 本地环境：使用\r实现动态更新
        printf "\r%s: %d%% (%d/%d)" "$prefix" "$progress" "$current" "$total"
    fi
}

# 通用并行处理函数
# 参数：作业数组名，并行数，处理函数名，结果文件
run_parallel_jobs() {
    local -n job_array=$1
    local parallel_count=$2
    local process_function=$3
    local results_file="$4"

    local completed_jobs=0
    local active_jobs=0
    local job_index=0
    local pids=()

    # 清空结果文件
    > "$results_file"

    echo "开始并行处理..."

    while [ $completed_jobs -lt ${#job_array[@]} ] || [ $active_jobs -gt 0 ]; do
        # 启动新作业
        while [ $active_jobs -lt $parallel_count ] && [ $job_index -lt ${#job_array[@]} ]; do
            local job="${job_array[$job_index]}"

            # 启动后台作业
            ($process_function "$job") >> "$results_file" &

            pids+=($!)
            active_jobs=$((active_jobs + 1))
            job_index=$((job_index + 1))
        done

        # 检查已完成的作业
        local new_pids=()
        for pid in "${pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                wait "$pid"
                active_jobs=$((active_jobs - 1))
                completed_jobs=$((completed_jobs + 1))

                # 更新进度
                show_progress "$completed_jobs" "${#job_array[@]}" "并行处理进度"
            else
                new_pids+=("$pid")
            fi
        done
        pids=("${new_pids[@]}")

        sleep 0.1
    done

    printf "\n"
}

# 通用的ImageMagick命令执行函数
run_magick_command() {
    local command="$1"
    local error_message="$2"
    local error_file="$TEMP_DIR/magick_error_$$.log"

    # 安全地执行命令并捕获错误，避免使用eval
    bash -c "$command" 2>"$error_file"
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}错误: $error_message${NC}"
        if [ -f "$error_file" ] && [ -s "$error_file" ]; then
            echo "ImageMagick错误信息:"
            cat "$error_file"
        fi
        rm -f "$error_file"
        return 1
    fi

    rm -f "$error_file"
    return 0
}

# 通用的文件存在检查函数
check_file_exists() {
    local file_path="$1"
    local error_message="$2"

    if [ ! -f "$file_path" ]; then
        echo -e "${RED}错误: $error_message${NC}"
        return 1
    fi
    return 0
}

# 验证配置参数（兼容旧版bash）
validate_config_param_value() {
    local param_name="$1"
    local param_value="$2"

    case "$param_name" in
        "MODE")
            [[ "$param_value" =~ ^(time|scene|keyframe)$ ]] || return 1
            ;;
        "INTERVAL"|"MIN_INTERVAL"|"MAX_INTERVAL"|"KEYFRAME_MIN_INTERVAL"|"COLUMN")
            [[ "$param_value" =~ ^[1-9][0-9]*$ ]] || return 1
            ;;
        "QUALITY")
            [[ "$param_value" =~ ^([1-9]|[1-9][0-9]|100)$ ]] || return 1
            ;;
        "GAP")
            [[ "$param_value" =~ ^[0-9]+$ ]] || return 1
            ;;
        "PARALLEL_JOBS")
            [[ "$param_value" =~ ^([1-9][0-9]*|auto)$ ]] || return 1
            ;;
        "SCENE_THRESHOLD")
            [[ "$param_value" =~ ^0\.[1-9]$|^1\.0$ ]] || return 1
            ;;
        "FORMAT")
            [[ "$param_value" =~ ^(webp|jpg|jpeg|png)$ ]] || return 1
            ;;
        "MAX_FRAMES_PER_PART")
            [[ "$param_value" =~ ^[0-9]+$ ]] || return 1
            ;;
        "SCENE_DETECTION_MAX_SEGMENTS")
            # 支持 auto 或正整数
            [[ "$param_value" = "auto" ]] || [[ "$param_value" =~ ^[1-9][0-9]*$ ]] || return 1
            ;;
        "SCENE_DETECTION_SEGMENT_TIMEOUT")
            [[ "$param_value" =~ ^[0-9]+$ ]] || return 1
            ;;
        "SCENE_DETECTION_SEGMENTS_MULTIPLIER")
            [[ "$param_value" =~ ^[1-9][0-9]*$ ]] || return 1
            ;;
        *)
            return 0  # 未知参数不验证
            ;;
    esac
    return 0
}

# 获取参数描述
get_param_description() {
    local param_name="$1"
    case "$param_name" in
        "MODE") echo "截图模式 (time|smart|keyframe)" ;;
        "INTERVAL") echo "时间间隔 (正整数秒)" ;;
        "MIN_INTERVAL") echo "最小间隔 (正整数秒)" ;;
        "MAX_INTERVAL") echo "最大间隔 (正整数秒)" ;;
        "KEYFRAME_MIN_INTERVAL") echo "关键帧最小间隔 (正整数秒)" ;;
        "COLUMN") echo "列数 (正整数)" ;;
        "QUALITY") echo "图片质量 (1-100)" ;;
        "GAP") echo "间距 (非负整数像素)" ;;
        "PARALLEL_JOBS") echo "并行作业数 (正整数或auto)" ;;
        "SCENE_THRESHOLD") echo "场景阈值 (0.1-1.0)" ;;
        "FORMAT") echo "输出格式 (webp|jpg|jpeg|png)" ;;
        *) echo "未知参数" ;;
    esac
}

# 验证单个配置参数
validate_config_param() {
    local param_name="$1"
    local param_value="$2"

    # 跳过空值
    if [ -z "$param_value" ]; then
        return 0
    fi

    # 验证参数值
    if ! validate_config_param_value "$param_name" "$param_value"; then
        echo -e "${RED}错误: 配置参数 $param_name 的值 '$param_value' 无效${NC}"
        echo -e "${YELLOW}期望: $(get_param_description "$param_name")${NC}"
        return 1
    fi

    return 0
}

# 验证配置参数的逻辑关系
validate_config_logic() {
    # 验证间隔关系
    if [ -n "$MIN_INTERVAL" ] && [ -n "$MAX_INTERVAL" ]; then
        if [ "$MIN_INTERVAL" -ge "$MAX_INTERVAL" ]; then
            echo -e "${RED}错误: MIN_INTERVAL ($MIN_INTERVAL) 必须小于 MAX_INTERVAL ($MAX_INTERVAL)${NC}"
            return 1
        fi
    fi

    # 验证并行作业数
    if [ "$PARALLEL_JOBS" != "auto" ] && [ -n "$PARALLEL_JOBS" ]; then
        if [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] && [ "$PARALLEL_JOBS" -gt 16 ]; then
            echo -e "${YELLOW}警告: 并行作业数 ($PARALLEL_JOBS) 过高，建议不超过16${NC}"
        fi
    fi

    # 验证质量参数
    if [ -n "$QUALITY" ] && [ "$QUALITY" -lt 50 ]; then
        echo -e "${YELLOW}警告: 图片质量 ($QUALITY) 较低，可能影响预览效果${NC}"
    fi

    return 0
}

# 统一的配置加载函数
load_and_validate_config() {
    local config_file="$1"
    local config_type="$2"  # default|preset|custom

    if [ ! -f "$config_file" ]; then
        if [ "$config_type" = "default" ]; then
            echo -e "${YELLOW}警告: 默认配置文件不存在: $config_file${NC}"
            return 0
        else
            echo -e "${RED}错误: 配置文件不存在: $config_file${NC}"
            return 1
        fi
    fi

    echo -e "${YELLOW}加载配置文件: $config_file${NC}"

    # 读取配置文件并验证每个参数
    local line_num=0
    local validation_errors=0

    while IFS='=' read -r key value; do
        line_num=$((line_num + 1))

        # 跳过注释和空行
        if [[ "$key" =~ ^[[:space:]]*# ]] || [[ "$key" =~ ^[[:space:]]*$ ]]; then
            continue
        fi

        # 移除前后空格和注释
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/#.*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"//;s/"$//')

        # 验证参数
        if ! validate_config_param "$key" "$value"; then
            echo -e "${RED}  位置: $config_file:$line_num${NC}"
            validation_errors=$((validation_errors + 1))
            continue
        fi

        # 应用配置（使用与原来相同的逻辑）
        case "$key" in
            DEFAULT_MODE)
                if [ -z "$MODE" ]; then MODE="$value"; fi ;;
            DEFAULT_INTERVAL)
                if [ -z "$INTERVAL" ]; then INTERVAL="$value"; fi ;;
            DEFAULT_MIN_INTERVAL)
                if [ -z "$MIN_INTERVAL" ]; then MIN_INTERVAL="$value"; fi ;;
            DEFAULT_MAX_INTERVAL)
                if [ -z "$MAX_INTERVAL" ]; then MAX_INTERVAL="$value"; fi ;;
            DEFAULT_SCENE_THRESHOLD)
                if [ -z "$SCENE_THRESHOLD" ]; then SCENE_THRESHOLD="$value"; fi ;;
            DEFAULT_KEYFRAME_MIN_INTERVAL)
                if [ -z "$KEYFRAME_MIN_INTERVAL" ]; then KEYFRAME_MIN_INTERVAL="$value"; fi ;;
            DEFAULT_OUTPUT_DIR)
                if [ -z "$OUTPUT_DIR" ]; then OUTPUT_DIR="$value"; fi ;;
            DEFAULT_WIDTH)
                if [ -z "$WIDTH" ]; then WIDTH="$value"; fi ;;
            DEFAULT_QUALITY)
                if [ -z "$QUALITY" ]; then QUALITY="$value"; fi ;;
            DEFAULT_COLUMN)
                if [ -z "$COLUMN" ]; then COLUMN="$value"; fi ;;
            DEFAULT_GAP)
                if [ -z "$GAP" ]; then GAP="$value"; fi ;;
            DEFAULT_FORMAT)
                if [ -z "$FORMAT" ]; then FORMAT="$value"; fi ;;
            DEFAULT_FONT_PATH)
                if [ -z "$FONT_PATH" ]; then FONT_PATH="$value"; fi ;;
            USE_PARAMETER_SUFFIX)
                if [ "$SUFFIX_ENABLED_BY_USER" != true ]; then
                    USE_PARAMETER_SUFFIX="$value"
                fi ;;
            FORCE_OVERWRITE)
                if [ "$FORCE_ENABLED_BY_USER" != true ]; then
                    FORCE_OVERWRITE="$value"
                fi ;;
            MAX_IMAGE_DIMENSION) MAX_IMAGE_DIMENSION="$value" ;;
            GENERATE_HTML_REPORT)
                if [ "$HTML_REPORT_ENABLED_BY_USER" != true ]; then
                    GENERATE_HTML_REPORT="$value"
                fi ;;
            HTML_TITLE)
                if [ -z "$HTML_TITLE" ]; then HTML_TITLE="$value"; fi ;;
            HTML_THEME)
                if [ -z "$HTML_THEME" ]; then HTML_THEME="$value"; fi ;;
            DEFAULT_HTML_THEME)
                if [ -z "$HTML_THEME" ]; then HTML_THEME="$value"; fi ;;
            ENABLE_PARALLEL_PROCESSING)
                if [ "$PARALLEL_DISABLED_BY_USER" != true ]; then
                    ENABLE_PARALLEL_PROCESSING="$value"
                fi ;;
            DEFAULT_PARALLEL_JOBS)
                if [ -z "$PARALLEL_JOBS" ]; then PARALLEL_JOBS="$value"; fi ;;
            ENABLE_KEYFRAME_DETECTION) ENABLE_KEYFRAME_DETECTION="$value" ;;
            DEFAULT_FONT_FILE) DEFAULT_FONT_FILE="$value" ;;
            DEFAULT_MAX_FRAMES_PER_PART)
                if [ -z "$MAX_FRAMES_PER_PART" ]; then MAX_FRAMES_PER_PART="$value"; fi ;;
            SUPPORTED_VIDEO_FORMATS) SUPPORTED_VIDEO_FORMATS="$value" ;;
            HEADER_SPACING) HEADER_SPACING="$value" ;;
            THEME_PRIMARY) THEME_PRIMARY="$value" ;;
            THEME_BACKGROUND) THEME_BACKGROUND="$value" ;;
            THEME_SUCCESS) THEME_SUCCESS="$value" ;;
            THEME_WARNING) THEME_WARNING="$value" ;;
            THEME_ERROR) THEME_ERROR="$value" ;;
            THEME_INFO) THEME_INFO="$value" ;;
            # 场景检测配置（简化版）
            SCENE_DETECTION_MAX_SEGMENTS)
                SCENE_DETECTION_MAX_SEGMENTS="$value"
                export SCENE_DETECTION_MAX_SEGMENTS
                ;;
            SCENE_DETECTION_SEGMENT_TIMEOUT)
                SCENE_DETECTION_SEGMENT_TIMEOUT="$value"
                export SCENE_DETECTION_SEGMENT_TIMEOUT
                ;;
            SCENE_DETECTION_SEGMENTS_MULTIPLIER)
                SCENE_DETECTION_SEGMENTS_MULTIPLIER="$value"
                export SCENE_DETECTION_SEGMENTS_MULTIPLIER
                ;;
            *)
                echo -e "${YELLOW}警告: 未知配置参数 '$key' 在 $config_file:$line_num${NC}" ;;
        esac
    done < "$config_file"

    if [ $validation_errors -gt 0 ]; then
        echo -e "${RED}配置文件验证失败: $validation_errors 个错误${NC}"
        return 1
    fi

    echo -e "${GREEN}配置文件加载完成${NC}"
    return 0
}

# 获取并行作业数
get_parallel_jobs() {
    if [ "$DEFAULT_PARALLEL_JOBS" = "auto" ]; then
        detect_cpu_cores
    else
        echo "$DEFAULT_PARALLEL_JOBS"
    fi
}

# 生成输出文件名
generate_output_filename() {
    local base_name="$1"
    local output_dir="$2"
    local format="${3:-$FORMAT}"  # 使用传入的格式或全局FORMAT变量

    if [ "$USE_PARAMETER_SUFFIX" = true ]; then
        # 生成包含参数的文件名
        local suffix=""

        case "$MODE" in
            "scene")
                # 场景检测模式：video_scene_c5_min30_max300_t02_g5_q100.webp
                # 格式化阈值：0.2 -> t02, 0.15 -> t015
                local threshold_suffix=$(echo "$SCENE_THRESHOLD" | sed 's/0\.//' | sed 's/\.//')
                suffix="scene_c${COLUMN}_min${MIN_INTERVAL}_max${MAX_INTERVAL}_t${threshold_suffix}_g${GAP}_q${QUALITY}"
                ;;
            "keyframe")
                # 关键帧模式：video_keyframe_c5_min5_g5_q100.webp
                suffix="keyframe_c${COLUMN}_min${KEYFRAME_MIN_INTERVAL}_g${GAP}_q${QUALITY}"
                ;;
            *)
                # 时间模式：video_time_c5_i10_g5_q100.webp
                suffix="time_c${COLUMN}_i${INTERVAL}_g${GAP}_q${QUALITY}"
                ;;
        esac

        echo "${output_dir}/${base_name}_${suffix}.${format}"
    else
        # 简单文件名
        echo "${output_dir}/${base_name}.${format}"
    fi
}
