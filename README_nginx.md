# Nginx gRPC 反向代理使用说明

## 概述
已配置nginx作为反向代理，用于代理两个gRPC服务，所有服务都通过6006端口对外提供服务：
- `core-pipeline` (50051) → nginx代理路径 `/core-pipeline/`
- `framaist-milvus` (50052) → nginx代理路径 `/framaist-milvus/`
- 健康检查端点也在6006端口

## 服务端口映射

### gRPC服务代理（统一端口6006）
- **Core Pipeline gRPC**: `http://localhost:6006/core-pipeline/` → `127.0.0.1:50051`
- **FramAist Milvus gRPC**: `http://localhost:6006/framaist-milvus/` → `127.0.0.1:50052`
- **未定义路径**: `http://localhost:6006/` → 返回404错误，提示使用正确路径

### 健康检查端点
- **Nginx健康检查**: `http://localhost:6006/health`
- **Core Pipeline健康检查**: `http://localhost:6006/core-pipeline/health`
- **FramAist Milvus健康检查**: `http://localhost:6006/framaist-milvus/health`

## 使用说明

### 1. 启动所有服务
```bash
# 启动supervisor管理的所有服务
supervisord -c supervisor.conf

# 或者单独启动nginx
supervisorctl -c supervisor.conf start nginx
```

### 2. 检查服务状态
```bash
# 查看所有服务状态
supervisorctl -c supervisor.conf status

# 检查nginx状态
curl http://localhost:6006/health

# 检查后端服务健康状态
curl http://localhost:6006/core-pipeline/health
curl http://localhost:6006/framaist-milvus/health
```

### 3. gRPC客户端连接
现在你可以通过nginx代理端口连接gRPC服务：

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

### 4. 外部访问
由于服务器只开放6006端口，外部客户端可以通过以下方式访问：

```python
import grpc

# 外部访问Core Pipeline服务
channel = grpc.insecure_channel('your-server:6006')
# 必须在gRPC调用时指定 core-pipeline 路径前缀

# 外部访问FramAist Milvus服务
channel = grpc.insecure_channel('your-server:6006')
# 必须在gRPC调用时指定 framaist-milvus 路径前缀
```

### 5. 日志查看
```bash
# 查看nginx访问日志
tail -f logs/nginx_access.log

# 查看nginx错误日志
tail -f logs/nginx_error.log

# 查看supervisor管理的nginx日志
tail -f logs/nginx_supervisor.log
```

## 配置特点

### gRPC专用配置
- ✅ HTTP/2支持（gRPC必需）
- ✅ gRPC错误处理
- ✅ 连接保持（keepalive）
- ✅ 超时设置（60秒）
- ✅ 正确的gRPC状态码返回

### 负载均衡和高可用
- ✅ Upstream配置支持多实例
- ✅ 连接保持优化
- ✅ 健康检查机制
- ✅ 优雅错误处理

### 监控和日志
- ✅ 访问日志记录
- ✅ 错误日志记录
- ✅ 健康检查端点
- ✅ Supervisor日志管理

## 扩展配置

### 添加SSL/TLS支持
如果需要HTTPS/TLS，可以修改server块：
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
1. **gRPC连接失败**
   - 检查后端服务是否正常运行
   - 检查端口是否被占用
   - 查看nginx错误日志

2. **HTTP/2不支持**
   - 确保nginx版本支持HTTP/2
   - 检查编译选项：`nginx -V`

3. **超时错误**
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

现在你可以通过nginx代理访问gRPC服务，同时获得负载均衡、监控和管理的能力。 