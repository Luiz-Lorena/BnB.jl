using Colors        # For color definitions
using CairoMakie    # For plotting
using GraphMakie    # For graph visualization
using NetworkLayout # For the Buchheim layout algorithm

"""
    status_symbol(status::BnBNodeStatus)

# Arguments
- `status`: the status of a branch-and-bound node.

Returns a string symbol representing the node status for visualization purposes.
"""
function status_symbol(status::BnBNodeStatus)
    if status == PrunedByIntegrality
        return "🔒"
    elseif status == PrunedByBound
        return "✂️"
    elseif status == PrunedByInfeasibility
        return "🚫"
    elseif status == Optimal
        return "⭐"
    else
        return ""
    end
end

"""
    print_ascii_tree(core::BnBCore, node_id::Int; prefix="", is_last=true)

# Arguments
- `core`: the branch-and-bound core structure containing the tree and nodes.
- `node_id`: the ID of the current node to print.
- `prefix`: string prefix for formatting the tree structure (used in recursion).
- `is_last`: boolean indicating if the current node is the last child of its parent (used for formatting).

Recursive helper function to print the branch-and-bound tree in ASCII format.
"""
function print_ascii_tree(core::BnBCore, node_id::Int; prefix="", is_last=true)
    node = core.nodes[node_id]
    branch = is_last ? "└── " : "├── "
    obj = node.relaxation.objective
    println(
        prefix *
        branch *
        "Node $(node.id) ($(round(obj,digits=2))) " *
        status_symbol(node.status)
    )
    children = collect(outneighbors(core.tree, node_id))
    for (i, child) in enumerate(children)
        next_prefix = prefix * (is_last ? "    " : "│   ")
        print_ascii_tree(
            core,
            child;
            prefix=next_prefix,
            is_last=i == length(children)
        )
    end
end

"""
    print_bnb_tree(core::BnBCore)

# Arguments
- `core`: the branch-and-bound core structure containing the tree and nodes.

Prints the branch-and-bound search tree in a human-readable ASCII format.
"""
function print_bnb_tree(core::BnBCore)
    println("\n=================================================")
    println("Search Tree")
    println("=================================================\n")
    print_ascii_tree(core, 1) # Start from the root node (id = 1)
    # Print legend for node statuses
    println("\nLegend:\n")
    println("\t🔒 : Pruned by Integrality")
    println("\t🚫 : Pruned by Infeasibility")
    println("\t✂️ : Pruned by Bound")
    println("\t⭐ : Optimal")
    println("\n=================================================")
end

"""
    plot_bnb_tree(bnb::BnBCore; plot_options::BnBPlotOptions)

# Arguments
- `bnb`: the branch-and-bound core structure containing the tree and nodes.
- `plot_options`: options for customizing the tree plot (node size, label size, legend, etc.).

Plots the branch-and-bound search tree using GraphMakie, with node colors and labels based on their status and bounds.
"""
function plot_bnb_tree(bnb::BnBCore; plot_options::BnBPlotOptions = BnBPlotOptions())

    # Define colors for each node status
    status_colors = Dict(
        Exhausted => colorant"lightgray",
        PrunedByBound => colorant"lightpink",
        PrunedByInfeasibility => colorant"lightcoral",
        PrunedByIntegrality => colorant"lightgoldenrodyellow",
        Optimal => colorant"limegreen"
    )
    
    # Build labels and colors from the final node statuses.
    node_labels = String[]
    node_colors = Color[]

    # Some nodes can be infeasible and keep relaxation = nothing.
    format_bound(x) = isnothing(x) || isinf(x) ? "NA" : string(round(x, digits=2))

    for node in bnb.nodes
        # Node labels with id, UB and LB values
        if bnb.is_maximization
            UB = format_bound(node.relaxation.objective)
            LB = format_bound(node.incumbent.objective)
        else
            UB = format_bound(node.incumbent.objective)
            LB = format_bound(node.relaxation.objective)
        end
        base_label = "Node $(node.id)\nUB: $(UB)\nLB: $(LB)"
        push!(node_labels, base_label)
        # Determine node color based on status
        push!(node_colors, get(status_colors, node.status, colorant"lightgray"))
    end
  
    # Create edge labels based on the fixed variable for each edge
    edge_labels = String[]
    for e in edges(bnb.tree)
        # Get the last branch for the child node (destination of the edge)
        branch = bnb.nodes[dst(e)].branch_constraints[end]
        # edge_label = "x[" * join(collect(fixed_variable[1]), ",") * "] = " * string(Int(fixed_variable[2]))
        edge_label = plot_options.branch_label(branch)
        push!(edge_labels, edge_label)
    end

    # Create the graph plot with GraphMakie
    f, ax, p = GraphMakie.graphplot(bnb.tree,
        layout=NetworkLayout.Buchheim(),
        nlabels=node_labels,
        nlabels_fontsize=plot_options.node_label_size,
        elabels_fontsize=plot_options.edge_label_size,
        node_color=node_colors,
        arrow_show=false,
        node_marker=:rect,
        node_size=plot_options.node_size,
        node_strokewidth=2,
        node_strokecolor=:black,
        elabels=edge_labels, elabels_textsize=plot_options.edge_label_size,
        nlabels_align=(:center, :center), nlabels_textsize=plot_options.node_label_size,
        edge_width=2, figure=(; size=plot_options.figure_size)
    )

    # Hide decorations and spines for a cleaner look
    hidedecorations!(ax)
    hidespines!(ax)

    # Add margins to the plot
    ax.leftspinevisible = false
    ax.rightspinevisible = false
    ax.topspinevisible = false
    ax.bottomspinevisible = false
    ax.xautolimitmargin[] = (0.12, 0.12)
    ax.yautolimitmargin[] = (0.12, 0.12)

    # Create a legend
    elements = [
        PolyElement(color=status_colors[Exhausted]),
        PolyElement(color=status_colors[PrunedByBound]),
        PolyElement(color=status_colors[PrunedByInfeasibility]),
        PolyElement(color=status_colors[PrunedByIntegrality]),
        PolyElement(color=status_colors[Optimal])
    ]

    # Legend labels
    labels = [
        "Exhausted",
        "Pruned by Bound",
        "Pruned by Infeasibility",
        "Pruned by Integrality",
        "Optimal"
    ]

    # Add legend to the plot if requested.
    # :right keeps the previous vertical layout, while :bottom creates a horizontal legend.
    if plot_options.show_legend
        if plot_options.legend_position == :bottom
            f[1, 1] = ax
            legend = Legend(f[2, 1], elements, labels;
                            orientation=:horizontal,
                            tellwidth=false,
                            tellheight=true)
        else
            legend = Legend(f[1, 2], elements, labels; tellheight=false)
            f[1, 1] = ax
            f[1, 2] = legend
        end
    end

    # Finalize layout and display the plot
    display(f)
end