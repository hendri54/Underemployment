function plot_defaults()
    set_default_aog_theme!();
    # For regular Makie plots.
    # set_theme!(default_theme());
end

default_aog_theme() = AlgebraOfGraphics.aog_theme();
set_default_aog_theme!() = set_aog_theme!();

color_scheme() = ColorSchemes.viridis;

function get_color(j :: Integer)
    return get(color_scheme(), j / 3);
end

function set_fig_opt!(d, oName, oValue)
    d[oName] = oValue;
end

function default_fig_opts()
    return Dict{Symbol,Any}(
        :size => (432, 432)
    )
end

function default_axis_opts()
    # return Vector{Pair{Symbol,Any}}([:xticklabelrotation => 0.0])
    return Dict{Symbol,Any}(
        :xticklabelrotation => 0.0
        )
end

function default_legend_opts()
    return Dict{Symbol,Any}(
        :position => :bottom,
        :framevisible => false,
        :titleposition => :left
        )
end

function render(plt; 
        axisOpts = default_axis_opts(), figOpts = default_fig_opts(),
        legendOpts = default_legend_opts(), kwargs...)
    return AlgebraOfGraphics.draw(plt; 
        figure = figOpts, axis = axisOpts, legend = legendOpts, kwargs...)
end


# """
# Useful for assembling a NamedTuple from elements. Such as axis options.
# """
# function make_named_tuple(v :: AbstractVector{Pair{T1, T2}}) where {T1, T2}
#     return NamedTuple(first.(v) .=> last.(v))
# end

# function make_named_tuple(v :: Dict)
#     return NamedTuple(keys(v) .=> values(v))
# end

# make_named_tuple(v :: NamedTuple) = v;


## ---------------  Saving figures

function figsave(filePath :: String, p; 
    figNotes = nothing, dataM = nothing)

    @assert !(p isa Tuple)  "Tuple input $p. Expecting a Figure";
    # newPath = change_extension(filePath, FigExtension);
    newPath = filePath;
    fDir, fName = splitdir(newPath);
    if !isdir(fDir)
        mkpath(fDir);
    end
    # This prevents trouble with corrupt files
    isfile(newPath)  &&  rm(newPath);
    save(newPath, p);
    
    save_fig_notes(figNotes, filePath);
    # save_fig_data(dataM, filePath; io);
    return filePath
end

figsave(fDir :: String, fName :: String, p; figNotes = nothing) =
    figsave(joinpath(fDir, fName), p; figNotes);


function save_fig_notes(figNotes :: AbstractVector, 
        fPath :: AbstractString)
    save_text_file(fig_notes_path(fPath), figNotes);
end

function save_fig_notes(figNotes :: AbstractString, 
        fPath :: AbstractString)
    save_fig_notes([figNotes], fPath);
end

function save_fig_notes(::Nothing, fPath) end

function fig_notes_path(fPath :: AbstractString)
    newDir = fig_data_dir(fPath);
    fDir, fName = splitdir(fPath);
    newPath = joinpath(newDir, change_extension(fName, ".txt"));
    return newPath
end

function fig_data_dir(fPath :: AbstractString)
    fDir, fName = splitdir(fPath);
    newDir = joinpath(fDir, "plot_data");
    isdir(newDir)  ||  mkpath(newDir);
    return newDir
end


## ----------  Line graph

function lines_layer(df, xVar, xLabel, yVar, yLabel, iColor)
    plt = data(df) * 
        mapping(var_label(xVar) => xLabel, var_label(yVar) => yLabel) * 
        visual(Lines; color = get_color(iColor), label = yLabel);
    return plt
end


function line_graph(df, xVar, yVar;
        xLabel = fig_label(xVar), yLabel = fig_label(yVar),
        axisOpts = default_axis_opts())

    plt = data(df) * 
        mapping(var_label(xVar) => xLabel, var_label(yVar) => yLabel) * 
        visual(Lines; color = get_color(1));

    # plt = lines_layer(df, xVar, xLabel, yVar, yLabel, 1);
    fig = render(plt; axisOpts);   
    return fig
end


"""
Line graph with multiple y variables, given by groupings in `df`
"""
function line_graph_grouped(df, xVar, yVar, colorVar;
        colorLabel = fig_label(colorVar),
        xLabel = fig_label(xVar), yLabel = fig_label(yVar),
        legendOpts = default_legend_opts(),
        axisOpts = default_axis_opts())
    colorMap = color_mapping(colorVar; colorLabel)
    plt = data(df) * 
        mapping(
            var_label(xVar) => xLabel,
            var_label(yVar) => yLabel
            ) *
        colorMap * visual(Lines);
    fig = render(plt; legendOpts, axisOpts);
    return fig
end


color_mapping(colorVar; colorLabel = fig_label(colorVar)) = 
    mapping(color = var_label(colorVar) => nonnumeric => colorLabel);
color_mapping(::Nothing; colorLabel) = mapping();


"""
Line graph with multiple y variables, given by different columns in `df`
"""
function multi_line_graph(df, xVar, xLabel, yVarV, yLabelV;
        legendOpts = default_legend_opts(),
        axisOpts = default_axis_opts())

    pltV = [lines_layer(df, xVar, xLabel, yVarV[j], yLabelV[j], j)
        for j in eachindex(yVarV)];
    fig = render(+(pltV...); legendOpts, axisOpts);   
    return fig
end


## -----------  Scatter plots

"""
Tasks:
- How to do constant marker size? If constant, it goes into Visual. If not, it goes into mapping. 
- Option to show linear regression line with std error bands
"""
function save_scatter_plot(df, xVar, yVar, ds;
        xLabel = fig_label(xVar), yLabel = fig_label(yVar),
        markerSizeVar = :mass, showRegrLine = true,
        axisOpts = default_axis_opts(), fDir = diagnostics_dir(ds))

    fig = scatter_plot(df, xVar, yVar; xLabel, yLabel, markerSizeVar,
        showRegrLine, axisOpts);

    fPath = joinpath(fDir, base_name([yVar, xVar]) * FigExtension);
    figsave(fPath, fig);
    return fPath
end

function scatter_plot(df :: AbstractDataFrame, xVar, yVar;
        xLabel = fig_label(xVar), yLabel = fig_label(yVar),
        markerSizeVar = :mass, showRegrLine = true,
        axisOpts = default_axis_opts())
    meanMass = mean(df[!, markerSizeVar]);
    df.mkSize = df[!, markerSizeVar] ./ meanMass;

    visualLayer = visual(Scatter; alpha = 0.5);
    if showRegrLine
        visualLayer += linear();
    end

    plt = data(df) * mapping(
        var_label(xVar) => xLabel,
        var_label(yVar) => yLabel;
        markersize = :mkSize
        ) * 
        visualLayer;
    fig = render(plt; axisOpts, legend = (show = false, ));
    return fig
end

function scatter_marker_size(n)
    if n < 100
        sz = 10;
    elseif n < 500
        sz = 5;
    else
        sz = 1;
    end
    return sz
end


## -----------  Bar graphs

"""
Horizontal bar graph. `barVar` is numeric and determines length of the bars.
`yVar` is categorical and generates bar labels.
"""
function horizontal_bar_graph(dfOut, barVar, yVar;
        fig = Figure(), iFig = 1,
        axisOpts = default_axis_opts())
    # Assumes categorical
    yLabelV = trim_string.(unwrap.(dfOut[!, var_label(barVar)]), 18);

    axisOptsLocal = copy(axisOpts);
    axisOptsLocal[:yticklabelsize] = 7;
    axisOptsLocal[:yticks] = (1 : nrow(dfOut), yLabelV);
    if iFig > 1
        axisOptsLocal[:yticklabelsvisible] = false;
        axisOptsLocal[:ylabelvisible] = false;
    end

    plt = data(dfOut) * 
        mapping(
            var_label(barVar) => presorted => fig_label(barVar), 
            var_label(yVar) => fig_label(yVar)) *
        visual(BarPlot; direction = :x);
        # better layout +++++
    AlgebraOfGraphics.draw!(fig[1,iFig], plt; axis = axisOptsLocal);
    return fig
end

trim_string(s :: AbstractString, maxLen) = first(s, min(maxLen, length(s)););


# ---------------