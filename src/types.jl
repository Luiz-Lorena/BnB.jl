"""
Abstract supertype for user-defined problem data consumed by `solve`.
"""
abstract type BnBData end

"""
Define a structure to hold options for branch-and-bound tree visualization.

# Fields
- `figure_size`: size of the plot in pixels (width, height).
- `node_size`: size of each node in the plot (width, height).
- `node_label_size`: font size for node labels.
- `edge_label_size`: font size for edge labels.
- `show_legend`: whether to display a legend in the plot.
- `legend_position`: position of the legend in the plot (:bottom, :right).
"""
mutable struct BnBPlotOptions
    figure_size::Tuple{Int, Int}
    node_size::Tuple{Int, Int}
    node_label_size::Int
    edge_label_size::Int
    show_legend::Bool
    legend_position::Symbol
    function BnBPlotOptions(;figure_size::Tuple{Int, Int} = (1000, 700),
                            node_size::Tuple{Int, Int} = (120, 100),
                            node_label_size::Int = 10,
                            edge_label_size::Int = 10,
                            show_legend::Bool = true,
                            legend_position::Symbol = :bottom)
        return new(figure_size, node_size, node_label_size, edge_label_size, show_legend, legend_position)
    end
end

"""
Status of a node in the branch-and-bound tree.
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
    relaxation::Union{Nothing, Float64}
    incumbent::Float64
    solution::Any
    status::BnBNodeStatus
    fixed_variables::Vector{Pair{Any, Float64}}
    # Constructor
    function BnBNode(;id::Int64,
                      relaxation::Union{Nothing, Float64} = nothing, 
                      incumbent::Float64 = 0.0, 
                      solution::Any = nothing, 
                      status::BnBNodeStatus = Active,
                      fixed_variables::Vector{Pair{Any, Float64}} = Vector{Pair{Any, Float64}}())
        return new(id, relaxation, incumbent, solution, status, fixed_variables)
    end
end

"""
Represents the final solution and summary of the branch-and-bound process.

# Fields
- `solution`: best solution found.
- `objective`: objective value of the best solution.
- `optimal_nodes`: list of node IDs marked as optimal.
- `total_nodes`: total number of nodes generated during the search.
"""
struct BnBSolution
    solution::Any
    objective::Float64
    optimal_nodes::Vector{Int64}
    total_nodes::Int64
end

"""
Holds the branch-and-bound state during and after `solve`.

# Fields
- `incumbent_solution`: best solution found.
- `incumbent_objective`: objective value of incumbent.
- `is_maximization`: if `true`, the problem is a maximization problem.
- `active_list`: pending nodes to process.
- `nodes`: all nodes generated in the search tree.
- `tree`: directed tree of parent-child branching relations.
- `optimal_node_ids`: node IDs marked as optimal after completion.
"""
mutable struct BnBCore
    incumbent_solution::Any
    incumbent_objective::Float64
    is_maximization::Bool
    active_list::Union{Stack{BnBNode}, PriorityQueue{BnBNode, Float64}}
    search_strategy::Symbol
    nodes::Vector{BnBNode}
    tree::SimpleDiGraph{Int64}
    optimal_node_ids::Vector{Int64}
    # Constructor
    function BnBCore(incumbent_solution,
                     incumbent_objective,
                     is_maximization::Bool,
                     active_list::Union{Stack{BnBNode}, PriorityQueue{BnBNode, Float64}},
                     search_strategy::Symbol)
        return new(incumbent_solution, 
                   incumbent_objective, 
                   is_maximization, 
                   active_list,
                   search_strategy,
                   Vector{BnBNode}(), 
                   SimpleDiGraph{Int64}(),
                   Int64[])
    end
end