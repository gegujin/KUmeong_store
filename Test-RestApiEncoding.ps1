$r = Invoke-RestMethod -Method GET "$base/chats/1/messages" -Headers @{ "X-User-Id"="42" }
$r.data | ConvertTo-Json -Depth 5 | Out-File -FilePath .\resp.json -Encoding utf8
notepad .\resp.json   # 한글 정상
