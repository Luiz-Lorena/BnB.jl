# Examples

This page collects complete usage examples for `BnB.jl`.

## BKP Example

The BKP example below solves a binary knapsack-style problem using JuMP and HiGHS for the node relaxations.

### What this example does

The BKP instance is a small binary knapsack problem:

- each item has a value `v = 4, 2, 10, 2, 1`
- each item has a weight `w = [12, 2, 4, 1, 1]`
- the knapsack capacity is `W = 14`

The goal is to maximize total value without exceeding the capacity.

```julia
using BnB   # Branch-and-Bound framework
using JuMP  # Modeling language
using HiGHS # Solver

# Structure to represent the knapsack problem data
struct BKPData <: BnB.BnBData
    v::Vector{Int64} # profits / values
    w::Vector{Int64} # weights
    W::Int64         # capacity
    n::Int           # number of items
    # Constructor
    function BKPData(;v::Vector{Int64}, w::Vector{Int64}, W::Int64)
        return new(v, w, W, length(v))
    end
end

# Function to find an initial incumbent solution using a greedy heuristic based on value-to-weight ratio
function bkp_incumbent(data::BKPData)
    # Value-to-weight ratios
    ratios = data.v ./ data.w
    # Sort items by decreasing ratio
    order = sortperm(ratios, rev=true)
    # Initialize solution vector
    solution = zeros(Int, data.n)
    # Greedy filling based on sorted order
    remaining_capacity = data.W
    incumbent_objective = 0.0
    for i in order
        if data.w[i] <= remaining_capacity
            solution[i] = 1
            remaining_capacity -= data.w[i]
            incumbent_objective += data.v[i]
        end
    end
    println("-"^30)
    println("Solved initial incumbent solution (LB) using greedy heuristic.")
    println("Incumbent solution: ", solution)
    println("Incumbent objective: ", incumbent_objective)
    return solution, incumbent_objective
end

# Function to solve the LP relaxation of the BKP for a given node
function bkp_relaxation(node::BnB.BnBNode, data::BKPData)
    model = JuMP.Model(HiGHS.Optimizer)
    JuMP.set_silent(model)
    @variable(model, 0 <= x[i in 1:data.n] <= 1)
    @objective(model, Max, sum(data.v[i] * x[i] for i in 1:data.n))
    @constraint(model, sum(data.w[i] * x[i] for i in 1:data.n) <= data.W)
    # Add constraints for fixed variables
    for (var_key, value) in node.fixed_variables
        @constraint(model, x[var_key] == value)
    end
    JuMP.optimize!(model)
    if termination_status(model) == JuMP.OPTIMAL
        return JuMP.value.(x), JuMP.objective_value(model)
    else
        return nothing, nothing
    end
end

# Function to check pruning conditions for a given node and update its status accordingly
function bkp_prune(bnb::BnB.BnBCore, node::BnB.BnBNode)
    # 1. Prune by Infeasibility
    if isnothing(node.solution)
        return BnB.PrunedByInfeasibility
    end
    # 2. Prune by Integrality
    if !any(x -> 1e-5 < x < (1 - 1e-5), node.solution)
        return BnB.PrunedByIntegrality
    end
    # 3. Prune by Bound
    if node.relaxation <= bnb.incumbent_objective
        return BnB.PrunedByBound
    end
end

# Function to select the variable for branching based on the first fractional variable in the solution
function bkp_branch_selection(node::BnB.BnBNode)
    # Find the first variable that is fractional in the solution
    branch_id = findfirst(x -> 1e-5 < x < (1 - 1e-5), node.solution)
    return branch_id
end

# Function to determine if a node is optimal by checking if it has an integral solution and if its relaxation value matches the incumbent objective value
function bkp_is_optimal_node(bnb::BnB.BnBCore, node::BnB.BnBNode)
    # Check if the node has a valid solution
    if isnothing(node.solution)
        return false
    end
    # Check if the solution is integral
    is_integral = !any(x -> 1e-5 < x < (1 - 1e-5), node.solution)
    # Check if the relaxation value matches the best incumbent objective value within a tolerance
    is_optimal = isapprox(node.relaxation, bnb.incumbent_objective; atol=1e-6)
    # A node is considered optimal if it has an integral solution and its relaxation value matches the incumbent objective value
    if is_integral && is_optimal
        return true
    end
    return false
end

# Function to print the details of a node in the branch-and-bound tree
function bkp_print_node(node::BnB.BnBNode)
    println("-"^30)
    println("Node ID: ", node.id)
    println("Solution: ", node.solution)
    println("Relaxation value: ", node.relaxation)
    println("Incumbent value: ", node.incumbent)
    println("Status: ", node.status)
end

# Example
data = BKPData(
    v = [4, 2, 10, 2, 1],
    w = [12, 2, 4, 1, 1],
    W = 15
)

# Define plot options for this example
custom_plot_options = BnB.BnBPlotOptions(
    figure_size = (750, 400),
    node_size = (130, 90),
    node_label_size = 14,
    edge_label_size = 14,
    show_legend = true,
    legend_position = :bottom
)

# Solve the BKP using the BnB framework
solution = BnB.solve(data,
                     is_maximization = true,
                     search_strategy = :best_bound,
                     custom_incumbent = bkp_incumbent,
                     custom_relaxation = bkp_relaxation,        
                     custom_prune = bkp_prune,
                     custom_branch_selection = bkp_branch_selection,
                     custom_is_optimal_node = bkp_is_optimal_node,
                     custom_print_node = bkp_print_node,
                     print_tree = true,
                     custom_plot_options = custom_plot_options)

# Print the final results
println("="^15, " Results ", "="^15)
println("Best solution found: ", solution.solution)
println("Best objective value: ", solution.objective)
println("Best nodes ID: ", solution.optimal_nodes)
println("Total nodes explored: ", solution.total_nodes)
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