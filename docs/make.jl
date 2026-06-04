using Documenter
using BnB

DocMeta.setdocmeta!(BnB, :DocTestSetup, :(using BnB); recursive=true)

makedocs(
    modules=[BnB],
    sitename="BnB.jl",
    authors="Luiz H N Lorena",
    format=Documenter.HTML(prettyurls=get(ENV, "CI", "false") == "true"),
    pages=[
        "Home" => "index.md",
        "Examples" => "examples.md",
        "API" => "api.md",
    ],
)

deploydocs(
    repo="github.com/Luiz-Lorena/BnB.jl.git",
    devbranch="main",
)
