let
    year = Text.From(Excel.CurrentWorkbook(){[Name="year"]}[Content]{0}[Column1]),
    ctx = [
        module  = "I",
        view    = "data",
        filters = {
            [ dim = "PM", items = {
                { year & "01", 0, 1 },
                { year & "02", 0, 1 },
                { year & "03", 0, 1 },
                { year & "04", 0, 1 },
                { year & "05", 0, 1 },
                { year & "06", 0, 1 },
                { year & "07", 0, 1 },
                { year & "08", 0, 1 },
                { year & "09", 0, 1 },
                { year & "10", 0, 1 },
                { year & "11", 0, 1 },
                { year & "12", 0, 1 }
            } ],
            [ dim = "2", items = {
                { null, 1, 1 },
                { null, 2, 1 },
                { null, 3, 1 },
                { null, 4, 1 },
                { null, 5, 1 }
            } ]
        },
        indicators = {
            [ type = "AMOUNT", id = 2, balance = false ]
        },
        x_axis = { [ dim = "PM", subtotal = true ], [ dim = "I", subtotal = true ] },
        y_axis = { [ dim = "2",  subtotal = true ] }
    ]
in
    FetchReport(ctx)