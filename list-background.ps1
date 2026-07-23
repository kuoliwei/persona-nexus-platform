# 列出指定聊天室在 Qdrant 中的角色背景切片
# 用法: list-background conv_xxxxxxxxx
param(
    [Parameter(Mandatory = $true)]
    [string]$ConversationId
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$body = @{
    filter = @{
        must = @(
            @{ key = "conversation_id"; match = @{ value = $ConversationId } }
            @{ key = "type"; match = @{ value = "character_background" } }
        )
    }
    limit = 200
    with_payload = $true
} | ConvertTo-Json -Depth 10

try {
    # 用 Invoke-WebRequest 拿原始位元組，手動以 UTF-8 解碼
    # （PowerShell 5.1 的 Invoke-RestMethod 在回應未標 charset 時會用錯誤編碼，中文會亂碼）
    $raw = Invoke-WebRequest -Method Post `
        -Uri "http://localhost:6333/collections/characters/points/scroll" `
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

Write-Host ""
Write-Host "聊天室:   $ConversationId"
Write-Host "資料種類: 角色背景（collection=characters, type=character_background）"
Write-Host "切片數量: $($points.Count)"
Write-Host ("=" * 70)

# 按 chunk_index 排序
$sorted = $points | Sort-Object { [int]$_.payload.chunk_index }

foreach ($p in $sorted) {
    Write-Host ""
    Write-Host "[切片 $($p.payload.chunk_index)] point_id: $($p.id)" -ForegroundColor Cyan
    Write-Host "    character_id: $($p.payload.character_id)"
    Write-Host "    內容: $($p.payload.text)"
}

Write-Host ""
Write-Host ("=" * 70)
