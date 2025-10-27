# scripts/start-mailpit.ps1
# 목적: 서버(Nest) 실행 전에 Mailpit 컨테이너가 자동으로 떠 있도록 보장
# 규칙: 호스트 1025 -> 컨테이너 1025(SMTP), 호스트 18025 -> 컨테이너 8025(Web UI)
# 참고: Windows에서 8025 충돌이 잦아 호스트 포트를 18025로 고정

$ErrorActionPreference = "Stop"

function Info($msg) { Write-Host "[Mailpit] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[Mailpit] $msg" -ForegroundColor Yellow }
function Note($msg) { Write-Host "[Mailpit] $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "[Mailpit] $msg" -ForegroundColor Red }

# 1) Docker 설치/실행 체크
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Warn "Docker가 설치되어 있지 않으므로 Mailpit 기동을 건너뜁니다."
  exit 0  # 서버는 계속 뜨게 두되, Mailpit은 건너뜀
}

# 2) Mailpit 컨테이너 상태 확인
$containerName = "mailpit"
$existing = docker ps -a --filter "name=$containerName" --format "{{.Names}}"

if ($existing -ne $containerName) {
  Note "컨테이너 없음 -> 새로 생성"
  docker run -d --name $containerName --restart unless-stopped -p 1025:1025 -p 18025:8025 axllent/mailpit | Out-Null
} else {
  # 존재하면 실행 중인지 확인
  $running = docker ps --filter "name=$containerName" --format "{{.Names}}"
  if ($running -ne $containerName) {
    Note "컨테이너 존재하지만 정지 상태 -> start"
    docker start $containerName | Out-Null
  } else {
    # 실행 중이면 포트 매핑만 점검(필요시 재생성)
    $ports = docker port $containerName
    $ok1 = $false
    $ok2 = $false
    if ($ports -match "1025/tcp ->") { $ok1 = $true }
    if ($ports -match "8025/tcp -> .*:18025") { $ok2 = $true }

    if (-not ($ok1 -and $ok2)) {
      Warn "포트 매핑 불일치 -> 재생성"
      docker rm -f $containerName | Out-Null
      docker run -d --name $containerName --restart unless-stopped -p 1025:1025 -p 18025:8025 axllent/mailpit | Out-Null
    } else {
      Info "이미 정상 실행 중"
    }
  }
}

# 3) 최종 확인 로그
$ports = docker port $containerName
$portsJoined = ($ports -join "; ")
Info ("Ports: " + $portsJoined)
Info "UI: http://localhost:18025"
