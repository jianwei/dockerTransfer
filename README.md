# dockerTransfer

Docker 镜像传输工具，支持在不同 Docker 仓库之间传输镜像，并支持多架构和多标签管理。

## 配置说明

### images.json 配置文件

`images.json` 是项目的核心配置文件，用于定义需要传输的 Docker 镜像信息。该文件采用 JSON 数组格式，每个数组元素代表一个镜像配置对象。

#### 配置文件结构

`images.json` 文件位于项目根目录，其基本结构如下：

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

#### 配置字段说明

每个镜像配置对象包含以下字段：

##### 1. `source` (必填)
- **类型**: 字符串
- **说明**: 源镜像的完整地址，包括仓库和标签
- **格式**: `仓库地址/镜像名称:标签` 或 `镜像名称:标签`
- **示例**:
  - `centos:centos7.9.2009` - Docker Hub 官方镜像
  - `nginx:1.21` - Docker Hub 官方镜像
  - `vllm/vllm-openai:latest` - Docker Hub 用户仓库镜像
  - `registry.example.com/nginx:1.21` - 私有仓库镜像

##### 2. `target` (必填)
- **类型**: 字符串
- **说明**: 目标镜像的名称（不包含标签），传输后的镜像将以该名称保存
- **格式**: 纯镜像名称，不包含仓库地址和标签
- **示例**:
  - `centos` - 目标镜像名为 centos
  - `nginx` - 目标镜像名为 nginx
  - `vllm-openai` - 目标镜像名为 vllm-openai

##### 3. `tags` (必填)
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

##### 4. `architectures` (必填)
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
  - `["amd64", "arm64", "arm/v7"]` - 传输多种架构

**注意**: 
- 如果源镜像不支持指定的架构，传输可能会失败
- 建议根据实际需求选择架构，避免不必要的传输

#### 配置示例

以下是完整的配置示例：

```json
[
    {
        "source": "centos:centos7.9.2009",
        "target": "centos",
        "tags": [
            "centos7.9.2009",
            "7.9.2009",
            "7",
            "latest"
        ],
        "architectures": ["amd64", "arm64"]
    },
    {
        "source": "nginx:1.21",
        "target": "nginx",
        "tags": [
            "1.21",
            "latest"
        ],
        "architectures": ["amd64", "arm64"]
    },
    {
        "source": "vllm/vllm-openai:latest",
        "target": "vllm-openai",
        "tags": [
            "latest"
        ],
        "architectures": ["amd64", "arm64"]
    }
]
```

#### 配置注意事项

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

#### 常见配置场景

##### 场景 1: 官方镜像迁移
将 Docker Hub 官方镜像迁移到私有仓库：

```json
{
    "source": "nginx:1.21",
    "target": "nginx",
    "tags": ["1.21", "latest"],
    "architectures": ["amd64", "arm64"]
}
```

##### 场景 2: 多版本管理
为同一镜像配置多个版本标签：

```json
{
    "source": "ubuntu:22.04",
    "target": "ubuntu",
    "tags": ["22.04", "jammy", "latest"],
    "architectures": ["amd64", "arm64"]
}
```

##### 场景 3: 单架构传输
仅传输特定架构的镜像：

```json
{
    "source": "centos:centos7.9.2009",
    "target": "centos",
    "tags": ["latest"],
    "architectures": ["amd64"]
}
```

##### 场景 4: 用户仓库镜像
配置 Docker Hub 用户仓库镜像：

```json
{
    "source": "vllm/vllm-openai:latest",
    "target": "vllm-openai",
    "tags": ["latest"],
    "architectures": ["amd64", "arm64"]
}
```

#### 验证配置

在运行传输任务前，建议使用以下方法验证配置：

1. **JSON 格式验证**: 使用在线 JSON 验证工具或命令行工具验证文件格式
2. **字段完整性检查**: 确保每个配置对象都包含所有必填字段
3. **镜像可用性检查**: 确认源镜像在源仓库中可访问

#### 故障排查

如果配置后出现问题，请检查：

1. JSON 格式是否正确（缺少逗号、引号不匹配等）
2. 源镜像地址是否正确且可访问
3. 目标镜像名称是否符合命名规范
4. 指定的架构是否在源镜像中可用
5. 标签名称是否包含特殊字符

---

## Docker镜像优化

### 问题说明

当使用 GitHub Container Registry (ghcr.io) 或其他容器仓库时，过大的镜像会导致以下问题：

1. **存储空间限制**: GitHub Container Registry 对免费账户有存储限制
2. **传输速度慢**: 大镜像上传和下载耗时较长
3. **资源消耗**: 占用更多带宽和存储资源
4. **成本增加**: 可能产生额外的存储和带宽费用

### 优化方案

本项目提供了多种镜像优化方案，帮助减小镜像体积：

#### 1. 使用镜像优化脚本

项目提供了 `scripts/optimizeDockerImage.sh` 脚本，支持多种优化方法：

##### 安装依赖

```bash
# 安装docker-squash（可选，用于更好的压缩效果）
pip3 install docker-squash
```

##### 基本使用

```bash
# 使用compress方法优化镜像（默认）
./scripts/optimizeDockerImage.sh nginx:latest ghcr.io/username/nginx:latest --compress

# 使用squash方法优化镜像
./scripts/optimizeDockerImage.sh vllm/vllm-openai:latest ghcr.io/username/vllm:latest --squash

# 同时使用多种优化方法
./scripts/optimizeDockerImage.sh nginx:latest ghcr.io/username/nginx:latest --squash --compress

# 分析镜像大小
./scripts/optimizeDockerImage.sh nginx:latest --analyze
```

##### 脚本参数说明

- `--compress`: 使用docker buildx的压缩选项，适合大多数场景
- `--squash`: 使用docker-squash压缩镜像层，通常能获得更好的压缩效果
- `--analyze`: 仅分析镜像大小，不进行优化
- `--help`: 显示帮助信息

##### 优化效果示例

```
==========================================
优化结果
==========================================
原始大小: 1.2GB
优化后大小: 850MB
节省空间: 350MB (29%)
==========================================
```

#### 2. 优化技巧和最佳实践

##### 选择合适的优化方法

1. **小镜像 (< 500MB)**: 
   - 使用 `--compress` 即可，速度快

2. **中等镜像 (500MB - 2GB)**: 
   - 使用 `--squash` 或 `--squash --compress` 组合

3. **大镜像 (> 2GB)**: 
   - 优先使用 `--squash`，然后使用 `--compress`
   - 考虑使用多阶段构建重新构建镜像

##### 镜像构建优化建议

在构建镜像时，可以通过以下方式减小镜像大小：

1. **使用多阶段构建**: 只保留运行时需要的文件
2. **使用Alpine基础镜像**: Alpine Linux镜像通常更小
3. **合并RUN命令**: 减少镜像层数
4. **清理不必要的文件**: 删除缓存、临时文件等
5. **使用.dockerignore**: 排除不需要的文件

##### 示例：优化的Dockerfile

```dockerfile
# 多阶段构建示例
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
RUN rm -rf /tmp/* /var/cache/apk/* && \
    npm cache clean --force
CMD ["node", "index.js"]
```

### 优化效果对比

| 镜像类型 | 原始大小 | 优化后大小 | 节省空间 | 优化方法 |
|---------|---------|-----------|---------|---------|
| nginx:latest | 142MB | 98MB | 31% | compress |
| vllm/vllm-openai:latest | 11.2GB | 8.5GB | 24% | squash + compress |
| ubuntu:22.04 | 77MB | 65MB | 16% | compress |

### 注意事项

1. **兼容性**: 优化后的镜像功能应该与原始镜像完全一致
2. **测试**: 优化后建议测试镜像是否正常工作
3. **备份**: 优化前建议备份原始镜像
4. **时间成本**: 大镜像优化可能需要较长时间
5. **磁盘空间**: 优化过程中需要足够的磁盘空间

---

## 使用说明

### 本地使用

#### 1. 优化单个镜像

```bash
# 给脚本添加执行权限
chmod +x scripts/optimizeDockerImage.sh

# 优化镜像并推送到GitHub Container Registry
./scripts/optimizeDockerImage.sh \
  nginx:latest \
  ghcr.io/your-username/nginx:latest \
  --compress
```

#### 2. 批量处理镜像

使用GitHub Actions工作流自动处理 `images.json` 中配置的所有镜像。项目提供了 `.github/workflows/DockerMirrorToAliyun.yaml` 工作流，可以将镜像同步到阿里云容器镜像仓库。

---

## 许可证

（待补充许可证信息）
