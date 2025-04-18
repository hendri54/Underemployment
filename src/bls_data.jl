# BLS education codes in order of increasing ed requirements
# "ESTIMATE CODE" in original data.
const OrderedBlsEdCodes = 
    ["00075", "00076", "00077", "01029", "00079", "00080", "00081"];
const OrderedBlsEdLevels = 
    ["NoEd",  "HSG",   "AD",    "BA",    "MA",    "Prof",  "PhD"];
# Fraction of jobs that require BA or more is 
# 1 - cumul fraction ed level 3
const BlsBaIdx = 4;

bls_data_dir() = joinpath(BaseDir, "bls occupations");
bls_log_file() = joinpath(bls_data_dir(), "bls_log.txt");


"""
Create a DataFrame with educational requirements by occupation.
Occupations are 2018 SOC codes.
"""
function process_bls_data(; io = stdout)
    dfBls = read_bls_data(; io);
    recode_bls_data!(dfBls; io);
    # perhaps save? 
    gdf = compute_occ_stats(dfBls; io);
    return gdf
end


"""
Read the BLS data file with educational requirements for SOC 2018 occupations.
Drop unused columns. 
Rename used columns as valid variable names.
All variables are strings. They need to be recoded.
No test.
"""
function read_bls_data(; io = stdout)
    info_msg(io, "Reading BLS data");
    xlsxFn = joinpath(bls_data_dir(), "2023-complete-dataset.xlsx");
    @assert isfile(xlsxFn);
    # Sheet 3 contains the actual data.
    df = DataFrame(XLSX.readtable(xlsxFn, 3));
    nrows = format(nrow(df); commas = true);
    info_msg(io, "  Xlsx file has $nrows rows");

    # Drop unused
    @select!(df, Not(["SERIES TITLE", "CATEGORY",
        "ADDITIVE CODE", "ADDITIVE", "DATATYPE CODE",
        "DATATYPE", "SERIES ID", "REQUIREMENT",
        "STANDARD ERROR",
        "DATA FOOTNOTE", "STANDARD ERROR FOOTNOTE", "SERIES FOOTNOTE"]));

    # Make usable names and convert to string (type stability)
    pairs = [
        # "SERIES ID" => :SeriesId, 
        "SOC 2018 CODE" => BlsOccVar, 
        "CATEGORY CODE" => :CategoryCode,
        "ESTIMATE CODE" => :EstimateCode,
        "ESTIMATE TEXT" => :EstimateText,
        "ESTIMATE" => :Estimate,
        "OCCUPATION" => :Occupation];
    for (oldName, newName) in pairs
        df[!, newName] = string.(df[!, oldName]);
    end
    @select!(df, Not(first.(pairs)));

    return df
end


function recode_bls_data!(df; io = stdout)
    # Only keep education requirements
    @subset!(df, :CategoryCode .== "073", do_keep_ed_level.(:EstimateCode));
    # Converts Strings to Floats. Deals with bounds (but not final answer).
    df.edFraction = recode_ed_fraction.(df.Estimate);
    # Convert ed level string codes into ordered 1 : n Integers.
    df.edLevels = recode_ed_levels(df.EstimateCode);
    # Bool indicator: BA or more
    idxBA = findfirst(x -> x == "BA", OrderedBlsEdLevels)
    df.BAorMore = (df.edLevels .>= idxBA);
    df.Soc2018Code = parse_to_ints(df.Soc2018Code);

    nrows = format(nrow(df); commas = true);
    info_msg(io, "DataFrame with education info has $nrows rows");
    return df
end


function recode_ed_levels(v :: AbstractVector{String})
    recodeDict = Dict(OrderedBlsEdCodes .=> (1 : length(OrderedBlsEdCodes)));
    return [recodeDict[x] for x in v]
end


"""
`s` contains the fraction of persons with a specific ed requirement (as string).
Numbers, such as "15.5" are simply parsed into numbers. But there are also upper bounds, such as "<0.5", and lower bounds, such as ">90.0". These are recoded if close to 0 or 100; otherwise treated as missing.
Result is between 0 and 1.
"""
function recode_ed_fraction(s)
    if startswith(s, "<")
        return recode_ed_ub(s)
    elseif startswith(s, ">")
        return recode_ed_lb(s)
    else
        frac = parse(Float64, s) / 100;
        if 0 <= frac <= 1
            return frac
        else
            return missing
        end
    end
end

"""
Recode entry that starts with "<".
Many are unspecific, such as "<25" or "<50". Cannot use those.
"""
function recode_ed_ub(s)
    frac = parse(Float64, s[2:end]);
    if 0 <= frac < 6
        # Midpoint to zero. Scaled between 0 and 1.
        return frac / 200;
    else
        return missing;
    end
end

function recode_ed_lb(s)
    frac = parse(Float64, s[2:end]);
    if 98 < frac < 100
        return (100 + frac) / 200;
    else
        return missing
    end
end

"""
Drop education levels that are contained in others, such as
`No min education and no literacy required`
"""
function do_keep_ed_level(s)
    return !(s in ("00085", "00086", "00803", "00804"))
end

# function recode_ba_or_more(s)
#     return s in ("00079", "00080", "00081", "01029")
# end


"""
Compute stats by occupation. 
There are missing values. Not all occs have data for all ed levels. Then input DataFrame lacks rows.
Each row is an occupation.
"""
function compute_occ_stats(dfBls; io = stdout)
    info_msg(io, "Computing BLS occupation statistics");
    gdf = groupby(dfBls, BlsOccVar);
    # Not clear how collect the columns for ed fractions with DataFramesMeta
    dfOut = combine(gdf,
        :Occupation => first => :Occupation,
        # [:BAorMore, :edFraction] => ((x,y) -> sum(x .* y)) => :fracBA,
        :edFraction => sum => :fracSum,
        [:edLevels, :Estimate] => ed_fractions_one_occ => AsTable
    );
    info_msg(io, "  Grouped DataFrame with", format_int(nrow(dfOut)), "rows");

    # Drop rows with missing ed fractions
    nEd = length(OrderedBlsEdCodes);
    vName = cum_ed_frac_name(nEd);
    @subset!(dfOut, $vName .> 0.9);
    info_msg(io, "  No of rows after dropping missing values", format_int(nrow(dfOut)));

    return dfOut
end

# function round_down_large_fracsums!(dfOut; io = stdout)
#     maxSum = maximum(skipmissing(dfOut.fracSum));
#     info_msg(io, "  Max of sum of education fractions", round(maxSum; digits = 1));
#     if maxSum > 105
#         error("Investigate large values of fracSum");
#     end
    
# end


"""
For one occupation, compute the fraction of workers with ed requirements
up to each level. That last one is always 100.
Handle incomplete data.

Tested with `ed_fractions_one`.
"""
function ed_fractions_one_occ(edLevels :: AbstractVector{<:Integer}, 
        edFractions :: AbstractVector{<:AbstractString})
    n = length(edLevels);
    nTg = length(OrderedBlsEdCodes);
    fracV = ed_fractions_one(edLevels, edFractions);
    if any(ismissing.(fracV))
        cumFracV = fill(missing, nTg);
    else
        cumFracV = cumsum(fracV);
    end
    nameV = cum_ed_frac_name.(1 : nTg);
    return NamedTuple{Tuple(nameV)}(cumFracV)
end

cum_ed_frac_name(j) = Symbol("cumEdFrac$j");


"""
Compute fraction with each education requirement for one occupation.
"""
function ed_fractions_one(edLevels :: AbstractVector{<:Integer}, 
        edFractions :: AbstractVector{<:AbstractString})

    fracV = sort_and_complete_ed_levels(edLevels, edFractions);
    validV = valid_ed_fraction.(fracV);
    if all(validV)
        return ed_fractions_all_valid(fracV);
    else
        return ed_fractions_some_invalid(fracV, validV);
    end

    # fracV = recode_ed_fraction.(edFractions);
    # fracSum = sum(fracV .* validV);
end


function sort_and_complete_ed_levels(edLevels, edFractions)
    n = length(edLevels);
    nTg = length(OrderedBlsEdCodes);
    if n <= nTg
        fracV = fill("0", nTg);
        fracV[edLevels] .= edFractions;
    else
        error("Invalid");
    end
    @assert length(fracV) == nTg;
    return fracV
end


"""
All entries are valid, but there can still be bounded entries of the form "<0.5" or ">99.5".
Those are close enough to 0 or 1 that they can be parsed.
"""
function ed_fractions_all_valid(fracStrV :: AbstractVector{<:AbstractString})
    # fracV = parse.(Float64, fracStrV) ./ 100;
    fracV = recode_ed_fraction.(fracStrV);
    @assert !any(ismissing.(fracV))  "Cannot parse $(fracStrV)";
    fracSum = sum(fracV);
    if (fracSum > 1.05)  ||  (fracSum < 0.95)
        return fill(missing, size(fracV));
    else
        return fracV ./ fracSum;
    end
end

"""
In practice, invalid entries are always "<X". ">X" only occurs for ">99.5" which is treated as valid.
"""
function ed_fractions_some_invalid(fracStrV :: AbstractVector{<:AbstractString}, validV)
    fracV = recode_ed_fraction.(fracStrV);
    if any(ismissing.(fracV))
        # Only "interior" values are missing (such as "<30"). Those cannot be handled.
        return fill(missing, size(fracV));
    else
        fracValid = sum(fracV .* validV);
        fracInvalid = sum(fracV) - fracValid;
        if 0.95 <= fracValid <= 1.05
            fracV[.!validV] .= 0.0;
            fracV ./= sum(fracV);
            return fracV
        else
            return fill(missing, size(fracV));
        end
    end
end


"""
Mark which strings containing ed fractions are valid.
Treat as valid: 
- all numbers
- "<5" or less
- ">95" or more
"""
function valid_ed_fraction(s :: AbstractString)
    if first(s) in ('<', '>')
        frac = parse(Float64, s[2:end]);
        return (first(s) == '<'  &&  frac < 6)  ||
            (first(s) == '>'  &&  frac > 94)
    else
        return true;
    end
end



# -----------------