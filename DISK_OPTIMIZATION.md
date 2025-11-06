# 磁盘空间扩容和优化方案

## 问题说明

GitHub Actions 托管 runner 的磁盘空间有限（通常约 14GB 工作空间，总磁盘约 72GB），在处理大型 Docker 镜像时可能會遇到磁盘空间不足的问题。

## 解决方案

### 方案 1: 使用自托管 Runner（推荐）

自托管 runner 可以自定义磁盘大小和配置，是最灵活的解决方案。

#### 步骤 1: 设置自托管 Runner

1. **准备服务器**
   - 推荐：至少 100GB 磁盘空间
   - 操作系统：Ubuntu 20.04+ 或类似 Linux 发行版
   - 安装 Docker 和 Docker Compose

2. **安装 GitHub Actions Runner**

```bash
# 创建 runner 目录
mkdir actions-runner && cd actions-runner

# 下载最新版本（替换 YOUR_TOKEN 和 YOUR_REPO）
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# 解压
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# 配置 runner（需要 Personal Access Token）
./config.sh --url https://github.com/YOUR_USERNAME/YOUR_REPO --token YOUR_TOKEN --labels large-disk --name docker-mirror-runner

# 安装为服务
sudo ./svc.sh install
sudo ./svc.sh start
```

3. **修改工作流使用自托管 Runner**

在工作流文件中修改 `runs-on`：

```yaml
jobs:
  sync-images:
    runs-on: [self-hosted, large-disk]  # 使用自托管 runner
```

#### 优势
- ✅ 完全控制磁盘大小
- ✅ 可以配置更大的磁盘（500GB+）
- ✅ 不受 GitHub 托管 runner 的限制
- ✅ 可以配置专用网络和存储

#### 注意事项
- ⚠️ 需要维护服务器
- ⚠️ 需要确保服务器安全
- ⚠️ 需要稳定的网络连接

---

### 方案 2: 优化镜像处理策略

已优化的工作流现在会：

1. **智能分批处理**
   - 优先处理大镜像（如 vllm, pytorch）
   - 大镜像逐个处理，避免同时处理多个大镜像
   - 普通镜像批量处理

2. **及时清理**
   - 镜像推送后立即删除
   - 根据磁盘使用率动态清理
   - 大镜像处理完后强制清理

3. **磁盘监控**
   - 实时监控磁盘使用率
   - 在操作前检查可用空间
   - 智能清理策略

---

### 方案 3: 使用 Docker Buildx 的缓存到外部存储

如果使用自托管 runner，可以配置 Docker 使用外部存储：

```bash
# 在 runner 服务器上配置 Docker daemon.json
sudo nano /etc/docker/daemon.json

# 添加以下配置（挂载更大的磁盘到 /mnt/docker）
{
  "data-root": "/mnt/docker"
}

# 重启 Docker
sudo systemctl restart docker
```

---

### 方案 4: 分批处理镜像（手动）

如果暂时无法使用自托管 runner，可以将镜像分批处理：

1. **创建多个 JSON 文件**
   - `images-large.json` - 包含大镜像
   - `images-small.json` - 包含小镜像

2. **创建多个工作流**
   - 分别处理大镜像和小镜像
   - 使用不同的触发时间

---

### 方案 5: 使用 GitHub Actions 的更大 Runner（如果可用）

某些 GitHub 计划可能提供更大的 runner，可以尝试：

```yaml
jobs:
  sync-images:
    # 尝试使用更大的 runner（如果可用）
    runs-on: ubuntu-latest-4-cores  # 示例，实际标签可能不同
    # 或
    runs-on: ubuntu-latest-8-cores  # 示例
```

**注意**: GitHub 托管 runner 的磁盘空间通常是固定的，这个方案可能不适用。

---

## 当前工作流的优化

当前工作流已包含以下优化：

1. ✅ **智能镜像分类**: 自动识别并优先处理大镜像
2. ✅ **动态清理策略**: 根据磁盘使用率智能清理
3. ✅ **及时资源释放**: 镜像推送后立即删除
4. ✅ **详细日志**: 显示清理前后的磁盘使用情况
5. ✅ **重试机制**: 拉取失败时自动清理并重试

---

## 推荐配置

### 小型项目（镜像总数 < 10，单个镜像 < 2GB）
- 使用当前的优化工作流
- 不需要额外配置

### 中型项目（镜像总数 10-50，有大镜像 < 10GB）
- 使用当前的优化工作流
- 考虑使用自托管 runner（50-100GB 磁盘）

### 大型项目（镜像总数 > 50，有大镜像 > 10GB）
- **强烈推荐使用自托管 runner**
- 配置至少 200GB+ 磁盘空间
- 考虑使用 SSD 提升性能

---

## 自托管 Runner 配置示例

### 基本配置（Docker Compose）

```yaml
version: '3.8'

services:
  github-runner:
    image: myoung34/github-runner:latest
    environment:
      RUNNER_NAME: docker-mirror-runner
      RUNNER_TOKEN: ${GITHUB_TOKEN}
      RUNNER_REPOSITORY_URL: https://github.com/YOUR_USERNAME/YOUR_REPO
      RUNNER_LABELS: large-disk,self-hosted
      RUNNER_WORKDIR: /tmp/runner
      DOCKER_IN_DOCKER: "true"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./runner:/tmp/runner
      - /mnt/large-disk:/mnt/large-disk  # 挂载大磁盘
    restart: unless-stopped
```

---

## 监控和调试

### 检查磁盘使用情况

工作流会自动输出：
- 清理前后的磁盘使用情况
- Docker 磁盘使用详情
- 可用空间统计

### 手动检查

如果使用自托管 runner，可以 SSH 到服务器检查：

```bash
# 检查磁盘使用
df -h

# 检查 Docker 磁盘使用
docker system df -v

# 清理 Docker（如果 needed）
docker system prune -af --volumes
```

---

## 常见问题

### Q: 为什么清理后磁盘使用率还是很高？
A: Docker 清理只能清理 Docker 相关的资源。如果整个系统磁盘使用率高，可能是系统文件或其他进程占用。需要检查整个系统的磁盘使用情况。

### Q: 能否使用 GitHub Actions 的缓存来减少磁盘使用？
A: 对于 Docker 镜像同步场景，缓存的作用有限，因为我们需要拉取完整的镜像。主要优化方向是及时清理已推送的镜像。

### Q: 自托管 runner 的安全性如何保证？
A: 
- 使用最小权限原则
- 定期更新系统和安全补丁
- 使用防火墙限制访问
- 定期检查日志
- 使用 GitHub 的 runner 安全最佳实践

---

## 总结

1. **短期方案**: 使用当前的优化工作流，它会智能管理磁盘空间
2. **长期方案**: 设置自托管 runner，配置更大的磁盘空间
3. **最佳实践**: 
   - 及时清理已推送的镜像
   - 分批处理大镜像
   - 监控磁盘使用情况

