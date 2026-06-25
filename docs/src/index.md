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

`BnB.jl` provides a generic Branch-and-Bound framework for Julia.

It provides the search-tree management, node selection strategies,
visualization, and bookkeeping required for branch-and-bound algorithms.
Users only need to implement problem-specific callbacks:

- Initial incumbent generation
- Relaxation solver
- Pruning logic
- Branching logic
- Optimality detection

The framework can be used for problems such as:

- Binary Knapsack
- Set Covering
- Vehicle Routing
- Integer Programming
- Column Generation + Branch-and-Price
- Branch-and-Cut

---

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/yourname/BnB.jl")
```

## Quick Start

To use the framework:

1. Create a problem data type inheriting from BnBData
2. Create a branching constraint type inheriting from BnBBranchConstraint
3. Implement the required callbacks
    - a. `custom_incumbent`: create initial incumbent generation 
    - b. `custom_relaxation`: solve the relaxation 
    - c. `custom_prune`: check pruning logic
    - d. `custom_branch`: create branches
    - e. `custom_is_optimal_solution`: utility to check for optimal solutions
4. Call solve(...)

For a complete mixed-integer example using JuMP and HiGHS, see [Examples](@ref).
