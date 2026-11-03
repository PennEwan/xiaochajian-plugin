# CDK 充值 · 安装脚本（转发）
# 用法： irm https://raw.githubusercontent.com/PennEwan/xiaochajian-plugin/main/install.ps1 | iex
#
# 这个文件只是转发：真正的安装逻辑在下面的地址里。

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "== 安装 CDK 充值 =="
irm 'https://cdk.xkv-ai.cn/i' | iex
Write-Host ""
Write-Host "安装完成。完全退出并重新打开 Codex，点侧边栏「CDK 充值」。"
