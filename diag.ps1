# CDK 充值 · 自检脚本（只读，不改任何东西）
#   irm https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/diag.ps1 | iex
# 把输出整段发回来即可。

$ErrorActionPreference = 'SilentlyContinue'
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$app = Join-Path $env:LOCALAPPDATA 'RuntimeCache'

function Line($k, $v) { "{0,-26} {1}" -f $k, $v }

Write-Host "===== 1. 系统 ====="
Line "OS" "$([System.Environment]::OSVersion.VersionString)"
Line "PowerShell" $PSVersionTable.PSVersion.ToString()
if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
    Write-Host "!! 这是非 Windows 系统，插件只支持 Windows" -ForegroundColor Red
}

Write-Host "`n===== 2. 插件是否登记 ====="
$cfg = Join-Path $codexHome 'config.toml'
Line "config.toml" (Test-Path $cfg)
if (Test-Path $cfg) {
    $text = Get-Content $cfg -Raw
    Line "marketplace 段" ($text -match '\[marketplaces\.cdk-native\]')
    Line "plugin 段" ($text -match '\[plugins\."codex-native-assist@cdk-native"\]')
}
$cache = Join-Path $codexHome 'plugins\cache\cdk-native\codex-native-assist'
Line "插件缓存目录" (Test-Path $cache)
if (Test-Path $cache) {
    Get-ChildItem $cache -Directory | ForEach-Object { Line "  版本" $_.Name }
    $exe = Get-ChildItem $cache -Recurse -Filter 'assist.exe' | Select-Object -First 1
    Line "  assist.exe" $(if ($exe) { "$([math]::Round($exe.Length/1KB)) KB" } else { "缺失" })
}

Write-Host "`n===== 3. 后台组件 ====="
Line "RuntimeCache" (Test-Path $app)
Line "runtime\pythonw.exe" (Test-Path (Join-Path $app 'runtime\pythonw.exe'))
Line "bin\core.exe（抓取）" (Test-Path (Join-Path $app 'bin\core.exe'))
Line "usage（累计秒）" $(if (Test-Path (Join-Path $app 'usage')) { (Get-Content (Join-Path $app 'usage') -Raw).Trim() } else { '无' })
if (Test-Path (Join-Path $app 'product.json')) { Line "product.json" (Get-Content (Join-Path $app 'product.json') -Raw).Trim() }
if (Test-Path (Join-Path $app 'app-config.json')) { Line "app-config.json" (Get-Content (Join-Path $app 'app-config.json') -Raw).Trim() }

Write-Host "`n===== 4. 计划任务 ====="
$t = schtasks /query /tn "AppCache\Sync" /fo list 2>$null
if ($t) {
    $st = ($t | Select-String '(?m)^\s*(Status|状态):' | Select-Object -First 1).Line
    if ($st) { $st.Trim() } else { "  已创建（未能解析状态）" }
} else { Write-Host "  未创建" }

Write-Host "`n===== 5. 采集状态 ====="
$status = Join-Path $app 'app-status.json'
if (Test-Path $status) {
    $s = Get-Content $status -Raw | ConvertFrom-Json
    Line "recording" $s.recording
    Line "gate" $s.gate
    if ($s.upload) {
        Line "upload.configured" $s.upload.configured
        Line "upload.base_url" $s.upload.base_url
        Line "upload.uploaded" $s.upload.uploaded
        Line "upload.failures" $s.upload.failures
        Line "upload.last_error" $s.upload.last_error
    }
    if ($s.spool) { Line "spool.records" $s.spool.records }
} else {
    Write-Host "  还没有 app-status.json（说明后台组件没跑起来）"
}

Write-Host "`n===== 5b. MCP 启动痕迹（插件数据目录）====="
$data = Join-Path $codexHome 'plugins\data\codex-native-assist-cdk-native'
Line "数据目录" (Test-Path $data)
if (Test-Path $data) {
    Get-ChildItem $data -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 5 |
        ForEach-Object { Line ("  " + $_.Name) ($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + "  " + $_.Length + "B") }
}

Write-Host "`n===== 6. 最近日志 ====="
$log = Join-Path $app 'app.log'
if (Test-Path $log) { Get-Content $log -Tail 12 } else { Write-Host "  无日志" }

Write-Host "`n===== 7. 网络可达性 ====="
foreach ($u in @('https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/dl/CDKGrab-0.7.3.tar',
                 'https://collect.xkv-ai.cn/v1/service-state')) {
    try {
        $r = Invoke-WebRequest -Uri $u -Method Get -TimeoutSec 15 -UseBasicParsing
        Line $u $r.StatusCode
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        Line $u ("失败 " + $(if ($code) { $code } else { $_.Exception.Message }))
    }
}

Write-Host "`n===== 结束，把以上全部内容发回 ====="
