# Docker 使用指南

## 快速开始

### 拉取并运行

```bash
# 拉取最新镜像
docker pull dreamytzk/shot-stitch:latest

# 为视频文件生成预览
docker run --rm -v $(pwd):/data dreamytzk/shot-stitch:latest /data/video.mp4

# 使用预设
docker run --rm -v $(pwd):/data dreamytzk/shot-stitch:latest /data/video.mp4 --preset movie

# 批量处理目录
docker run --rm -v $(pwd):/data dreamytzk/shot-stitch:latest /data/videos/
```

### 常见使用模式

#### 基本视频处理
```bash
# 挂载当前目录并处理视频
docker run --rm -v $(pwd):/data dreamytzk/shot-stitch:latest /data/movie.mp4
```

#### 自定义输出目录
```bash
# 挂载特定目录
docker run --rm \
  -v /path/to/videos:/input \
  -v /path/to/output:/output \
  dreamytzk/shot-stitch:latest \
  /input/video.mp4 --output-dir /output
```

#### 高级选项
```bash
# 高质量关键帧模式，带 HTML 报告
docker run --rm -v $(pwd):/data dreamytzk/shot-stitch:latest \
  /data/video.mp4 \
  --mode keyframe \
  --column 6 \
  --quality 95 \
  --html \
  --force
```

### 可用预设

| 预设 | 最适合 | 示例 |
|------|--------|------|
| `movie` | 电影、电视剧 | `--preset movie` |
| `lecture` | 讲座、会议 | `--preset lecture` |
| `quick` | 快速预览 | `--preset quick` |

### 卷挂载

Docker 镜像期望文件挂载在 `/data`:

```bash
# 挂载当前目录
-v $(pwd):/data

# 挂载特定目录
-v /path/to/videos:/data

# 挂载多个目录
-v /path/to/input:/input -v /path/to/output:/output
```

### 输出文件

生成的文件将出现在挂载的目录中:
- `video_preview.webp` - 主预览图像
- `video_preview_report.html` - HTML 报告 (如果使用了 `--html`)

### 故障排除

#### 权限问题
```bash
# 使用当前用户 ID 运行
docker run --rm --user $(id -u):$(id -g) -v $(pwd):/data dreamytzk/shot-stitch:latest /data/video.mp4
```

#### 大文件
```bash
# 为大视频增加共享内存
docker run --rm --shm-size=2g -v $(pwd):/data dreamytzk/shot-stitch:latest /data/large_video.mp4
```

### 本地构建

如果您想自己构建镜像:

```bash
# 克隆仓库
git clone https://github.com/kkfive/shot-stitch.git
cd shot-stitch

# 构建镜像
docker build -t shot-stitch:local .

# 测试构建
./scripts/test-docker.sh
```
