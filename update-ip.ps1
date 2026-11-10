# Auto-detect WiFi IP and update Flutter app config
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*WiFi*" -or $_.InterfaceAlias -like "*Wireless*"
} | Select-Object -First 1).IPAddress

if (-not $ip) {
    Write-Host "❌ No WiFi interface found. Check your connection." -ForegroundColor Red
    exit 1
}

Write-Host "📡 Detected WiFi IP: $ip" -ForegroundColor Cyan

# Update api_service.dart
$apiFile = "D:\pfa\mobile\lib\services\api_service.dart"
(Get-Content $apiFile) -replace "http://[\d\.]+:3000/api", "http://${ip}:3000/api" | Set-Content $apiFile
Write-Host "✅ Updated api_service.dart" -ForegroundColor Green

# Update socket_service.dart
$socketFile = "D:\pfa\mobile\lib\services\socket_service.dart"
(Get-Content $socketFile) -replace "http://[\d\.]+:3000", "http://${ip}:3000" | Set-Content $socketFile
Write-Host "✅ Updated socket_service.dart" -ForegroundColor Green

Write-Host "`n🚀 Done! IP set to $ip in both files." -ForegroundColor Green
