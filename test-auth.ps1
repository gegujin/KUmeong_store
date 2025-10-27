# diag-friends.ps1 — /friends 500 원인 잡기 (UTF-8 고정 + 에러 본문 출력)
try { chcp 65001 > $null } catch {}
[Console]::InputEncoding = [System.Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::UTF8
$OutputEncoding = [System.Text.UTF8Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'

$base = "http://localhost:3000/api/v1"

function Show-HttpError($err) {
  Write-Host "❌ HTTP Error" -ForegroundColor Red
  try {
    $resp = $err.Exception.Response
    if ($resp -ne $null) {
      $status = [int]$resp.StatusCode
      Write-Host "Status: $status"
      $stream = $resp.GetResponseStream()
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.UTF8Encoding]::UTF8)
      $body = $reader.ReadToEnd()
      if ($body) { Write-Host "Body:`n$body" } else { Write-Host $err.Exception.Message }
    }
    else {
      if ($err.ErrorDetails.Message) { Write-Host $err.ErrorDetails.Message } else { Write-Host $err.Exception.Message }
    }
  }
  catch { Write-Host $err.Exception.Message }
}

Write-Host "=== 🔑 LOGIN ===" -ForegroundColor Cyan
$loginBody = @{ email = "11@kku.ac.kr"; password = "1111" } | ConvertTo-Json
try {
  $login = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $loginBody
}
catch { Show-HttpError $_; exit 1 }
if (-not $login.ok) { $login | ConvertTo-Json -Depth 8; exit 1 }
$AT = $login.data.accessToken
Write-Host "✅ as $($login.data.user.email)"

Write-Host "`n=== 👤 /auth/me ===" -ForegroundColor Cyan
try {
  $me = Invoke-RestMethod -Uri "$base/auth/me" -Method GET -Headers @{ Authorization = "Bearer $AT" }
  $me | ConvertTo-Json -Depth 8
}
catch { Show-HttpError $_; exit 1 }

# ─────────────────────────────────────────────────────────────
#  A) /friends -> 본문/스택을 반드시 보고 싶으면 curl.exe로 raw 덤프
# ─────────────────────────────────────────────────────────────
Write-Host "`n=== 🤝 /friends (raw) ===" -ForegroundColor Cyan
$hdr = "Authorization: Bearer $AT"
# -i 로 헤더 포함, --silent, --show-error 로 오류도 본문 출력
& curl.exe -i --silent --show-error -H "$hdr" "$base/friends"

# ─────────────────────────────────────────────────────────────
#  B) /friends (JSON 파서) – 성공 시 JSON으로 예쁘게
# ─────────────────────────────────────────────────────────────
Write-Host "`n=== 🤝 /friends (IRM) ===" -ForegroundColor Cyan
try {
  $friends = Invoke-RestMethod -Uri "$base/friends" -Method GET -Headers @{ Authorization = "Bearer $AT" }
  $friends | ConvertTo-Json -Depth 8
}
catch { Show-HttpError $_ }

# (옵션) 스키마/버전 헬스체크
Write-Host "`n=== 🩺 /users/debug/db-info ===" -ForegroundColor Cyan
try {
  Invoke-RestMethod -Uri "$base/users/debug/db-info" -Method GET | ConvertTo-Json -Depth 8
}
catch { Show-HttpError $_ }

Write-Host "`n=== DONE ===" -ForegroundColor Yellow
