# BnB.jl

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="assets/logo-with-text.svg">
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark-with-text.svg">
    <img alt="JuMP.jl logo." src="assets/logo-with-text-background.svg">
  </picture>
</p>

<p align="center">
  <a href="https://luiz-lorena.github.io/BnB.jl/">
    <img alt="Documentation" src="https://img.shields.io/badge/docs-GitHub%20Pages-blue?style=flat-square">
  </a>
</p>

---

BnB.jl is a lightweight, callback-driven branch-and-bound framework for binary optimization problems in Julia. It lets you plug in your own incumbent, relaxation, pruning, branching, and optimality checks while the package manages the search tree, node state, and solution tracking.

The package is organized around a small core API:

- `BnBData` for user-defined problem data
- `BnBNode` for individual search nodes
- `BnBCore` for the algorithm state
- `solve` as the main entry point

Optional tree visualization is available through `GraphMakie` and `CairoMakie` when `print_tree = true`.

## Installation

Install the package from GitHub with Julia's package manager:

```julia
using Pkg
Pkg.add(url="https://github.com/Luiz-Lorena/BnB.jl")
```

## BKP Example

This BKP example solves a binary knapsack problem with custom branch-and-bound callbacks.

```julia
using BnB
using JuMP
using HiGHS

struct BKPData <: BnB.BnBData
  v::Vector{Int64}
  w::Vector{Int64}
  W::Int64
  n::Int

  function BKPData(; v::Vector{Int64}, w::Vector{Int64}, W::Int64)
    return new(v, w, W, length(v))
  end
end

function bkp_incumbent(data::BKPData)
  ratios = data.v ./ data.w
  order = sortperm(ratios, rev = true)

  solution = zeros(Int, data.n)
  remaining_capacity = data.W
  incumbent_objective = 0.0

  for i in order
    if data.w[i] <= remaining_capacity
      solution[i] = 1
      remaining_capacity -= data.w[i]
      incumbent_objective += data.v[i]
    end
  end

  return solution, incumbent_objective
end

function bkp_relaxation(node::BnB.BnBNode, data::BKPData)
  model = JuMP.Model(HiGHS.Optimizer)
  JuMP.set_silent(model)

  @variable(model, 0 <= x[i in 1:data.n] <= 1)
  @objective(model, Max, sum(data.v[i] * x[i] for i in 1:data.n))
  @constraint(model, sum(data.w[i] * x[i] for i in 1:data.n) <= data.W)

  for (var_key, value) in node.fixed_variables
    @constraint(model, x[var_key] == value)
  end

  JuMP.optimize!(model)

  if termination_status(model) == JuMP.OPTIMAL
    return JuMP.value.(x), JuMP.objective_value(model)
  end

  return nothing, nothing
end

function bkp_prune(bnb::BnB.BnBCore, node::BnB.BnBNode)
  if isnothing(node.solution)
    return BnB.PrunedByInfeasibility
  end

  if node.relaxation <= bnb.incumbent_objective
    return BnB.PrunedByBound
  end

  if !any(x -> 1e-5 < x < (1 - 1e-5), node.solution)
    return BnB.PrunedByIntegrality
  end

  return BnB.Active
end

function bkp_branch_selection(node::BnB.BnBNode)
  return findfirst(x -> 1e-5 < x < (1 - 1e-5), node.solution)
end

function bkp_is_optimal_node(bnb::BnB.BnBCore, node::BnB.BnBNode)
  if isnothing(node.solution)
    return false
  end

  is_integral = !any(x -> 1e-5 < x < (1 - 1e-5), node.solution)
  is_optimal = isapprox(node.relaxation, bnb.incumbent_objective; atol = 1e-6)

  return is_integral && is_optimal
end

bkp_print_node(::BnB.BnBNode) = nothing

data = BKPData(
  v = [4, 2, 10, 2, 1],
  w = [12, 2, 4, 1, 1],
  W = 15,
)

BnB.solve(
  data;
  print_tree = false,
  sense = BnB.Max,
  custom_incumbent = bkp_incumbent,
  custom_relaxation = bkp_relaxation,
  custom_prune = bkp_prune,
  custom_branch_selection = bkp_branch_selection,
  custom_is_optimal_node = bkp_is_optimal_node,
  custom_print_node = bkp_print_node,
)
```

For a step-by-step walkthrough, see the Examples page in the documentation: https://luiz-lorena.github.io/BnB.jl/examples/