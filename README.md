# Supervisor 守护进程配置使用说明

## 概述
本配置文件用于管理两个服务：
- `core-pipeline`: 运行在端口 50051
- `framaist-milvus`: 运行在端口 50052

## 使用步骤

### 1. 创建日志目录
```bash
mkdir -p logs
```

### 2. 安装 supervisor（如果尚未安装）
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install supervisor

# 或者使用 pip
pip install supervisor
```

### 3. 启动服务
```bash
# 使用配置文件启动supervisor
supervisord -c supervisor.conf

# 或者将配置文件复制到系统目录
sudo cp supervisor.conf /etc/supervisor/conf.d/
sudo supervisorctl reread
sudo supervisorctl update
```

### 4. 管理服务
```bash
# 查看所有服务状态
supervisorctl -c supervisor.conf status

# 启动特定服务
supervisorctl -c supervisor.conf start core-pipeline
supervisorctl -c supervisor.conf start framaist-milvus

# 停止特定服务
supervisorctl -c supervisor.conf stop core-pipeline
supervisorctl -c supervisor.conf stop framaist-milvus

# 重启特定服务
supervisorctl -c supervisor.conf restart core-pipeline
supervisorctl -c supervisor.conf restart framaist-milvus

# 启动所有服务
supervisorctl -c supervisor.conf start autodl-guard-services:*

# 停止所有服务
supervisorctl -c supervisor.conf stop autodl-guard-services:*
```

### 5. 查看日志
```bash
# 查看 core-pipeline 日志
tail -f logs/core-pipeline.log

# 查看 framaist-milvus 日志
tail -f logs/framaist-milvus.log

# 查看错误日志
tail -f logs/core-pipeline_error.log
tail -f logs/framaist-milvus_error.log
```

## 配置说明

### 主要配置项：
- `autostart=true`: 系统启动时自动启动服务
- `autorestart=true`: 服务异常退出时自动重启
- `startretries=3`: 启动失败时重试3次
- `stopwaitsecs=10`: 停止时等待10秒
- `killasgroup=true`: 停止时杀死子进程组

### 日志配置：
- 标准输出日志最大10MB，保留5个备份
- 错误日志最大10MB，保留5个备份
- 日志文件位于 `logs/` 目录下

### 环境变量：
- `PYTHONPATH`: Python路径
- `PIP_INDEX_URL`: 使用清华镜像源
- `HF_ENDPOINT`: 使用HuggingFace镜像

## 注意事项

1. 确保两个服务的虚拟环境已经正确设置
2. 确保配置文件路径存在：
   - `services/core-pipeline/config/default.yaml`
   - `services/FramAist-Milvus/config/default.yaml`
3. 如果端口被占用，可以修改配置文件中的端口号
4. 日志目录需要有写入权限

## 故障排除

如果服务无法启动：
1. 检查虚拟环境是否存在
2. 检查配置文件路径是否正确
3. 检查端口是否被占用
4. 查看错误日志文件获取详细信息 