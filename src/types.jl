"""
Abstract supertype for user-defined problem data consumed by `solve`.
"""
abstract type BnBData end

"""
Optimization sense used by `BnBCore`.

- `Max`: maximize objective values.
- `Min`: minimize objective values.
"""
@enum BnBSense begin
    Max
    Min
end

"""
Status of a node in the branch-and-bound tree.
"""
@enum BnBNodeStatus begin
    Active
    Exhausted
    PrunedByBound
    PrunedByIntegrality
    PrunedByInfeasibility
    Optimal
end

"""
Represents a node in the branch-and-bound search tree.

# Fields
- `id`: node identifier.
- `relaxation`: objective value from relaxed subproblem.
- `incumbent`: incumbent objective known when node is processed.
- `solution`: relaxed solution object returned by user callback.
- `status`: node processing status.
- `fixed_variables`: branching fixings applied to this node.
"""
mutable struct BnBNode
    id::Int64
    relaxation::Float64
    incumbent::Float64
    solution::Any
    status::BnBNodeStatus
    fixed_variables::Vector{Pair{Any, Float64}}
    # Constructor
    function BnBNode(;id::Int64, 
                      relaxation::Float64 = 0.0, 
                      incumbent::Float64 = 0.0, 
                      solution::Any = nothing, 
                      status::BnBNodeStatus = Active,
                      fixed_variables::Vector{Pair{Any, Float64}} = Vector{Pair{Any, Float64}}())
        return new(id, relaxation, incumbent, solution, status, fixed_variables)
    end
end

"""
Holds the branch-and-bound state during and after `solve`.

# Fields
- `incumbent_solution`: best solution found.
- `incumbent_objective`: objective value of incumbent.
- `sense`: optimization sense.
- `active_list`: pending nodes to process.
- `nodes`: all nodes generated in the search tree.
- `tree`: directed tree of parent-child branching relations.
- `optimal_node_ids`: node IDs marked as optimal after completion.
"""
mutable struct BnBCore
    incumbent_solution::Any
    incumbent_objective::Float64
    sense::BnBSense
    active_list::Stack{BnBNode}
    nodes::Vector{BnBNode}
    tree::SimpleDiGraph{Int64}
    optimal_node_ids::Vector{Int64}
    # Constructor
    function BnBCore(incumbent_solution, incumbent_objective, sense, active_list::Stack{BnBNode})
        return new(
            incumbent_solution, 
            incumbent_objective, 
            sense, 
            active_list,
            Vector{BnBNode}(), 
            SimpleDiGraph{Int64}(),
            Int64[]
        )
    end
end