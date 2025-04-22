make_rng(seed) = Xoshiro(seed);

function info_msg(io, args...)
    msg = join(args, "  ");
    @info msg;
    if !isequal(io, stdout)
        println(io, msg);
    end
end

function format_int(x :: Integer)
    return format(x; commas = true);
end

"""
Delete DataFrame rows where one variable is missing.
Report fraction of total mass deleted.
"""
function delete_missing_rows!(dfCps :: AbstractDataFrame, varNameIn; 
        massVar = WeightVar, io = stdout, silent = false)
    varName = var_symbol(varNameIn);
    @assert string(varName) in names(dfCps);
    nrows = nrow(dfCps);
    if !silent
        totalMass = sum(skipmissing(dfCps[!, massVar]));
    end
    filter!(row -> !ismissing(getproperty(row, varName)), dfCps);
    nDrop = nrows - nrow(dfCps);
    if (nDrop > 0)  &&  !silent
        droppedMass = totalMass - sum(skipmissing(dfCps[!, massVar]));
        droppedFrac = droppedMass / totalMass;
        info_msg(io, "  Dropped $nDrop rows with missing $(varName) info (fraction ",
            format(droppedFrac; precision = 2), " of total mass).");
    end
    return nDrop
end


"""
Drop an element by value from a Vector
"""
function drop_one(v :: AbstractVector{T}, vDrop :: T) where T
    idx = findfirst(x -> x == vDrop, v);
    if !isnothing(idx)
        return v[Not(idx)], idx;
    else
        return copy(v), nothing;
    end
end


"""
Produce a DataFrame with all combinations of the elements in two vectors.
"""
function all_combinations(x, y)
    n = length(x) * length(y);
    df = DataFrame(x = repeat(x; inner = length(y)),
        y = repeat(y; outer = length(x)));
    return df
end



"""
Parse to a Vector{Int,Missing}. `v` can contain String, Float, Int, or Missing.
"""
function parse_to_ints(v :: AbstractVector)
    n = length(v);
    v2 = Vector{Union{Int,Missing}}(undef, n);
    for (i, x) in enumerate(v)
        v2[i] = parse_to_int(x);
    end
    return v2
end

parse_to_int(::Missing) = missing;
parse_to_int(x :: Integer) = x;
parse_to_int(x :: AbstractFloat) = float_to_int(x);
parse_to_int(x :: AbstractString) = float_to_int(parse(Float64, x));

function float_to_int(x :: AbstractFloat)
    y = round(Int, x);
    @assert isapprox(x, y)  "Inexact Int conversion for $x";
    return y;
end


create_vector(T, n) = Vector{Union{T,Missing}}(missing, n);


function get_var(dfRow :: DataFrameRow, vName)
    getproperty(dfRow, var_symbol(vName));
end
# function get_var(dfRow :: DataFrameRow, vName)
#     getproperty(dfRow, vName);
# end
function set_var!(dfRow :: DataFrameRow, vName, vValue)
    setproperty!(dfRow, var_symbol(vName), vValue);
end

# -----------------