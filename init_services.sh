#!/bin/bash

# 初始化子模块
git submodule update --init --recursive

# 初始化 core-pipeline
cd services/core-pipeline
uv sync --extra cu128 --extra build --extra compile
cd ../../

# 初始化 FramAist-Milvus
cd services/FramAist-Milvus
uv sync --extra cu128
cd ../../

# 启动服务
# supervisorctl start all