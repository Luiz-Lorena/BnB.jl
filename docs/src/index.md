# BnB.jl

`BnB.jl` provides a customizable branch-and-bound framework for binary decision problems.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/luizhlorena/BnB.jl")
```

## Quick Start

The solver is generic: you provide problem-specific callbacks.

```julia
using BnB

struct DummyData <: BnBData end

dummy_incumbent(::DummyData) = (nothing, 1.0)
dummy_relaxation(::BnBNode, ::DummyData) = (Dict(:x => 1.0), 1.0)
dummy_prune(::BnBCore, ::BnBNode) = PrunedByIntegrality
dummy_branch_selection(::BnBNode) = nothing
dummy_is_optimal_node(bnb::BnBCore, node::BnBNode) = node.relaxation == bnb.incumbent_objective
dummy_print_node(::BnBNode) = nothing

solve(
    DummyData();
    print_tree=false,
    sense=Max,
    custom_incumbent=dummy_incumbent,
    custom_relaxation=dummy_relaxation,
    custom_prune=dummy_prune,
    custom_branch_selection=dummy_branch_selection,
    custom_is_optimal_node=dummy_is_optimal_node,
    custom_print_node=dummy_print_node,
)
```

## Package Layout

- Core algorithm in `src/core.jl`
- Core data types in `src/types.jl`
- Tree plotting in `src/visualization.jl`

## Optional Visualization

Set `print_tree=true` in `solve` to render the search tree with GraphMakie/CairoMakie.
