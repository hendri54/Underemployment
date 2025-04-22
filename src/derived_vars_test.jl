@testitem "recode var" begin
    using Underemployment, Test;
    dCodes = Dict(2 => "two", 1 => "one", 3 => missing);
    v = [3, 2, 1];
    r = Underemployment.recode_var(v, dCodes; tgType = Union{Missing, String});
    @test all(isequal.(r ,[missing, "two", "one"]));
end

@testitem "recode_from_ub" begin
    using Underemployment, Test;

    function check_recode(v, r, ubV)
        if r == 1
            return (v <= ubV[r])
        else
            return (v <= ubV[r])  &&  (v > ubV[r-1]);
        end
    end

    ubV = [0.3, 0.8, 1.0];
    n = 50;
    rng = Underemployment.make_rng(34);
    v = rand(rng, n);
    r = Underemployment.recode_from_ub(v, ubV);

    validV = check_recode.(v, r, Ref(ubV));
    @test all(validV);

    r1 = Underemployment.recode_from_ub([1.0], ubV);
    @test r1 == [3];
end


# -----------------