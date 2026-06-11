"""
Abstract supertype for user-defined problem data consumed by `solve`.
"""
abstract type BnBData end

"""
Abstract supertype for user-defined branching constraints consumed by `solve`.
"""
abstract type BnBBranchConstraint end

"""
Abstract supertype for user-defined columns consumed by `solve`.
"""
abstract type BnBColumn end

"""
Define a structure to hold options for branch-and-bound tree visualization.

# Fields
- `figure_size`: size of the plot in pixels (width, height).
- `node_size`: size of each node in the plot (width, height).
- `node_label_size`: font size for node labels.
- `edge_label_size`: font size for edge labels.
- `show_legend`: whether to display a legend in the plot.
- `legend_position`: position of the legend in the plot (:bottom, :right).
- `branch_label`: function to generate edge labels based on branching constraints.
"""
mutable struct BnBPlotOptions
    figure_size::Tuple{Int, Int}
    node_size::Tuple{Int, Int}
    node_label_size::Int
    edge_label_size::Int
    show_legend::Bool
    legend_position::Symbol
    branch_label::Function
    function BnBPlotOptions(;figure_size::Tuple{Int, Int} = (1000, 700),
                            node_size::Tuple{Int, Int} = (120, 100),
                            node_label_size::Int = 10,
                            edge_label_size::Int = 10,
                            show_legend::Bool = true,
                            legend_position::Symbol = :bottom,
                            branch_label::Function = _ -> "")
        return new(figure_size, node_size, node_label_size, edge_label_size, show_legend, legend_position, branch_label)
    end
end

"""
Status of a node in the branch-and-bound tree.
- `Active`: node is pending exploration.
- `Exhausted`: node has been explored without finding a better solution.
- `PrunedByInfeasibility`: node is pruned due to infeasibility.
- `PrunedByIntegrality`: node is pruned due to integrality constraints.
- `PrunedByBound`: node is pruned because its relaxation bound is worse than the incumbent.
- `Optimal`: node is marked as optimal by user callback.
"""
@enum BnBNodeStatus begin
    Active
    Exhausted
    PrunedByInfeasibility
    PrunedByIntegrality
    PrunedByBound
    Optimal
end

"""
Represents a solution candidate in the branch-and-bound algorithm.

# Fields
- `solution`: user-defined solution object.
- `objective`: objective value associated with the solution.
"""
struct BnBSolution
    solution::Any
    objective::Union{Nothing, Float64}
    # Constructor
    function BnBSolution(;solution = nothing, objective = nothing)
        return new(solution, objective)
    end
end

"""
Represents a node in the branch-and-bound search tree.

# Fields
- `id`: node identifier.
- `relaxation`: objective value from relaxed subproblem.
- `incumbent`: incumbent objective known when node is processed.
- `solution`: relaxed solution object returned by user callback.
- `status`: node processing status.
- `branch_constraints`: branching constraints applied to this node.
- `columns`: columns associated with this node.
"""
mutable struct BnBNode
    id::Int64
    relaxation::BnBSolution
    incumbent::BnBSolution
    status::BnBNodeStatus
    branch_constraints::Vector{BnBBranchConstraint}
    columns::Union{Nothing,Vector{BnBColumn}}
    # Constructor
    function BnBNode(;id::Int64,
                      relaxation::BnBSolution = BnBSolution(),
                      incumbent::BnBSolution = BnBSolution(),
                      status::BnBNodeStatus = Active,
                      branch_constraints::Vector{BnBBranchConstraint} = Vector{BnBBranchConstraint}(),
                      columns::Union{Nothing,Vector{BnBColumn}} = nothing)
        return new(id, relaxation, incumbent, status, branch_constraints, columns)
    end
end

"""
Holds the branch-and-bound state during and after `solve`.

# Fields
- `data`: user-defined problem data.
- `incumbent`: best solution found during the search.
- `is_maximization`: if `true`, the problem is a maximization problem.
- `active_list`: pending nodes to process.
- `search_strategy`: strategy for selecting the next node to explore (DFS or Best Bound).
- `nodes`: all nodes generated in the search tree.
- `tree`: directed tree of parent-child branching relations.
- `optimal_node_ids`: node IDs marked as optimal after completion.
- `global_cuts`: set of global cuts added during the search.
"""
mutable struct BnBCore
    data::BnBData
    incumbent::BnBSolution
    is_maximization::Bool
    active_list::Union{Stack{BnBNode}, PriorityQueue{BnBNode, Float64}}
    search_strategy::Symbol
    nodes::Vector{BnBNode}
    tree::SimpleDiGraph{Int64}
    optimal_node_ids::Vector{Int64}
    global_cuts::Set{Any}
    # Constructor
    function BnBCore(data::BnBData,
                     incumbent::BnBSolution,
                     is_maximization::Bool,
                     active_list::Union{Stack{BnBNode}, PriorityQueue{BnBNode, Float64}},
                     search_strategy::Symbol)
        return new(data, 
                   incumbent,   
                   is_maximization, 
                   active_list,
                   search_strategy,
                   Vector{BnBNode}(), 
                   SimpleDiGraph{Int64}(),
                   Int64[],
                   Set{Any}())
    end
end