param(
	[string]$RefreshToken,
	[string]$Domain = "report.reporting.cz"
)

$Domain = "https://$Domain"

# Exchange new access token using the refresh token
$tokenUrl = "$Domain/auth/oauth"
$body = ConvertTo-Json @{
	grant_type = "refresh_token"
	refresh_token = $RefreshToken
}
$response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType "application/json"

if (!$response -or !$response.access_token) {
	Write-Error "Failed to retrieve access token."
	exit 1;
}

echo "Access Token: $($response.access_token)"
echo "Refresh Token: $($response.refresh_token)"
$exirationTime = [DateTime]::Now.AddSeconds($response.expires_in)
echo "Expires In: $($response.expires_in) seconds (at $exirationTime)"