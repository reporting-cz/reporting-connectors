param(
	[string]$AccessToken,
	[string]$Domain = "report.reporting.cz",
	[string]$LocalPath = "c:\accounts.csv",
	[string]$FileName = "accounts.csv"
)

$client = New-Object System.Net.WebClient
$client.Headers.Add("Authorization", "Bearer $AccessToken")

$Domain = "https://$Domain"
$url = $(
	$Domain,
	"/api/import/?",
	"file=", $FileName
) -join ""

$client.UploadFile($url, $LocalPath)
