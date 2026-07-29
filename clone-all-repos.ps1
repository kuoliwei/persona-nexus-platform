# 一次性複製所有服務倉庫到本地
# 使用方法：.\clone-all-repos.ps1

param(
  [string]$Owner = "kuoliwei"
)

$baseDir = Get-Location
$repos = @(
  "api-gateway",
  "auth-service",
  "user-service",
  "character-service",
  "chat-service",
  "ai-service",
  "persona-nexus-auth",
  "persona-nexus-character",
  "persona-nexus-lobby",
  "persona-nexus-chat"
)

Write-Host "準備複製所有服務倉庫 (Owner: $Owner)...`n" -ForegroundColor Cyan

$cloneCount = 0
$skipCount = 0
$errorCount = 0

foreach ($repo in $repos) {
  $repoPath = Join-Path $baseDir $repo

  if (Test-Path $repoPath) {
    Write-Host "⊘ $repo - 已存在，跳過" -ForegroundColor Yellow
    $skipCount++
    continue
  }

  Write-Host "→ 正在複製 $repo..." -ForegroundColor White
  $url = "https://github.com/$Owner/$repo.git"

  git clone $url $repoPath 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ 複製成功" -ForegroundColor Green
    $cloneCount++
  } else {
    Write-Host "  ✗ 複製失敗：請檢查網路或倉庫名稱" -ForegroundColor Red
    $errorCount++
  }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "複製完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "成功: $cloneCount 個" -ForegroundColor Green
Write-Host "跳過: $skipCount 個" -ForegroundColor Gray
Write-Host "失敗: $errorCount 個" -ForegroundColor Red
Write-Host ""
