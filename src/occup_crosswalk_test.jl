@testitem "Parse code out of title" begin
    using Underemployment, Test, TestItems;
    f = Underemployment.parse_code_out_of_title;
    @test f("Air Crew Members (55-3011)") == 553011;
    @test ismissing(f("Financial Managers"));
    @test ismissing(f("Air Crew members (a5-3011)"));
end

@testitem "Copy missing codes down" begin
    using DataFrames, Underemployment, Test, TestItems;
    cCodeV = [40, 50, missing, missing, 60, 70];
    titleV = map(x -> (ismissing(x) ? missing : string(x)),  cCodeV);
    df = DataFrame(
        Census2010Code = cCodeV,
        Census2010Title = titleV;
    );
    Underemployment.copy_missing_codes_down!(df);
    newCodeV = [40, 50, 50, 50, 60, 70];
    @test df.Census2010Code == newCodeV;
    @test df.Census2010Title == string.(newCodeV);
end

@testitem "CPS occ codes" begin
    using DataFrames, Underemployment, Test, TestItems;

    ds = data_settings(:test);
    codeV = [10, 20, 30, 30, 20, 10, 20, 30];
    massV = codeV .* 1.1;
    titleV = map(x -> "title $x", codeV);
    cpsOccVar = Underemployment.CpsOccVar;
    wtVar = Underemployment.WeightVar;
    titleVar = Underemployment.OccVar;
    dfCps = DataFrame(
        cpsOccVar => codeV,
        wtVar => massV,
        titleVar => titleV
    );

    codeDf = Underemployment.cps_occ_codes(dfCps, ds);
    @test codeDf[!, cpsOccVar] == [10, 20, 30];
    @test codeDf[!, :Census2010Title] == 
        ["title 10", "title 20", "title 30"];
    wtV = codeDf[!, :occMass];
    tgWt = sum(massV .* (codeV .== 10)) ./ sum(massV);
    @test isapprox(first(wtV), tgWt);

    # for dfRow in eachrow(codeDf)
    #     oCode = getproperty(dfRow, cpsOccVar);
    #     idxV = findall(x -> x == codeV, oCode);
    #     # Check mapping code -> title
    #     @test getproperty(dfRow, :Census2010Title) == titleV[first(idxV)];
    # end
end

@testitem "SOC codes for CPS codes" begin
    using DataFrames, Underemployment, Test, TestItems;
    cpsVar = Underemployment.CpsOccVar;
    blsVar = Underemployment.BlsOccVar;
    dfOcc = DataFrame(
        cpsVar => [10, 20, 50, 50, 100, 100],
        blsVar => [110, 120, 151, 152, 1101, 1102]
    );
    dfOut = Underemployment.soc_codes_for_cps_codes(dfOcc);
    @test dfOut[!, cpsVar] == unique(dfOcc[!, cpsVar]);
    @test dfOut[!, blsVar] == [[110], [120], [151, 152], [1101, 1102]];
end

# ---------------