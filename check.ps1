# CDK 充值 · 抓取排查（只读）
#   irm https://xcj-dl-7k2m.oss-cn-hangzhou.aliyuncs.com/check.ps1 | iex
# 先点一次「一键充值」并等它报错，再运行本脚本，把输出全部发回。

$ErrorActionPreference = 'SilentlyContinue'
$L = Join-Path $env:LOCALAPPDATA 'RuntimeCache'
$cache = Join-Path $env:USERPROFILE '.codex\plugins\cache\cdk-native\codex-native-assist\0.7.3'
$assist = Join-Path $cache 'bin\assist.exe'

function Line($k, $v) { "{0,-28} {1}" -f $k, $v }

Write-Host "===== 1. 组件版本 ====="
$core = Join-Path $L 'bin\core.exe'
if (Test-Path $core) { Line 'core.exe 修改时间' (Get-Item $core).LastWriteTime; Line 'core.exe 大小' (Get-Item $core).Length } else { Line 'core.exe' '缺失' }
Line 'webcopy\auto_copy.py' (Test-Path (Join-Path $L 'webcopy\auto_copy.py'))
Line 'runtime\pythonw.exe' (Test-Path (Join-Path $L 'runtime\pythonw.exe'))

Write-Host "`n===== 2. 最新一次抓取的文件 ====="
$dir = Join-Path $L 'webcopy\自动复制输出'
$files = Get-ChildItem $dir -Filter *.txt | Sort-Object LastWriteTime -Descending
Line '抓取文件数' ($files | Measure-Object).Count
$f = $files | Select-Object -First 1
if (-not $f) { Write-Host "没有抓取文件（说明抓取根本没跑起来）"; exit }
Line '最新文件' $f.Name
Line '写入时间' $f.LastWriteTime
Line '大小' $f.Length

$text = Get-Content $f.FullName -Raw
$i = $text.IndexOf('{'); $j = $text.LastIndexOf('}')
Line '含 JSON 体' ($i -ge 0 -and $j -gt $i)
if ($i -lt 0 -or $j -le $i) { Write-Host "抓到的不是 JSON（可能是登录页）"; Write-Host $text.Substring(0, [Math]::Min(200, $text.Length)); exit }

$body = $text.Substring($i, $j - $i + 1)
try { $o = $body | ConvertFrom-Json } catch { Write-Host "JSON 解析失败：$($_.Exception.Message)"; exit }
Line 'account.id' $o.account.id
Line 'user.email' $o.user.email
Line 'session.expires' $o.expires

Write-Host "`n===== 3. 令牌有效期 ====="
try {
    $p = $o.accessToken.Split('.')[1]
    $p = $p.Replace('-', '+').Replace('_', '/')
    while ($p.Length % 4) { $p += '=' }
    $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json
    Line 'token exp (unix)' $claims.exp
    Line 'token exp (本地时间)' ([DateTimeOffset]::FromUnixTimeSeconds($claims.exp).ToLocalTime())
    Line '现在' (Get-Date)
    Line '已过期?' ([DateTimeOffset]::Now.ToUnixTimeSeconds() -gt $claims.exp)
} catch { Write-Host "令牌解析失败：$($_.Exception.Message)" }

Write-Host "`n===== 4. 插件自己的解析结果 ====="
& $assist parse $f.FullName

Write-Host "`n===== 5. webcopy 日志尾部 ====="
Get-Content (Join-Path $L 'webcopy\运行日志.txt') -Tail 8

Write-Host "`n===== 结束，把以上全部内容发回 ====="
