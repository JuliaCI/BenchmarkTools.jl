using BenchmarkTools
using Documenter
using DocThemeIndigo
indigo = DocThemeIndigo.install(BenchmarkTools)

makedocs(;
    modules=[BenchmarkTools],
    repo="https://github.com/JuliaCI/BenchmarkTools.jl/blob/{commit}{path}#{line}",
    sitename="BenchmarkTools.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaCI.github.io/BenchmarkTools.jl",
        assets=String[indigo],
    ),
    pages=[
        "Home" => "index.md",
        "Manual" => "manual.md",
        "Linux-based environments" => "linuxtips.md",
        "Reference" => "reference.md",
        hide("Internals" => "internals.md"),
    ],
)

deploydocs(; repo="github.com/JuliaCI/BenchmarkTools.jl")
