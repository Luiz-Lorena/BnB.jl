using Test
using BnB

struct DummyData <: BnB.BnBData end

dummy_incumbent(::DummyData) = (nothing, 1.0)
dummy_relaxation(::BnB.BnBNode, ::DummyData) = (Dict(:x => 1.0), 1.0)
dummy_prune(::BnB.BnBCore, ::BnB.BnBNode) = BnB.PrunedByIntegrality
dummy_branch_selection(::BnB.BnBNode) = nothing
dummy_is_optimal_node(bnb::BnB.BnBCore, node::BnB.BnBNode) = node.relaxation == bnb.incumbent_objective
dummy_print_node(::BnB.BnBNode) = nothing

@testset "BnB" begin
    @test BnB.Active isa BnB.BnBNodeStatus

    node = BnB.BnBNode(id = 1)
    @test node.id == 1
    @test node.status == BnB.Active
    @test isempty(node.fixed_variables)

    @test isnothing(
        BnB.solve(
            DummyData();
            print_tree = false,
            sense = BnB.Max,
            custom_incumbent = dummy_incumbent,
            custom_relaxation = dummy_relaxation,
            custom_prune = dummy_prune,
            custom_branch_selection = dummy_branch_selection,
            custom_is_optimal_node = dummy_is_optimal_node,
            custom_print_node = dummy_print_node,
        )
    )
end

include("bkp_test.jl")