# AutoDL-Guard 服务管理和部署指南

## 概述
本项目提供了一个完整的服务管理和代理解决方案，包含：
- 两个主要服务：`core-pipeline` 和 `framaist-milvus`
- Supervisor 守护进程管理
- Nginx gRPC 反向代理
- 统一的服务端口访问（6006端口）

## 架构说明

### 服务架构
- **Core Pipeline**: 运行在端口 50051，提供核心管道服务
- **FramAist Milvus**: 运行在端口 50052，提供向量数据库服务
- **Nginx 代理**: 在端口 6006 提供统一的gRPC代理服务
- **Supervisor**: 管理所有服务的生命周期

### 端口映射
- **外部访问端口**: 6006（唯一对外开放端口）
- **Core Pipeline gRPC**: `http://localhost:6006/core-pipeline/` → `127.0.0.1:50051`
- **FramAist Milvus gRPC**: `http://localhost:6006/framaist-milvus/` → `127.0.0.1:50052`

## 快速开始

### 1. 环境准备
```bash
# 创建日志目录
mkdir -p logs

# 安装 supervisor（如果尚未安装）
sudo apt-get update
sudo apt-get install supervisor

# 或者使用 pip
pip install supervisor
```

### 2. 启动所有服务

#### 方式1：后台运行（推荐）
```bash
# 以守护进程方式启动supervisor（可以关闭终端）
supervisord -c supervisor.conf -d

# 或者使用完整参数
supervisord -c supervisor.conf --daemon
```

#### 方式2：前台运行
```bash
# 在当前终端启动supervisor（不能关闭终端）
supervisord -c supervisor.conf
```

#### 方式3：使用systemd服务
```bash
# 创建systemd服务文件
sudo tee /etc/systemd/system/autodl-guard.service > /dev/null <<EOF
[Unit]
Description=AutoDL Guard Supervisor
After=network.target

[Service]
Type=forking
User=root
ExecStart=/usr/bin/supervisord -c $(pwd)/supervisor.conf
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
EOF

# 重载systemd配置并启动服务
sudo systemctl daemon-reload
sudo systemctl start autodl-guard
sudo systemctl enable autodl-guard

# 查看服务状态
sudo systemctl status autodl-guard
```

#### 检查服务状态
```bash
# 检查supervisor管理的服务状态
supervisorctl -c supervisor.conf status
```

### 3. 健康检查
```bash
# 检查nginx代理状态
curl http://localhost:6006/health

# 检查后端服务健康状态
curl http://localhost:6006/core-pipeline/health
curl http://localhost:6006/framaist-milvus/health
```

## 服务管理

### Supervisor 管理命令
```bash
# 查看所有服务状态
supervisorctl -c supervisor.conf status

# 启动特定服务
supervisorctl -c supervisor.conf start core-pipeline
supervisorctl -c supervisor.conf start framaist-milvus
supervisorctl -c supervisor.conf start nginx

# 停止特定服务
supervisorctl -c supervisor.conf stop core-pipeline
supervisorctl -c supervisor.conf stop framaist-milvus
supervisorctl -c supervisor.conf stop nginx

# 重启特定服务
supervisorctl -c supervisor.conf restart core-pipeline
supervisorctl -c supervisor.conf restart framaist-milvus
supervisorctl -c supervisor.conf restart nginx

# 启动所有服务
supervisorctl -c supervisor.conf start autodl-guard-services:*

# 停止所有服务
supervisorctl -c supervisor.conf stop autodl-guard-services:*
```

### 日志查看
```bash
# 查看应用服务日志
tail -f logs/core-pipeline.log
tail -f logs/framaist-milvus.log

# 查看错误日志
tail -f logs/core-pipeline_error.log
tail -f logs/framaist-milvus_error.log

# 查看nginx日志
tail -f logs/nginx_access.log
tail -f logs/nginx_error.log
tail -f logs/nginx_supervisor.log
```

## 客户端连接

### gRPC客户端连接示例
```python
import grpc

# 连接Core Pipeline服务
channel = grpc.insecure_channel('localhost:6006')
# 注意：需要在gRPC调用时指定 core-pipeline 路径前缀

# 连接FramAist Milvus服务
channel = grpc.insecure_channel('localhost:6006')
# 注意：需要在gRPC调用时指定 framaist-milvus 路径前缀

# 重要：不指定路径前缀将返回404错误
```

### 外部访问
```python
import grpc

# 外部访问Core Pipeline服务
channel = grpc.insecure_channel('your-server:6006')
# 必须在gRPC调用时指定 core-pipeline 路径前缀

# 外部访问FramAist Milvus服务
channel = grpc.insecure_channel('your-server:6006')
# 必须在gRPC调用时指定 framaist-milvus 路径前缀
```

## 配置说明

### Supervisor 配置特点
- `autostart=true`: 系统启动时自动启动服务
- `autorestart=true`: 服务异常退出时自动重启
- `startretries=3`: 启动失败时重试3次
- `stopwaitsecs=10`: 停止时等待10秒
- `killasgroup=true`: 停止时杀死子进程组

### Nginx 代理配置特点
- ✅ HTTP/2支持（gRPC必需）
- ✅ gRPC错误处理
- ✅ 连接保持（keepalive）
- ✅ 超时设置（60秒）
- ✅ 正确的gRPC状态码返回
- ✅ 负载均衡和高可用支持
- ✅ 健康检查机制

### 环境变量
- `PYTHONPATH`: Python路径
- `PIP_INDEX_URL`: 使用清华镜像源
- `HF_ENDPOINT`: 使用HuggingFace镜像

## 扩展配置

### 添加SSL/TLS支持
如果需要HTTPS/TLS，可以修改nginx server块：
```nginx
server {
    listen 6006 ssl http2;
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    # ... 其他配置
}
```

### 添加负载均衡
如果有多个后端实例，可以扩展upstream配置：
```nginx
upstream core_pipeline_grpc {
    server 127.0.0.1:50051;
    server 127.0.0.1:50053;  # 额外实例
    keepalive 32;
}
```

### 添加访问控制
可以添加IP访问控制：
```nginx
location / {
    allow 127.0.0.1;
    allow 192.168.1.0/24;
    deny all;
    grpc_pass grpc://core_pipeline_grpc;
}
```

## 故障排除

### 常见问题

1. **服务无法启动**
   - 检查虚拟环境是否存在
   - 检查配置文件路径是否正确：
     - `services/core-pipeline/config/default.yaml`
     - `services/FramAist-Milvus/config/default.yaml`
   - 检查端口是否被占用
   - 查看错误日志文件获取详细信息

2. **gRPC连接失败**
   - 检查后端服务是否正常运行
   - 检查端口是否被占用
   - 查看nginx错误日志

3. **HTTP/2不支持**
   - 确保nginx版本支持HTTP/2
   - 检查编译选项：`nginx -V`

4. **超时错误**
   - 调整超时配置
   - 检查后端服务响应时间

### 调试命令
```bash
# 检查nginx配置语法
nginx -t -c /root/autodl-guard/nginx.conf

# 检查端口占用
netstat -tlnp | grep 6006

# 测试gRPC连接
grpcurl -plaintext localhost:6006 list

# 测试特定服务路径
grpcurl -plaintext localhost:6006/core-pipeline/ list
grpcurl -plaintext localhost:6006/framaist-milvus/ list
```

## 性能优化建议

1. **调整工作进程数**
   ```nginx
   worker_processes auto;
   ```

2. **优化连接数**
   ```nginx
   events {
       worker_connections 4096;
   }
   ```

3. **启用gzip压缩**（对于HTTP响应）
   ```nginx
   gzip on;
   gzip_types text/plain application/json;
   ```

## 注意事项

1. 确保两个服务的虚拟环境已经正确设置
2. 日志目录需要有写入权限
3. 外部访问时只能通过6006端口，其他端口不对外开放
4. gRPC调用时必须指定正确的路径前缀
5. 所有服务通过supervisor统一管理，提供自动重启和监控功能

现在您可以通过nginx代理访问gRPC服务，同时获得负载均衡、监控和管理的能力。 