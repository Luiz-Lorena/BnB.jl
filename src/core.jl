"""
    push_active!(bnb::BnBCore, node::BnBNode)

Adds a node to the active frontier according to the selected search strategy.

# Arguments
- `bnb`: the branch-and-bound core structure containing the active frontier and search strategy.
- `node`: the `BnBNode` to be added to the active frontier.
"""
function push_active!(bnb::BnBCore, node::BnBNode)
    if bnb.search_strategy == :best_bound
        # Best-bound for Max picks larger bounds first; for Min picks smaller first.
        priority = bnb.is_maximization ? -node.relaxation.objective : node.relaxation.objective
        enqueue!(bnb.active_list, node, priority)
    else
        # DFS just pushes to the stack (LIFO).
        push!(bnb.active_list, node)
    end
end

"""
    pop_active!(bnb::BnBCore)::BnBNode

Pops a node from the active frontier according to the selected search strategy.

# Arguments
- `bnb`: the branch-and-bound core structure containing the active frontier and search strategy.

Returns the selected `BnBNode`.
"""
function pop_active!(bnb::BnBCore)::BnBNode
    if bnb.search_strategy == :best_bound
        return dequeue!(bnb.active_list)
    end
    return pop!(bnb.active_list)
end

"""
    custom_incumbent(data::BnBData)::BnBSolution

Function to initialize the incumbent solution for the branch-and-bound algorithm. This function must be provided by the user.

# Arguments
- `data`: the branch-and-bound data structure containing the problem data.

Returns a `BnBSolution` object representing the initial incumbent solution.
"""
function custom_incumbent(data::BnBData)::BnBSolution
    error("User must provide a custom function to initialize the incumbent BnBSolution.")
end


"""
    custom_relaxation(node::BnBNode, bnb::BnBCore)::BnBSolution

Function to solve the relaxation for a given node in the branch-and-bound algorithm. This function must be provided by the user.

# Arguments
- `node`: the current node being processed.
- `bnb`: the branch-and-bound core structure containing the problem data and incumbent solution.

Returns a `BnBSolution` object representing the solution of the relaxation for the given node.
"""
function custom_relaxation(node::BnBNode, bnb::BnBCore)::BnBSolution
    error("User must provide a custom function to solve the relaxation for a node and return a BnBSolution.")
end

"""
    custom_prune(node::BnBNode, bnb::BnBCore)::BnBNodeStatus

Function to determine the pruning status of a node in the branch-and-bound algorithm. This function must be provided by the user.

# Arguments
- `node`: the current node being processed.
- `bnb`: the branch-and-bound core structure containing the problem data and incumbent solution.

Returns a `BnBNodeStatus` indicating whether the node should be pruned or not.
"""
function custom_prune(node::BnBNode, bnb::BnBCore)::BnBNodeStatus
    error("User must provide a custom function to determine the pruning status of a node.")
end

"""
    custom_branch(node::BnBNode, bnb::BnBCore)::Vector{BnBBranchConstraint}

Function to determine how to branch a node in the branch-and-bound algorithm. This function must be provided by the user.

# Arguments
- `node`: the current node being processed.
- `bnb`: the branch-and-bound core structure containing the problem data and incumbent solution.

Returns a vector of `BnBBranchConstraint` objects representing the branching decisions.
"""
function custom_branch(node::BnBNode, bnb::BnBCore)::Vector{BnBBranchConstraint}
    error("User must provide a custom function to determine how to branch a node returning a vector of BnBBranchConstraint.")
end

"""
    custom_is_optimal_solution(node::BnBNode, bnb::BnBCore)::Bool

Function to determine if a node's solution is optimal in the branch-and-bound algorithm. This function must be provided by the user.

# Arguments
- `node`: the current node being processed.
- `bnb`: the branch-and-bound core structure containing the problem data and incumbent solution.

Returns `true` if the node's solution is optimal, `false` otherwise.
"""
function custom_is_optimal_solution(node::BnBNode, bnb::BnBCore)::Bool
    error("User must provide a custom function to determine if the solution in a node is optimal.")
end

"""
    initialize(data::BnBData, is_maximization::Bool, search_strategy::Symbol)::BnBCore

Initializes the branch-and-bound structure with the root node.

# Arguments
- `data`: user-defined problem data.
- `is_maximization`: if `true`, the problem is a maximization problem.
- `search_strategy`: strategy for selecting the next node to explore (DFS or Best Bound).

Returns the initialized `BnBCore` object.
"""
function initialize(data::BnBData, is_maximization::Bool, search_strategy::Symbol)::BnBCore
    # Get initial incumbent solution and objective
    incumbent = custom_incumbent(data)
    
    # Initialize BnB active list based on search strategy
    if search_strategy == :best_bound
        # Best-bound for Max picks larger bounds first; for Min picks smaller first.
        active_list = PriorityQueue{BnBNode, Float64}()
    else
        # Default frontier is a stack (LIFO/DFS).
        active_list = Stack{BnBNode}()
    end
    # Initialize BnB structure
    bnb = BnBCore(data, incumbent, is_maximization, active_list, search_strategy)
    
    # Initialize root node with incumbent objective
    root_node = BnBNode(id=1, incumbent = incumbent)
    # Solve relaxation for root node to get a valid bound for best-bound strategy
    root_node.relaxation = custom_relaxation(root_node, bnb)
    # Add root node to active list with its relaxation objective as the bound
    push_active!(bnb, root_node)
    # Add root node to tree
    add_vertex!(bnb.tree)
    # Add root node to node list (for plotting later)
    push!(bnb.nodes, root_node)
    return bnb
end

"""
    mark_optimal_nodes!(bnb::BnBCore)

Checks if a node is optimal based on user-defined criteria and marks it accordingly in the BnB structure.

# Arguments
- `bnb`: the branch-and-bound core structure containing the tree and nodes.
"""
function mark_optimal_nodes!(bnb::BnBCore)
    empty!(bnb.optimal_node_ids)
    for node in bnb.nodes
        is_optimal = custom_is_optimal_solution(node, bnb)
        if is_optimal
            node.status = Optimal
            push!(bnb.optimal_node_ids, node.id)
            bnb.nodes[node.id] = node
        end
    end
end

"""
    branch(bnb::BnBCore, node::BnBNode)

Creates the branches based on the user criteria.

# Arguments
- `bnb`: the branch-and-bound core structure containing the tree and nodes.
- `node`: the current node being processed.
"""
function branch(bnb::BnBCore, node::BnBNode)
    # Find the variables to branch
    branches = custom_branch(node, bnb)
    # Create branches
    for branch in branches
        # Get constraints for parent node
        new_branches = copy(node.branch_constraints)
        # Add it the current branch constraint
        push!(new_branches, branch)
        # Create child node and add the constraints
        child = BnBNode(id = length(bnb.nodes) + 1, branch_constraints = new_branches)
        # Solve relaxation for child node to get a valid bound for best-bound strategy
        relaxation = custom_relaxation(child, bnb)
        if !isnothing(relaxation)
            child.relaxation = relaxation
        else
            if bnb.is_maximization
                child.relaxation = BnBSolution(solution=nothing, objective=-Inf)
            else
                child.relaxation = BnBSolution(solution=nothing, objective=Inf)
            end
        end
        # Update tree structure
        add_vertex!(bnb.tree)
        # Add edge from parent to child
        add_edge!(bnb.tree, node.id, child.id)
        # Add child node to BnB structure
        push!(bnb.nodes, child)
        # Add child to active list
        push_active!(bnb, child)
    end
end

"""
    found_new_incumbent(node::BnBNode, bnb::BnBCore)

Checks if a node's relaxation solution is a new incumbent and updates the BnB structure accordingly.

# Arguments
- `node`: the current node being processed.
- `bnb`: the branch-and-bound core structure containing the incumbent solution and objective.
"""
function found_new_incumbent(node::BnBNode, bnb::BnBCore)
    if (bnb.is_maximization && node.relaxation.objective > bnb.incumbent.objective) || (!bnb.is_maximization && node.relaxation.objective < bnb.incumbent.objective)
        bnb.incumbent = node.relaxation
    end
end

"""
    prune(bnb::BnBCore, node::BnBNode)::Bool

Checks pruning conditions and updates node status accordingly.

# Arguments
- `bnb`: the branch-and-bound core structure containing the tree and nodes.
- `node`: the current node being processed.

Returns `true` if the node was pruned, `false` otherwise.
"""
function prune(bnb::BnBCore, node::BnBNode)::Bool
    # Update the node incumbent with the current global incumbent before checking pruning conditions
    node.incumbent = bnb.incumbent
    status = custom_prune(node, bnb)
    if status == PrunedByInfeasibility
        node.status = status
        bnb.nodes[node.id] = node
        return true
    elseif status == PrunedByIntegrality
        node.status = status
        bnb.nodes[node.id] = node
        # Check if we found a better incumbent solution
        found_new_incumbent(node, bnb)
        return true
    elseif status == PrunedByBound
        node.status = status
        bnb.nodes[node.id] = node
        return true
    end
    node.status = Exhausted
    bnb.nodes[node.id] = node
    return false
end

"""
    solve(data::BnBData; kwargs...)::BnBSolution

Run the branch-and-bound algorithm using user-provided callbacks.

# Keyword Arguments
- `is_maximization::Bool=true`: if `true`, the problem is a maximization problem.
- `search_strategy::Symbol=:best_bound`: strategy for selecting the next node to explore (:best_bound, :dfs).
- `print_tree::Bool=true`: if `true`, plot the final search tree.
- `plot_tree::Bool=true`: if `true`, display the BnB tree plot.
- `custom_plot_options::BnBPlotOptions`: options for customizing the plot appearance.

Returns a `BnBSolution` object containing the best solution, objective value, optimal nodes, and total nodes explored.
"""
function solve(data::BnBData;
               is_maximization::Bool = true,           
               search_strategy::Symbol = :best_bound,
               print_tree::Bool = true,
               plot_tree::Bool = true,
               custom_plot_options::BnBPlotOptions = BnBPlotOptions())::BnBSolution
    # BnB time
    total_time = time()

    # 1. Initialize BnB structure
    bnb = initialize(data, is_maximization, search_strategy)
    # 2. Main BnB loop
    while !isempty(bnb.active_list)
        # 3. Select subproblem from active list
        node = pop_active!(bnb)
        # 4. Update incumbent and check pruning conditions
        if !prune(bnb, node)
            # 5. If not pruned, create child nodes by branching
            branch(bnb, node)
        end
    end

    # Update time
    total_time = time() - total_time

    # Check for optimal nodes and mark them in the BnB structure
    mark_optimal_nodes!(bnb)

    println("========== Branch-and-Bound Completed ==========\n")

    println("Total time: $total_time seconds")
    println("Best solution: $(bnb.incumbent.solution)")
    println("Objective value: $(bnb.incumbent.objective)")
    
    println("\nNodes explored: $(length(bnb.nodes))")
    println("Nodes pruned: $(count(node -> node.status in (PrunedByInfeasibility, PrunedByIntegrality, PrunedByBound), bnb.nodes))")
    println("Pruning statistics:")
    println("\t- Pruned by infeasibility: $(count(node -> node.status == PrunedByInfeasibility, bnb.nodes))")
    println("\t- Pruned by integrality: $(count(node -> node.status == PrunedByIntegrality, bnb.nodes))")
    println("\t- Pruned by bound: $(count(node -> node.status == PrunedByBound, bnb.nodes))")

    if !isempty(bnb.global_cuts)
        println("\nCuts generated: $(length(bnb.global_cuts))")
    end
    
    # Print the search tree in ASCII format
    if print_tree
        print_bnb_tree(bnb)
    end

    # Display the BnB tree
    if plot_tree
        plot_bnb_tree(bnb; plot_options = custom_plot_options)
    end

    # Return best solution and summary
    return bnb.incumbent
end