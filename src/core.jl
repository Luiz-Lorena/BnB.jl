# Adds a node to the active frontier according to the selected search strategy.
function push_active!(bnb::BnBCore, node::BnBNode, bound_hint::Union{Nothing, Float64} = nothing)
    if bnb.search_strategy == :best_bound
        # Best-bound for Max picks larger bounds first; for Min picks smaller first.
        bound = isnothing(bound_hint) ? node.incumbent : bound_hint
        priority = bnb.is_maximization ? -bound : bound
        enqueue!(bnb.active_list, node, priority)
    else
        push!(bnb.active_list, node)
    end
end

# Pops a node from the active frontier according to the selected search strategy.
function pop_active!(bnb::BnBCore)
    if bnb.search_strategy == :best_bound
        return dequeue!(bnb.active_list)
    end
    return pop!(bnb.active_list)
end

# Function to initialize the BnB structure with the root node
function initialize(incumbent_solution, incumbent_objective, is_maximization::Bool, search_strategy::Symbol)
    if search_strategy == :best_bound
        active_list = PriorityQueue{BnBNode, Float64}()
    else
        # Default frontier is a stack (LIFO/DFS).
        active_list = Stack{BnBNode}()
    end

    # Initialize root node with incumbent objective
    root_node = BnBNode(id=1, incumbent = incumbent_objective)

    # Initialize BnB structure
    bnb = BnBCore(incumbent_solution, incumbent_objective, is_maximization, active_list, search_strategy)
    push_active!(bnb, root_node, incumbent_objective)
    push!(bnb.nodes, root_node)
    add_vertex!(bnb.tree)
    return bnb
end

# Mark all nodes that match the final incumbent as optimal.
function mark_optimal_nodes!(bnb::BnBCore, custom_is_optimal_node::Function)
    empty!(bnb.optimal_node_ids)
    for node in bnb.nodes
        is_optimal = custom_is_optimal_node(bnb, node)
        if is_optimal
            node.status = Optimal
            push!(bnb.optimal_node_ids, node.id)
            bnb.nodes[node.id] = node
        end
    end
end

# Function to branch on a node by creating child nodes based on the selected variable
function branch(bnb::BnBCore, node::BnBNode, bnb_branch_selection::Function)
    # Find the first variable that is fractional in the solution
    branch_id = bnb_branch_selection(node)
    isnothing(branch_id) && return
    # Generic creation of binary branches (0 and 1)
    for val in [0.0, 1.0]
        # Create new fixed variables list for the child node
        new_fixes = copy(node.fixed_variables)
        push!(new_fixes, Pair{Any, Float64}(branch_id, val))
        # Create child node with new fixed variable
        child = BnBNode(id=length(bnb.nodes) + 1, fixed_variables=new_fixes)
        # Add child node to BnB structure
        push!(bnb.nodes, child)
        # Update tree structure
        add_vertex!(bnb.tree)
        # Add edge from parent to child
        add_edge!(bnb.tree, node.id, child.id)
        # Add child to active list
        push_active!(bnb, child, node.relaxation)
    end
end

# Function to check if we found a new incumbent solution
function found_new_incumbent(bnb::BnBCore, node::BnBNode)
    if (bnb.is_maximization && node.relaxation > bnb.incumbent_objective) || (!bnb.is_maximization && node.relaxation < bnb.incumbent_objective)
        bnb.incumbent_solution = node.solution
        bnb.incumbent_objective = node.relaxation
        println("New incumbent found with objective: ", bnb.incumbent_objective)
    end
end

# Function to check pruning conditions and update node status accordingly
function prune(bnb::BnBCore, node::BnBNode, custom_prune::Function, custom_print_node::Function)
    node.incumbent = bnb.incumbent_objective
    status = custom_prune(bnb, node)
    if status == PrunedByInfeasibility
        node.status = status
        bnb.nodes[node.id] = node
        custom_print_node(node)
        return true
    elseif status == PrunedByIntegrality
        node.status = status
        # Check if we found a better incumbent solution
        bnb.nodes[node.id] = node
        custom_print_node(node)
        found_new_incumbent(bnb, node)
        return true
    elseif status == PrunedByBound
        node.status = status
        bnb.nodes[node.id] = node
        custom_print_node(node)
        return true
    end
    custom_print_node(node)
    println("Node not pruned, branching...")
    node.status = Exhausted
    bnb.nodes[node.id] = node
    return false
end

"""
    solve(data::BnBData; kwargs...)

Run the branch-and-bound algorithm using user-provided callbacks.

# Keyword Arguments
- `is_maximization::Bool=true`: if `true`, the problem is a maximization problem.
- `search_strategy::Symbol=:best_bound`: strategy for selecting the next node to explore (:best_bound, :dfs).
- `custom_incumbent::Function`: returns initial `(solution, objective)`.
- `custom_relaxation::Function`: solves node relaxation, returns `(solution, objective)`.
- `custom_prune::Function`: returns a `BnBNodeStatus` pruning decision.
- `custom_branch_selection::Function`: chooses branching variable/index.
- `custom_is_optimal_node::Function`: marks nodes matching final optimum.
- `custom_print_node::Function`: custom hook called when nodes are processed.
- `print_tree::Bool=true`: if `true`, plot the final search tree.
- `custom_plot_options::BnBPlotOptions`: options for customizing the plot appearance.

Returns a `BnBSolution` object containing the best solution, objective value, optimal nodes, and total nodes explored.
"""
function solve(data::BnBData;
               is_maximization::Bool = true,           
               search_strategy::Symbol = :best_bound,
               custom_incumbent::Function, 
               custom_relaxation::Function,
               custom_prune::Function,
               custom_branch_selection::Function,
               custom_is_optimal_node::Function,
               custom_print_node::Function,
               print_tree::Bool = true,
               custom_plot_options::BnBPlotOptions = BnBPlotOptions())
    # 1. Initialize incumbent solution and objective
    sol, obj = custom_incumbent(data)
    # 2. Initialize BnB structure
    bnb = initialize(sol, obj, is_maximization, search_strategy)
    # 3. Main BnB loop
    while !isempty(bnb.active_list)
        # 4. Select subproblem from active list
        node = pop_active!(bnb)
        # 5. Solve the relaxed subproblem
        node.solution, node.relaxation = custom_relaxation(node, data)
        # 6. Update incumbent and check pruning conditions
        if !prune(bnb, node, custom_prune, custom_print_node)
            # 7. If not pruned, create child nodes by branching
            branch(bnb, node, custom_branch_selection)
        end
    end
    
    # Check for optimal nodes and mark them in the BnB structure
    mark_optimal_nodes!(bnb, custom_is_optimal_node)
    
    # Display the BnB tree
    if print_tree
        plot_bnb_tree(bnb; plot_options = custom_plot_options)
    end

    # Return best solution and summary
    return BnBSolution(bnb.incumbent_solution, 
                       bnb.incumbent_objective, 
                       bnb.optimal_node_ids, 
                       length(bnb.nodes))
end