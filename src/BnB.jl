module BnB

using Graphs
using DataStructures

include("types.jl")
include("core.jl")
include("visualization.jl")

export
    BnBData,
    BnBBranchConstraint,
    BnBColumn,
    BnBPlotOptions,
    BnBNodeStatus,
    BnBSolution,
    BnBNode,
    BnBCore,
    solve,
    custom_incumbent,
    custom_relaxation,
    custom_prune,
    custom_branch,
    custom_is_optimal_solution

end