struct FileType
    extension :: String
end

const FigureFile = FileType(".pdf");
const TextFile = FileType(".txt");
const FigExtension = ".pdf";

# Variables in the original dataset. These are not used after importing.
const OccVar = :occ10ly;
const EducVar = :educ;
# Sums to about 5e9
const WeightVar = :asecwt;  # the right one? +++++


# Holds CPS occ codes in occ datasets
const CpsOccVar = :Census2010Code;
const CpsOccTitleVar = :Census2010Title;
# BLS occupation codes for ed requirements
const BlsOccVar = :Soc2018Code;

const GradOccLabel = "Graduate";
const NonGradOccLabel = "Non-graduate";
const GradLabel = "Graduate";
const NonGradLabel = "Non-graduate";

const MinYear = 1968;
const MaxYear = 2024;
const BaseDir = "/Users/lutz/Documents/projects/p2025/underemployment";


# Downloaded 2025-Feb-12 from https://data.bls.gov/pdq/SurveyOutputServlet
# Years 1962 to 2024
const CpiByYear = [
    30.2, 30.6, 31.0, 31.5, 32.4, 33.4, 34.8, 36.7, 38.8, 40.5, 41.8, 44.4, 
    49.3, 53.8, 56.9, 60.6, 65.2, 72.6, 82.4, 90.9, 96.5, 99.6, 103.9, 107.6, 
    109.6, 113.6, 118.3, 124.0, 130.7, 136.2, 140.3, 144.5, 148.2, 152.4, 156.9, 
    160.5, 163.0, 166.6, 172.2, 177.1, 179.9, 184.0, 188.9, 195.3, 201.6, 207.342, 
    215.303, 214.537, 218.056, 224.939, 229.594, 232.957, 236.736, 237.017, 240.007, 
    245.120, 251.107, 255.657, 258.811, 270.970, 292.655, 304.702, 313.689
    ];

function cpi_index(yr) 
    @assert all(yr .>= 1962);
    @assert all(yr .<= 2024);
    return CpiByYear[yr .- 1961] ./ first(CpiByYear);
end


## -----------  Variables

struct VarInfo
    name :: String
    label :: String
end

const LogOccupWage = VarInfo("logOccupWage", "Log occupational wage");
const MeanLogOccupWage = VarInfo("meanLogOccupWage", 
    "Mean log occupational wage");
const LogWageResidual = VarInfo("logWageResidual", "Log wage residual");
const MeanLogWageResidual = 
    VarInfo("meanLogWageResidual", "Mean log wage residual");
const LogWage = VarInfo("logWage", "Log wage");
const MeanLogWage = VarInfo("meanLogWage", "Mean log wage");
const Occup = VarInfo("occup", "Occupation");
const FracBA = VarInfo("fracBA", "Fraction BA or more");
const FracRequireBA = 
    VarInfo("fracRequireBA", "Fraction of jobs requiring BA");
const FracUnder = VarInfo("fracUnder", "Fraction underemployed");


var_symbol(v :: VarInfo) = Symbol(v.name);
var_label(v :: VarInfo) = v.name;
fig_label(v :: VarInfo) = v.label;
fig_name(v :: VarInfo) = v.name;

# -----------------