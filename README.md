# BnB.jl

<picture>
  <source media="(prefers-color-scheme: light)" srcset="assets/logo-with-text.svg">
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark-with-text.svg">
  <img alt="JuMP.jl logo." src="assets/logo-with-text-background.svg">
</picture>

---

BnB.jl is a lightweight, callback-driven branch-and-bound framework for binary optimization problems in Julia. It lets you plug in your own incumbent, relaxation, pruning, branching, and optimality checks while the package manages the search tree, node state, and solution tracking.

The package is organized around a small core API:

- `BnBData` for user-defined problem data
- `BnBNode` for individual search nodes
- `BnBCore` for the algorithm state
- `solve` as the main entry point

Optional tree visualization is available through `GraphMakie` and `CairoMakie` when `print_tree = true`.

## Install Julia

You need Julia installed before you can use `BnB.jl`.

- Windows: install Julia with `winget` or the official installer from [julialang.org](https://julialang.org/downloads/).

```powershell
winget install --id JuliaLang.Julia -e
```

- macOS: install Julia with Homebrew or the official `.dmg` from [julialang.org](https://julialang.org/downloads/).

```bash
brew install julia
```

- Linux: download the official tarball from [julialang.org](https://julialang.org/downloads/), extract it, and add `julia` to your `PATH`. On many distributions you can also use your package manager, but the official binaries are usually the simplest way to get a current version.

After installation, confirm it works:

```julia
julia --version
```

## Installation

Install the package from GitHub with Julia's package manager:

```julia
using Pkg
Pkg.add(url="https://github.com/luizhlorena/BnB.jl")
```

If you want to work on the package locally, develop it from a cloned checkout:

```julia
using Pkg
Pkg.develop(path="/path/to/BnB.jl")
```

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