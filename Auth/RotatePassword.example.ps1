$passwords = @{
    "YYYY-MM-DD" = "replace-with-local-password"
}

$today = Get-Date -Format "yyyy-MM-dd"

if (-not $passwords.ContainsKey($today)) {
    Write-Host "No password scheduled for today."
    exit
}

$newPassword = $passwords[$today]
$newSecret = [guid]::NewGuid().ToString()

setx STREAM_PASSWORD "$newPassword" /M
setx STREAM_SECRET "$newSecret" /M