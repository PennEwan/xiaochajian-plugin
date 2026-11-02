# CDK 充值 · 安装脚本（Windows，PowerShell 5+）
#
#   irm https://raw.githubusercontent.com/PennEwan/xiaochajian-plugin/main/install.ps1 | iex
#
# 只做一件事：把插件装进 Codex。

$ErrorActionPreference = 'Stop'
$ver  = '0.8.1'
$repo = 'PennEwan/xiaochajian-plugin'

$zipUrls = @(
    "https://codeload.github.com/$repo/zip/refs/heads/main",
    "https://github.com/$repo/archive/refs/heads/main.zip"
)

$home_ = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$root  = Join-Path $env:LOCALAPPDATA 'CodexRecharge'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path $env:TEMP ("cdk-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    Write-Host "== 安装 =="
    $zip = Join-Path $tmp 'p.zip'
    $ok = $false
    foreach ($u in $zipUrls) {
        try {
            Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing -TimeoutSec 120
            $ok = (Test-Path $zip) -and (Get-Item $zip).Length -gt 10240
            if ($ok) { break }
        } catch { }
    }
    if (-not $ok) { throw "网络异常，请稍后重试" }

    $unpack = Join-Path $tmp 'src'
    Expand-Archive -Path $zip -DestinationPath $unpack -Force
    $top = Get-ChildItem $unpack -Directory | Select-Object -First 1
    $base = if ($top) { $top.FullName } else { $unpack }
    $srcPlugin = Join-Path $base 'plugins\codex-native-assist'
    $market = Join-Path $base '.agents\plugins\marketplace.json'
    if (-not (Test-Path (Join-Path $srcPlugin 'bin\assist.exe'))) { throw "包结构异常" }

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

    Write-Host ""
    Write-Host "已安装。侧边栏会出现「CDK 充值」，直接用就行。"
} finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
