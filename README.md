# BnB.jl

## Documentation

This package uses `Documenter.jl`.

Build docs locally from the repository root with:

```julia
julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

## Testing

Run the package tests from the repository root with:

```julia
julia --project=. -e 'using Pkg; Pkg.test()'
```

To run a knapsack-style integration test with JuMP and HiGHS (same pattern as your example), use:

```julia
julia --project=. -e 'using Pkg; Pkg.test()'
```

The BKP integration test is in [test/bkp_test.jl](test/bkp_test.jl).

## Optional Visualization

Tree plotting is optional and loaded only when `print_tree = true`. To enable it in your current environment, install:

```julia
using Pkg
Pkg.add(["Colors", "CairoMakie", "GraphMakie", "NetworkLayout"])
```

## Manifest Policy

This repository is a package, so `Manifest.toml` is intentionally not tracked (it is ignored in [.gitignore](.gitignore)).