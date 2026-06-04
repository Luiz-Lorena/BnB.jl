# Examples

This page collects complete usage examples for `BnB.jl`.

## BKP Example

The BKP example below solves a binary knapsack-style problem using JuMP and HiGHS for the node relaxations.

### What this example does

The BKP instance is a small binary knapsack problem:

- each item has a value `v[i]`
- each item has a weight `w[i]`
- the knapsack capacity is `W`

The goal is to maximize total value without exceeding the capacity.

```julia
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

### Step-by-step walkthrough

1. `BKPData` stores the problem data and precomputes `n`, the number of items.
2. `bkp_incumbent` builds a fast initial feasible solution by sorting items by value-to-weight ratio and greedily filling the knapsack.
3. `bkp_relaxation` solves the linear relaxation of the current node with JuMP and HiGHS, allowing fractional item values between 0 and 1.
4. The fixed variables in `node.fixed_variables` are applied as equality constraints so each branch inherits the decisions made higher in the tree.
5. `bkp_prune` decides whether a node should be discarded because it is infeasible, cannot beat the incumbent bound, or is already integral.
6. `bkp_branch_selection` picks the first fractional variable and branches on it.
7. `bkp_is_optimal_node` checks whether the node is both integral and matches the current incumbent objective.
8. `bkp_print_node` is a no-op hook, so the solver does not print per-node output.
9. `BnB.solve` ties everything together by running branch-and-bound on the sample data with the custom callbacks.

This example matches the integration test in the repository's test suite, which lives in the GitHub source tree.