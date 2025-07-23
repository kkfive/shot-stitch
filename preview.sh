#!/bin/bash
# preview.sh - shot stitch
#
# Author: DreamyTZK
# Version: 0.1.0
# Description: Local video preview image generator

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 内置核心默认值（简化配置系统）
DEFAULT_INTERVAL=10
DEFAULT_QUALITY=90
DEFAULT_COLUMN=5
DEFAULT_MODE="time"
DEFAULT_FORMAT="jpg"
DEFAULT_GAP=5
ENABLE_PARALLEL_PROCESSING=true
DEFAULT_PARALLEL_JOBS="auto"

# 加载所有模块
load_modules() {
    local modules=(
        "core.sh"
        "args.sh"
        "video_info.sh"
        "scene_detect.sh"
        "keyframe.sh"
        "parallel.sh"
        "frame_extract.sh"
        "image_process.sh"
        "html_report.sh"
        "batch_process.sh"
    )
    
    for module in "${modules[@]}"; do
        local module_path="$SCRIPT_DIR/lib/$module"
        if [ -f "$module_path" ]; then
            source "$module_path"
        else
            echo "错误: 无法找到模块 $module" >&2
            exit 1
        fi
    done
}

# 主函数
main() {
    # 加载模块
    load_modules

    # 解析参数
    parse_arguments "$@"

    # 检查是否是向导模式
    if [ "$WIZARD_MODE" = true ]; then
        run_wizard
        # 向导完成后，VIDEO_FILE变量已设置，使用它作为INPUT_PATH
        INPUT_PATH="$VIDEO_FILE"
    fi

    # 验证参数
    validate_args

    # 检查依赖
    check_dependencies

    # 检测输入类型并处理
    if [ -d "$INPUT_PATH" ]; then
        # 目录批量处理
        batch_process_videos "$INPUT_PATH"
    elif [ -f "$INPUT_PATH" ]; then
        # 单个文件处理
        process_video "$INPUT_PATH"
    else
        error_exit "输入路径不存在: $INPUT_PATH"
    fi
}

# 错误处理
trap cleanup EXIT

# 启动主程序
main "$@"
