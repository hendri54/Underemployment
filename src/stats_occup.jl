function show_occup_stats(df, ds)
    # DataFrame with occupations and their wages
    gdf = occ_stats_df(df, ds);
    show_occ_scatter_plots(gdf, ds);
    for topBottom in (:top, :bottom)
        show_top_bottom_occs(gdf, :topBottom, ds);
    end
    show_occ_wage_cdfs(df, ds; gradsOnly = true);
    show_occ_highWage_lowFracBA(gdf, ds);
end

function occ_stats_df(df, ds)
    dfOcc = load_data(occ_wage_path(ds));
    gdf = stats_grouped(df, Occupations, ds);
    leftjoin!(gdf, dfOcc; on = var_label(Occup));
    return gdf
end

function show_occ_highWage_lowFracBA(gdf, ds)
    df1 = @select(gdf, Not(:fracGradOccs, :fracUnder));
    df1.fracBaEmployment = df1.massBA ./ sum(df1.massBA);
    df1.fracEmployment = df1.mass ./ sum(df1.mass);
    df1 = @select(df1, Not(:massBA, :mass));

    maxFracBA = 0.1;
    df2 = @subset(df1, 
        $(var_symbol(FracBA)) .<= maxFracBA, 
        $(var_symbol(MeanLogOccupWage)) .>= 0.0);
    fPath = joinpath(occup_dir(ds), "occ_highWage_lowFracBA.txt");
    save_output(fPath, df2);
    return fPath
end

function show_occ_scatter_plots(gdf, ds)
    pairs = [
        MeanLogOccupWage => FracBA,
        MeanLogOccupWage => MeanLogWage,
        MeanLogOccupWage => MeanLogWageResidual,
        MeanLogWage => FracBA
    ];
    for pair in pairs
        save_scatter_plot(gdf, pair..., ds; fDir = occup_dir(ds));
    end
end


"""
Show characteristics of the top or bottom occupations arranged by `sortVar`.
"""
function show_top_bottom_occs(gdf, topBottom, ds;
        sortVar = MeanLogOccupWage)
    if topBottom == :top
        nTop = 30; nBottom = 0;
    elseif topBottom == :bottom
        nBottom = 30; nTop = 0;
    else
        nTop = 15; nBottom = 15;
    end
    drop_small_occupations!(gdf);
    dfOut = keep_top_bottom_rows(gdf, sortVar, nTop, nBottom);

    fig = Figure();
    for (iFig, barVar) in enumerate((sortVar, FracBA, MeanLogWageResidual))
        horizontal_bar_graph(dfOut, Occup, barVar; fig, iFig);
    end
    
    fPath = joinpath(occup_dir(ds), 
        "occup_char_$(var_label(sortVar))_$(topBottom)" * FigExtension);
    figsave(fPath, fig);
    return fPath
end


function drop_small_occupations!(gdf; cutoff = 0.05)
    smallMass = quantile(gdf.mass, cutoff);
    @subset!(gdf, :mass .> smallMass);
end



function keep_top_bottom_rows(df, sortVar, nTop, nBottom)
    dfOut = sort(df, var_label(sortVar); rev = true);
    if nTop > 0
        keepIdxV = 1 : nTop;
    else
        keepIdxV = Vector{Int}();
    end
    if nBottom > 0
        botIdxV = nrow(dfOut) .+ (-(nBottom - 1) : 0);
        keepIdxV = vcat(keepIdxV, botIdxV);
    end
    dfOut = dfOut[keepIdxV, :];
    return dfOut
end



# -----------------