## -------------  Settings

abstract type AbstractGradOccDef end;

mutable struct GradOccFracBA <: AbstractGradOccDef
    # Cutoff for fraction BA that makes an occ a "graduate" occ.
    cutoff :: Float64;
end

mutable struct GradOccRequBA <: AbstractGradOccDef
    # Cutoff for fraction requiring BA that makes an occ a "graduate" occ.
    cutoff :: Float64;
end

@kwdef mutable struct Settings
    name :: Symbol = :default;
    minAge :: Int = 18;
    maxAge :: Int = 60;
    minYear :: Int = MinYear;
    maxYear :: Int = MaxYear;
    minWeeksWorked :: Int = 40;
    maxWeeksWorked :: Int = 52;
    # :minIncome => 10_000,
    menOnly :: Bool = false;

    ageGroupUb :: Vector{Int} = [29, 39, 49, 60];
    yearGroupUb :: Vector{Int} = [1975, 1985, 1995, 2005, 2015, MaxYear];
    # Fraction of observations to keep (set to 1 except for testing)
    fracObsToKeep :: Float64 = 1.0;  
    gradOccDef :: AbstractGradOccDef = GradOccRequBA(0.2)
end

function data_settings(cname = :default)
    ds = Settings(; name = cname);
    if (cname == :default)  ||  (cname == :test)
    elseif cname == :gradOccsFracBA
        ds.gradOccDef = GradOccFracBA(0.3);
    elseif cname == :men
        ds.menOnly = true;
    else
        error("Invalid settings name  $(cname)");
    end
    return ds
end

function fracRequBa_cutoff(ds :: Settings)
    g = ds.gradOccDef;
    if g isa GradOccRequBA
        return g.cutoff;
    else
        error("Wrong grad occ def");
    end
end

# --------------------