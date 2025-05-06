// This file contains your Data Connector logic
[Version = "1.0.0"]
section Reporting;

defaultDomain = "report.reporting.cz";
defaultThread = "PowerBI/test";
client_id = "28bcedda-5acd-4050-9312-1bd7bccde8c4"; // Text.FromBinary(Extension.Contents("client_id"));
client_secret = "jbaft7gsv4n3nb7rkezki4c2rr5x2tic"; // Text.FromBinary(Extension.Contents("client_secret"));
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 700;
windowHeight = 700;

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
		domain2 = Text.Split(domain, "/")
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
		tab1 = Table.Buffer(Csv.Document(Web.Contents(url, [
			Headers = [#"Authorization" = "Bearer " & Extension.CurrentCredential()[access_token]]
		]), [
			Delimiter = "#(tab)",
			Encoding = 65001, 
			QuoteStyle = QuoteStyle.None
		])),
		tab2 = Table.PromoteHeaders(tab1, [PromoteAllScalars=true])
	in
		tab2;

// TableRequestType = type function (
// 	thread as (
// 		type text meta [
// 			Documentation.FieldCaption = "Thread",
// 			Documentation.FieldDescription = "ETL thread name"
// 		]
// 	)
// ) as table meta [
// 	Documentation.Name = "ETL thread result",
// 	Documentation.LongDescription = "ETL thread result"
// ];

// Data Source Kind description
Reporting = [
	TestConnection = (dataSourcePath) => {"Reporting.Content", "excel-export-test1", "{""a"":1}"},
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

GetDomainFromResource = (resourceUrl) =>
	let
		json = Json.Document(resourceUrl),
		domain = if Record.HasFields(json, "domain") then GetDomain(json[domain]) else defaultDomain
	in
		domain;


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
		Parts;


RefreshTokenMethod = (resourceUrl, refreshToken, state) =>
	let
		domain = GetDomainFromResource(resourceUrl),
		Response = Web.Contents("https://" & domain & "/auth/oauth?", [
			Content = Json.FromValue([
				client_id = client_id,
				client_secret = client_secret,
				grant_type = "refresh_token",
				refresh_token = refreshToken,
				redirect_uri = redirect_uri
			]),
			Headers = [#"Content-type" = "application/json", #"Accept" = "application/json"]
		]),
		Parts = Json.Document(Response)
	in
		Parts;