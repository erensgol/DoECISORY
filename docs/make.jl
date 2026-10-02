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
        "Home" => "index.md",
        "Workflow Manual" => "manual.md",
        "API Reference" => "api.md",
        "Licence & Citation" => "licence.md"
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
