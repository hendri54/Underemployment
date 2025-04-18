function delete_var!(df :: AbstractDataFrame, vName)
    if column_exists(df, vName)
        select!(df, Not(vName));
    end
end

@testitem "delete_var!" begin
    using DataFrames, Underemployment, Test;
    df = DataFrame(a = [1, 2, 3], b = [4, 5, 6]);
    Underemployment.delete_var!(df, :a);
    @test names(df) == ["b"];
    df2 = DataFrame(a = [1, 2, 3], b = [4, 5, 6]);
    Underemployment.delete_var!(df2, "b");
    @test names(df2) == ["a"];
end

function column_exists(df :: AbstractDataFrame, vName)
    return String(vName) in names(df);
end

@testitem "column exists" begin
    using DataFrames, Underemployment, Test;
    df = DataFrame(a = [1, 2, 3], b = [4, 5, 6]);
    @test Underemployment.column_exists(df, :a);
    @test Underemployment.column_exists(df, "a");
    @test !Underemployment.column_exists(df, "c");
end


"""
Apply `fltFct` to each row. `fltFct` returns `true` if the row should be dropped.
"""
function apply_filter_fct!(df :: DataFrame, fltFct)
    df.keep = trues(nrow(df));
    for (ir, dfRow) in enumerate(eachrow(df))
        if fltFct(dfRow)
            df.keep[ir] = false;
        end
    end
    filter!(row -> row.keep, df);
    @info "  " * format(nrow(df); commas = true) * " rows";
end

@testitem "apply_filter_fct!" begin
    using DataFrames, Underemployment, Test;
    df = DataFrame(a = [1, 2, 3], b = [4, 5, 6]);

    function test_filter(dfRow)
        return dfRow.a == 1;
    end

    Underemployment.apply_filter_fct!(df, test_filter);
    @test df.a == [2, 3];
end

# -------------------