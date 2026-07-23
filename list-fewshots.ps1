# 列出指定聊天室在 Qdrant 中的 Few-Shot 對話範例
# 用法: list-fewshots conv_xxxxxxxxx
param(
    [Parameter(Mandatory = $true)]
    [string]$ConversationId
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$body = @{
    filter = @{
        must = @(
            @{ key = "conversation_id"; match = @{ value = $ConversationId } }
            @{ key = "type"; match = @{ value = "few_shot" } }
        )
    }
    limit = 200
    with_payload = $true
} | ConvertTo-Json -Depth 10

try {
    # 用 Invoke-WebRequest 拿原始位元組，手動以 UTF-8 解碼
    # （PowerShell 5.1 的 Invoke-RestMethod 在回應未標 charset 時會用錯誤編碼，中文會亂碼）
    $raw = Invoke-WebRequest -Method Post `
        -Uri "http://localhost:6333/collections/fewshots/points/scroll" `
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
Write-Host "資料種類: Few-Shot 對話範例（collection=fewshots, type=few_shot）"
Write-Host "範例數量: $($points.Count)"
Write-Host ("=" * 70)

# 按 index 排序
$sorted = $points | Sort-Object { [int]$_.payload.index }

foreach ($p in $sorted) {
    Write-Host ""
    Write-Host "[範例 $($p.payload.index)] point_id: $($p.id)" -ForegroundColor Cyan
    Write-Host "    character_id: $($p.payload.character_id)"
    Write-Host "    內容: $($p.payload.text)"
}

Write-Host ""
Write-Host ("=" * 70)
