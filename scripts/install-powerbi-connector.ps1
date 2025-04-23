$documentDir = [Environment]::GetFolderPath('MyDocuments')
$pbiDir = "$documentDir\Microsoft Power BI Desktop\Custom Connectors"

if (!(Test-Path -Path $pbiDir)) {
	New-Item -ItemType Directory -Path $pbiDir -Force | Out-Null
}

$sourceUrl = "https://github.com/reporting-cz/reporting-connectors/raw/refs/heads/main/powerbi/dist/reporting-powerbi.mez"
$destinationPath = "$pbiDir\reporting-powerbi.mez"
Invoke-WebRequest -Uri $sourceUrl -OutFile $destinationPath
