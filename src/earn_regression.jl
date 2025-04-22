function add_wage_residual!(df, ds)
    mdl = earnings_regression(df, ds; useOccupations = false, outDir = diagnostics_dir(ds));
    df[!, var_symbol(LogWageResidual)] = residuals(mdl);

    show_experience_profile(mdl, ds);
    show_year_dummies(mdl, ds);
end

"""
Add occupational wage to df. Also save DataFrame with occupational wages by occ
"""
function add_occ_wage!(df, ds)
    mdl = earnings_regression(df, ds; 
        useOccupations = true, outDir = diagnostics_dir(ds));
    dfOcc = get_occup_dummies(mdl);
    save_data(occ_wage_path(ds), dfOcc);
    leftjoin!(df, dfOcc; on = :occup);
    filter!(row -> !ismissing(row.logOccupWage), df);
end


"""
Could be tested with simulated earnings.
"""
function earnings_regression(df, ds; useOccupations = false, outDir = nothing)
    @info "Running earnings regression";
    # additional filter? +++++

    df.xpRegr = experience_regressor(df.experience);

    xpTerms = [power_term(term(:xpRegr), j) for j = 1 : max_exper_power()];
    rhs = ConstantTerm(1) + Term(:edLevel) + sum(xpTerms) + Term(:year);
    cDict = Dict(:year => DummyCoding());
    if !(ds.menOnly)
        rhs = rhs + Term(var_symbol(Gender));
    end
    if useOccupations
        rhs = rhs + Term(:occup);
        cDict[:occup] = DummyCoding();
    end
    fmla = log_term(term(:wage)) ~ rhs;
    mdl = lm(fmla, df;   contrasts = cDict);
    if !isnothing(outDir)
        suffix = useOccupations  ?  "_with_occ"  :  "";
        fPath = joinpath(outDir, 
            file_name("wage_regression" * suffix, nothing, TextFile));
        save_output(fPath, mdl);
    end
    return mdl
end

experience_regressor(experV) = experV ./ 10;
max_exper_power() = 4;

# For constructing formula terms
power_term(x :: AbstractTerm, j) = FunctionTerm(z -> z^j, [x], :($x ^ $j));
log_term(x :: AbstractTerm) = FunctionTerm(log, [x], :(log($(x))));


function show_experience_profile(mdl, ds)
    experV = 0 : 30;
    df = (
        exper = experV,
        logWage = experience_profile(mdl, experV)
        );
    fig = line_graph(df, :exper, :logWage;
        xLabel = "Experience", yLabel = "Log wage");
    fPath = joinpath(diagnostics_dir(ds), 
        file_name("experience_profile", nothing, FigureFile));
    figsave(fPath, fig);
    return fPath
end


"""
Make retrieving exp coefficients more robust +++++
"""
function experience_profile(mdl, experV)
    xV = experience_regressor(experV);
    logWageV = zeros(size(xV));
    for iExp = 1 : max_exper_power()
        coeffName = experience_coeff_name(iExp);
        betaX = coeff_value(mdl, coeffName);
        logWageV .+= betaX .* (xV .^ iExp);
    end
    return logWageV;
end

function experience_coeff_name(iExp)
    suffix = (iExp > 0)  ?  " ^ $iExp"  :  "";
    return "xpRegr" * suffix
end

function coeff_value(mdl, coeffName)
    idx = findfirst(x -> x == coeffName, coefnames(mdl));
    @assert !isnothing(idx)  "Not found: $coeffName";
    return coef(mdl)[idx]
end


function show_year_dummies(mdl, ds)
    df = get_year_dummies(mdl);
    fPath = joinpath(diagnostics_dir(ds), 
        file_name("wage_regr_year_dummies", nothing, FigureFile));
    fig = line_graph(df, "Year", "Coefficient");
    figsave(fPath, fig);
end

"""
Retrieve dummy coefficients that match a RegEx.
"""
function get_dummies(mdl, year_regex; regrVar = "Regressor")
    idxV = find_regressors(mdl, year_regex);
    isnothing(idxV)  &&  return nothing;

    df = DataFrame(Coefficient = coef(mdl)[idxV]);
    df[!, regrVar] = coefnames(mdl)[idxV];
    return df
end

function get_year_dummies(mdl)
    df = get_dummies(mdl, r"^year");
    df.Year = map(extract_year, df.Regressor);
    return df
end

"""
Extract the year from a regressor name of the form "year: 1999"
"""
function extract_year(yearRegr)
    year_regex = r"year: (\d{4})";
    m = match(year_regex, yearRegr);
    if isnothing(m)
        return nothing
    else
        return parse(Int, m.captures[1]);
    end
end

function get_occup_dummies(mdl)
    df = get_dummies(mdl, r"^occup"; regrVar = :occup);
    df.occup = remove_prefix.(Ref("occup: "), df.occup);
    rename!(df, "Coefficient" => "logOccupWage");
    return df
end

function remove_prefix(rgEx, s)
    if startswith(s, rgEx)
        return s[(length(rgEx) + 1) : end]
    else
        return s
    end
    # m = match(rgEx, s);
    # return m.captures[1]
end


"""
Find all regressors that match a pattern. Pattern can be regex.
Test: "Dummies"
"""
function find_regressors(mdl, rgEx)
    return findall(x -> occursin(rgEx, x), coefnames(mdl))
end


"""
Graph by year: mean log wage residual, mean log occ wage
for 4 groups: grads (underemployed or not), non-grads (in grad occs or not)
"""
function show_earnings_stats(df, ds; gradOccVar = GradOccs, genderLbl = nothing)
    gradsGradOccVar = GradsGradOccs;
        
    df2 = subset_gender(df, genderLbl);
    grpVars = [gradsGradOccVar, Years];
    statsDf = stats_grouped(df2, grpVars, ds; gradOccVar);

    for v in [MeanLogOccupWage, MeanLogWageResidual]
        fig = line_graph_grouped(statsDf, Years, v, gradsGradOccVar;
            yLabel = fig_label(v));
        fPath = fig_path(base_name(v) * file_suffix(genderLbl), grpVars, ds);
        figsave(fPath, fig);
    end
end


"""
Show earnings quantiles. For all and for grads.
"""
function show_earn_quantiles(df, ds)
    grpVars = [YearGroups, Grads];
    dfGrads = subset_grads(df, GradLabel);
    for varName in (LogOccupWage, LogWageResidual, LogWage)
        show_quantiles_grouped(df, varName, grpVars, [0.25, 0.75], ds);
        show_quantiles_grouped(dfGrads, varName, YearGroups, 
            [0.05, 0.25, 0.5, 0.75, 0.95], ds; 
            suffix = file_suffix(Grads));
    end
end


function show_quantiles_grouped(df, varName, grpVars :: AnyGrouping, pctV, ds;
        suffix = "")
    if grpVars isa MultiGrouping
        @assert length(grpVars) == 2  "Expecting 2 grouping variables. Or graph gets messy";
        xVar = first(grpVars);
        colorVar = last(grpVars);
    else
        xVar = grpVars;
        colorVar = nothing;
    end
    dfOut = quantiles_grouped(df, varName, grpVars, colorVar, pctV);
    fig = line_graph_grouped(dfOut, xVar, varName, :Group;
        colorLabel = "Group");

    fPath = fig_path(var_label(varName) * "_quantiles" * suffix, grpVars, ds);
    figsave(fPath, fig);
end

"""
`colorVar` contains either nothing or a combination of groupings (one for each combi).
"""
function quantiles_grouped(df, varName, grpVars, colorVar, pctV;
        basePct = nothing)
    @assert all(0.0 .<= pctV .<= 1.0);
    gdf = groupby(df, var_labels(grpVars));
    dfOut = var_quantiles(gdf, varName, pctV; basePct);
    # Color is the combination of grouping variable and quantile.
    dfOut.Group = make_quantile_column(dfOut, colorVar);
    return dfOut
end

function make_quantile_column(dfOut, colorVar)
    return string.(dfOut[!, var_label(colorVar)], "-", dfOut.quantile);
end

function make_quantile_column(dfOut, ::Nothing)
    return string.(dfOut.quantile);
end


"""
Show occupational wage cdfs by year group. Graduates only by default.
"""
function show_occ_wage_cdfs(dfCps, ds; gradsOnly = true)
    dfCps.tmpWt = copy(dfCps[!, WeightVar]);
    if gradsOnly
        idxV = find_grads(dfCps, NonGradLabel);
        dfCps.tmpWt[idxV] .= 0.0;
        suffix = file_suffix(Grads);
    else
        suffix = "";
    end
    # Do not modify this! It affects dfCps.
    gdf = groupby(dfCps, var_symbol(YearGroups));

    pctV = 0.05 : 0.01 : 0.95;
    for basePct in (nothing, 0.5)
        dfOut = var_quantiles(gdf, LogOccupWage, pctV; basePct);
        if isnothing(basePct)
            bSuffix = "";
        else
            bSuffix = "basePct";
        end

        fig = line_graph_grouped(dfOut, "quantile", LogOccupWage, YearGroups);
        fPath = joinpath(occup_dir(ds), 
            fig_fn("occup_wage_cdfs" * suffix * bSuffix, YearGroups));
        figsave(fPath, fig);
    end
end



# -------------------