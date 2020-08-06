using Documenter
using FGenerators

makedocs(
    sitename = "FGenerators",
    format = Documenter.HTML(),
    modules = [FGenerators]
)

deploydocs(;
    repo = "github.com/JuliaFolds/FGenerators.jl",
    push_preview = true,
)
