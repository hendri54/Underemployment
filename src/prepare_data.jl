function prepare_data(ds; io = stdout)
    dfCps = prepare_cps_data(ds; io);
    dfCpsOcc = cps_occ_codes(dfCps, ds; io);

    # Make Df with CPS occupations and education requirements
    dfOcc = prepare_occ_data(dfCpsOcc, ds; io);
    leftjoin!(dfCps, dfOcc; on = CpsOccVar);

    # Indicators for graduate occs and match (such as "underemployed")
    add_grad_occs!(dfCps, ds; io);

    save_data(data_fn(ds), dfCps);
    info_msg(io, "Saved CPS data");
    return dfCps
end

function prepare_cps_data(ds; io = stdout)
    dfCps = read_cps_data(ds; io);
    pre_filter_data!(dfCps, ds; io);
    add_derived_vars!(dfCps, ds);
    filter_data!(dfCps, ds; io);
    add_wage_residual!(dfCps, ds);
    add_occ_wage!(dfCps, ds);
    # add_grad_occs_by_frac_ba!(dfCps, ds);
    # add_grad_gradocc!(dfCps, ds, GradOccs); 
    return dfCps
end

function read_cps_data(ds; io = stdout)
    info_msg(io, "Reading CPS data");
    fn = joinpath(data_dir(ds), base_fn() * ".dta");
    tb = readstat(fn);
    df = DataFrame(tb);
    info_msg(io, "  " * format(nrow(df); commas = true) * " rows");
    return df
end


function pre_filter_data!(df :: DataFrame, ds; io = stdout)
    info_msg(io, "Pre-filtering data");
    drop_df_variables!(df, [
        :asecflag, :asecwth, :cpsid, :cpsidp, :cpsidv, 
        :empstat, :firmsize, :hflag,
        :serial, :pernum, :relate, 
        :metarea, :month,
        :occ90ly, :occ2010, :ind90ly
        ]);
    apply_filter_fct!(df, dfRow -> should_drop_row_pre(dfRow, ds));
    drop_df_variables!(df, (:gq, :gqtype));
    if ds.fracObsToKeep < 1.0
        random_sub_sample!(df, ds.fracObsToKeep);
    end
    info_msg(io, "  Year range $(extrema(df.year))");
end

function drop_df_variables!(df, varNameV)
    vDropV = intersect(string.(varNameV), names(df));
    @select!(df, Not(vDropV));
end


"""
Should a row be dropped during pre-filtering?
"""
function should_drop_row_pre(dfRow, ds)
    toDrop = false;
    # 400 observations have negative asecwt (not clear from documentation why)
    if ismissing(dfRow.gq)  ||  (dfRow.gq != 1)  ||  (dfRow[WeightVar] <= 0.0)
        toDrop = true;
    # elseif ismissing(dfRow.disabwrk)  ||  (dfRow.disabwrk == 2)
    #     toDrop = true;
    elseif ismissing(getproperty(dfRow, OccVar))  ||  
            ismissing(getproperty(dfRow, EducVar))  ||
            !is_worker(dfRow)
        toDrop = true;
    end
    return toDrop
end

function is_worker(dfRow)
    # Variable used in `classwly` as LabeledArray
    clw = dfRow.classwly;
    # Include gov employees
    return 22 <= clw <= 28
end

function random_sub_sample!(df, fracToKeep)
    @info "Keeping random subsample ($fracToKeep)";
    rng = make_rng(430);
    filter!(row -> rand(rng) < fracToKeep, df);
    @info "  " * format(nrow(df); commas = true) * " rows";
end


"""
Filter data after derived variables have been constructed.
"""
function filter_data!(df :: DataFrame, ds; io = stdout)
    info_msg(io, "Filtering data");
    apply_filter_fct!(df, dfRow -> should_drop_row(dfRow, ds));
    @assert nrow(df) > 100_000  "Too few observations: $(nrow(df))";
    # earnwt and uhrsworkly have many missing values.
    drop_df_variables!(df, (
        :classwly, :earnwt, :educ, :incwage, :labforce, :wkswork2, :disabwrk, :uhrsworkly
        ));
    filter_extreme_wages!(df, ds);
end

function should_drop_row(dfRow, ds)
    toDrop = false;
    if (dfRow.age < ds.minAge) || (dfRow.age > ds.maxAge)
        toDrop = true;
    elseif ismissing(dfRow.edLevel)
        toDrop = true;
    elseif ismissing(dfRow.weeksWorked)  ||  
            ismissing(dfRow.wage)  ||  (dfRow.wage <= 0.0)  ||
            (dfRow.weeksWorked < ds.minWeeksWorked) || 
            (dfRow.weeksWorked > ds.maxWeeksWorked)
        toDrop = true;
    elseif ds.menOnly && (dfRow.sex != "male")
        toDrop = true;
    end
    return toDrop
end

function filter_extreme_wages!(df, ds)
    @assert all_at_least(df[!, WeightVar], 0.0);
    wageQuants = quantile(df.wage, ProbabilityWeights(df[!, WeightVar]), [0.01, 0.99]);
    filter!(row -> (row.wage >= wageQuants[1]) && (row.wage <= wageQuants[2]), df);
    return wageQuants
end

@testitem "filter extreme wages" begin
    using DataFrames, Underemployment, Test;
    n = 10_000;
    rng = Underemployment.make_rng(430);
    df = DataFrame(wage = rand(rng, n))
    df[!, Underemployment.WeightVar] = rand(rng,n);
    Underemployment.filter_extreme_wages!(df, data_settings(:default));
    wMin, wMax = extrema(df.wage);
    @test isapprox(wMin, 0.01; atol = 0.01);
    @test isapprox(wMax, 0.99; atol = 0.01);
end


## --------------  Graduate occs

"""
This is done after all occ info has been added to dfCps.
"""
function add_grad_occs!(dfCps, ds; io = stdout)
    if ds.gradOccDef isa GradOccRequBA
        # Using fraction requiring BA definition.
        add_baRequOccs!(dfCps, ds; io);
        # delete_missing_rows!(dfCps, BaRequOccs; io);
        # add_grad_gradocc!(dfCps, ds, BaRequOccs);
    elseif ds.gradOccDef isa GradOccFracBA
        add_grad_occs_by_frac_ba!(dfCps, ds);
    else
        error("Invalid grad occ definition.");
    end
    # Questionable - dropping about 12 pct of sample +++
    delete_missing_rows!(dfCps, GradOccs; io);
    add_grad_gradocc!(dfCps, ds, GradOccs);
end

"""
Add Occupation groups by fraction BA in reference year group.
"""
function add_grad_occs_by_frac_ba!(df, ds)
    dfOcc = grad_occs_by_frac_ba(df, ds);
    vGradOccs = var_label(GradOccs);
    # Just in case the variable is already in the dataframe
    delete_var!(df, vGradOccs);
    leftjoin!(df, dfOcc, on = var_label(Occupations));

    # nMissing = sum(ismissing.(df[!, vGradOccs]));
    # if nMissing > 0
    #     @info "Dropping missing occupations in reference year: $nMissing";
    #     filter!(row -> !ismissing(row[vGradOccs]), df);
    # end
end

"""
Occupation groups by fraction BA in reference year group.
Returns DataFrame with one row per occupation.
Not all occupations are present in the reference year group.

Tests itself.
"""
function grad_occs_by_frac_ba(df, ds)
    yearVar = YearGroups;
    ubV = [0.5, 1.0];
    dfOY = group_occs_by_frac_ba(df, ds; yearVar,
        ubV, labelV = grad_occ_labels(ds));

    filter_ref_year_group!(dfOY);

    vGradOccs = var_label(GradOccs);
    rename!(dfOY, :fracBAgroup => vGradOccs);

    @assert check_occ_groups(dfOY, first(ubV));
    select!(dfOY, var_label(Occupations), vGradOccs);
    return dfOY
end

function filter_ref_year_group!(df)
    vYear = var_label(YearGroups);
    refYearGroup = last(levels(df[!, vYear]));
    filter!(row -> getproperty(row, vYear) == refYearGroup, df);
end

"""
Based on fraction BA.
"""
function check_occ_groups(dfOY, cutoff)
    isValid = true;
    for dfRow in eachrow(dfOY)
        isValid = check_occ_groups_row(dfRow, cutoff);
        isValid || break;
    end
    return isValid
end

function check_occ_groups_row(dfRow, cutoff)
    fracBA = dfRow.fracBA;
    shouldBeGradOcc = (fracBA >= cutoff);
    # Check is correct b/c this is only for GradOccs concept.
    isValid = (0 <= fracBA <= 1)  &&  
        (is_grad_occ(dfRow[var_label(GradOccs)]) == shouldBeGradOcc);
    isValid  ||  @show dfRow;
    return isValid
end


"""
Add a single variable that makes a grouping
    graduate yes/no  x  graduate occ yes/no
"""
function add_grad_gradocc!(df, ds, gradOccVar)
    vGgo = var_label(GradsGradOccs);  # grads_grad_occ_var(gradOccVar));
    # vGgo = var_label(GradsGradOccs); 
    df[!, vGgo] = create_vector(String, nrow(df));
    for dfRow in eachrow(df)
        fill_grad_gradocc!(dfRow, gradOccVar);
    end
    df[!, vGgo] = categorical(df[!, vGgo]);
end

function fill_grad_gradocc!(dfRow, gradOccVar)
    v = grad_gradocc_match(dfRow, gradOccVar);
    # vGgo = grads_grad_occ_var(gradOccVar);
    set_var!(dfRow, GradsGradOccs, v);  
end

function grad_gradocc_match(dfRow, gradOccVar)
    isGradOcc = is_grad_occ(dfRow, gradOccVar);
    if ismissing(isGradOcc)
        v = missing;
    elseif is_grad(dfRow)
        if isGradOcc
            v = GradLabel;
        else
            v = "Underemployed";
        end
    else
        if isGradOcc
            v = "Overemployed";
        else
            v = NonGradLabel;
        end
    end
    return v
end


"""
Add classifier for graduate occs based on fraction requiring BA.
Categorical variable with labels GradOccLabel and NonGradOccLabel.
"""
function add_baRequOccs!(dfCps, ds; io = stdout)
    cutoff = fracRequBa_cutoff(ds);
    v = create_vector(String, nrow(dfCps));
    for (iRow, fracRequBA) in enumerate(dfCps[!, var_symbol(FracRequireBA)])
        if ismissing(fracRequBA)
            v[iRow] = missing;
        elseif fracRequBA <= cutoff
            v[iRow] = NonGradOccLabel;
        else
            v[iRow] = GradOccLabel;
        end
    end
    dfCps[!, var_symbol(GradOccs)] = categorical(v);
end


# -----------------