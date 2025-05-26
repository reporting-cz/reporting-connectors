# Projects

## Reporting PowerBI Connector

### Installation
To install the Reporting PowerBI Connector, run the following command in PowerShell:

```shell
irm https://raw.githubusercontent.com/reporting-cz/reporting-connectors/refs/heads/main/scripts/install-powerbi-connector.ps1 | iex
```

## Reporting PowerShell Client

### Authorization
Start the authorization flow to obtain an access token:

```powershell
./powershell/authorization.ps1
```

### Export Data
Export data from Reporting.cz using the following command:

```powershell
./powershell/request.ps1 -AccessToken "xxx" -Thread "export123"
```

### Refresh Token
Exchange a refresh token for a new access token:

```powershell
./powershell/refreshtoken.ps1 -RefreshToken "xxx"
```