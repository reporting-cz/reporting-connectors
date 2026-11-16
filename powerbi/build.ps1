# Builds the Power BI connector into ./dist/reporting-powerbi.mez
# Requires the Power Query SDK extension for VS Code (provides MakePQX.exe and PQTest.exe).

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$name = "reporting-powerbi"
$files = @("reporting.pq", "client_id", "client_secret", "resources.resx", "*.png")

# find SDK tools (newest version)
$tools = Get-ChildItem "$env:USERPROFILE\.vscode\extensions\powerquery.vscode-powerquery-sdk-*\.nuget\Microsoft.PowerQuery.SdkTools.*\tools" -Directory |
	Sort-Object FullName -Descending | Select-Object -First 1
if (!$tools) { throw "Power Query SDK tools not found - install the 'Power Query SDK' extension in VS Code." }

# stage only the connector files (MakePQX packs everything in the source directory)
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) "$name-build"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory $tmp | Out-Null
$files | ForEach-Object { Copy-Item (Join-Path $root $_) $tmp }

# replace placeholder client_id / client_secret with real values from credentials.json (gitignored), if present
$credentialsFile = Join-Path $root "credentials.json"
if (Test-Path $credentialsFile) {
	$credentials = [System.IO.File]::ReadAllText($credentialsFile) | ConvertFrom-Json
	$utf8NoBom = New-Object System.Text.UTF8Encoding $false
	foreach ($key in "client_id", "client_secret") {
		$value = $credentials.$key
		if ([string]::IsNullOrWhiteSpace($value)) { throw "credentials.json is missing '$key'" }
		# no trailing newline - the connector reads the file as-is via Text.FromBinary
		[System.IO.File]::WriteAllText((Join-Path $tmp $key), $value.Trim(), $utf8NoBom)
	}
	Write-Host "Using client_id / client_secret from credentials.json"
} else {
	Write-Host "credentials.json not found - using placeholder client_id / client_secret" -ForegroundColor Yellow
}

try {
	# build .mez
	& "$($tools.FullName)\MakePQX.exe" compile $tmp -d "$root\dist" -t $name | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "MakePQX failed with exit code $LASTEXITCODE" }

	# validate that the engine can load it
	$info = & "$($tools.FullName)\PQTest.exe" info -e "$root\dist\$name.mez" | ConvertFrom-Json
	if ($info[0].ErrorStatus) { throw "Connector failed to load: $($info[0].ErrorStatus | ConvertTo-Json -Depth 5)" }

	Write-Host "Built $root\dist\$name.mez ($($info[0].Members.Name -join ', '))" -ForegroundColor Green
} finally {
	Remove-Item -Recurse -Force $tmp
}
