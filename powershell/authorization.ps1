param(
	[string]$Domain = "report.reporting.cz",
	[int]$Accounting = $null
)

$Domain = "https://$Domain"

# Authorization Code Flow
$tcpListener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$tcpListener.Start()
$port = $tcpListener.LocalEndpoint.Port
$tcpListener.Stop()

$redirectUrl = "http://localhost:$port";
$authorizationUrl = @(
	$Domain,
	"/auth/oauth/authorizationcode?",
	"redirect=", $redirectUrl
) -join ""

if ($null -ne $Accounting) {
	$authorizationUrl += "&a=$Accounting"
}

Start-Process $authorizationUrl

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("$redirectUrl/")
$listener.Start()
Write-Host "Listening on $redirectUrl..."

$authorizationCode = $null

try {
	$context = $listener.GetContext()
	$request = $context.Request

	$queryParams = [System.Web.HttpUtility]::ParseQueryString($request.Url.Query)
	foreach ($key in $queryParams.Keys) {
		if ($key -eq "authorization_code") {
			$authorizationCode = $queryParams[$key]
		}
	}

	$response = $context.Response
	$responseString = "Authorization successful. You can close this window."
	$buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)
	$response.ContentLength64 = $buffer.Length
	$response.OutputStream.Write($buffer, 0, $buffer.Length)
	$response.OutputStream.Close()
} catch {
	Write-Error "An error occurred: $_"
	exit 1;
} finally {
	$listener.Stop()
	Write-Host "Listener stopped."
}

if (-not $authorizationCode) {
	Write-Error "Authorization code not received."
	exit 1;
}

# Exchange the authorization code for an access token
$tokenUrl = "$Domain/auth/oauth"
$body = ConvertTo-Json @{
	grant_type = "authorization_code"
	authorization_code = $authorizationCode
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
