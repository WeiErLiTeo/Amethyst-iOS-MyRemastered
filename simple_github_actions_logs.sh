#!/bin/bash

# 简化的GitHub Actions日志查看脚本
# 通过直接访问公开仓库的API来获取日志

# 仓库信息
REPO_OWNER="herbrine8403"
REPO_NAME="Amethyst-iOS-MyRemastered"

echo "GitHub Actions 构建日志查看工具"
echo "================================"

echo "由于匿名访问限制，我们无法直接通过API获取工作流列表。"
echo "请先在GitHub网站上查看最新的工作流运行记录，然后输入相关信息。"

# 获取用户输入
read -p "请输入工作流运行ID (在GitHub Actions页面URL中可以找到): " RUN_ID

if [ -z "$RUN_ID" ]; then
    echo "工作流运行ID不能为空"
    exit 1
fi

echo "正在获取工作流运行 $RUN_ID 的信息..."

# 获取运行详情
RUN_DETAILS=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runs/$RUN_ID")

if [ -z "$RUN_DETAILS" ] || echo "$RUN_DETAILS" | grep -q "Not Found"; then
    echo "无法获取运行详情，可能的原因："
    echo "1. 运行ID不正确"
    echo "2. 运行记录不存在"
    echo "3. 网络连接问题"
    exit 1
fi

# 显示运行状态
STATUS=$(echo "$RUN_DETAILS" | grep '"status"' | head -1 | cut -d'"' -f4)
CONCLUSION=$(echo "$RUN_DETAILS" | grep '"conclusion"' | head -1 | cut -d'"' -f4)

echo "运行状态: $STATUS"
echo "结论: ${CONCLUSION:-未完成}"

# 获取作业列表
echo "正在获取作业列表..."
JOBS=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runs/$RUN_ID/jobs")

if [ -z "$JOBS" ]; then
    echo "无法获取作业列表"
    exit 1
fi

# 提取作业信息
JOB_IDS=$(echo "$JOBS" | grep '"id"' | grep -o '[0-9]*')
JOB_NAMES=$(echo "$JOBS" | grep '"name"' | cut -d'"' -f4)

if [ -z "$JOB_IDS" ]; then
    echo "未找到任何作业"
    exit 1
fi

# 显示作业列表
echo ""
echo "作业列表:"
paste <(echo "$JOB_IDS") <(echo "$JOB_NAMES") | nl -v0

# 选择作业
read -p "请选择作业编号 (输入'all'查看所有作业日志): " JOB_CHOICE

if [ "$JOB_CHOICE" = "all" ]; then
    # 显示所有作业的日志
    echo "$JOB_IDS" | while read job_id; do
        if [ -n "$job_id" ]; then
            echo ""
            echo "==================== 作业 ID: $job_id 日志 ===================="
            curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/jobs/$job_id/logs"
        fi
    done
else
    # 获取选中的作业ID
    JOB_ID=$(echo "$JOB_IDS" | sed -n "${JOB_CHOICE}p")
    
    if [ -z "$JOB_ID" ]; then
        echo "无效的作业编号"
        exit 1
    fi
    
    # 显示选中作业的日志
    echo ""
    echo "==================== 作业 ID: $JOB_ID 日志 ===================="
    curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/jobs/$JOB_ID/logs"
fi

echo ""
echo "日志查看完成。"