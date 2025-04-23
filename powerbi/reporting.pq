// This file contains your Data Connector logic
[Version = "1.0.0"]
section Reporting;

domain = "report.reporting.cz";
client_id = "28bcedda-5acd-4050-9312-1bd7bccde8c4"; // Text.FromBinary(Extension.Contents("client_id"));
client_secret = "jbaft7gsv4n3nb7rkezki4c2rr5x2tic"; // Text.FromBinary(Extension.Contents("client_secret"));
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 600;
windowHeight = 600;

[DataSource.Kind="Reporting", Publish="Reporting.Publish"]
shared Reporting.Contents = (thread as text) =>
    let
        url = "https://" & domain & "/api/export/" & thread & "?" & Uri.BuildQueryString([
            delimiter = "tab",
            decimal_separator = ".",
            header = "1",
            encoding = "UTF-8"
        ]),
        tab = Table.Buffer(Csv.Document(Web.Contents(url, [
            Headers = [#"Authorization" = "Bearer " & Extension.CurrentCredential()[access_token]]
        ]), [
            Delimiter = "#(tab)",
            Encoding = 65001, 
            QuoteStyle = QuoteStyle.None
        ]))
    in
        tab;

// Data Source Kind description
Reporting = [
    TestConnection = (dataSourcePath) => {"Reporting.Contents", "excel-export-test1"},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ]
];

// // Data Source UI publishing description
Reporting.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Reporting.Icons,
    SourceTypeImage = Reporting.Icons
];

Reporting.Icons = [
    Icon16 = { Extension.Contents("reporting16.png"), Extension.Contents("reporting20.png"), Extension.Contents("reporting24.png"), Extension.Contents("reporting32.png") },
    Icon32 = { Extension.Contents("reporting32.png"), Extension.Contents("reporting40.png"), Extension.Contents("reporting48.png"), Extension.Contents("reporting64.png") }
];


//
// OAuth2 flow definition
//
StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://" & domain & "/auth/oauth/authorizationcode?"
            & Uri.BuildQueryString(
                [
                    client_id = client_id,
                    redirect = redirect_uri,
                    prefer_sso = "1",
                    oauth2 = "1"
                ]
            )
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) => let Parts = Uri.Parts(callbackUri)[Query] in TokenMethod(Parts[authorization_code]);

TokenMethod = (code) =>
    let
        Response = Web.Contents(
           "https://" & domain & "/auth/oauth?",
            [
                Content = Json.FromValue(
                        [
                            client_id = client_id,
                            client_secret = client_secret,
                            grant_type = "authorization_code",
                            authorization_code = code,
                            redirect_uri = redirect_uri
                        ]
                ),
                Headers = [#"Content-type" = "application/json", #"Accept" = "application/json"]
            ]
        ),
        Parts = Json.Document(Response)
    in
        Parts;
