module Underemployment

using Chain, DataFrames, DataFramesMeta, DataSkimmer, Format, Random, StatsBase;
using CategoricalArrays, GLM, ReadStatTables, Serialization, XLSX;
using TestItemRunner, TestItems;
using CairoMakie, AlgebraOfGraphics, ColorSchemes;
using CommonLH, FilesLH;

# Types
export Grouping, MultiGrouping, AnyGrouping;
export YearGroups, AgeGroups, GradOccs, Occupations, Years;
export var_symbol, var_label;
# Run all
export run_all, data_settings, prepare_data, run_stats, stats_grouped;
# Load / save
export load_data, data_fn;
# Figures
export plot_defaults;
export test_dir, out_dir;
export make_rng;

include("constants.jl");
include("classifications.jl");
include("settings.jl");
include("helpers.jl");
include("helpers_test.jl");
include("testing.jl");

include("load_save.jl");
include("figures.jl");
include("figures_test.jl");
include("dataframes.jl");

include("prepare_data.jl");
include("derived_vars.jl");
include("derived_vars_test.jl");
include("earn_regression.jl");
include("earn_regressions_test.jl");
include("stats.jl");
include("stats_test.jl");
include("stats_occup.jl");

include("bls_data.jl");
include("bls_data_test.jl");
include("occup_crosswalk.jl");
include("occup_crosswalk_test.jl");


"""
Run everything in sequence.
Main DataFrame can be loaded with
    `load_data(data_fn(ds))`
"""
function run_all(cname = :default)
    ds = data_settings(cname);
    make_dirs(ds);
    plot_defaults();
    logPath = joinpath(out_dir(ds), "log.txt");
    open(logPath, "w") do io
        dfCps = prepare_data(ds; io);
        run_stats(dfCps, ds; io);
    end
end

end
