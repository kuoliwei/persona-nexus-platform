# 檢查 4 個前端的 vite.config.js 是否都有 Caddy 同源部署需要的必要設定。
# 用法：powershell -File check-vite-configs.ps1
#
# 背景：2026-07-24 曾經因為 persona-nexus-auth / persona-nexus-character 的
# vite.config.js 缺少 host/allowedHosts（造成 Caddy 容器連不進來，502）以及
# 缺少 base（造成資產路徑沒有前綴，被 Caddy 導到錯的前端）而卡住整個同源架構。
# 4 個前端各自是獨立 git 倉庫，沒有共用設定檔可以防止再度漂移，所以用這支腳本
# 做事後檢查：新增第 5 個前端、或改動任一個 vite.config.js 之後都應該重跑一次。

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# 每個前端預期的 base 路徑，對應 deploy/Caddyfile 的路由規則。
$frontends = @(
    @{ name = 'persona-nexus-auth';      expectedBase = '/login/' }
    @{ name = 'persona-nexus-character'; expectedBase = '/character/' }
    @{ name = 'persona-nexus-lobby';     expectedBase = '/' }
    @{ name = 'persona-nexus-chat';      expectedBase = '/chat/' }
)

$hasProblem = $false

foreach ($fe in $frontends) {
    $configPath = Join-Path $root "$($fe.name)\vite.config.js"

    if (-not (Test-Path $configPath)) {
        Write-Host "[缺檔] $($fe.name)\vite.config.js 不存在" -ForegroundColor Red
        $hasProblem = $true
        continue
    }

    $content = Get-Content $configPath -Raw

    $problems = @()

    if ($content -notmatch 'host\s*:\s*true') {
        $problems += "缺少 host: true（Caddy 容器透過 host.docker.internal 連不進來，會 502）"
    }
    if ($content -notmatch 'allowedHosts\s*:\s*true') {
        $problems += "缺少 allowedHosts: true（Caddy 轉發的 Host 標頭會被 Vite 拒絕）"
    }

    $expectedBaseEscaped = [regex]::Escape($fe.expectedBase)
    if ($content -notmatch "base\s*:\s*['""]$expectedBaseEscaped['""]") {
        $problems += "base 不是預期的 '$($fe.expectedBase)'（資產路徑前綴會跟 Caddy 路由對不上，掉進錯的前端）"
    }

    if ($problems.Count -eq 0) {
        Write-Host "[OK] $($fe.name)" -ForegroundColor Green
    } else {
        Write-Host "[有問題] $($fe.name)" -ForegroundColor Red
        foreach ($p in $problems) {
            Write-Host "    - $p" -ForegroundColor Yellow
        }
        $hasProblem = $true
    }
}

Write-Host ""
if ($hasProblem) {
    Write-Host "有前端設定不齊全，請對照上面訊息修正 vite.config.js。" -ForegroundColor Red
    exit 1
} else {
    Write-Host "4 個前端的 vite.config.js 都符合同源部署的必要設定。" -ForegroundColor Green
    exit 0
}
