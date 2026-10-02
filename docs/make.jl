using Pkg
Pkg.activate(@__DIR__)

using Documenter
using DoECISORY

DocMeta.setdocmeta!(DoECISORY, :DocTestSetup, :(using DoECISORY); recursive=true)

makedocs_kwargs = Dict{Symbol, Any}(
    :sitename => "DoECISORY.jl",
    :modules => [DoECISORY],
    :authors => "Eren Selim GÖL, MPharm",
    :format => Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://erensgol.github.io/DoECISORY.jl",
        edit_link = "main",
        assets = String[]
    ),
    :pages => [
        "Overview"                => "index.md",
        "Methodology"             => "methodology.md",
        "Graphical Guide"         => "interface.md",
        "Scripting Guide"         => "scripting.md",
        "Case Study"              => "tutorial.md",
        "Statistics"              => "statistics.md",
        "Visualisations"          => "visuals.md",
        "API Reference"           => "api.md",
        "Citation"                => "citation.md"
    ],
    :checkdocs => :exports,
    :warnonly => true
)

if get(ENV, "CI", "false") != "true"
    makedocs_kwargs[:remotes] = nothing
end

makedocs(; makedocs_kwargs...)

deploydocs(
    repo = "github.com/erensgol/DoECISORY.jl.git",
    devbranch = "main",
    push_preview = true
)
