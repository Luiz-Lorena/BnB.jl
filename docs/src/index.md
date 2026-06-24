```@raw html
<div style="text-align: center;">
    <img class="display-dark-only"
         src="assets/logo-dark-with-text.svg"
         alt="BnB logo"/>
    <img class="display-light-only"
         src="assets/logo-with-text.svg"
         alt="BnB logo"/>
</div>
```

# Introduction

`BnB.jl` provides a customizable branch-and-bound framework for binary decision problems.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/Luiz-Lorena/BnB.jl")
```

## Quick Start

The solver is generic: you provide problem-specific callbacks.



For a complete mixed-integer example using JuMP and HiGHS, see [Examples](@ref).

## Package Layout

- Core algorithm in `src/core.jl`
- Core data types in `src/types.jl`
- Tree plotting in `src/visualization.jl`

## Optional Visualization

Set `print_tree=true` in `solve` to render the search tree with GraphMakie/CairoMakie.
