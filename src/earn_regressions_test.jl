@testitem "Extract year" begin
    using Underemployment, Test, TestItems;
    f(x) = Underemployment.extract_year(x);
    @test f("year: 1990") == 1990;
    @test isnothing(f("year: 199"));
end

@testitem "Dummies" begin
    using GLM, Random, Underemployment, Test, TestItems;
    rng = Xoshiro(43);
    n = 20;
    yearV = 1990 : 1995;
    df = (
        year = rand(rng, yearV, n),
        x = rand(rng, n),
        y = rand(rng, n)
    );

    mdl = lm(@formula(y ~ x + year), df;  
        contrasts = Dict(:year => DummyCoding()));

    dfOut = Underemployment.get_year_dummies(mdl);
    @test sort(dfOut.Year) == collect(yearV[2 : end]);

    idxV = Underemployment.find_regressors(mdl, r"^year");
    @test length(idxV) == (length(yearV) - 1);
    @test all(startswith.(coefnames(mdl)[idxV], "year"));
end

@testitem "Quantiles grouped" begin
    using DataFrames, Random, Underemployment, Test, TestItems;
    rng = Xoshiro(43);
    n = 250;
    grpVars = Underemployment.Years;
    df = DataFrame(
        year = rand(rng, 1990 : 1992, n),
        asecwt = rand(rng, n),
        y = rand(rng, n)
    );
    pctV = [0.2, 0.5, 0.9];
    dfOut = Underemployment.quantiles_grouped(df, :y, grpVars, nothing, pctV);
end


# -----------------