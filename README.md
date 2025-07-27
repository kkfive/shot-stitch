# 视频预览生成器

[![Version](https://img.shields.io/badge/version-0.5.0-blue.svg)](https://github.com/kkfive/shot-stitch)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-supported-blue.svg)](Dockerfile)

一个功能强大的本地视频预览图像生成器，具备智能场景检测、批量处理和 Docker 支持。零配置生成高质量视频缩略图。

## ✨ 核心特性

### 🎯 智能处理
- **三种捕获模式**: 时间间隔、场景检测和关键帧检测
- **智能宽度计算**: 基于列数和格式限制自动优化宽度
- **自动分割功能**: 大图像分割为平衡的部分，保持质量
- **动态超时**: 基于文件大小和时长智能调整超时时间

### 🧠 高级算法 (v0.2.0 全面升级)
- **场景检测优化**: 降采样分析，多线程处理，性能提升 2-5倍
- **关键帧检测优化**: 自适应算法选择，流式处理，性能提升 2-45倍
- **自适应策略**: 根据文件大小自动选择最佳算法
- **智能回退机制**: 多层回退保证 100% 兼容性
- **并行处理**: 多核并行捕获，支持大文件分段处理
- **批量处理**: 处理整个目录的视频文件

### 🚀 并行场景检测 (v0.4.0 重大突破)
- **分段并行算法**: 视频分段并行处理，性能提升3-5倍
- **实时进度监控**: `总进度:75% [分段0:✓ | 分段1:✓ | 分段2:60%]`
- **智能分段策略**: 基于CPU核心数动态调整，最多8个分段
- **超时问题解决**: 彻底解决大文件超时失败问题
- **macOS兼容**: 完美支持macOS环境，解决timeout命令问题

### 🎯 分批生成 (v0.3.0 新增)
- **智能分批**: 自动按帧数或尺寸限制分割大型预览图
- **灵活控制**: 支持用户自定义每部分最大帧数
- **强制分批**: 可强制启用分批模式，适合特殊需求

### 🎯 保留小图片功能 (v0.5.0 新增)
- **智能保留**: `--keep-frames` 参数，自动保留截图的小图片到与文件同名的文件夹
- **智能管理**: 自动清理已存在的小图片文件夹，避免混合不同处理结果
- **用户友好**: 清晰显示保留的图片数量和存储位置
- **灵活配置**: 可通过配置文件设置默认行为

### 🔧 场景检测算法重构 (v0.5.0 新增)
- **算法优化**: 重构场景检测核心逻辑，移除过度优化模式
- **配置增强**: 新增分段倍数控制，支持auto和数字两种分段模式
- **进度优化**: 使用两位数分段编号，提升可读性和用户体验
- **稳定性提升**: 严格遵守用户配置，改进错误处理和进度监控

### 🔧 稳定性增强 (v0.4.2)
- **并行处理修复**: 修复FFmpeg输出重定向错误，恢复并行场景检测功能
- **智能阈值调整**: 自动调整过高的场景检测阈值，提高检测成功率
- **错误处理改进**: 增强后台进程管理和错误恢复机制
- **进度显示优化**: 提供更准确的进度反馈和状态报告

### 🌐 国际化支持 (v0.4.1 新增)
- **中文文件名支持**: 自动检测并解码URL编码的中文文件名
- **多语言兼容**: 支持中文、日文等多种语言文件名
- **智能显示**: 预览图显示可读的中文名称，而非URL编码
- **ImageMagick兼容**: 修复特殊字符导致的警告和错误

### 📊 性能表现 (v0.4.0)
| 视频规模 | v0.3.0 | v0.4.0 | 提升幅度 |
|---------|--------|--------|----------|
| 2.4GB, 40分钟 | 133秒 | 132秒 | 基准 |
| 5.8GB, 112分钟 | 超时失败 | ~5-8分钟 | **从失败到成功** |
| 10GB+ 大文件 | 超时失败 | ~10-15分钟 | **3-5倍提升** |
- **预设优化**: 各预设模板内置最佳分批参数

### 📊 用户体验
- **实时进度**: 所有处理步骤的详细百分比进度
- **增强标题**: 紧凑的标题和文件名显示，包含分割信息
- **时间戳显示**: 每个缩略图的精确时间点
- **性能保护**: 20 列限制防止 ImageMagick 问题

### 🎨 输出定制
- **网格间距控制**: 可调整缩略图之间的间距
- **多种格式**: WebP/JPG/PNG 支持，智能格式处理
- **HTML 报告**: 专业分析报告，现代/简洁主题
- **智能命名**: 可选参数后缀命名，避免冲突
- **Web预览器**: 内置发布资源预览器，支持图片查看和下载 (v0.3.0)

### 🔧 技术卓越
- **预设模板**: 针对不同视频类型的 3 个优化预设
- **模块化架构**: 清洁、可维护、可扩展的代码库
- **配置管理**: 统一配置系统，智能验证

## 🚀 快速演示

```bash
# 基本用法 - 几秒钟内生成视频预览
./preview.sh video.mp4

# 场景检测模式，智能识别场景变化 (推荐)
./preview.sh video.mp4 --mode scene

# 电影高质量关键帧模式
./preview.sh video.mp4 --preset movie

# 动态内容密集截图模式
./preview.sh video.mp4 --preset dynamic

# 分批生成模式 - 每部分最多30帧
./preview.sh video.mp4 --max-frames-per-part 30

# 批量处理整个目录
./preview.sh ./videos/
```

**示例输出:**
- 带时间戳的高质量网格布局
- 自动格式优化 (WebP/JPG/PNG)
- 专业 HTML 报告
- 智能文件命名，避免冲突

## 📦 安装

### 🐳 Docker (推荐)

**零依赖一键设置:**

```bash
# 快速开始
docker run --rm -v $(pwd):/data video-preview-tool video.mp4

# 从源码构建
git clone https://github.com/kkfive/shot-stitch.git
cd shot-stitch
docker build -t video-preview-tool .
docker run --rm -v $(pwd):/data video-preview-tool video.mp4
```

### 📦 本地安装

**依赖要求:**
- **FFmpeg**: 视频处理和帧提取
- **ImageMagick**: 图像处理和合成
- **bc**: 数学计算

**安装依赖:**

```bash
# macOS
brew install ffmpeg imagemagick bc

# Ubuntu/Debian
sudo apt update && sudo apt install ffmpeg imagemagick bc

# CentOS/RHEL/Fedora
sudo dnf install ffmpeg ImageMagick bc
```

## 🚀 快速开始

### 基本用法

```bash
# 使用默认设置生成预览
./preview.sh video.mp4

# 场景检测模式，智能识别场景变化 (推荐)
./preview.sh video.mp4 --mode scene

# 高质量关键帧模式
./preview.sh video.mp4 --mode keyframe

# 使用优化预设
./preview.sh video.mp4 --preset movie

# 动态内容预设
./preview.sh video.mp4 --preset dynamic

# 批量处理目录
./preview.sh ./videos/

# 生成 HTML 报告
./preview.sh video.mp4 --html --preset movie

# 保留截图的小图片
./preview.sh video.mp4 --keep-frames

# 动态内容优化处理
./preview.sh video.mp4 --preset dynamic --keep-frames
```

### 高级示例

```bash
# 自定义参数
./preview.sh video.mp4 --mode scene --min-interval 60 --max-interval 300 --column 4 --quality 90

# 高密度捕获
./preview.sh video.mp4 --column 8 --interval 30 --format webp

# 大文件处理 (自动分割)
./preview.sh large_video.mkv --mode keyframe --column 6

# 强制分批生成
./preview.sh video.mp4 --force-split --max-frames-per-part 25

# 保留小图片并使用动态预设 (v0.5.0)
./preview.sh video.mp4 --preset dynamic --keep-frames --html

# 中文文件名支持 (v0.4.1)
./preview.sh "movie%20%E4%B8%AD%E6%96%87%E7%94%B5%E5%BD%B1.mp4" --mode scene
# 自动解码为: movie 中文电影.mp4
```

## 📖 API 参考

### 命令语法
```bash
./preview.sh <视频文件或目录> [选项]
```

### 核心参数

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `--mode <time\|scene\|keyframe>` | 捕获模式 | time |
| `--interval <秒数>` | 捕获时间间隔 | 10 |
| `--min-interval <秒数>` | 场景检测模式最小间隔 | 30 |
| `--max-interval <秒数>` | 场景检测模式最大间隔 | 300 |
| `--scene-threshold <0.1-1.0>` | 场景变化敏感度 | 0.3 |
| `--keyframe-min <秒数>` | 关键帧模式最小间隔 | 5 |
| `--quality <1-100>` | 图像质量 (越高越好) | 100 |
| `--column <数量>` | 网格列数 (最大 20) | 5 |
| `--format <webp\|jpg\|png>` | 输出格式 | webp |
| `--preset <name>` | 使用预设配置 | - |
| `--html` | 生成 HTML 报告 | - |
| `--jobs <数量\|auto>` | 并行处理任务数 | auto |
| `--max-frames-per-part <数量>` | 每部分最大帧数，用于分批生成 | 0 (使用尺寸限制) |
| `--force-split` | 强制启用分批生成模式 | - |
| `--force` | 覆盖现有文件 | - |
| `--keep-frames` | 保留截图的小图片到与文件同名的文件夹 | - |
| `--help` | 显示帮助信息 | - |

### 🚀 高级配置

对于高级用户，可以通过预设配置文件自定义更多参数，如并行场景检测、分批生成等。

> 📋 **高级配置**: 查看 [presets/](presets/) 目录中的配置文件了解所有可用参数

### 可用预设

使用 `--preset <name>` 参数选择预设模式：
- `movie` - 电影、电视剧优化
- `lecture` - 讲座、会议优化
- `quick` - 快速预览模式
- `dynamic` - 动态内容优化

> 📋 **详细配置**: 查看 [presets/](presets/) 目录了解每个预设的具体参数

## 🎛️ 捕获模式

### 时间模式 (默认)
- **最适合**: 通用目的，一致间隔
- **工作原理**: 按固定时间间隔捕获帧
- **使用场景**: 快速预览，均匀采样

### 场景检测模式 (推荐) ⚡ v0.4.0 重大升级
- **最适合**: 有场景变化的动态内容
- **工作原理**: 基于视觉内容变化的智能检测
- **使用场景**: 电影、纪录片、多样化内容
- **性能优化**: 降采样分析，多线程处理，2-5倍性能提升
- **🚀 并行算法**: 分段并行处理，大文件性能提升3-5倍
- **📊 实时监控**: 显示每个分段的处理进度
- **🔧 智能分段**: 基于CPU核心数动态调整分段策略

### 关键帧模式 (高质量)
- **最适合**: 高质量内容，电影
- **工作原理**: 检测并捕获 I 帧 (关键帧)
- **使用场景**: 优质内容，详细分析
- **性能优化**: 自适应算法选择，流式处理，2-45倍性能提升

## 🎯 分批生成详解

### 什么是分批生成
分批生成功能可以将大量截图自动分割成多个较小的预览图文件，避免单个文件过大导致的问题：
- **内存限制**: 避免ImageMagick内存不足
- **文件大小**: 控制单个文件大小，便于分享和查看
- **加载性能**: 提升大型预览图的加载速度

### 分批触发条件
1. **用户强制**: 使用 `--force-split` 参数
2. **帧数限制**: 使用 `--max-frames-per-part` 设置每部分最大帧数
3. **尺寸限制**: 自动检测图像尺寸是否超出格式限制

### 分批参数说明
- `--max-frames-per-part 30`: 每个部分最多30帧
- `--force-split`: 强制启用分批模式
- 设置为0表示使用尺寸限制逻辑（默认行为）

### 分批示例
```bash
# 每部分最多25帧
./preview.sh video.mp4 --max-frames-per-part 25

# 强制分批，使用预设的分批参数
./preview.sh video.mp4 --force-split --preset dynamic

# 结合其他参数使用
./preview.sh video.mp4 --mode scene --max-frames-per-part 20 --column 4
```

## 🌐 Web预览器

项目内置了现代化的Web预览器 (`index.html`)，提供图片查看、批量下载、格式转换等功能。

**使用方法**: 在浏览器中打开 `index.html`，拖拽或选择图片文件进行查看。

> 📋 **功能详情**: 查看 [index.html](index.html) 了解完整的预览器功能

## 🤖 GitHub Actions 工作流

### 自动化截图生成
项目内置了GitHub Actions工作流，支持通过Web界面自动生成视频截图：

#### 功能特性
- **在线处理**: 无需本地环境，直接在GitHub上处理视频
- **灵活配置**: 支持自定义预设模式和目标仓库
- **自动发布**: 生成的截图自动发布到指定仓库的Releases
- **进度跟踪**: 实时显示下载和处理进度

#### 使用方法
1. 在GitHub仓库页面点击 "Actions" 标签
2. 选择 "生成视频截图" 工作流
3. 点击 "Run workflow" 并填写参数：
   - **视频URL**: 要处理的视频文件链接
   - **预设模式**: 选择预设配置（movie/lecture/quick/dynamic）
   - **目标仓库**: 发布截图的仓库（默认：kkfive-action/private-screenshots）
4. 等待工作流完成，在目标仓库的Releases中下载结果

#### 参数说明
- `video_url`: 支持HTTP/HTTPS的视频文件直链
- `preset`: 预设模式，影响截图质量和数量
- `target_repo`: 格式为 `owner/repo-name`，需要有相应的访问权限

> 📖 **详细配置**: 查看 [工作流文件](.github/workflows/generate-screenshots.yml) 了解完整的参数配置

## 🎨 预设模式

本项目提供4种优化预设，每种针对不同的视频类型进行了专门优化：

| 预设 | 适用场景 | 核心特点 |
|------|----------|----------|
| **Movie** | 电影、电视剧、纪录片 | 关键帧检测，保证重要场景不遗漏 |
| **Lecture** | 讲座、会议、教程 | 时间间隔模式，适合变化较慢的内容 |
| **Quick** | 快速预览、批量处理 | 速度优先，快速了解视频概况 |
| **Dynamic** | 动作片、游戏视频 | 场景检测，密集捕获动态变化 |

> 📋 **详细配置**: 查看 [presets/](presets/) 目录中的具体配置文件了解每个预设的详细参数

## �🏗️ 项目结构

```
shot-stitch/
├── preview.sh              # 主入口点
├── index.html              # Web预览器 (v0.3.0)
├── .github/                # GitHub Actions 工作流
│   └── workflows/
│       └── generate-screenshots.yml  # 自动化截图生成
├── lib/                    # 核心模块
│   ├── core.sh             # 核心功能
│   ├── args.sh             # 参数解析
│   ├── video_info.sh       # 视频信息
│   ├── scene_detect.sh     # 场景检测
│   ├── keyframe.sh         # 关键帧检测
│   ├── parallel.sh         # 并行处理
│   ├── frame_extract.sh    # 帧提取
│   ├── image_process.sh    # 图像处理 (分批生成)
│   ├── html_report.sh      # HTML 报告
│   └── batch_process.sh    # 批量处理
├── presets/                # 配置预设
│   ├── movie.conf          # 电影预设 (含分批配置)
│   ├── lecture.conf        # 讲座预设 (含分批配置)
│   ├── quick.conf          # 快速预设 (含分批配置)
│   └── dynamic.conf        # 动态内容预设 (含分批配置)
├── font/                   # 字体文件
├── README.md               # 本文件
├── CHANGELOG.md            # 更新日志
├── CONTRIBUTING.md         # 贡献指南
├── DOCKER_USAGE.md         # Docker 使用指南
└── LICENSE                 # MIT 许可证
```

## 🤝 贡献

我们欢迎贡献！请查看我们的 [贡献指南](CONTRIBUTING.md) 了解详情。

### 开发设置

```bash
git clone https://github.com/kkfive/shot-stitch.git
cd shot-stitch
chmod +x preview.sh
./preview.sh --help
```

## 📝 更新日志

查看完整的更新日志，请参阅 [CHANGELOG.md](CHANGELOG.md)。

## 📄 许可证

本项目采用 MIT 许可证 - 详情请查看 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- **FFmpeg** - 强大的视频处理框架
- **ImageMagick** - 全面的图像处理工具包
- **社区** - 感谢所有贡献者和用户

---

**为视频处理社区用 ❤️ 制作**
