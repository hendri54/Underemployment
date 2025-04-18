@testitem "Figure options" begin
    using Underemployment, Test, TestItems;
    opts = Underemployment.default_legend_opts();
    Underemployment.set_fig_opt!(opts, :position, :new);
    @test opts[:position] == :new;  
end

@testitem "Line graph" begin
    using Underemployment, Test, TestItems;
    ds = data_settings(:default);
    fPath = joinpath(Underemployment.test_dir(ds), "line_graph.pdf");
    isfile(fPath)  &&  rm(fPath);
    df = (x = [1,2,3], y = [3.0, 2.7, 3.3]);
    fig = Underemployment.line_graph(df, :x, :y; xLabel = "x variable");
    Underemployment.figsave(fPath, fig);
    @test isfile(fPath);
end

@testitem "Line graph grouped" begin
    using Underemployment, Test, DataFrames;
    ds = data_settings(:default);
    x = 1:3;
    y = ["y1", "y2"];
    df = Underemployment.all_combinations(x, y);
    df.z = 0.5 .* df.x .+ LinRange(0.0, 0.2, length(df.x));
    fig = Underemployment.line_graph_grouped(df, :x, :z, :y;
        xLabel = "x var", yLabel = "z var");
    fPath = joinpath(test_dir(ds), "line_graph_grouped.pdf");
    isfile(fPath)  &&  rm(fPath);
    Underemployment.figsave(fPath, fig);
    @test isfile(fPath);
end

@testitem "Multi line graph" begin
    using DataFrames, Random;
    using AlgebraOfGraphics;
    using Test, Underemployment;
    ds = data_settings(:default);
    
    # Create a test dataframe
    df = DataFrame(
        x = 1:10,
        y1 = rand(10),
        y2 = rand(10)
        );
    
    fig = Underemployment.multi_line_graph(df, 
        :x, "X", [:y1, :y2], ["Y1", "Y2"]);
    @test fig isa AlgebraOfGraphics.FigureGrid;
    fPath = joinpath(test_dir(ds), "multi_line_graph.pdf");
    isfile(fPath)  &&  rm(fPath);
    Underemployment.figsave(fPath, fig);
    @test isfile(fPath);
end

@testitem "Scatter plot" begin
    using DataFrames, Random, Underemployment, Test, TestItems;
    ds = data_settings(:default);
    rng = Xoshiro(54);
    df = DataFrame(x = 1 : 10, y = (1 : 10) .+ randn(rng, 10) .* 0.2, 
        mass = rand(rng, 10));
    fig = Underemployment.scatter_plot(df, :x, :y);
    fPath = joinpath(test_dir(ds), "scatter_plot.pdf");
    isfile(fPath)  &&  rm(fPath);
    Underemployment.figsave(fPath, fig);
    @test isfile(fPath);
end

@testitem "Horizontal bar graph" begin
    using CategoricalArrays, DataFrames, Random;
    using Underemployment, Test, TestItems;
    ds = data_settings(:default);
    rng = Xoshiro(54);
    barVar = categorical(["Label $j" for j = 1 : 10]);
    df = DataFrame(x = barVar, y = (1 : 10) .+ randn(rng, 10) .* 0.2);
    fig = Underemployment.horizontal_bar_graph(df, :x, :y);
    fPath = joinpath(test_dir(ds), "horizontal_bar.pdf");
    isfile(fPath)  &&  rm(fPath);
    Underemployment.figsave(fPath, fig);
    @test isfile(fPath);
end


# -------------------