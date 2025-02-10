using Underemployment
using Documenter

DocMeta.setdocmeta!(Underemployment, :DocTestSetup, :(using Underemployment); recursive=true)

makedocs(;
    modules=[Underemployment],
    authors="hendri54 <hendricksl@protonmail.com> and contributors",
    sitename="Underemployment.jl",
    format=Documenter.HTML(;
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
