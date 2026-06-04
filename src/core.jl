# Function to initialize the BnBCore structure with the root node
function initialize(incumbent_solution, incumbent_objective, sense) 
    # Initialize active list as a stack (LIFO)
    active_list = Stack{BnBNode}()
    # Initialize root node with sense and incumbent objective
    root_node = BnBNode(id=1, incumbent = incumbent_objective)
    push!(active_list, root_node)
    # Initialize BnBCore structure
    bnb = BnBCore(incumbent_solution, incumbent_objective, sense, active_list)
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
        # Add child node to BnBCore structure
        push!(bnb.nodes, child)
        # Update tree structure
        add_vertex!(bnb.tree)
        # Add edge from parent to child
        add_edge!(bnb.tree, node.id, child.id)
        # Add child to active list
        push!(bnb.active_list, child)
    end
end

# Function to check if we found a new incumbent solution
function found_new_incumbent(bnb::BnBCore, node::BnBNode)
    if (bnb.sense == Max && node.relaxation > bnb.incumbent_objective) || (bnb.sense == Min && node.relaxation < bnb.incumbent_objective)
        bnb.incumbent_solution = node.solution
        bnb.incumbent_objective = node.relaxation
        bnb.best_node_id = node.id
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
    elseif status == PrunedByBound
        node.status = status
        bnb.nodes[node.id] = node
        custom_print_node(node)
        return true
    elseif status == PrunedByIntegrality
        node.status = status
        # Check if we found a better incumbent solution
        found_new_incumbent(bnb, node)
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
- `print_tree::Bool=true`: if `true`, plot the final search tree.
- `sense::BnBSense`: optimization sense (`Max` or `Min`).
- `custom_incumbent::Function`: returns initial `(solution, objective)`.
- `custom_relaxation::Function`: solves node relaxation, returns `(solution, objective)`.
- `custom_prune::Function`: returns a `BnBNodeStatus` pruning decision.
- `custom_branch_selection::Function`: chooses branching variable/index.
- `custom_is_optimal_node::Function`: marks nodes matching final optimum.
- `custom_print_node::Function`: custom hook called when nodes are processed.

Returns `nothing` and prints a search summary.
"""
function solve(data::BnBData;
               print_tree::Bool = true,
               sense::BnBSense,
               custom_incumbent::Function, 
               custom_relaxation::Function,
               custom_prune::Function,
               custom_branch_selection::Function,
               custom_is_optimal_node::Function,
               custom_print_node::Function)
    # 1. Initialize incumbent solution and objective
    sol, obj = custom_incumbent(data)
    # 2. Initialize BnBCore structure
    bnb = initialize(sol, obj, sense)
    # 3. Main BnB loop
    while !isempty(bnb.active_list)
        # 4. Select subproblem from active list
        node = pop!(bnb.active_list)
        # 5. Solve the relaxed subproblem
        node.solution, node.relaxation = custom_relaxation(node, data)
        # 6. Update incumbent and check pruning conditions
        if !prune(bnb, node, custom_prune, custom_print_node)
            # 7. If not pruned, create child nodes by branching
            branch(bnb, node, custom_branch_selection)
        end
    end
    
    # Check for optimal nodes and mark them in the BnBCore structure
    mark_optimal_nodes!(bnb, custom_is_optimal_node)
    
    # Display the BnB tree
    if print_tree
        _ensure_visualization_loaded!()
        plot_bnb_tree(bnb)
    end

    println("="^15, " Results ", "="^15)
    println("Best solution found: ", bnb.incumbent_solution)
    println("Best objective value: ", bnb.incumbent_objective)
    println("Best nodes ID: ", bnb.optimal_node_ids)
    println("Total nodes explored: ", length(bnb.nodes))
    
end