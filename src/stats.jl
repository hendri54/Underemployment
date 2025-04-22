"""
Compute all stats.
"""
function run_stats(dfCps, ds; io = stdout)
    gradOccVar = GradOccs;
    show_stats_by_year(dfCps, ds; gradOccVar);
    show_stats_grouped(dfCps, Years, FracUnder, Gender, ds);
    show_frac_under_age_year(dfCps, ds; gradOccVar);
    show_grads_in_gradoccs(dfCps, ds; gradOccVar);
    for genderLbl in fixed_codes(Gender)
        show_earnings_stats(dfCps, ds; gradOccVar, genderLbl);
    end
    for groups in (YearGroups, [AgeGroups, YearGroups])
        save_grouped_stats(dfCps, groups, ds; gradOccVar);
    end

    # Scatter plots with 3m obs don't work
    # show_scatter_plots(dfCps, ds);

    for gradLbl in (nothing, NonGradLabel, GradLabel)
        show_frac_by_fracRequireBA(dfCps, ds; yearVar = YearGroups, gradLbl)        
        show_frac_by_occFracBa(dfCps, ds; gradLbl);
        for refYear in (first(year_group_labels(ds)), last(year_group_labels(ds)));
            show_frac_by_occFracBa(dfCps, ds; gradLbl, yearVar = YearGroups, refYear);
        end
    end

    show_earn_quantiles(dfCps, ds);
    show_occup_stats(dfCps, ds);
end

run_stats(ds = data_settings(:default)) = run_stats(load_data(data_fn(ds)), ds);

function save_grouped_stats(df, groups, ds; gradOccVar)
    dfU = stats_grouped(df, groups, ds; gradOccVar);
    save_dataframe("stats", merge_groups(groups, gradOccVar), dfU, ds);
end


"""
Grouped stats.

# Example

`stats_grouped(df, [AgeGroups, YearGroups], ds)`

Test: check_stats_one_group, called from "stats_test.jl".
"""
function stats_grouped(df, groups :: MultiGrouping, ds; gradOccVar = GradOccs)
    grpVars = var_labels(groups);
    statsDf = mass_by_groups(df, groups);
    statsDf.fracBA = clamp.(statsDf.massBA ./ statsDf.mass, 0.0, 1.0);

    if !isnothing(gradOccVar)  &&  !(gradOccVar in groups)  &&  
            (var_label(gradOccVar) in names(df))
        dfGrad = frac_grad_occs(df, groups; gradOccVar);
        leftjoin!(statsDf, dfGrad; on = grpVars);
    end

    gdf = groupby(df, grpVars);

    # If a variable does not exist, easiest to create a "fake" variable
    # and delete it later. There is no good way of doing conditional 
    # calculations in `combine`
    varsToDrop = Vector{String}();
    if "logOccupWage" in names(df)
        vLogOccupWage = :logOccupWage;
    else
        vLogOccupWage = :wage;
        push!(varsToDrop, "meanLogOccupWage")
    end

    wageDf = @combine gdf begin
        :count = length($WeightVar);
        :tmpMass = sum($WeightVar);
        :meanWage = sum($WeightVar .* :wage) / sum($WeightVar);
        :meanLogWage = sum($WeightVar .* :logWage) / sum($WeightVar);
        :fracMale = sum($WeightVar .* :isMale) / sum($WeightVar);
        :meanLogWageResidual = 
            sum($WeightVar .* :logWageResidual) / sum($WeightVar);
        :meanLogOccupWage = 
            sum($WeightVar .* $vLogOccupWage) / sum($WeightVar);
    end

    # Delete vars not computed
    if !isempty(varsToDrop)
        select!(wageDf, Not(varsToDrop));
    end

    leftjoin!(statsDf, wageDf; on = grpVars);
    return statsDf
end

stats_grouped(df, groups :: Grouping, ds; gradOccVar = GradOccs) = 
    stats_grouped(df, [groups], ds; gradOccVar);


"""
Check that stats for on combination of groups are calculated correctly.
"""
function check_stats_one_group(df, statsDf, groups, groupValV, ds;
        gradOccVar = GradOccs)
    df2 = filter(row -> groups_match(row, groups, groupValV), df);
    statsDf2 = filter(row -> groups_match(row, groups, groupValV), statsDf);
    @assert nrow(statsDf2) == 1  "Expecting unique match. Found $(nrow(statsDf2))";
    statsRow = first(eachrow(statsDf2));

    isValid = true;
    # if statsRow.count != nrow(df2)
    #     @warn "Invalid count";
    #     isValid = false;
    # end
    if !isapprox(statsRow.mass, sum(df2[!, WeightVar]); rtol = 1e-3)
        @warn "Invalid mass";
        isValid = false;
    end
    fracBA = sum(df2[!, WeightVar] .* df2.BAorMore) ./ sum(df2[!, WeightVar]);
    if !isapprox(statsRow.fracBA, fracBA; rtol = 1e-3)
        @warn "Invalid fracBA";
        isValid = false;
    end

    if !(gradOccVar in groups)
        # # To check fracUnder, keep those in grad occs and those not.
        # vGradOccs = var_label(GradOccs);
        # groups3, idx3 = drop_one(groups, GradOccs);
        # groupVal3V = groupValV[Not(idx3)];
        # # We now have 2 rows: for grad occs and for non-grad occs.
        # statsDf3 = filter(row -> groups_match(row, groups3, groupVal3V), statsDf);
        # @assert nrow(statsDf3) == 2;

        # # Across the two rows, the fractions sum to 1
        # # Frac of BAs on grad occs
        # if !isapprox(sum(statsDf3[!, "fracGradOcc"]), 1.0)  
        #     @warn "Frac grad occ should sum to 1";
        #     isValid = false;
        # end
        # # Fraction underemployed. Only meaningful when not in grad occs.
        # if !isapprox(sum(statsDf3[!, "fracUnder"]), 1.0)  
        #     @warn "Frac under occ should sum to 1";
        #     isValid = false;
        # end
        vGradOccs = var_label(gradOccVar);
        groups3 = vcat(groups, gradOccVar);
        statsDf3 = stats_grouped(df, groups3, ds; gradOccVar);
        # Now we have two rows (for this one group): for grad occs and for non-grad occs.
        statsDf4 = filter(row -> groups_match(row, groups, groupValV), statsDf3);
        @assert nrow(statsDf4) == 2;

        # Check fraction underemployed = fraction BAs in grad occs
        rGrad = findfirst(x -> x == GradOccLabel, statsDf4[!, vGradOccs]);
        @assert rGrad in (1, 2);
        rNonGrad = (rGrad == 1) ? 2 : 1;
        fracUnder = statsDf4.massBA[rNonGrad] / sum(statsDf4.massBA);
        @assert 0 <= fracUnder <= 1;
        if !isapprox(fracUnder, statsRow.fracUnder; rtol = 1e-3)
            @warn "Invalid fracUnder";
            isValid = false;
        end

        # Check fraction in grad occs
        fracGradOccs = statsDf4.mass[rGrad] / sum(statsDf4.mass);
        if !isapprox(fracGradOccs, statsRow.fracGradOccs; rtol = 1e-3)
            @warn "Invalid fracGradOccs:  $(fracGradOccs)  vs  $(statsRow.fracGradOccs)";
            isValid = false;
        end
    end
    return isValid
end




"""
Check that a row matches given values for all groups

Test: Implicit in testing `stats_grouped`.
"""
function groups_match(row, groups, groupValV)
    isValid = true;
    for (g, gv) in zip(var_labels(groups), groupValV)
        if getproperty(row, g) != gv
            isValid = false;
            break;
        end
    end
    return isValid
end

"""
Creates one row per quantile value. Adds a `pct` column to indicate the quantile.
"""
function var_quantiles(gdf, varName, pctV; weights = WeightVar, basePct = nothing)
    # The trick is that a combine operation can create vectors.
    # Then you get multiple rows in the DataFrame.
    varSym = var_symbol(varName);
    wtSym = var_symbol(weights);
    dfOut = @combine gdf begin
        $varSym = quantile_with_base($varSym, ProbabilityWeights($wtSym), pctV, basePct);
        :quantile = pctV;  
    end
    sort!(dfOut, :quantile);
    return dfOut
end

function quantile_with_base(x, wt, pctV, basePct :: Number)
    baseIdx = findfirst(x -> x == basePct, pctV);
    @assert !isnothing(baseIdx)  "Base percentile $(basePct) not in $(pctV)";
    qV = quantile(x, wt, pctV);
    qV .-= qV[baseIdx];
    return qV
end

quantile_with_base(x, wt, pctV, basePct :: Nothing) =   
    quantile(x, wt, pctV);



# """
# Add variable "fraction in graduate occupations" and
# "fraction underemployed" (really: fraction of BAs in (non)graduate occupations).
# Only if `GradOccs` is in `groups`.
# """
# function add_frac_grad_occ!(statsDf, groups, ds)
#     (GradOccs in groups) || return;

#     groups2 = filter(x -> x != GradOccs, groups);
#     df2 = mass_by_groups(statsDf, groups2; massVar = "totalMass", massBaVar = "totalMassBA");
#     leftjoin!(statsDf, df2, on = var_labels(groups2));
#     statsDf.fracGradOcc = statsDf.mass ./ statsDf[!, "totalMass"];
#     statsDf.fracUnder = statsDf.massBA ./ statsDf[!, "totalMassBA"];
#     return nothing
# end

"""
Fraction in grad occs and fraction underemployed.
Only if gradOccVar not in DataFrame df
"""
function frac_grad_occs(df, groups; gradOccVar = GradOccs)
    (gradOccVar in groups) && return;

    # Mass by groups and GradOccs
    dfGrad = mass_by_groups(df, vcat(groups, gradOccVar); 
        massVar = "massG", massBaVar = "massBaG");
    # Mass by groups only
    dfAll = mass_by_groups(df, groups; 
        massVar = "massA", massBaVar = "massBaA");

    leftjoin!(dfGrad, dfAll; on = var_labels(groups));

    # FracUnder = mass BA in grad occ / mass BA
    dfGrad.fracUnder = dfGrad.massBaG ./ dfGrad.massBaA;
    # Only keep rows not in grad occs
    dfU = subset_not_grad_occs(dfGrad, gradOccVar);
    select!(dfU, "fracUnder", var_labels(groups)...);

    # Fraction of all workers in grad occs
    dfGrad.fracGradOccs = dfGrad.massG ./ dfGrad.massA;
    # Only keep rows in grad occs
    dfG = subset_grad_occs(dfGrad, gradOccVar);
    select!(dfG, "fracGradOccs", var_labels(groups)...);

    # Now we have a DataFrame with both indicators by groups
    leftjoin!(dfG, dfU; on = var_labels(groups));
    return dfG
end


"""
Compute total mass and massBA by groups.
"""
function mass_by_groups(df, grpVars; 
        wtVar = WeightVar, massVar = "mass", massBaVar = "massBA")
    gdf2 = groupby(df, var_labels(grpVars));
    # Variable names must be Symbols
    dfOut = @combine gdf2 begin
        # :count = length($WeightVar);
        $massVar = sum($wtVar);
        $massBaVar = sum($wtVar .* :BAorMore);
    end
    return dfOut
end




# """
# Returns a DataFrame with predicted fraction BA or more from a regression of 
# "has BA or more" on occupation and year group dummies.
# For one reference year group.
# """
# function frac_ba_regression(df, refYearGroup, ds)
#     mdl = lm(@formula(BAorMore ~ occup + yearGroup), df);
#     @show mdl

#     nOcc = length(levels(df.occup));
#     xData = DataFrame(
#         occup = levels(df.occup), 
#         yearGroup = fill(refYearGroup, nOcc)
#         );
#     xData.fracBA = predict(mdl, xData);
#     return xData
# end


function show_stats_by_year(df, ds; gradOccVar = GradOccs)
    axisOpts = default_axis_opts();
    legendOpts = default_legend_opts();
    set_fig_opt!(axisOpts, :limits, (nothing, nothing, 0, nothing));

    groups = Years;
    vX = var_label(groups);
    dfY = stats_grouped(df, groups, ds; gradOccVar);

    fig = Figure();
    plt1 = lines_layer(dfY, vX, fig_label(Years), :meanWage, 
        "Mean wage", 1);
    AlgebraOfGraphics.draw!(fig[1,1], plt1; axis = axisOpts);
    plt2 = lines_layer(dfY, vX, fig_label(Years), :fracMale,
        "Fraction male", 1);
    AlgebraOfGraphics.draw!(fig[1,2], plt2; axis = axisOpts);
    fPath = joinpath(diagnostics_dir(ds), file_name("stats_other", Years, FigureFile));
    figsave(fPath, fig);

    fig = multi_line_graph(dfY, vX, fig_label(Years), 
        [:fracBA, :fracGradOccs, :fracUnder], 
        ["Fraction BA or more", "Fraction graduate occ.", "Fraction underemployed"]; 
        axisOpts, legendOpts)

    fPath = fig_path("stats", Years, ds);
    figsave(fPath, fig);
    return fPath
end


function show_stats_grouped(dfCps, xVar, yVar, colorVar, ds;
        outDir = diagnostics_dir(ds))
    grpVars = [xVar, colorVar];
    statsDf = stats_grouped(dfCps, grpVars, ds);
    fig = line_graph_grouped(statsDf, xVar, yVar, colorVar);
    fPath = joinpath(outDir, file_name(yVar, grpVars, FigureFile));
    figsave(fPath, fig);
end


"""
Over time, show fraction of persons working in occupations with more than a given BA+ percenage.
"""
function show_frac_by_occFracBa(dfCps, ds; 
        yearVar = Years, refYear = nothing, gradLbl = nothing)
    @assert var_label(yearVar) in names(dfCps);
    df2 = frac_by_occFracBa(dfCps, ds; yearVar, refYear, ubV = 0.1 : 0.1 : 1.0);
    fig, yLabel = plot_fracBA_by_groups(df2, yearVar; gradLbl, refYear);

    if isnothing(refYear)
        refYrSuffix = "";
    else
        refYrSuffix = "_" * string(refYear);
    end
    baseFn = "fracByOccFracBa" * refYrSuffix * file_suffix(gradLbl);
    fPath = fig_path(baseFn, yearVar, ds); 
    figsave(fPath, fig; figData = df2, figNotes = [
        "$(yLabel) working in occupations with different fractions of BA or more workers.",
        "Fraction BA or more is computed year by year."
    ]);
    return fPath
end

function plot_fracBA_by_groups(df2, yearVar; gradLbl = nothing, refYear = nothing)
    @assert var_label(yearVar) in names(df2);
    if is_grad(gradLbl)
        yVar = "cumFracBAs";
        yLabel = "Fraction of graduates";
    elseif is_non_grad(gradLbl)
        yVar = "cumFracNoBAs";
        yLabel = "Fraction of non-grads";
    elseif isnothing(gradLbl)
        yVar = "cumFrac";
        yLabel = "Fraction of all workers";
    else
        error("Not implemented for $gradLbl");
    end

    plt = data(df2) *
        mapping(
            var_label(yearVar) => fig_label(yearVar), 
            yVar => yLabel;
            color = "fracBAgroup" => "Frac BA") *
        visual(Lines);
    
    axisOpts = default_axis_opts();
    set_fig_opt!(axisOpts, :limits, (nothing, nothing, 0.0, 1.0));
    fig = render(plt; axis = axisOpts);
    return fig, yLabel
end

"""
DataFrame with occupations grouped by fraction BA in each year. Or in reference year, if `refYear` is provided.
Also contains fraction of all workers in each occupation (by year).
Drops occupations with missing data.

test for grouping by reference year frac BA +++++
"""
function frac_by_occFracBa(dfCps, ds; 
        ubV = [0.25, 0.5, 0.75, 1.0],
        yearVar = Years, refYear = nothing)
    BAgroupVar = "fracBAgroup";
    df2 = group_occs_by_frac_ba(dfCps, yearVar, ubV, ds; refYear);

    delete_missing_rows!(df2, BAgroupVar; silent = true);
    dfOut = frac_by_group_yr(df2, BAgroupVar, yearVar);
    return dfOut
end


"""
The same, but occupations are grouped by fraction requiring BA.
"""
function show_frac_by_fracRequireBA(dfCps, ds; 
        yearVar = Years, gradLbl = nothing)
    df2 = frac_by_fracRequireBA(dfCps, ds; 
        yearVar, ubV = [0.05, 0.1, 0.15, 0.25, 0.5, 0.75, 0.85, 1.0]);
    fig, yLabel = plot_fracBA_by_groups(df2, yearVar; gradLbl, refYear = nothing);

    baseFn = "fracByFracRequireBa" * file_suffix(gradLbl);
    fPath = fig_path(baseFn, yearVar, ds); 
    figsave(fPath, fig; figData = df2, figNotes = [
        "$(yLabel) working in occupations with different fractions requiring BA."
    ]);
    return fPath
end

"""
test this +++++
"""
function frac_by_fracRequireBA(dfCps, ds; ubV = 0.25 : 0.25 : 1.0, yearVar = Years)
    BAgroupVar = "fracBAgroup";

    dfCps[!, BAgroupVar] = categorical_from_ub(dfCps[!, var_label(FracRequireBA)], ubV);
    df2 = mass_by_groups(dfCps, [BAgroupVar, yearVar]);

    delete_missing_rows!(df2, BAgroupVar; silent = true);
    dfOut = frac_by_group_yr(df2, BAgroupVar, yearVar);
    return dfOut
end




"""
Compute fraction of all, of BAs, and of Non-BAs in each (occupation) group and year.

Input DataFrame has fields: mass, massBA (and grouping variables).

test this +++++
"""
function frac_by_group_yr(df2, BAgroupVar, yearVar)
    yrLbl = var_label(yearVar);
    gdf = groupby(df2, [BAgroupVar, yrLbl]);
    dfOut = @combine gdf begin
        :mass = sum(:mass);
        :massBA = sum(:massBA);
    end
    dfOut.massNoBA = dfOut.mass .- dfOut.massBA;

    # Add mass by year
    gdf = groupby(df2, yrLbl);
    dfMass = @combine gdf begin
        :yearMass = sum(:mass);
        :yearMassBA = sum(:massBA);
    end
    dfMass.yearMassNoBA = dfMass.yearMass .- dfMass.yearMassBA;
    leftjoin!(dfOut, dfMass; on = yrLbl);

    # add_mass_by_year!(dfOut, df2, ds; yearVar,  massVar = "yearMass");

    # Fraction all workers in occ
    dfOut.frac = dfOut.mass ./ dfOut.yearMass;
    # Fraction of BAs in occ
    dfOut.fracBAs = dfOut.massBA ./ dfOut.yearMassBA;
    dfOut.fracNoBAs = dfOut.massNoBA ./ dfOut.yearMassNoBA;
    sort!(dfOut, var_label(yearVar));

    # Make cumulative fractions
    gdf = groupby(dfOut, var_label(yearVar));
    df2 = @combine gdf begin
        :cumFrac = cumsum(:frac);
        :cumFracBAs = cumsum(:fracBAs);
        :cumFracNoBAs = cumsum(:fracNoBAs);
        $BAgroupVar = $BAgroupVar;  
    end
    dfOut = innerjoin(dfOut, df2; on = [var_label(yearVar), BAgroupVar]);

    return dfOut
end

"""
Group occupations by fraction BA in each year or year group. Optionally for a single ref year.
Returns a DataFrame with occupations and groups coded as Categorical.
There will be missing values.

Tested by function that generates indicator for graduate occupations.
"""
function group_occs_by_frac_ba(df, yearVar, ubV, ds; 
        refYear = nothing,
        labelV = string.(round.(ubV, digits = 2)))
    df2 = stats_grouped(df, [Occupations, yearVar], ds);
    grpIdxV = recode_from_ub(df2.fracBA, ubV);

    dFrac = Dict(1 : length(ubV) .=> labelV);
    df2.fracBAgroup = categorical(recode_var(grpIdxV, dFrac; tgType = String));

    if !isnothing(refYear)
        yrLbl = var_label(yearVar);
        BAgroupVar = "fracBAgroup";
            # This variable will have missing values
        df3 = @subset(df2, $yrLbl .== refYear);
        @assert !isempty(df3);
        select!(df3, var_label(Occupations), BAgroupVar);
        # Avoid name conflict
        rename!(df2, BAgroupVar => "fracBAgroupByYear");
        leftjoin!(df2, df3; on = var_label(Occupations));
    end

    return df2
end

function add_mass_by_year!(dfOut, df, ds; 
        yearVar = Years, massVar = "yearMass", massBaVar = massVar * "BA")
    dfY = stats_grouped(df, [yearVar], ds);
    select!(dfY, var_label(yearVar), "mass", "massBA");
    rename!(dfY, "mass" => massVar, "massBA" => massBaVar);
    leftjoin!(dfOut, dfY, on = var_label(yearVar));
end


function show_grads_in_gradoccs(df, ds; gradOccVar = GradOccs)
    statsDf = grads_in_gradoccs(df, ds; gradOccVar);

    plt = data(statsDf) *
        mapping(
            var_label(Years) => fig_label(Years), 
            "fracGradOccs" => "Fraction in graduate occ.";
            color = var_label(Grads) => fig_label(Grads)) *
        visual(Scatter);
    fig = render(plt);
    
    fPath = fig_path("grads_in_gradoccs", [gradOccVar, Years], ds);
    figsave(fPath, fig);
    return fPath
end

"""
test this +++++
"""
function grads_in_gradoccs(df, ds; gradOccVar = GradOccs)
    groups = [gradOccVar, Years, Grads];
    statsDf = stats_grouped(df, groups, ds);
    # Now we have stats by [gradOccVar, Years] for graduates only
    # filter!(row -> is_grad(row), statsDf);

    # Total mass across occs
    groups2, _ = drop_one(groups, gradOccVar);
    grpVars2 = var_labels(groups2);
    dfY = groupby(statsDf, grpVars2);
    dfY = @combine dfY begin
        :massYG = sum(:mass);
    end
    select!(dfY,  "massYG", grpVars2...);

    leftjoin!(statsDf, dfY, on = grpVars2);
    statsDf.fracGradOccs = statsDf.mass ./ statsDf.massYG;
    statsDf = subset_grad_occs(statsDf, gradOccVar);

    return statsDf
end


function show_frac_under_age_year(dfCps, ds; yearVar = YearGroups, gradOccVar = GradOccs)
    ageVar = AgeGroups;
    grpVars = [ageVar, yearVar];
    statsDf = stats_grouped(dfCps, grpVars, ds; gradOccVar);
    sort!(statsDf, var_label(ageVar));

    # Plot with age or with year on x axis
    for plotGrps in (grpVars, reverse(grpVars))
        xVar, colorVar = plotGrps;
        yVar = FracUnder;
        fig = line_graph_grouped(statsDf, xVar, yVar, colorVar);
        
        fPath = fig_path(base_name(yVar), plotGrps, ds);
        figsave(fPath, fig);
    end
end


# function show_scatter_plots(df, ds)
#     pairs = (LogOccupWage => LogWageResidual, 
#         LogOccupWage => LogWage);
#     for pair in pairs
#         scatter_plot(df, pair...);
#     end
# end


# """
# Loop over grouped Df and apply a function

#     Try to rewrite `stats_grouped` this way.
#     Speed difference is small, except for lots of groups (e.g. 200). Then factor 2.
# """
# function stats_grouped2(df, groups, ds)

#     grpVars = var_labels(groups);
#     statsDf = mass_by_groups(df, groups);
#     statsDf.fracBA = clamp.(statsDf.massBA ./ statsDf.mass, 0.0, 1.0);
#     if !(GradOccs in groups)  &&  (var_label(GradOccs) in names(df))
#         dfGrad = frac_grad_occs(df, groups);
#         leftjoin!(statsDf, dfGrad; on = grpVars);
#     end

#     gdf = groupby(df, grpVars);

#     v = Vector{Any}();
#     for subdf in gdf
#         push!(v, group_stats(subdf));
#     end
#     return v
# end

# function group_stats(gdf)
#     # If a variable does not exist, easiest to create a "fake" variable
#     # and delete it later. There is no good way of doing conditional 
#     # calculations in `combine`
#     if "logOccupWage" in names(gdf)
#         vLogOccupWage = :logOccupWage;
#     else
#         vLogOccupWage = :wage;
#     end

#     wtV = gdf[!, WeightVar];
#     count = nrow(gdf);
#     mass = sum(wtV);
#     fracMale = sum(wtV .* gdf[!, :isMale]) / mass;
#     meanWage = sum(wtV .* gdf[!, :wage]) / mass;
#     meanLogWage = sum(wtV .* gdf[!, :logWage]) / mass;
#     meanLogWageResidual = sum(wtV .* gdf[!, :logWageResidual]) / mass;

#     return (count = count, mass = mass, fracMale = fracMale, meanWage = meanWage, meanLogWage = meanLogWage, meanLogWageResidual = meanLogWageResidual)
# end


# ----------------