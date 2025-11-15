# Docker 镜像传输工具

一个基于 GitHub Actions 和 skopeo 的 Docker 镜像自动同步工具，支持在不同容器仓库之间传输镜像，并提供多架构（amd64、arm64）和多标签管理功能。

## 功能特性

- ✅ **多架构支持**: 自动识别并同步 amd64 和 arm64 架构的镜像
- ✅ **多标签管理**: 支持为同一镜像配置多个标签
- ✅ **自动化同步**: 基于 GitHub Actions 的定时任务和手动触发
- ✅ **智能重试**: 内置重试机制，提高传输成功率
- ✅ **错误处理**: 完善的错误处理和日志输出
- ✅ **多仓库支持**: 支持 Docker Hub、GitHub Container Registry、阿里云容器镜像服务等

## 项目结构

```
dockerTransfer/
├── .github/
│   └── workflows/
│       └── syncImage.yaml      # GitHub Actions 工作流配置
├── images.json                 # 镜像配置文件
└── README.md                   # 项目说明文档
```

## 快速开始

### 1. 配置镜像列表

编辑 `images.json` 文件，添加需要同步的镜像配置：

```json
[
    {
        "source": "nginx:latest",
        "target": "nginx",
        "tags": ["latest"],
        "architectures": ["amd64", "arm64"]
    }
]
```

### 2. 配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets：

- `ALIYUN_USERNAME`: 阿里云容器镜像服务的用户名
- `ALIYUN_PASSWORD`: 阿里云容器镜像服务的密码
- `ALIYUN_NAMESPACE`: 阿里云容器镜像服务的命名空间

### 3. 触发同步

#### 方式一：手动触发

1. 进入 GitHub 仓库的 Actions 页面
2. 选择 "Sync Image to Aliyun With skopeo" 工作流
3. 点击 "Run workflow" 按钮

#### 方式二：定时触发

工作流已配置为每天凌晨 2 点（UTC）自动执行，可在 `.github/workflows/syncImage.yaml` 中修改 cron 表达式。

## 配置文件说明

### images.json 结构

`images.json` 是项目的核心配置文件，采用 JSON 数组格式，每个元素代表一个镜像配置对象。

#### 基本结构

```json
[
    {
        "source": "源镜像地址",
        "target": "目标镜像名称",
        "tags": ["标签列表"],
        "architectures": ["架构列表"]
    }
]
```

#### 字段说明

##### `source` (必填)

- **类型**: 字符串
- **说明**: 源镜像的完整地址，包括仓库和标签
- **格式**: `仓库地址/镜像名称:标签` 或 `镜像名称:标签`
- **示例**:
  - `nginx:latest` - Docker Hub 官方镜像
  - `vllm/vllm-openai:latest` - Docker Hub 用户仓库镜像
  - `ghcr.io/open-webui/open-webui:main` - GitHub Container Registry 镜像
  - `registry.example.com/nginx:1.21` - 私有仓库镜像

##### `target` (必填)

- **类型**: 字符串
- **说明**: 目标镜像的名称（不包含标签），传输后的镜像将以该名称保存
- **格式**: 纯镜像名称，不包含仓库地址和标签
- **示例**:
  - `nginx` - 目标镜像名为 nginx
  - `vllm-openai` - 目标镜像名为 vllm-openai

##### `tags` (必填)

- **类型**: 字符串数组
- **说明**: 目标镜像的标签列表，源镜像会被推送为这些标签
- **格式**: 字符串数组，每个元素代表一个标签
- **示例**:
  - `["latest"]` - 仅推送 latest 标签
  - `["1.21", "latest"]` - 推送 1.21 和 latest 两个标签
  - `["centos7.9.2009", "7.9.2009", "7", "latest"]` - 推送多个版本标签

**注意**: 
- 同一个源镜像可以被打上多个目标标签
- 标签顺序不影响传输结果
- 建议至少包含一个 `latest` 标签以便于使用

##### `architectures` (必填)

- **类型**: 字符串数组
- **说明**: 需要传输的镜像架构列表
- **可选值**: 
  - `amd64` - x86_64 架构（Intel/AMD 64位）
  - `arm64` - ARM 64位架构（如 Apple Silicon、AWS Graviton）
  - `arm/v7` - ARM 32位架构
  - `ppc64le` - PowerPC 64位小端架构
  - `s390x` - IBM Z 架构
- **示例**:
  - `["amd64"]` - 仅传输 amd64 架构
  - `["amd64", "arm64"]` - 传输 amd64 和 arm64 两种架构

**注意**: 
- 如果源镜像不支持指定的架构，传输可能会失败
- 建议根据实际需求选择架构，避免不必要的传输
- 当前工作流主要支持 `amd64` 和 `arm64` 架构

### 配置示例

#### 示例 1: 基础镜像同步

```json
{
    "source": "nginx:latest",
    "target": "nginx",
    "tags": ["latest"],
    "architectures": ["amd64", "arm64"]
}
```

#### 示例 2: 多版本标签

```json
{
    "source": "ubuntu:22.04",
    "target": "ubuntu",
    "tags": ["22.04", "jammy", "latest"],
    "architectures": ["amd64", "arm64"]
}
```

#### 示例 3: 用户仓库镜像

```json
{
    "source": "vllm/vllm-openai:v0.11.0",
    "target": "vllm-openai",
    "tags": ["v0.11.0", "latest"],
    "architectures": ["amd64", "arm64"]
}
```

#### 示例 4: GitHub Container Registry 镜像

```json
{
    "source": "ghcr.io/open-webui/open-webui:main",
    "target": "open-webui",
    "tags": ["main", "latest"],
    "architectures": ["amd64", "arm64"]
}
```

### 配置注意事项

1. **JSON 格式要求**:
   - 文件必须是有效的 JSON 格式
   - 字符串必须使用双引号，不能使用单引号
   - 数组最后一个元素后面不能有逗号
   - 建议使用 JSON 验证工具检查格式是否正确

2. **镜像命名规范**:
   - `source` 字段必须包含完整的镜像标识（仓库/名称:标签）
   - `target` 字段只需包含镜像名称，不应包含标签
   - 标签名称应遵循 Docker 标签命名规范（字母、数字、下划线、连字符、点）

3. **架构选择建议**:
   - 根据目标环境选择合适的架构
   - 多架构支持会增加传输时间和存储空间
   - 确保源镜像仓库支持指定的架构

4. **标签管理**:
   - 建议为每个镜像配置语义化的版本标签
   - 保留 `latest` 标签以便于使用
   - 避免使用过多标签，以免增加管理复杂度

## 工作流说明

### 工作流特性

- **自动多架构处理**: 自动识别源镜像是否支持多架构，并分别处理每个架构
- **智能重试机制**: 每个镜像传输操作最多重试 5 次
- **超时保护**: 
  - amd64 架构传输超时时间：60 分钟
  - arm64 架构传输超时时间：30 分钟
- **错误恢复**: 如果某个架构传输失败，会继续处理其他架构
- **磁盘空间管理**: 自动清理 Docker 系统以释放磁盘空间

### 工作流程

1. **环境准备**: 安装 skopeo、jq 等必要工具
2. **登录认证**: 登录到目标容器镜像仓库（阿里云）
3. **镜像处理**: 遍历 `images.json` 中的每个镜像配置
4. **架构同步**: 对于每个标签，分别同步 amd64 和 arm64 架构
5. **多架构清单**: 如果两个架构都成功，创建多架构 manifest list
6. **清理工作**: 清理临时文件和释放磁盘空间

### 执行时间

- **定时执行**: 每天 UTC 时间 02:00（北京时间 10:00）
- **手动触发**: 随时可以通过 GitHub Actions 界面手动触发
- **超时设置**: 整个工作流最多运行 2 小时

## 使用场景

### 场景 1: 镜像迁移

将 Docker Hub 或其他公共仓库的镜像迁移到私有仓库（如阿里云容器镜像服务）：

```json
{
    "source": "nginx:1.21",
    "target": "nginx",
    "tags": ["1.21", "latest"],
    "architectures": ["amd64", "arm64"]
}
```

### 场景 2: 镜像备份

定期备份重要的生产环境镜像：

```json
{
    "source": "myapp:production",
    "target": "myapp-backup",
    "tags": ["production", "latest"],
    "architectures": ["amd64"]
}
```

### 场景 3: 多架构镜像构建

为不同架构的平台提供统一的镜像访问入口：

```json
{
    "source": "myapp:latest",
    "target": "myapp",
    "tags": ["latest"],
    "architectures": ["amd64", "arm64"]
}
```

## 故障排查

### 常见问题

#### 1. 镜像传输失败

**问题**: 工作流执行时出现镜像传输失败

**排查步骤**:
1. 检查源镜像地址是否正确且可访问
2. 确认源镜像是否支持指定的架构
3. 检查网络连接是否正常
4. 查看工作流日志中的详细错误信息

#### 2. 认证失败

**问题**: 登录目标仓库时认证失败

**排查步骤**:
1. 检查 GitHub Secrets 中的用户名和密码是否正确
2. 确认命名空间（namespace）是否正确
3. 验证账户是否有推送权限

#### 3. 架构不支持

**问题**: 某些架构的镜像传输失败

**排查步骤**:
1. 使用 `skopeo inspect` 命令检查源镜像支持的架构
2. 如果源镜像不支持指定架构，从 `architectures` 数组中移除该架构
3. 工作流会自动处理单架构镜像的情况

#### 4. JSON 格式错误

**问题**: 工作流无法解析 `images.json` 文件

**排查步骤**:
1. 使用 JSON 验证工具检查文件格式
2. 确认所有字符串都使用双引号
3. 检查是否有多余的逗号或缺少逗号
4. 验证数组和对象的括号是否匹配

### 调试技巧

1. **查看详细日志**: 工作流已启用 `set -x`，会显示所有执行的命令
2. **手动测试**: 可以在本地使用 skopeo 命令手动测试镜像传输
3. **检查磁盘空间**: 工作流会输出磁盘使用情况，确保有足够的空间

## 技术栈

- **skopeo**: 用于容器镜像的传输和管理
- **GitHub Actions**: 提供 CI/CD 自动化能力
- **jq**: 用于 JSON 文件的解析和处理
- **Docker Registry API**: 用于创建多架构 manifest list

## 许可证

（待补充许可证信息）

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 更新日志

### 当前版本

- ✅ 支持多架构镜像同步（amd64、arm64）
- ✅ 支持多标签管理
- ✅ 自动创建多架构 manifest list
- ✅ 完善的错误处理和重试机制
- ✅ 定时任务和手动触发支持
