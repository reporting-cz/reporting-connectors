param(
	[string]$AccessToken,
	[string]$Thread = "PowerBI/D_STATEMENT",
	[string]$Domain = "report.reporting.cz",
	[int]$CsvHeader = 1,
	[string]$CsvDelimiter = ";",
	[string]$CsvQuote = ""
)

$Domain = "https://$Domain"
$resourceUrl = $(
	$Domain,
	"/api/export/?",
	"name=", $Thread,
	"&header=", $CsvHeader,
	"&delimiter=", $CsvDelimiter,
	"&enclosure=", $CsvQuote
) -join ""

$response = Invoke-RestMethod -Uri $resourceUrl -Method Get -Headers @{
	Authorization = "Bearer $AccessToken"
}

echo $response