# Examples

This page collects complete usage examples for `BnB.jl`.

## Example 1: Binary Knapsack Problem

The following example solves the Binary Knapsack Problem (BKP) using Linear Programming relaxation in each node.

### What this example does

The BKP instance is a small binary knapsack problem:

- each item has a value `v = [4, 2, 10, 2, 1]`
- each item has a weight `w = [12, 2, 4, 1, 1]`
- the knapsack capacity is `W = 14`

The goal is to maximize total value without exceeding the capacity.

```julia
using BnB   # Branch-and-Bound framework
using JuMP  # Modeling language
using HiGHS # Solver

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

# Structure to represent the branch constraint
struct FixVariable <: BnB.BnBBranchConstraint
    i::Int64     # Variable index
    value::Int64 # Value to fix
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
    return BnB.BnBSolution(solution=solution, objective=incumbent_objective)
end

# Function to solve the LP relaxation of the BKP for a given node
function bkp_relaxation(node::BnB.BnBNode, bnb::BnBCore)
    model = JuMP.Model(HiGHS.Optimizer)
    JuMP.set_silent(model)
    @variable(model, 0 <= x[i in 1:bnb.data.n] <= 1)
    @objective(model, Max, sum(bnb.data.v[i] * x[i] for i in 1:bnb.data.n))
    @constraint(model, sum(bnb.data.w[i] * x[i] for i in 1:bnb.data.n) <= bnb.data.W)
    # Add constraints for fixed variables
    for branch in node.branch_constraints
        @constraint(model, x[branch.i] == branch.value)
    end
    JuMP.optimize!(model)
    if JuMP.termination_status(model) == JuMP.OPTIMAL
        return BnB.BnBSolution(solution=JuMP.value.(x), objective=JuMP.objective_value(model))
    end
end

# Function to check pruning conditions for a given node and update its status accordingly
function bkp_prune(node::BnB.BnBNode, bnb::BnBCore)
    # 1. Prune by Infeasibility
    if isnothing(node.relaxation.solution)
        return BnB.PrunedByInfeasibility
    end
    # 2. Prune by Integrality
    if !any(x -> 1e-5 < x < (1 - 1e-5), node.relaxation.solution)
        return BnB.PrunedByIntegrality
    end
    # 3. Prune by Bound
    if node.relaxation.objective <= bnb.incumbent.objective
        return BnB.PrunedByBound
    end
    return BnB.Active
end

# Function to select the branches and the values to fix for a given node
function bkp_branch(node::BnB.BnBNode, bnb::BnB.BnBCore)
    # Create two branches: one excluding the edge and one including the edge
    branch_constraints = Vector{BnB.BnBBranchConstraint}()
    # Find all fractional variables in the solution
    fractional_variables = findall(x -> 1e-5 < x < (1 - 1e-5), node.relaxation.solution)
    # Create branches
    for var in fractional_variables
        left_branch = FixVariable(var, 0)
        right_branch = FixVariable(var, 1)
        # Check if the variable is already fixed to 0.0 in the current node
        if left_branch in node.branch_constraints || right_branch in node.branch_constraints
            continue
        end
        push!(branch_constraints, left_branch)  # Left branch: exclude the item
        push!(branch_constraints, right_branch) # Right branch: include the item
        return branch_constraints
    end
end

# Function to determine if a node contains an optimal solution
function bkp_is_optimal_solution(node::BnB.BnBNode, bnb::BnBCore)
    # Check if the node has a valid solution
    if isnothing(node.relaxation.solution)
        return false
    end
    # Check if the solution is integral (i.e., all variables are either 0 or 1)
    is_integral = !any(x -> 1e-5 < x < (1 - 1e-5), node.relaxation.solution)
    # Check if the relaxation value matches the best incumbent objective value within a tolerance
    is_optimal = isapprox(node.relaxation.objective, bnb.incumbent.objective; atol=1e-6)
    # It is optimal if it has an integral solution and its relaxation value matches the incumbent objective value
    if is_integral && is_optimal
        return true
    end
    return false
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
    legend_position = :bottom,
    branch_label = (branch::FixVariable) -> "x[$(branch.i)] = $(branch.value)"
)

# Solve the BKP using the BnB framework
solution = BnB.solve(data,
                     is_maximization = true,
                     custom_incumbent = bkp_incumbent,
                     custom_relaxation = bkp_relaxation,        
                     custom_prune = bkp_prune,
                     custom_branch = bkp_branch,
                     custom_is_optimal_solution = bkp_is_optimal_solution,
                     custom_plot_options = custom_plot_options)
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

## Example 2: Travelling Salesman Problem

The following example solves the Travelling Salesman Problem (TSP) using Linear Programming relaxation in each node.

### What this example does

The TSP instance file is composed by 7 cities:

```math
coordinates = \begin{bmatrix}
-23.2018 & -45.9000 \\
-23.1980 & -45.8925 \\
-23.1985 & -45.9010 \\
-23.2040 & -45.8950 \\
-23.2030 & -45.9025 \\
-23.2039 & -45.8995 \\
-23.1995 & -45.8998
\end{bmatrix}
```

![TSP instance](assets/TSP.png)

The goal is to find the shortest possible route that allows a traveler to visit a set of cities exactly once and return to the starting city.

```julia
using BnB       # Branch-and-Bound framework
using JuMP      # Modeling language
using HiGHS     # Solver
using CSV       # Data handling
using Distances # Distance computations

# Structure to represent the TSP data
struct TSPData <: BnB.BnBData
    coordinates::Matrix{Float64}     # City coordinates
    distance_matrix::Matrix{Float64} # Precomputed distance matrix
    n::Int                           # Number of cities
    # Constructor
    function TSPData(;file_path::String)
        coordinates = CSV.read(file_path, CSV.Tables.matrix, header=false)
        distance_matrix = Distances.pairwise(Distances.Haversine(), coordinates, dims=1)
        return new(coordinates, distance_matrix, size(coordinates, 1))
    end
end

# Structure to represent the branch constraint
struct FixVariable <: BnB.BnBBranchConstraint
    i::Int64     # Variable index i 
    j::Int64     # Variable index j
    value::Int64 # Value to fix
end

# Function to find an initial incumbent solution using the Nearest Neighbor heuristic
function tsp_incumbent(data::TSPData)
    visited = falses(data.n)
    solution = zeros(Int, data.n)
    # Start from the first city
    current_city = 1
    solution[1] = current_city
    visited[current_city] = true
    incumbent_objective = 0.0
    for k in 2:data.n
        # Find the nearest unvisited city
        next_city = argmin([visited[j] ? Inf : data.distance_matrix[current_city, j] for j in 1:data.n])
        solution[k] = next_city
        visited[next_city] = true
        incumbent_objective += data.distance_matrix[current_city, next_city]
        current_city = next_city
    end
    # Add the distance to return to the starting city
    incumbent_objective += data.distance_matrix[current_city, solution[1]]
    return BnB.BnBSolution(solution=solution, objective=incumbent_objective)
end

# Function to solve the LP relaxation of the TSP for a given node
function tsp_relaxation(node::BnB.BnBNode, bnb::BnBCore)
    model = JuMP.Model(HiGHS.Optimizer)
    JuMP.set_silent(model)
    @variable(model, x[i in 1:bnb.data.n, j in 1:bnb.data.n], Bin)
    @objective(model, Min, sum(bnb.data.distance_matrix[i, j] * x[i, j] for i in 1:bnb.data.n, j in 1:bnb.data.n))
    @constraint(model, [i in 1:bnb.data.n], x[i, i] == 0)
    @constraint(model, [j in 1:bnb.data.n], sum(x[i, j] for i in 1:bnb.data.n) == 1)
    @constraint(model, [i in 1:bnb.data.n], sum(x[i, j] for j in 1:bnb.data.n) == 1)
    # Add constraints for fixed variables
    for branch in node.branch_constraints
        @constraint(model, x[branch.i, branch.j] == branch.value)
    end
    JuMP.optimize!(model)
    if JuMP.termination_status(model) == JuMP.OPTIMAL
        # Extract the routes from the solution
        x_val = JuMP.value.(x)
        # Identify cycles in the solution to check for integrality and to identify subtours
        visited = fill(false, bnb.data.n)
        cycles = Vector{Vector{Int}}()
        for start in 1:bnb.data.n
            if !visited[start]
                cycle = Int[start]
                visited[start] = true
                nxt = findfirst(x_val[start, :] .> 0.5)
                while nxt !== nothing && !visited[nxt]
                    push!(cycle, nxt)
                    visited[nxt] = true
                    nxt = findfirst(x_val[nxt, :] .> 0.5)
                end
                push!(cycles, cycle)
            end
        end
        # return cycles, JuMP.objective_value(model)
        return BnB.BnBSolution(solution=cycles, objective=JuMP.objective_value(model))
    end
end

# Function to check pruning conditions for a given node and update its status accordingly
function tsp_prune(node::BnB.BnBNode, bnb::BnB.BnBCore)
    # 1. Prune by Infeasibility
    if isnothing(node.relaxation.objective)
        return BnB.PrunedByInfeasibility
    end
    # 2. Prune by Integrality
    if length(node.relaxation.solution) == 1
        return BnB.PrunedByIntegrality
    end
    # 3. Prune by Bound
    if node.relaxation.objective >= bnb.incumbent.objective
        return BnB.PrunedByBound
    end
    return BnB.Active
end

# Function to select the branches and the values to fix for a given node
function tsp_branch(node::BnB.BnBNode, bnb::BnB.BnBCore)
    # Create two branches: one excluding the edge and one including the edge
    branch_constraints = Vector{BnB.BnBBranchConstraint}()
    # Sort cycles by length to prioritize branching on the smallest subtour
    subtours = sort(node.relaxation.solution, by=length)
    # Select the first edge of the smallest subtour for branching
    for subtour in subtours
        # Iterate through the edges of the subtour and find the first edge that is not already fixed to 0.0 in the current node
        for i in 1:(length(subtour) - 1)
            left_branch = FixVariable(subtour[i], subtour[i+1], 0)
            right_branch = FixVariable(subtour[i+1], subtour[i], 0)
            # Check if the edge is already fixed to 0 in the current node
            if left_branch in node.branch_constraints || right_branch in node.branch_constraints
                continue
            end
            push!(branch_constraints, left_branch)  # Left branch: exclude the edge
            push!(branch_constraints, right_branch) # Right branch: exclude the reverse edge
            return branch_constraints
        end
    end
end

# Function to determine if a node contains an optimal solution
function tsp_is_optimal_solution(node::BnB.BnBNode, bnb::BnB.BnBCore)
    # Check if the node has a valid solution
    if isnothing(node.relaxation.solution)
        return false
    end
    # Check if the solution is integral (i.e., forms a single cycle)
    is_integral = length(node.relaxation.solution) == 1
    # Check if the relaxation value matches the best incumbent objective value within a tolerance
    is_optimal = isapprox(node.relaxation.objective, bnb.incumbent.objective; atol=1e-6)
    # A node is considered optimal if it has an integral solution and its relaxation value matches the incumbent objective value
    if is_integral && is_optimal
        return true
    end
    return false
end

# Example
data = TSPData(file_path="data/tsp_instance.csv")

# Define plot options for this example
custom_plot_options = BnB.BnBPlotOptions(
    figure_size = (750, 400),
    node_size = (140, 90),
    node_label_size = 14,
    edge_label_size = 14,
    show_legend = true,
    legend_position = :bottom,
    branch_label = (branch::FixVariable) -> "x[$(branch.i),$(branch.j)] = $(branch.value)"
)

# Solve the TSP using the BnB framework
solution = BnB.solve(data,
                     is_maximization = false,
                     custom_incumbent = tsp_incumbent,
                     custom_relaxation = tsp_relaxation,        
                     custom_prune = tsp_prune,
                     custom_branch = tsp_branch,
                     custom_is_optimal_solution = tsp_is_optimal_solution,
                     custom_plot_options = custom_plot_options)
```

## Example 3: Maximum Independent Set Problem

The following example solves the Maximum Independent Set Problem (MISP) using Linear Programming relaxation in each node of the BnB tree.

```@raw html
<img src="assets/MISP.png" alt="MISP instance"/>
```

### What this example does

The MISP instance is a graph: 

$$
A = \begin{bmatrix}
0 & 1 & 0 & 0 & 0 & 1 & 0 & 1 & 1 & 0 & 0 & 1 \\
1 & 0 & 1 & 0 & 0 & 1 & 1 & 0 & 1 & 0 & 0 & 0 \\
0 & 1 & 0 & 1 & 0 & 0 & 1 & 0 & 1 & 1 & 0 & 0 \\
0 & 0 & 1 & 0 & 1 & 0 & 1 & 0 & 0 & 1 & 1 & 0 \\
0 & 0 & 0 & 1 & 0 & 1 & 1 & 0 & 0 & 0 & 1 & 1 \\
1 & 1 & 0 & 0 & 1 & 0 & 1 & 0 & 0 & 0 & 0 & 1 \\
0 & 1 & 1 & 1 & 1 & 1 & 0 & 0 & 0 & 0 & 0 & 0 \\
1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 & 1 & 1 & 1 \\
1 & 1 & 1 & 0 & 0 & 0 & 0 & 1 & 0 & 1 & 0 & 0 \\
0 & 0 & 1 & 1 & 0 & 0 & 0 & 1 & 1 & 0 & 1 & 0 \\
0 & 0 & 0 & 1 & 1 & 0 & 0 & 1 & 0 & 1 & 0 & 1 \\
1 & 0 & 0 & 0 & 1 & 1 & 0 & 1 & 0 & 0 & 1 & 0
\end{bmatrix}
$$

The goal is to find the largest possible independent set (maximum cardinality) in the graph.

```julia
using BnB    # Branch-and-Bound framework
using JuMP   # Modeling language
using HiGHS  # Solver
using Graphs # Graphs package

# Structure to represent the MISP data
struct MISPData <: BnB.BnBData
    graph::Graphs.SimpleGraph # Graph structure
    n::Int64                  # Number of vertices
    m::Int64                  # Number of edges
    # Constructor
    function MISPData(graph::Graphs.SimpleGraph)
        n = Graphs.nv(graph)
        m = Graphs.ne(graph)
        return new(graph, n, m)
    end
end

# Structure to represent the branch constraint
struct FixVariable <: BnB.BnBBranchConstraint
    v::Int64     # Variable index
    value::Int64 # Value to fix
end

# Function to find an initial incumbent solution using a greedy heuristic
function misp_incumbent(data::MISPData)
    graph = data.graph
    n = data.n
    # Initialize the independent set and a set to track selected vertices
    independent_set = Set{Int}()
    selected = falses(n)
    # Iterate over vertices in order of degree (lowest degree first)
    for v in sort(1:n, by=v -> Graphs.degree(graph, v))
        if !selected[v]
            push!(independent_set, v)
            selected[v] = true
            # Mark neighbors as selected to prevent their inclusion
            for neighbor in Graphs.neighbors(graph, v)
                selected[neighbor] = true
            end
        end
    end
    return BnB.BnBSolution(solution=independent_set, objective=length(independent_set))
end

# Function to solve the LP relaxation of the MISP for a given node
function misp_relaxation(node::BnB.BnBNode, bnb::BnBCore)
    # Create the model
    model = JuMP.Model(HiGHS.Optimizer)
    # Silent mode (solver output is not printed)
    JuMP.set_silent(model)
    # Define the decision variables
    @variable(model, 0 <= x[v in 1:bnb.data.n] <= 1)
    # Objective function: maximize the total of selected vertices
    @objective(model, Max, sum(x[v] for v in 1:bnb.data.n))
    # Independence constraint
    for e in Graphs.edges(bnb.data.graph)
        @constraint(model, x[e.src] + x[e.dst] <= 1)
    end
    # Add constraints for fixed variables
    for branch in node.branch_constraints
        @constraint(model, x[branch.v] == branch.value)
    end
    # Run the solver
    JuMP.optimize!(model)
    if JuMP.termination_status(model) == JuMP.OPTIMAL
        return BnB.BnBSolution(solution=JuMP.value.(x), objective=JuMP.objective_value(model))
    end
end

# Function to check pruning conditions for a given node and update its status accordingly
function misp_prune(node::BnB.BnBNode, bnb::BnB.BnBCore)
    # 1. Prune by Infeasibility
    if isnothing(node.relaxation.solution)
        return BnB.PrunedByInfeasibility
    end
    # 2. Prune by Integrality
    if !any(x -> 1e-5 < x < (1 - 1e-5), node.relaxation.solution)
        return BnB.PrunedByIntegrality
    end
    # 3. Prune by Bound
    if node.relaxation.objective <= bnb.incumbent.objective
        return BnB.PrunedByBound
    end
    return BnB.Active
end

# Function to select the branches and the values to fix for a given node
function misp_branch(node::BnB.BnBNode, bnb::BnB.BnBCore)
    # Create two branches: one excluding the edge and one including the edge
    branch_constraints = Vector{BnB.BnBBranchConstraint}()
    # Find all fractional variables in the solution
    fractional_variables = findall(x -> 1e-5 < x < (1 - 1e-5), node.relaxation.solution)
    # Create branches
    for var in fractional_variables
        left_branch = FixVariable(var, 0)
        right_branch = FixVariable(var, 1)
        # Check if the variable is already fixed in the current node
        if left_branch in node.branch_constraints || right_branch in node.branch_constraints
            continue
        end
        push!(branch_constraints, left_branch)  # Left branch: exclude the vertice
        push!(branch_constraints, right_branch) # Right branch: include the vertice
        return branch_constraints
    end
end

# Function to determine if a node is optimal by checking if it has an integral solution and if its relaxation value matches the incumbent objective value
function misp_is_optimal_solution(node::BnB.BnBNode, bnb::BnB.BnBCore)
    # Check if the node has a valid solution
    if isnothing(node.relaxation.solution)
        return false
    end
    # Check if the solution is integral (i.e., all variables are either 0 or 1)
    is_integral = !any(x -> 1e-5 < x < (1 - 1e-5), node.relaxation.solution)
    # Check if the relaxation value matches the best incumbent objective value within a tolerance
    is_optimal = isapprox(node.relaxation.objective, bnb.incumbent.objective; atol=1e-6)
    # It is optimal if it has an integral solution and its relaxation value matches the incumbent objective value
    if is_integral && is_optimal
        return true
    end
    return false
end

# Example
graph = Graphs.smallgraph("icosahedral")
data = MISPData(graph)

# Define plot options for this example
custom_plot_options = BnB.BnBPlotOptions(
    figure_size = (950, 950),
    node_size = (95, 90),
    node_label_size = 14,
    edge_label_size = 14,
    show_legend = true,
    legend_position = :bottom,
    branch_label = (branch::FixVariable) -> "x[$(branch.v)] = $(branch.value)"
)

# Solve the MISP using the BnB framework
solution = BnB.solve(data,
                     is_maximization = true,
                     custom_incumbent = misp_incumbent,
                     custom_relaxation = misp_relaxation,        
                     custom_prune = misp_prune,
                     custom_branch = misp_branch,
                     custom_is_optimal_solution = misp_is_optimal_solution,
                     custom_plot_options = custom_plot_options)
```