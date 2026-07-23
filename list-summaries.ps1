# 列出指定聊天室在 Qdrant 中的所有摘要，並配對顯示每份摘要涵蓋的訊息
# 用法: list-summaries conv_xxxxxxxxx
param(
    [Parameter(Mandatory = $true)]
    [string]$ConversationId
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$chatServiceDir = Join-Path $PSScriptRoot "chat-service"

# ===== 1. 從 Qdrant 撈摘要 =====
$body = @{
    filter = @{
        must = @(
            @{ key = "conversation_id"; match = @{ value = $ConversationId } }
        )
    }
    limit = 100
    with_payload = $true
} | ConvertTo-Json -Depth 10

try {
    # 用 Invoke-WebRequest 拿原始位元組，手動以 UTF-8 解碼
    # （PowerShell 5.1 的 Invoke-RestMethod 在回應未標 charset 時會用錯誤編碼，中文會亂碼）
    $raw = Invoke-WebRequest -Method Post `
        -Uri "http://localhost:6333/collections/summaries/points/scroll" `
        -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
        -UseBasicParsing
    $json = [System.Text.Encoding]::UTF8.GetString($raw.RawContentStream.ToArray())
    $res = $json | ConvertFrom-Json
} catch {
    Write-Host "Qdrant 查詢失敗: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$points = $res.result.points

# ===== 2. 從 chat-service DB 撈訊息（node + Prisma） =====
$messages = @()
try {
    Push-Location $chatServiceDir
    $msgJson = & node "scripts/dump-messages.js" $ConversationId 2>$null
    Pop-Location
    if ($msgJson) {
        $messages = $msgJson | ConvertFrom-Json
    }
} catch {
    Pop-Location
    Write-Host "chat-service DB 查詢失敗: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "（僅顯示 Qdrant 摘要，不含配對訊息）" -ForegroundColor Yellow
}

function Show-Msg($m) {
    $preview = $m.text
    if ($preview.Length -gt 40) { $preview = $preview.Substring(0, 40) + "..." }
    Write-Host "        - id=$($m.id) [$($m.role)] $preview"
}

# ===== 3. 顯示 =====
Write-Host ""
Write-Host "聊天室: $ConversationId"
Write-Host "摘要數量: $($points.Count) / 訊息總數: $($messages.Count)"
Write-Host ("=" * 70)

# 按 timestamp 排序（舊 → 新）
$sorted = $points | Sort-Object { $_.payload.timestamp }

$idx = 0
foreach ($p in $sorted) {
    $idx++
    $time = [DateTimeOffset]::FromUnixTimeSeconds([long]$p.payload.timestamp).LocalDateTime.ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host ""
    Write-Host "[$idx] summary_id: $($p.id)" -ForegroundColor Cyan
    Write-Host "    建立時間:   $time"
    Write-Host "    摘要內容:   $($p.payload.text)"

    $covered = @($messages | Where-Object { $_.summaryId -eq $p.id })
    Write-Host "    涵蓋訊息:   $($covered.Count) 條"
    foreach ($m in $covered) { Show-Msg $m }
}

# ===== 4. 額外區塊：未摘要的訊息 =====
$unsummarized = @($messages | Where-Object { -not $_.summaryId })
Write-Host ""
Write-Host ("-" * 70)
Write-Host "未摘要的訊息: $($unsummarized.Count) 條" -ForegroundColor DarkGray
foreach ($m in $unsummarized) { Show-Msg $m }

# ===== 5. 一致性檢查：DB 中有 summaryId 但 Qdrant 找不到對應摘要 =====
$qdrantIds = @($points | ForEach-Object { $_.id })
$orphans = @($messages | Where-Object { $_.summaryId -and ($qdrantIds -notcontains $_.summaryId) })
if ($orphans.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  一致性異常: 以下訊息的 summaryId 在 Qdrant 中不存在！" -ForegroundColor Red
    foreach ($m in $orphans) {
        Write-Host "    id=$($m.id) summaryId=$($m.summaryId)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host ("=" * 70)
