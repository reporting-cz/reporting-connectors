// This file contains your Data Connector logic
[Version = "1.0.0"]
section Reporting;

defaultDomain = "report.reporting.cz";
defaultThread = "PowerBI/test";
client_id = Text.FromBinary(Extension.Contents("client_id"));
client_secret = Text.FromBinary(Extension.Contents("client_secret"));
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 700;
windowHeight = 700;

// DEBUG: overrides the access token lifetime (seconds) to test the refresh flow.
// Set to null for production (uses expires_in from the server).
debugTokenLifetime = null;

ApplyTokenLifetime = (token as record) as record =>
	if debugTokenLifetime = null then token
	else Record.AddField(Record.RemoveFields(token, "expires_in", MissingField.Ignore), "expires_in", debugTokenLifetime);

[DataSource.Kind="Reporting", Publish="Reporting.Publish"]
shared Reporting.Content = ContentRequest; //(thread as text) => Value.ReplaceType(TableRequest, TableRequestType);

// converts parameters in json to query string
// example: { "a": 1, "b": 2 } => "p[a]=1&p[b]=2"
ParametersToQueryString = (parameters as text) =>
	let
		json = Json.Document(parameters),
		keys = List.Transform(Record.FieldNames(json), each "p[" & _ & "]"),
		params = Record.FromList(List.Transform(Record.FieldValues(json), each Text.From(_)), keys)
	in
		Uri.BuildQueryString(params);

GetDomain = (domain as text) =>
	let
		domain1 = if domain = null or domain = "" then defaultDomain else domain,
		domain2 = Text.Split(domain1, "/")
	in 
		domain2{0};

ContentRequest = (domain as text, optional thread as text, optional parameters as text) =>
	let
		thread = thread ?? defaultThread,
		parameters = if parameters = null or parameters = "" then "" else ("&" & ParametersToQueryString(parameters)),
		url = "https://" & GetDomain(domain) & "/api/export/" & thread & "?" & Uri.BuildQueryString([
			delimiter = "tab",
			decimal_separator = ".",
			header = "1",
			encoding = "UTF-8"
		]) & parameters,
		// Authorization header is added automatically by the M engine (OAuth credential),
		// which also handles token expiration and calls RefreshTokenMethod when needed.
		tab1 = Table.Buffer(Csv.Document(Web.Contents(url), [
			Delimiter = "#(tab)",
			Encoding = 65001, 
			QuoteStyle = QuoteStyle.None
		])),
		tab2 = Table.PromoteHeaders(tab1, [PromoteAllScalars=true])
	in
		tab2;

// Data Source Kind description
Reporting = [
	TestConnection = (dataSourcePath) => {"Reporting.Content", defaultDomain, defaultThread, "{}"},
	Authentication = [
		OAuth = [
			StartLogin = StartLogin,
			FinishLogin = FinishLogin,
			Refresh = RefreshTokenMethod,
			Label = Extension.LoadString("AuthenticationLabel")
		]
	]
];

// Data Source UI publishing description
Reporting.Publish = [
	Category = "Other",
	ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
	LearnMoreUrl = "https://report.reporting.cz/wiki/Power_BI",
	SourceImage = Reporting.Icons,
	SourceTypeImage = Reporting.Icons
];

Reporting.Icons = [
	Icon16 = { Extension.Contents("reporting16.png"), Extension.Contents("reporting20.png"), Extension.Contents("reporting24.png"), Extension.Contents("reporting32.png") },
	Icon32 = { Extension.Contents("reporting32.png"), Extension.Contents("reporting40.png"), Extension.Contents("reporting48.png"), Extension.Contents("reporting64.png") }
];

// resourceUrl is the data source path, e.g. {"domain":"report.reporting.cz"};
// it can also be null or a plain text (e.g. during token refresh)
GetDomainFromResource = (resourceUrl) =>
	let
		parsed = try Json.Document(resourceUrl) otherwise null,
		domain =
			if parsed is record and Record.HasFields(parsed, "domain") and parsed[domain] is text then GetDomain(parsed[domain])
			else if parsed is text and parsed <> "" then GetDomain(parsed)
			else if resourceUrl is text and resourceUrl <> "" and parsed = null then GetDomain(resourceUrl)
			else defaultDomain,
		resourceText =if resourceUrl = null then "null" else (try Text.From(resourceUrl) otherwise null) ?? "?"
	in
		Diagnostics.Trace(TraceLevel.Information, "Reporting: resourceUrl=" & resourceText & ", domain=" & domain, domain);


// OAuth2 flow definition
StartLogin = (resourceUrl, state, display) =>
	let
		domain = GetDomainFromResource(resourceUrl),
		AuthorizeUrl = "https://" & domain & "/auth/oauth/authorizationcode?" & Uri.BuildQueryString([
			client_id = client_id,
			redirect = redirect_uri,
			prefer_sso = "1",
			oauth2 = "1",
			test = resourceUrl
		])
	in
		[
			LoginUri = AuthorizeUrl,
			CallbackUri = redirect_uri,
			WindowHeight = windowHeight,
			WindowWidth = windowWidth,
			Context = domain
		];

FinishLogin = (context, callbackUri, state) => 
	let 
		Parts = Uri.Parts(callbackUri)[Query] 
	in
		TokenMethod(Parts[authorization_code], context);

TokenMethod = (code, domain) =>
	let
		Response = Web.Contents("https://" & domain & "/auth/oauth?", [
			Content = Json.FromValue([
				client_id = client_id,
				client_secret = client_secret,
				grant_type = "authorization_code",
				authorization_code = code,
				redirect_uri = redirect_uri
			]),
			Headers = [#"Content-type" = "application/json", #"Accept" = "application/json"]
		]),
		Parts = Json.Document(Response)
	in
		ApplyTokenLifetime(Parts);


// NOTE: must have exactly 2 parameters. With 3 parameters the engine uses
// a different signature (clientApplication, dataSourcePath, oldCredential).
RefreshTokenMethod = (resourceUrl, refreshToken) =>
	let
		domain = GetDomainFromResource(resourceUrl),
		// Binary.Buffer: the response must be read exactly once. Web.Contents is lazy and every
		// access would send a new POST - the server rotates refresh tokens, so a second request
		// with the same (already used) refresh token fails with "invalid refresh token".
		Response = Binary.Buffer(Web.Contents("https://" & domain & "/auth/oauth?", [
			Content = Json.FromValue([
				client_id = client_id,
				client_secret = client_secret,
				grant_type = "refresh_token",
				refresh_token = refreshToken,
				redirect_uri = redirect_uri
			]),
			Headers = [#"Content-type" = "application/json", #"Accept" = "application/json"],
			ManualStatusHandling = {400, 401, 403, 404, 500}
		])),
		Parts = try Json.Document(Response) otherwise null,
		_ = if Parts is record and Record.HasFields(Parts, "access_token") then null
			else error Error.Record(
				"Reporting.RefreshFailed",
				"Token refresh failed (" & domain & "): " & Text.FromBinary(Response)
			),
		// keep the original refresh token if the server doesn't issue a new one
		Result = if _ = null and Record.HasFields(Parts, "refresh_token") and Parts[refresh_token] <> null
			then Parts
			else Record.AddField(Record.RemoveFields(Parts, "refresh_token", MissingField.Ignore), "refresh_token", refreshToken)
	in
		Diagnostics.Trace(TraceLevel.Information, "Reporting: access token refreshed", ApplyTokenLifetime(Result));