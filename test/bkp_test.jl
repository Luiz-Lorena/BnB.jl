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

@testset "BKP JuMP/HiGHS" begin
    data = BKPData(
        v = [4, 2, 10, 2, 1],
        w = [12, 2, 4, 1, 1],
        W = 15,
    )

    @test isnothing(
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
    )
end
