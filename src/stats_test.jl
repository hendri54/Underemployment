@testitem "var quantiles" begin
    using DataFrames, DataFramesMeta, Random, StatsBase, Underemployment, Test;
    rng = Xoshiro(43);
    ng = 3;
    n = 500;
    df = DataFrame(
        grp = rand(rng, 1 : ng, n),
        wt = rand(rng, n)
    );
    df.y = df.grp .* randn(rng, n);
    gdf = groupby(df, :grp);

    pctV = [0.25, 0.75];
    dfQ = Underemployment.var_quantiles(gdf, :y, pctV; weights = :wt);

    ig = 2;
    dfSub = @subset(df, :grp .== ig);
    quantV = quantile(dfSub.y, ProbabilityWeights(dfSub.wt), pctV);
    dfQSub = @subset(dfQ, :grp .== ig);
    @test isapprox(quantV, dfQSub.y; rtol = 1e-3);
end


@testitem "stats grouped" setup = [TestSetup] begin
    using DataFrames, Underemployment, Test;

    gradOccVar = GradOccs;
    for groups in (
        [YearGroups], 
        [AgeGroups, YearGroups], 
        [gradOccVar, YearGroups]
        );
        groupValV = [
            first(Underemployment.group_labels(g, TestSetup.DS))   
            for g in groups
                ];
        statsDf = stats_grouped(TestSetup.DF, groups, TestSetup.DS);
        @test Underemployment.check_stats_one_group(TestSetup.DF, statsDf, 
            groups, groupValV, TestSetup.DS; gradOccVar);
    end
end


@testitem "Frac by OccFracBa" setup = [TestSetup] begin
    using CategoricalArrays, DataFrames, DataFramesMeta, Underemployment, Test, TestItems;
    ubV = [0.25, 0.75, 1.0];
    yearVar = var_symbol(Years);
    dfOut = Underemployment.frac_by_occFracBa(TestSetup.DF, TestSetup.DS;
        ubV);

    dfY = @subset(TestSetup.DF, $yearVar .== 1980);
    dfStats = Underemployment.mass_by_groups(dfY, Occupations);
    dfStats.fracBA = dfStats.massBA ./ dfStats.mass;
    dfG1 = @subset(dfStats, :fracBA .<= ubV[1]);
    fracG1 = sum(dfG1.mass) ./ sum(dfStats.mass);
    dfMatch = @subset(dfOut, $yearVar .== 1980, 
        levelcode.(:fracBAgroup) .== 1);
    @test nrow(dfMatch) == 1;
    @test isapprox(fracG1, only(dfMatch.frac));
end



# ----------------