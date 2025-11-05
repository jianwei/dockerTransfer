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

## 使用说明

（待补充项目具体使用方法）

## 许可证

（待补充许可证信息）
