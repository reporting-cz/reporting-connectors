// Base url = reporting.bi api v2 base url, eg. https://reporting.bi/api/v2
// Accounting = accounting id
// Token = access token
(Context as record) as table =>
let
    ContextJson = Text.FromBinary(Json.FromValue(Context)),

    Response = Web.Contents(
        BaseUrl,
        [
            RelativePath = Text.From(Accounting) & "/reports",
            Query        = [ context = ContextJson ],
            Headers      = [s
                #"Accept"        = "text/csv",
                #"Authorization" = "Bearer " & Token
            ]
        ]
    ),

    Csv     = Csv.Document(Response, [Delimiter = "#(tab)", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Headers = Table.PromoteHeaders(Csv, [PromoteAllScalars = true]),

    NumericPrefixes = {"AMOUNT_", "QTY_", "COMP_", "VAR_"},
    IsNumeric = (name as text) =>
        List.AnyTrue(List.Transform(NumericPrefixes, (p) => Text.StartsWith(name, p))),

    Typed = Table.TransformColumnTypes(
        Headers,
        List.Transform(
            Table.ColumnNames(Headers),
            (c) => {c, if IsNumeric(c) then type number else type text}
        ),
        "en-US"
    )
in
    Typed