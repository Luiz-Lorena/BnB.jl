```@raw html
<img class="display-dark-only" src="assets/logo-dark-with-text.svg" alt="BnB logo"/>
<img class="display-light-only" src="assets/logo-with-text.svg" alt="BnB logo"/>
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

```julia
using BnB

struct MyProblemData <: BnBData end

custom_incumbent(data::MyProblemData) = (nothing, 1.0)
custom_relaxation(node::BnBNode, data::MyProblemData) = (Dict(:x => 1.0), 1.0)
custom_prune(::BnBCore, node::BnBNode) = PrunedByIntegrality
custom_branch_selection(node::BnBNode) = nothing
custom_is_optimal_node(bnb::BnBCore, node::BnBNode) = node.relaxation == bnb.incumbent_objective
custom_print_node(::BnBNode) = nothing

solve(
    MyProblemData();
    print_tree=false,
    is_maximization=true,
    custom_incumbent=dummy_incumbent,
    custom_relaxation=dummy_relaxation,
    custom_prune=dummy_prune,
    custom_branch_selection=dummy_branch_selection,
    custom_is_optimal_node=dummy_is_optimal_node,
    custom_print_node=dummy_print_node,
)
```

For a complete mixed-integer example using JuMP and HiGHS, see [Examples](@ref).

## Package Layout

- Core algorithm in `src/core.jl`
- Core data types in `src/types.jl`
- Tree plotting in `src/visualization.jl`

## Optional Visualization

Set `print_tree=true` in `solve` to render the search tree with GraphMakie/CairoMakie.
