module BnB

using Graphs
using DataStructures

include("types.jl")
include("core.jl")
include("visualization.jl")

export
    BnBData,
    BnBNodeStatus,
    BnBNode,
    BnBCore,
    solve

end