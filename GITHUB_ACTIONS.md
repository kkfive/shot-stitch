# GitHub Actions 工作流使用指南

## 概述

Shot Stitch 项目提供了一个 GitHub Actions 工作流，允许您通过 Web 界面自动生成视频截图，无需本地环境设置。

## 工作流功能

### 🎯 主要特性
- **在线处理**: 直接在 GitHub 上处理视频文件
- **灵活配置**: 支持多种预设模式和自定义参数
- **自动发布**: 生成的截图自动发布到指定仓库
- **进度跟踪**: 实时显示处理进度和文件信息

### 📋 输入参数

| 参数 | 描述 | 必需 | 默认值 | 类型 |
|------|------|------|--------|------|
| `video_url` | 视频文件的 URL | ✅ | - | string |
| `preset` | 预设模式 | ❌ | dynamic | choice |
| `target_repo` | 发布到的仓库 | ❌ | kkfive-action/private-screenshots | string |
| `custom_filename` | 自定义文件名（不含扩展名） | ❌ | - | string |

#### 预设模式选项
- **movie**: 电影模式，适合长片内容
- **lecture**: 讲座模式，适合教育内容
- **quick**: 快速模式，适合快速预览
- **dynamic**: 动态模式，适合变化频繁的内容

#### 自定义文件名说明
`custom_filename` 参数用于重命名下载的视频文件：

- **用途**: 将下载的视频文件重命名为指定名称
- **格式**: 不含扩展名，例如 `我的视频` 会保存为 `我的视频.mp4`
- **扩展名**: 自动从原始URL中提取扩展名
- **何时使用**:
  - URL中的文件名包含复杂字符或编码
  - 希望使用更简洁的文件名
  - 需要统一的命名规范

**示例**:
- URL: `http://example.com/n1815%20%E6%9D%B1%E7%86%B1.mp4`
- 自定义文件名: `东热激情`
- 实际保存: `东热激情.mp4`

## 使用步骤

### 1. 启动工作流
1. 访问 GitHub 仓库页面
2. 点击 "Actions" 标签
3. 在左侧选择 "生成视频截图" 工作流
4. 点击 "Run workflow" 按钮

### 2. 填写参数
- **视频 URL**: 输入可访问的视频文件直链
  - 支持 HTTP/HTTPS 协议
  - 建议使用稳定的文件托管服务
- **预设模式**: 根据视频类型选择合适的预设
- **发布到的仓库**: 指定存储截图的目标仓库
  - 格式: `owner/repo-name`
  - 需要有相应的访问权限
- **自定义文件名** (可选): 重命名下载的视频文件
  - 不含扩展名，例如：`我的视频`
  - 留空则使用URL中的原始文件名
  - 推荐在URL文件名复杂时使用

### 3. 监控执行
工作流包含以下主要步骤：
1. **验证输入**: 检查 URL 格式和参数有效性
2. **下载视频**: 从指定 URL 下载视频文件
3. **生成截图**: 使用 Docker 容器处理视频
4. **创建 Release**: 在目标仓库创建新的 Release
5. **上传文件**: 将生成的截图上传到 Release

### 4. 获取结果
- 工作流完成后，在目标仓库的 Releases 页面查看结果
- Release 包含所有生成的截图文件和 HTML 报告
- 可以直接下载单个文件或整个 Release

## 配置要求

### 权限设置
确保工作流有以下权限：
- 对目标仓库的写入权限
- 创建 Release 的权限
- 上传文件的权限

### 密钥配置
工作流使用以下 GitHub Secrets：
- `PRIVATE_REPO_TOKEN`: 用于访问目标仓库的 Personal Access Token
- `HOSTS_MAPPING` (可选): 自定义 hosts 映射

### Token 权限
Personal Access Token 需要以下权限：
- `repo`: 完整的仓库访问权限
- `write:packages`: 如果需要访问 GitHub Packages

## 故障排除

### 常见问题

#### 1. 视频下载失败
- **原因**: URL 无效或文件不可访问
- **解决**: 检查 URL 是否正确，确保文件可以直接访问

#### 2. 权限错误
- **原因**: Token 权限不足或目标仓库访问受限
- **解决**: 检查 Token 权限和仓库访问设置

#### 3. 处理超时
- **原因**: 视频文件过大或处理时间过长
- **解决**: 尝试使用较小的文件或调整预设模式

### 调试技巧
1. 查看工作流日志了解详细错误信息
2. 验证输入参数的格式和有效性
3. 检查目标仓库的访问权限
4. 确认 Secrets 配置正确

## 最佳实践

### 视频文件
- 使用稳定的文件托管服务
- 确保文件 URL 支持直接下载
- 避免使用过大的文件（建议 < 2GB）

### 仓库管理
- 定期清理旧的 Release 以节省空间
- 使用有意义的仓库名称和描述
- 设置适当的仓库访问权限

### 安全考虑
- 不要在公共仓库中暴露敏感的视频 URL
- 定期轮换 Personal Access Token
- 使用私有仓库存储敏感内容

## 示例

### 基本使用
```
视频 URL: https://example.com/video.mp4
预设模式: dynamic
发布到的仓库: myorg/screenshots
```

### 电影处理
```
视频 URL: https://cdn.example.com/movie.mkv
预设模式: movie
发布到的仓库: myorg/movie-screenshots
```

### 讲座视频
```
视频 URL: https://storage.example.com/lecture.mp4
预设模式: lecture
发布到的仓库: myorg/lecture-materials
```

### 使用自定义文件名
```
视频 URL: https://example.com/n1815%20%E6%9D%B1%E7%86%B1%E6%BF%80%E6%83%85.mp4
预设模式: movie
发布到的仓库: myorg/screenshots
自定义文件名: 东热激情_part1
```
*说明: 视频将保存为 `东热激情_part1.mp4`，生成的截图文件名也会基于此名称*

---

更多信息请参考 [README.md](README.md) 和 [CHANGELOG.md](CHANGELOG.md)。
