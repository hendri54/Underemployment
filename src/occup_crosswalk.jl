"""
Construct a DataFrame with ed requirements by CPS occ code.
Input is DataFrame with CPS occupation codes and masses.
"""
function prepare_occ_data(dfCpsOcc, ds; io = stdout)
    # Crosswalk BLS - Census
    dfOcc = occupation_crosswalk(dfCpsOcc; io);
    # Each Census occ has multiple BLS (SOC) occs
    dfMatch = soc_codes_for_cps_codes(dfOcc);
    leftjoin!(dfMatch, dfCpsOcc; on = CpsOccVar);

    # Education requirements
    # Each row is a BLS (SOC) occupation
    dfEd = process_bls_data(; io);

    dfMatch[!, var_symbol(FracRequireBA)] = create_vector(Float64, nrow(dfMatch));
    for dfRow in eachrow(dfMatch)
        set_var!(dfRow, FracRequireBA,
            edRequirements_one_cpsOcc(dfEd, getproperty(dfRow, BlsOccVar); io));
    end

    set_ed_requ_by_hand!(dfMatch; io);

    save_data(occ_ed_require_fn(ds), dfMatch);
    info_msg(io, "Saved occupational ed requirements data");

    report_missing_ed_requirements(dfMatch; io);

    return dfMatch
end


"""
Input: Occupation crosswalk.
Output: DataFrame with all SOC codes for each CPS code.
"""
function soc_codes_for_cps_codes(dfOcc)
    gdf = groupby(dfOcc, CpsOccVar);
    # This is used to collect the SOC codes as Ints (without Views or missings).
    list_all(x) = [Int.(x)];
    dfOut = @combine gdf begin
        $CpsOccVar = first($CpsOccVar);
        $BlsOccVar = list_all($BlsOccVar);
    end
    return dfOut
end

# test this +++++
"""
Calculate education requirements for one CPS occupation.
Currently just fraction of jobs that require BA or more.

# Arguments
- dfEd: DataFrame with BLS education requirements for SOC occupations.
- socCodes: SOC codes for one CPS occupation.
"""
function edRequirements_one_cpsOcc(dfEd, socCodes; io = stdout)
    idxV = findall(x -> x in socCodes, dfEd[!, BlsOccVar]);
    if isnothing(idxV)
        return missing
    end
       
    # Fraction BA or more is 1 - fraction(BlsBAIdx - 1)
    vFrac = cum_ed_frac_name(BlsBaIdx - 1);
    if length(idxV) == 1
        idx = only(idxV);
        fracUnder = dfEd[idx, vFrac];
        if ismissing(fracUnder)
            return missing
        else
            return 1 - fracUnder;
        end
    else
        fracUnderV = dfEd[idxV, vFrac];
        if all(ismissing.(fracUnderV))
            return missing
        else
            return 1 - mean(skipmissing(fracUnderV));
        end
    end
end


"""
Construct a DataFrame with occ codes for SOC 2018 (BLS ed requirements)
and Census 2010.
Some SOC codes map into multiple Census codes. Then typically the first Census2010Code in the group lacks a SOC code because it represents the union of the following rows with the same Census codes.
Input is DataFrame with CPS occupations.
"""
function occupation_crosswalk(dfCpsOcc; io = stdout)
    dfCross = crosswalk_2018_2010(; io);
    # dfCpsOcc = cps_occ_codes(dfCps; io);
    # Avoid duplicate variable name
    dfJoin = outerjoin(dfCross, @select(dfCpsOcc, Not(CpsOccTitleVar)); on = CpsOccVar);
    sort!(dfJoin, CpsOccVar);
    adjust_based_on_titles!(dfJoin; io);
    report_missing_occ_codes(dfJoin; io);
    info_msg(io, "The following overstates the fraction of occs with missing SOC codes.");
    # Most deleted rows are for Census2010 codes that are unions of the next rows.
    # They can be deleted, but no mass is lost.
    delete_missing_rows!(dfJoin, BlsOccVar; io, massVar = :occMass);
    return dfJoin
end

occup_log_file() = joinpath(bls_data_dir(), "occup_log.txt");
occup_crosswalk_file() = joinpath(bls_data_dir(), "occup_crosswalk.mat");


"""
Create crosswalk between 2010 census codes and 2018 SOC codes.
For the most part, 
test this +++++
"""
function crosswalk_2018_2010(; io = stdout)
    dfCross = load_occ_crosswalk(; io);
    # @subset!(dfCross, .!ismissing.(BlsOccVar));
    # info_msg(io, "  Rows with SOC 2018 info: " * format_int(nrow(dfCross)));
    # fill_combined_codes!(dfCross; io);
    # Some codes are stored in title variables (!)
    copy_codes_out_of_titles!(dfCross);
    copy_missing_codes_down!(dfCross);
    save_data(occup_crosswalk_file(), dfCross);
    return dfCross
end


"""
Some CPS occupations are coded as grouped, while in the census they are not.
Example: 130 = Human resources managers -> 136 in Census
These are hand-recoded. The missing SOC code is copied from the non-missing line.
Input is DataFrame with 
"""
function adjust_based_on_titles!(dfOcc; io = stdout)
    # Mapping CPS codes into Census codes that match by title
    d = Dict(130 => 136,  560 => 565, 620 => 630, 720 => 725, 730 => 740,
        1000 => 1005, 1100 => 1105, 1960 => 1965, 2020 => 2025,
        2140 => 2145, 2150 => 2160, 3240 => 3245, 3410 => 3420,
        3530 => 3535, 3650 => 3655, 4050 => 4110, 4060 => 4110,
        5800 => 5810, 6930 => 6940, 8230 => 8256, 9100 => 9110,
        9730 => 9750, 3130 => 3255, 3950 => 3840
        );
    for (oldCode, newCode) in d
        adjust_one_based_on_title!(dfOcc, oldCode, newCode; io);
    end
end

function adjust_one_based_on_title!(dfOcc, oldCode, newCode; io)
    # Find all old codes
    idxV = findall(x -> x == oldCode, dfOcc.Census2010Code);
    if !isempty(idxV)
        # Find one row with new code
        idxNew = findfirst(x -> x == newCode, dfOcc.Census2010Code);
        if !isempty(idxNew)
            dfOcc[idxV, BlsOccVar] .= dfOcc[idxNew, BlsOccVar];
            dfOcc[idxV, CpsOccTitleVar] .= dfOcc[idxNew, CpsOccTitleVar];
        end
    end
end


"""
Given a DataFrame with Census2010Code and Soc2018Code. When a Census2010Code is missing,
copy from previous row. That groups entries with multiple Soc codes.
"""
function copy_missing_codes_down!(dfOcc)
    for (iRow, dfRow) in enumerate(eachrow(dfOcc))
        if ismissing(dfRow.Census2010Code)
            if iRow > 1
                dfRow.Census2010Code = dfOcc.Census2010Code[iRow - 1];
                dfRow.Census2010Title = dfOcc.Census2010Title[iRow - 1];
            end
        end
    end
end

"""
Keep in mind that some Census codes map into multiple SOC codes.
"""
function report_missing_occ_codes(dfOcc; io = stdout)
    info_msg(io, "\n", "Occup codes in Census 2010 without SOC 2018 matches");
    missingMass = 0.0;
    for iRow in 1 : nrow(dfOcc)
       mass = report_if_missing(dfOcc, iRow; io);
       missingMass += mass;
    end
    totalMass = sum(skipmissing(dfOcc[!, :occMass]));
    info_msg(io, "Fraction missing SOC 2018 codes: ", 
        format(missingMass / totalMass; precision = 2));
end

function report_if_missing(dfOcc, iRow; io = stdout)
    socCode = dfOcc[iRow, BlsOccVar];
    censusCode = dfOcc[iRow, CpsOccVar];
    nextCensusCode = (iRow < nrow(dfOcc))  ? dfOcc[iRow+1, CpsOccVar]  :  0;
    # Need to check whether same as next census code. Then don't report b/c 
    # next row may have SOC code.
    if ismissing(socCode)  &&  !ismissing(censusCode)  &&  
            !isequal(censusCode, nextCensusCode)
        mass = dfOcc[iRow, :occMass];
        mass = ismissing(mass)  ?  0.0  :  mass;  # why does that happen? +++++
        massFmt = format(mass; precision = 3);
        info_msg(io, censusCode, dfOcc[iRow, CpsOccTitleVar], 
            "[mass $massFmt]");
    else
        mass = 0.0;
    end
    return mass
end


"""
Make a DataFrame with CPS occupation codes (Int) and labels.
Based on actual codes found in dataset.
Also add total mass of workers (sums to 1).
Saves DataFrame.
"""
function cps_occ_codes(dfCps :: AbstractDataFrame, ds; io = stdout)
    info_msg(io, "Creating CPS occupation code list.");
    codeDf = cps_occ_codes_and_titles(dfCps; io);
    add_occ_mass!(codeDf, dfCps);
    save_data(cps_occs_fn(ds), codeDf);
    info_msg(io, "Saved CPS occupation list");
    return codeDf
end

function add_occ_mass!(codeDf, dfCps)
    totalWt = sum(dfCps[!, WeightVar]);
    gdf = groupby(dfCps, CpsOccVar);
    dfMass = @combine gdf begin
        :occMass = sum($WeightVar) / totalWt;
    end
    leftjoin!(codeDf, dfMass; on = CpsOccVar);
    @assert isapprox(sum(codeDf[!, :occMass]), 1.0; atol = 0.001);

    return codeDf
end

"""
Make DataFrame with all CPS occ codes and their titles.
Self-tests.
"""
function cps_occ_codes_and_titles(dfCps; io = stdout)
    # This implementation is brittle. Therefore self-tested below.
    labelV = string.(unique(skipmissing(dfCps[!, OccVar])));
    codeV = unique(skipmissing(dfCps[!, CpsOccVar]));
    idxV = sortperm(codeV);
    codeDf = DataFrame(CpsOccVar => codeV[idxV], CpsOccTitleVar => labelV[idxV]);
    @assert check_cps_occ_codes(codeDf, dfCps);
    return codeDf
end

"""
Check that mapping codes -> titles matches dfCps.
"""
function check_cps_occ_codes(codeDf, dfCps)
    isValid = true;
    for iRow in 1 : 100 : nrow(dfCps)
        idx = findfirst(x -> x == dfCps[iRow, CpsOccVar], codeDf[!, CpsOccVar]);
        if isnothing(idx)
            @warn "Not found: $(dfCps[iRow, CpsOccVar])";
            isValid = false
        elseif !isequal(codeDf[idx, CpsOccTitleVar], string(dfCps[iRow, OccVar]))
            @warn """
                Occ mismatch:  $(dfCps[iRow, CpsOccVar])
                $(codeDf[idx, CpsOccTitleVar])
                $(string(dfCps[iRow, OccVar]))
            """
            isValid = false;
        end
    end
    return isValid
end


# function split_occ_entry(s :: AbstractString)
#     sep = " => ";
#     if contains(s, sep)
#         occCode, occDescr = split(s, sep);
#         occCode = parse(Int, occCode);
#     else
#         occCode = nothing;
#         occDescr = nothing;
#     end
#     return occCode, occDescr
# end

"""
Load occupational crosswalk spreadsheet. 
SOC 2018 -> Census 2018 -> Census 2010.
Recode variables sensibly.
"""
function load_occ_crosswalk(; io = stdout)
    info_msg(io, "Loading occupation crosswalks");
    fn = joinpath(bls_data_dir(), "2018-occupation-code-list-and-crosswalk.xlsx");
    @assert isfile(fn);
    df = DataFrame(XLSX.readtable(fn, 4; first_row = 4, stop_in_empty_row = false));

    # Recode all variables for type stability and consistency.
    df[!, CpsOccVar] = parse_to_ints(df[!, "2010 Census Code"]);
    # Mostly format adjustments.
    df[!, BlsOccVar] = recode_soc_2018_codes(df[!, "2018 SOC Code"]);
    idx = findfirst(s -> startswith(s, "2018 Census Title"), names(df));
    v2018Title = names(df)[idx];
    df.Census2018Title = Vector{Union{String,Missing}}(df[!, v2018Title]);
    idx = findfirst(s -> startswith(s, "2010 Census Title"), names(df));
    v2010Title = names(df)[idx];
    df[!, CpsOccTitleVar] = Vector{Union{String,Missing}}(df[!, v2010Title]);

    drop_df_variables!(df, ["2010 Census Code", v2010Title,
        "2010 SOC code", "2018 SOC Code", "2018 Census Code", v2018Title]);

    info_msg(io, "  Loaded " * format_int(nrow(df)) * " rows.");
    return df;
end


"""
Copy 2018 SOC codes out of 2018 Census titles.
For occs that do not exist in 2018 Census, the 2018 SOC codes and titles are stored in the 2018 Census Title (!). Example: "Air Crew Members (55-3011)".
Transfer the codes to where they belong.
"""
function copy_codes_out_of_titles!(df)
    for dfRow in eachrow(df)
        copy_one_code_out_of_title!(dfRow);
    end
end

function copy_one_code_out_of_title!(dfRow)
    titleStr = dfRow.Census2018Title;
    if ismissing(titleStr)  ||  !ismissing(dfRow.Soc2018Code)
        return nothing;
    end
    if titleStr isa String
        dfRow.Soc2018Code = parse_code_out_of_title(titleStr);
    else
        @info "Unexpected title: $titleStr";
    end
end

function parse_code_out_of_title(titleStr)
    m = match(r"\((\d{2}-\d{4})\)", titleStr);
    if isnothing(m)
        return missing;
    else
        return recode_one_soc_2018_code(m.captures[1])
    end
end


"""
Codes are of the form "11-1234". Some are "none". Some missing (not string).
"""
function recode_soc_2018_codes(v)
    outV = Vector{Union{Int,Missing}}(undef, length(v));
    for (j, x) in enumerate(v)
        outV[j] = recode_one_soc_2018_code(x);
    end
    return outV
end

function recode_one_soc_2018_code(x)
    if ismissing(x)
        return missing
    elseif (x == "none")  ||  endswith(x, 'X')
        # These are group codes that are made up. The detailed codes in
        # lines below will be used.
        return missing
    elseif x[3] == '-'
        return parse(Int, replace(x, "-" => ""));
    else
        error("Cannot parse occ code $x")
    end
end


function set_ed_requ_by_hand!(dfOcc; io = stdout)
    # Based on inspecting descriptions and ed requirement entries.
    # For largest occupations
    occCodeV = [(4000, 6.1, "chefs"),  (1000, 85.0, "computer scientists"),
        (6355, 5.0, "electricians"), (6050, 5.0, "ag workers"),
        (3500, 5.0, "licensed practical etc"), (8030, 2.0, "machinists"),
        (1410, 90.0, "electrical engineers"), (5330, 6.0, "loan reviewers"),
        (4510, 1.0, "hairdressers"), (9750, 1.0, "moving workers"),
        (7330, 5.0, "mechanics"), (4920, 10.0, "realtors"),
        (5810, 10.0, "data entry keyers"), (7220, 5.0, "mechanics"),
        (5550, 1.0, "mail carriers"), (1530, 90.0, "engineers"),
        (7315, 1.0, "heating techs"), (8230, 5.0, "bookbinders"),
        (7210, 5.0, "truck mechanics"), (2140, 25.0, "paralegals"),
        (5540, 1.0, "postal clerks"), (1540, 25.0, "drafters"),
        (4820, 45.0, "securities analysts"), (3640, 1.0, "dental assistants"),
        (7720, 5.0, "electrical equipment assemblers"), (1220, 65.0, "OR analysts"),
        (5510, 1.0, "messengers"), (5020, 1.0, "telephone operators"),
        (7140, 3.0, "aircraft mechanics"), (6220, 1.0, "brickmasons"),
        (7150, 1.0, "auto repair"), (5350, 10.0, "correspondent clerks"),
        (8130, 1.0, "tool makers"), (3160, 63.0, "physical therapists"),
        (4650, 1.0, "personal care workers"), (3310, 1.0, "dental hygienists"),
        (5840, 2.5, "insurance claims processors"), (4950, 1.0, "door to door sales"),
        (6240, 1.0, "flooring installers"), (1760, 90.0, "physical scientists"),
        (7420, 1.0, "telecom installers")
        ];
    for (occCode, fracRequireBA, descr) in occCodeV
        set_one_ed_requirement!(dfOcc, occCode, fracRequireBA / 100);
    end
end

function set_one_ed_requirement!(dfOcc, occCode, fracRequireBA)
    idx = findfirst(x -> x == occCode, dfOcc[!, CpsOccVar]);
    if !isnothing(idx)
        dfOcc[idx, var_symbol(FracRequireBA)] = fracRequireBA;
    end
end


"""
Report occupations with missing ed requirements and positive mass in CPS.
"""
function report_missing_ed_requirements(dfOcc; io = stdout)
    edVar = var_symbol(FracRequireBA);
    totalMass = sum(skipmissing(dfOcc.occMass));
    
    df = @subset(dfOcc, :occMass .> 0.0, ismissing.($edVar));
    sort!(df, :occMass; rev = true);
    df.frac = df.occMass ./ totalMass;
    info_msg(io, "Fraction of employment in occs with missing ed requirements: ",
        format(sum(df.frac); precision = 2));

    println(io, "Largest occupations with missing ed requirements:");
    show(io, first(df, 20));
end


# """
# Fill in codes for occupations in 2010 Census that combine SOC codes.
# Report the combinations.
# `Census2010Complete` contains the completed set of codes.
# """
# function fill_combined_codes!(df; io = stdout)
#     n = nrow(df);
#     df[!, :Census2010Complete] = zeros(Int, n);

#     lastTgOcc = nothing;
#     lastTitle = nothing;
#     logV = Vector{String}();
#     for (j, dfRow) in enumerate(eachrow(df))
#         lastTgOcc, lastTitle = assign_one_census_occ!(dfRow, 
#             lastTgOcc, lastTitle, logV);
#     end
    
#     for line in logV
#         println(io, line);
#     end
# end

# function assign_one_census_occ!(dfRow, lastTgOcc, lastTitle, logV)
#     tgVar = dfRow.Census2010Code;
#     if ismissing(tgVar)
#         newVar = lastTgOcc;
#         newTitle = lastTitle;
#         push!(logV, "$lastTgOcc  $lastTitle");
#         push!(logV, "  add:  $(dfRow.Census2018Code)  $(dfRow.Census2018Title)");
#     else
#         if tgVar isa Integer
#             newVar = tgVar;
#         else
#             newVar = parse(Int, tgVar);
#         end
#         newTitle = dfRow.Census2010Title;
#     end
#     dfRow.Census2010Complete = newVar;
#     return newVar, newTitle
# end

# -----------------