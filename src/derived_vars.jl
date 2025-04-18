function add_derived_vars!(df :: DataFrame, ds)
    @info  "Adding derived vars";
    df.year = Int.(df.year);
    # Converts labeled array into Int
    df.age = Int.(refarray(df.age));
    df.weeksWorked = make_weeks_worked(df);
    df.wage = make_wage(df, ds);
    df.logWage = log.(df.wage);
    df.edLevel = make_education_level(df);
    df.experience = make_experience(df);

    # df[!, :hasCollege] = df.educd .>= 70;  # at least 1 year of college
    # Has BA degree or more
    df[!, :BAorMore] = has_ba(df);
    df[!, var_label(Grads)] = ba_categorical(df.BAorMore);
    # df[!, :isWhite] = df.race .== 1;
    df.isMale = (df.sex .== 1);
    df.sex = make_sex(df.sex);
    df.race = CategoricalArray(valuelabels(df.race));
    df.occup = CategoricalArray(valuelabels(df[!, OccVar]));
    df.marst = CategoricalArray(valuelabels(df.marst));
    # Integer IPUMS occ codes
    df[!, CpsOccVar] = refarray(df[!, OccVar]);
    df.ageGroup = make_age_groups(df.age, ds);
    df.yearGroup = make_year_groups(df.year, ds);
    # df[!, :raceCat] = recode_race(df.race);
    # if !ds[:menOnly]
    #     df[!, :sexCat] = recode_sex(df.sex);
    # end
end


"""
Recode a variable based on a Dict with codes and values.
Not categorical.
"""
function recode_var(v :: AbstractVector, dCodes :: Dict; tgType = Union{Missing, Float64})
    return Vector{tgType}(map(x -> dCodes[x], v));
end

@testitem "recode var" begin
    using Underemployment, Test;
    dCodes = Dict(2 => "two", 1 => "one", 3 => missing);
    v = [3, 2, 1];
    r = Underemployment.recode_var(v, dCodes; tgType = Union{Missing, String});
    @test all(isequal.(r ,[missing, "two", "one"]));
end


"""
Recode a Vector to group indices based on group upper bounds.
All values up to (including) ub element j belong to group j.
"""
function recode_from_ub(v :: AbstractVector, ub :: AbstractVector)
    # minDiff = minimum(diff(ub));
    # minDiff = 0;
    # return searchsortedfirst.(Ref(ub .+ minDiff / 2), v) .+ 1;
    vMax = maximum(v);
    @assert vMax <= last(ub)  """
        Values out of bounds: $vMax  vs  $(last(ub))
        """;
    return [findfirst(ub1 -> ub1 >= x, ub) for x in v]
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


function make_sex(sexV)
    v = recode_var(sexV, sex_codes(); 
        tgType = Union{Missing, String});
    return categorical(v)
end

sex_codes() = Dict(1 => "male", 2 => "female");


function make_year_groups(yearV, ds)
    group_indices = recode_from_ub(yearV, ds.yearGroupUb);    
    return categorical(year_group_labels(ds)[group_indices]);
end

function year_group_labels(ds)
    ["To $ub"  for ub in ds.yearGroupUb];
end


function make_age_groups(ageV, ds)
    group_indices = recode_from_ub(ageV, ds.ageGroupUb);    
    return categorical(age_group_labels(ds)[group_indices]);
end

function age_group_labels(ds)
    ["To $ub"  for ub in ds.ageGroupUb];
end


function make_weeks_worked(df :: DataFrame)
    return recode_var(df.wkswork2, weeks_worked_codes());
end

weeks_worked_codes() = Dict(
    0 => 0.0, 1 => 7.0, 2 => 20.0, 3 => 33.0, 4 => 43.5, 5 => 48.5, 6 => 51.0, 9 => missing
    );


"""
Weekly wage. Constant prices.
"""
function make_wage(df :: DataFrame, ds)
    wage = Vector{Union{Missing, Float64}}(df.incwage);
    for (j, w) in enumerate(wage)
        weeksWorked = df.weeksWorked[j];
        if (w > 99999997)  ||  ismissing(weeksWorked)  ||  (weeksWorked <= 0)
            wage[j] = missing;
        else
            # CPIs are factors. Multiply, not divide by them.
            wage[j] = w / weeksWorked / cpi_index(df.year[j]);
        end
    end
    return wage
end


function make_experience(df :: DataFrame)
    @assert EducVar == :educ;
    yrSchool = recode_var(df.edLevel, educ_years(); tgType = Union{Missing, Float64});
    xpV = max.(df.age .- yrSchool .- 6, 0.0);
    return xpV
end


function make_education_level(df :: DataFrame)
    # Educ99 is a LabeledArray
    @assert EducVar == :educ;
    categorical(recode_var(refarray(df[!, EducVar]), educ_codes(); 
        tgType = Union{Missing, String}));
end

# Must be String codes for categorical vector.
educ_codes() = Dict(
    0 => missing, 1 => missing, 2 => missing, 999 => missing, missing => missing,
    10 => "HSD", 11 => "HSD", 12 => "HSD", 13 => "HSD", 14 => "HSD",
    20 => "HSD", 21 => "HSD", 22 => "HSD",
    30 => "HSD", 31 => "HSD", 32 => "HSD", 
    40 => "HSD", 50 => "HSD", 60 => "HSD",
    70 => "HSG", 71 => "HSD", 72 => "HSG", 73 => "HSG",
    80 => "SC", 81 => "SC", 90 => "SC", 91 => "SC", 92 => "SC",
    100 => "SC", 110 => "CG", 111 => "CG", 120 => "CG", 121 => "CG", 122 => "CG", 
    123 => "MA", 124 => "MA", 125 => "PHD"
);

# Assumed years of schooling by education level
educ_years() = Dict(
    "HSD" => 11, "HSG" => 12, "SC" => 14, "CG" => 16, "MA" => 18, "PHD" => 20, missing => missing
    );

function has_ba(df :: AbstractDataFrame) 
    @assert EducVar == :educ;
    return (df.educ .>= 110);
end

function ba_categorical(hasBaV)
    return categorical(recode_var(hasBaV, 
        Dict(false => NonGradLabel, true => GradLabel);
        tgType = Union{Missing, String}));
end

# Educ99 is only available after 1992
# educ99_codes() = Dict(
#     0 => missing, missing => missing,
#     1 => :HSD, 2 => :HSD, 3 => :HSD, 4 => :HSD, 5 => :HSD, 6 => :HSD, 7 => :HSD, 8 => :HSD, 9 => :HSD, 
#     10 => :HSG, 
#     11 => :SC, 12 => :SC, 13 => :SC, 14 => :SC, 
#     15 => :CG, 16 => :MA, 17 => :MA, 18 => :PHD
# )

# function make_education_level!(dfRow)
#     edRaw = dfRow.educ99;
#     if ismissing(edRaw)  ||  (edRaw <= 0)
#         dfRow.edLevel = missing;
#     else
#         recode_var
# end

# ------------------