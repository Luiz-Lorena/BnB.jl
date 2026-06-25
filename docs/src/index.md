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

Consider the Binary Knapsack Problem (BKP) using Linear Programming relaxation in each node. The BKP instance is a small binary knapsack problem:

- each item has a value `v = [8, 16, 20, 12, 6, 10, 4]`
- each item has a weight `w = [3, 7, 9, 6, 3, 5, 2]`
- the knapsack capacity is `W = 17`

The goal is to maximize total value without exceeding the capacity.

### Step 1 - Load packages

The first step is to import the necessary packages.

```julia
using BnB   # BnB Framework
using JuMP  # Modeling language
using HiGHS # Solver
```

### Step 2 - Data structure for the problem

Create a problem data type inheriting from `BnBData`

```julia
# Structure to represent the BKP data
struct BKPData <: BnB.BnBData
    v::Vector{Int64} # values
    w::Vector{Int64} # weights
    W::Int64         # capacity
    n::Int           # number of items
    # Constructor
    function BKPData(;v::Vector{Int64}, w::Vector{Int64}, W::Int64)
        return new(v, w, W, length(v))
    end
end
```

### Step 3 - Create structure to represent branch constraints

```julia
# Structure to represent the branch constraint
struct FixVariable <: BnB.BnBBranchConstraint
    i::Int64     # Variable index
    value::Int64 # Value to fix
end
```



For a complete mixed-integer example using JuMP and HiGHS, see [Examples](@ref).
