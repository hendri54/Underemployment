## -------------  File names

base_name(v :: VarInfo) = v.name;
base_name(g :: Grouping) = g.varLabel;
base_name(x) = string(x);
base_name(varNameV :: AbstractVector) = join(base_name.(varNameV), "-");

file_suffix(g :: Grouping) = "_" * g.suffix;
file_suffix(v :: MultiGrouping) = "_" * prod([g.suffix for g in v]);
file_suffix(s :: AbstractString) = "_" * s;
file_suffix(::Nothing) = "";

file_name(baseFn, groups, fType :: FileType) = 
    base_name(baseFn) * file_suffix(groups) * fType.extension;
file_name(varNameV :: AbstractVector, groups, fType :: FileType) =
    file_name(base_name(varNameV), groups, fType);


## -----------  Load / save

"""
Save any data. Not permanent.
"""
function save_data(fPath, df)
    serialize(fPath, df);
end

"""
Load what was saved with `save_data`.
"""
function load_data(fPath)
    return deserialize(fPath);
end

"""
Load the prepared data as a DataFrame.
"""
function load_data_df(ds)
    return load_data(data_fn(ds));
end

"""
Saves anything that can be written to a text file with `show`. 
Includes DataFrames.
"""
function save_output(fPath, df)
    open(fPath, "w") do io
        show(io, df);
    end 
end

function save_dataframe(baseFn, groups, df, ds)
    save_data(data_path(baseFn, groups, ds), df);
    save_output(out_path(baseFn, groups, TextFile, ds), df);
end

function save_text_file(fPath, txtV :: AbstractVector; io = nothing)
    open(fPath, "w") do ioWrite
        for txt in txtV
            println(ioWrite, txt);
        end
    end
    showPath = fpath_to_show(fPath);
    isnothing(io)  ||  println(io, "Saved  $showPath");
end

function fpath_to_show(fPath :: String; nDirs :: Integer = 3)
    fDir, fName = splitdir(fPath);
    s = right_dirs(fDir, nDirs) * " - " * fName;
    return s
end


## ------------  File names

function make_dirs(ds)
    for fDir in (mat_dir(ds), out_dir(ds), diagnostics_dir(ds), occup_dir(ds), test_dir(ds))
        isdir(fDir)  ||  mkpath(fDir);
    end
end

sub_dir(ds) = string(ds.name);
data_dir(ds) = joinpath(BaseDir, "cps");
mat_dir(ds) = joinpath(BaseDir, "mat", sub_dir(ds));
out_dir(ds) = joinpath(BaseDir, "out", sub_dir(ds));
test_dir(ds) = joinpath(BaseDir, "test");
diagnostics_dir(ds) = joinpath(out_dir(ds), "diagnostics");
occup_dir(ds) = joinpath(out_dir(ds), "occupations");

base_fn() = "cps_00018";
data_suffix() = ".mat";
# Complete CPS data file. With occ info mixed in.
data_fn(ds) = joinpath(mat_dir(ds), "data" * data_suffix());
# CPS occupation list
cps_occs_fn(ds) = joinpath(mat_dir(ds), "cps_occupations" * data_suffix());
# Education requirements for CPS occs
occ_ed_require_fn(ds) = joinpath(mat_dir(ds), "occ_ed_require" * data_suffix());

# For occupational wage DataFrame
occ_wage_path(ds) = joinpath(mat_dir(ds), "occup_wage_df" * data_suffix());

"""
File path for a human readable file.
"""
out_path(baseFn :: AbstractString, groups, fType :: FileType, ds) = 
    joinpath(out_dir(ds), file_name(baseFn, groups, fType));

fig_path(baseFn :: AbstractString, groups, ds) = joinpath(out_dir(ds), fig_fn(baseFn, groups));
fig_fn(baseFn :: AbstractString, groups) = file_name(baseFn, groups, FigureFile);



"""
File path for a data table. Possibly indexed by grouping.
"""
function data_path(baseFn :: AbstractString, groups, ds)
    fPath = joinpath(mat_dir(ds), data_fn(baseFn, groups));
    return fPath
end

function data_fn(baseFn :: AbstractString, groups)
    return baseFn * file_suffix(groups) * data_suffix();
end


# ----------------