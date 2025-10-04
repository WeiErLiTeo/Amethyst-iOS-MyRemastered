#!/bin/bash

# GitHub Actions 日志查看脚本
# 用于在终端直接查看 GitHub Actions 构建日志

# 仓库信息
REPO_OWNER="herbrine8403"
REPO_NAME="Amethyst-iOS-MyRemastered"

# GitHub API 基础URL
API_BASE="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME"

# 检查是否安装了 curl
if ! command -v curl &> /dev/null; then
    echo "错误: 未找到 curl 命令，请先安装 curl"
    exit 1
fi

# GitHub Token (使用用户提供的token)
GITHUB_TOKEN="YOUR_GITHUB_TOKEN_HERE"

# 设置请求头
HEADERS="-H \"Accept: application/vnd.github.v3+json\""
if [ -n "$GITHUB_TOKEN" ] && [ "$GITHUB_TOKEN" != "YOUR_GITHUB_TOKEN_HERE" ]; then
    HEADERS="$HEADERS -H \"Authorization: token $GITHUB_TOKEN\""
fi

# 获取工作流列表
echo "正在获取工作流列表..."
workflows=$(eval "curl -s $HEADERS \"$API_BASE/actions/workflows\"")

if [ $? -ne 0 ] || [ -z "$workflows" ]; then
    echo "获取工作流列表失败"
    echo "可能的原因："
    echo "1. 网络连接问题"
    echo "2. GitHub API 速率限制"
    echo "3. 仓库不存在或无访问权限"
    echo "4. Token 无效或无权限"
    exit 1
fi

# 提取工作流名称和ID
echo "可用的工作流:"
workflow_names=$(echo "$workflows" | grep -o '"name":"[^"]*"' | sed 's/"name":"\([^"]*\)"/\1/')
workflow_ids=$(echo "$workflows" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

# 检查是否获取到工作流
if [ -z "$workflow_names" ]; then
    echo "未找到任何工作流"
    exit 1
fi

# 显示工作流列表
echo "$workflow_names" | nl -v0

# 选择工作流
read -p "请选择工作流编号: " workflow_index

# 获取选中的工作流ID
workflow_id=$(echo "$workflow_ids" | sed -n "$((workflow_index+1))p")

if [ -z "$workflow_id" ]; then
    echo "无效的工作流编号"
    exit 1
fi

# 获取工作流运行列表
echo "正在获取工作流运行列表..."
runs=$(eval "curl -s $HEADERS \"$API_BASE/actions/workflows/$workflow_id/runs?per_page=10\"")

if [ $? -ne 0 ]; then
    echo "获取工作流运行列表失败"
    exit 1
fi

# 提取运行ID和状态
echo "最近的运行记录:"
run_ids=$(echo "$runs" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
run_status=$(echo "$runs" | grep -o '"status":"[^"]*"' | sed 's/"status":"\([^"]*\)"/\1/')

# 检查是否获取到运行记录
if [ -z "$run_ids" ]; then
    echo "未找到任何运行记录"
    exit 1
fi

# 显示运行记录列表
paste <(echo "$run_ids") <(echo "$run_status") | nl -v0

# 选择运行记录
read -p "请选择运行记录编号: " run_index

# 获取选中的运行ID
run_id=$(echo "$run_ids" | sed -n "$((run_index+1))p")

if [ -z "$run_id" ]; then
    echo "无效的运行记录编号"
    exit 1
fi

# 获取运行详情
echo "正在获取运行详情..."
run_details=$(eval "curl -s $HEADERS \"$API_BASE/actions/runs/$run_id\"")

if [ $? -ne 0 ]; then
    echo "获取运行详情失败"
    exit 1
fi

# 获取工作流运行的作业列表
echo "正在获取作业列表..."
jobs=$(eval "curl -s $HEADERS \"$API_BASE/actions/runs/$run_id/jobs\"")

if [ $? -ne 0 ]; then
    echo "获取作业列表失败"
    exit 1
fi

# 提取作业ID和名称
echo "作业列表:"
job_ids=$(echo "$jobs" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
job_names=$(echo "$jobs" | grep -o '"name":"[^"]*"' | sed 's/"name":"\([^"]*\)"/\1/')

# 检查是否获取到作业
if [ -z "$job_ids" ]; then
    echo "未找到任何作业"
    exit 1
fi

# 显示作业列表
paste <(echo "$job_ids") <(echo "$job_names") | nl -v0

# 选择作业
read -p "请选择作业编号 (输入'all'查看所有作业日志): " job_choice

if [ "$job_choice" = "all" ]; then
    # 获取所有作业的日志
    for job_id in $job_ids; do
        echo "==================== 作业 ID: $job_id ===================="
        eval "curl -s $HEADERS \"$API_BASE/actions/jobs/$job_id/logs\""
        echo ""
    done
else
    # 获取选中的作业ID
    job_id=$(echo "$job_ids" | sed -n "$((job_choice+1))p")

    if [ -z "$job_id" ]; then
        echo "无效的作业编号"
        exit 1
    fi

    # 获取并显示日志
    echo "正在获取作业日志..."
    eval "curl -s $HEADERS \"$API_BASE/actions/jobs/$job_id/logs\""
fi

echo "日志查看完成。"