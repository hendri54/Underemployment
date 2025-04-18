@testitem "Parse to ints" begin
    using Underemployment, Test, TestItems;
    @test Underemployment.parse_to_int("24") == 24;
    @test Underemployment.parse_to_int(453) == 453;
    @test ismissing(Underemployment.parse_to_int(missing));
    @test Underemployment.parse_to_int(345.000000001) == 345;
    @test Underemployment.parse_to_int("345.000000001") == 345;
end

@testitem "Delete missing rows" begin
    using DataFrames, Underemployment, Test, TestItems;
    # Test 1: Drop rows with missing values
    df = DataFrame(:var => [1, missing, 3], 
        Underemployment.WeightVar => [1.0, 2.0, 3.0])
    nDrop = Underemployment.delete_missing_rows!(df, :var)
    @test nDrop == 1
    @test nrow(df) == 2
    @test df.var == [1, 3]

    # Test 2: Correct fraction of total mass deleted
    df = DataFrame(:var => [1, missing, 3, missing], 
        Underemployment.WeightVar => [1.0, 2.0, 3.0, 4.0]);
    nDrop = Underemployment.delete_missing_rows!(df, :var);
    @test nDrop == 2;
    @test nrow(df) == 2;
    @test all(.!ismissing.(df.var));
    @test sum(df[!, Underemployment.WeightVar]) ≈ 4.0;

    # Test 3: No missing values
    df = DataFrame(:var => [1, 2, 3], 
        Underemployment.WeightVar => [1.0, 2.0, 3.0])
    nDrop = Underemployment.delete_missing_rows!(df, :var);
    @test nDrop == 0
    @test nrow(df) == 3
end

@testitem "drop one" begin
    using Underemployment, Test;

    v = ["one", "two", "three"];
    v2, _ = Underemployment.drop_one(v, "two");
    @test v2 == ["one", "three"];

    v3, _ = Underemployment.drop_one(v, "nada");
    @test v3 == v;

    v4 = [YearGroups, AgeGroups, GradOccs];
    v5, idx5 = Underemployment.drop_one(v4, GradOccs);
    @test v5 == [YearGroups, AgeGroups];
    @test idx5 == 3;
end


# ------------