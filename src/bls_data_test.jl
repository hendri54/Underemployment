@testitem "Ed fractions" begin
    using Underemployment, Test, TestItems, Random;
    rng = Xoshiro(43);
    nTg = length(Underemployment.OrderedBlsEdCodes);

    fracTrueV = LinRange(1.0, 2.0, nTg);
    fracTrueV = fracTrueV ./ sum(fracTrueV);

    # All valid
    levelV = randperm(rng, nTg);
    frac1V = fracTrueV[levelV];
    s1V = string.(frac1V .* 100);
    out1V = Underemployment.ed_fractions_one(levelV, s1V);
    @test all(isapprox.(out1V, fracTrueV));

    # Some missing
    level2V = levelV[1 : (nTg-2)];
    frac2V = fracTrueV[level2V];
    frac2V ./= sum(frac2V);
    s2V = string.(frac2V .* 100);
    out2V = Underemployment.ed_fractions_one(level2V, s2V);
    fracTrue2V = fracTrueV[level2V] ./ sum(fracTrueV[level2V]);
    @test all(isapprox.(out2V[level2V], fracTrue2V));
end


@testitem "Valid ed fraction" begin
    using Underemployment, Test, TestItems;
    @test Underemployment.valid_ed_fraction("54.3");
    @test Underemployment.valid_ed_fraction("54.3");
    @test !Underemployment.valid_ed_fraction("<15");
    @test Underemployment.valid_ed_fraction(">96");
    @test !Underemployment.valid_ed_fraction(">90");
end


@testitem "Recode ed fraction" begin
    using Underemployment, Test, TestItems;
    @test Underemployment.recode_ed_fraction("15.3") ≈ 0.153;
    @test Underemployment.recode_ed_fraction("<4") ≈ 0.02;
    @test ismissing(Underemployment.recode_ed_fraction("<6"));
    @test Underemployment.recode_ed_fraction(">99") ≈ 0.995;
    @test ismissing(Underemployment.recode_ed_fraction(">90"));
end


@testitem "Ed fractions some invalid" begin
    using Underemployment, Test, TestItems;
    nTg = length(Underemployment.OrderedBlsEdCodes);
    fracTrueV = collect(LinRange(1.0, 2.0, nTg));
    
    validV = trues(nTg);
    validV[2] = false;
    fracTrueV[2] = 0.0;
    fracTrueV = fracTrueV ./ sum(fracTrueV);
    fracStrV = string.(fracTrueV .* 100);
    fracV = Underemployment.ed_fractions_some_invalid(fracStrV, validV);
    @test all(isapprox.(fracTrueV, fracV));
end


@testitem "sort and complete levels" begin
    using Underemployment, Test, TestItems, Random;
    rng = Xoshiro(443);
    nTg = length(Underemployment.OrderedBlsEdCodes);
    fracV = LinRange(1, 2, nTg);
    fracV = fracV ./ sum(fracV) .* 100;

    s1V = string.(fracV);
    frac1V = Underemployment.sort_and_complete_ed_levels(collect(1 : nTg), s1V);
    @test frac1V == s1V;

    levelV = randperm(rng, nTg);
    frac2V = Underemployment.sort_and_complete_ed_levels(levelV, s1V[levelV]);
    @test frac2V == s1V;

    level3V = [4,1,2];
    s3V = s1V[level3V];
    frac3V = Underemployment.sort_and_complete_ed_levels(level3V, s3V);
    @test frac3V[level3V] == s1V[level3V];   
end


# -------------