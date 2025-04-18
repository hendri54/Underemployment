## ------------  Classifications

struct Grouping
    varLabel :: String
    descr :: String
    suffix :: String
end

const MultiGrouping = AbstractVector{Grouping};
const AnyGrouping = Union{Grouping, AbstractVector{Grouping}};

const YearGroups = Grouping("yearGroup", "Year group", "Yg");
const AgeGroups = Grouping("ageGroup", "Age group", "Ag");
const Occupations = Grouping("occup", "Occupation", "O");
const Years = Grouping("year", "Year", "Y");
const Grads = Grouping("grad", "Graduate", "G");

# Different ways of defining graduate occupations and who works in them
const GradOccs = Grouping("gradOcc", "Graduate occupations", "Go");
const GradsGradOccs = 
    Grouping("gradsGradOccs", "Degree and match", "Ggo");
# const BaRequOccs = Grouping("baRequOcc", "Occupation requiring BA", "Bo");
# const GradsBaRequOccs = 
#     Grouping("gradsBaRequOccs", "Degree and match", "Gbo");

# Pairs of grad occ concepts and the matching "degree and match" variables.
# Idea is to create stats for different definitions.
# grad_occ_definitions() = (
#     (GradOccs, GradsGradOccs), 
#     (BaRequOccs, GradsBaRequOccs)
#     );

# function grads_grad_occ_var(gradOccVar)
#     gdefs = grad_occ_definitions();
#     idx = findfirst(x -> first(x) == gradOccVar,  gdefs);
#     @assert !isnothing(idx)  "Not found: $(gradOccVar)";
#     _, gradsGradOccVar = gdefs[idx];
#     return gradsGradOccVar
# end


## ---------  Generic

var_label(g :: Grouping) = g.varLabel;
var_label(g) = String.(g);
var_symbol(g :: Grouping) = Symbol(g.varLabel);
var_symbol(g) = Symbol.(g);

var_labels(g :: Grouping) = [g.varLabel];
var_labels(g :: MultiGrouping) = var_label.(g);
var_labels(v :: AbstractVector) = var_label.(v);

file_suffix(g :: Grouping) = "_" * g.suffix;
file_suffix(v :: MultiGrouping) = "_" * prod([g.suffix for g in v]);
file_suffix(::Nothing) = "";

fig_label(g :: Grouping) = g.descr;
fig_label(::Nothing) = nothing;
fig_label(g) = string(g);


function grouping_list()
    return [YearGroups, AgeGroups, GradOccs, Occupations, Years];
end

function group_labels(g :: Grouping, ds)
    if g == YearGroups
        return year_group_labels(ds)
    elseif g == AgeGroups
        return age_group_labels(ds)
    elseif g == GradOccs
        return grad_occ_labels(ds);
    else
        error("Invalid grouping $g");
    end
end

function merge_groups(g1, g2)
    return unique(vcat(g1, g2))
end


## -----------  Specific

grad_occ_labels(ds) = [NonGradOccLabel, GradOccLabel];

# For converting categorical variable to Bool
# Works for any graduate occupation concept (same labels).
is_grad_occ(occ :: AbstractString) = (occ == GradOccLabel);
is_grad_occ(occ :: CategoricalValue) = (occ == GradOccLabel);

# Can be missing
function is_grad_occ(dfRow :: DataFrameRow, gradOccVar; missVal = missing)
    v = get_var(dfRow, gradOccVar);
    if ismissing(v)
        return missVal
    else
        return v == GradOccLabel;
    end
end

grads_gradoccs_labels(ds) = 
    [GradLabel, "Underemployed", "Overemployed", NonGradLabel];

"""
Only keep rows for graduate occupations.
"""
function subset_grad_occs(df :: AbstractDataFrame, gradOccVar)
    filter(dfRow -> is_grad_occ(dfRow, gradOccVar; missVal = false), df);
end

function subset_not_grad_occs(df :: AbstractDataFrame, gradOccVar)
    filter(dfRow -> !is_grad_occ(dfRow, gradOccVar; missVal = true), df);
end


is_grad(dfRow :: DataFrameRow) = is_grad(dfRow[var_label(Grads)]);
is_grad(g :: CategoricalValue) = (g == GradLabel);
is_grad(g :: AbstractString) = (g == GradLabel);

# Cannot do that for GroupedDataFrame.
function subset_grads!(df :: AbstractDataFrame)
    subset(df, var_label(Grads) => (x -> x .== GradLabel));
end

# test this +++++
function subset_grads(df :: AbstractDataFrame)
    subset(df, var_label(Grads) => (x -> x .== GradLabel));
end

# test this +++++
function find_grads(df :: AbstractDataFrame)
    return findall(x -> x == GradLabel, df[!, var_label(Grads)]);
end

function find_non_grads(df :: AbstractDataFrame)
    return findall(x -> x != GradLabel, df[!, var_label(Grads)]);
end


## ----------  Testing

@testitem "Classifications" begin
    using Underemployment, Test;

    function test_grouping(g :: Grouping)
        @test Underemployment.var_label(g) isa String;
        @test Underemployment.fig_label(g) isa String;
        @test Underemployment.var_labels(g) isa AbstractVector{String};
    end

    function test_grouping(g :: MultiGrouping)
        @test Underemployment.var_labels(g) isa AbstractVector{String};
    end

    for g in Underemployment.grouping_list()
        test_grouping(g);
    end

    test_grouping([Underemployment.YearGroups, Underemployment.AgeGroups]);
end


# ----------------