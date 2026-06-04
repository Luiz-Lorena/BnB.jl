using Colors        # For color definitions
using CairoMakie    # For plotting
using GraphMakie    # For graph visualization
using NetworkLayout # For the Buchheim layout algorithm

# Function to visualize the branch-and-bound tree using GraphMakie
function plot_bnb_tree(bnb::BnBCore)
    # Define colors for each node status
    status_colors = Dict(
        Exhausted => colorant"lightgray",
        PrunedByInfeasibility => colorant"lightpink",
        PrunedByBound => colorant"lightcoral",
        PrunedByIntegrality => colorant"lightgoldenrodyellow",
        Optimal => colorant"limegreen"
    )
    
    # Build labels and colors from the final node statuses.
    node_labels = String[]
    node_colors = Color[]
    for node in bnb.nodes
        # Node labels with id, UB and LB values
        if bnb.sense == Max
            UB = round(node.relaxation, digits=2)
            LB = round(node.incumbent, digits=2)
        else
            UB = round(node.incumbent, digits=2)
            LB = round(node.relaxation, digits=2)
        end
        base_label = "Node $(node.id)\nUB: $(UB)\nLB: $(LB)"
        push!(node_labels, base_label)
        # Determine node color based on status
        push!(node_colors, status_colors[node.status])
    end
  
    # Create edge labels based on the fixed variable for each edge
    edge_labels = String[]
    for e in edges(bnb.tree)
        # Get the last fixed variable for the child node (destination of the edge)
        fixed_variable = bnb.nodes[dst(e)].fixed_variables[end]
        edge_label = "x[$(fixed_variable[1])] = $(fixed_variable[2])"
        push!(edge_labels, edge_label)
    end

    # Use a scalar for node_size, not a tuple
    node_size = (120,100)

    # Create the graph plot with GraphMakie
    f, ax, p = GraphMakie.graphplot(bnb.tree,
        layout=NetworkLayout.Buchheim(),
        nlabels=node_labels,
        nlabels_fontsize=14,
        elabels_fontsize=14,
        node_color=node_colors,
        arrow_show=false,
        node_marker=:rect,
        node_size=node_size,
        node_strokewidth=2,
        node_strokecolor=:black,
        elabels=edge_labels, elabels_textsize=10,
        nlabels_align=(:center, :center), nlabels_textsize=10,
        edge_width=2, figure=(; size=(800, 600))
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
        PolyElement(color=status_colors[PrunedByInfeasibility]),
        PolyElement(color=status_colors[PrunedByBound]),
        PolyElement(color=status_colors[PrunedByIntegrality]),
        PolyElement(color=status_colors[Optimal])
    ]

    # Legend labels
    labels = [
        "Exhausted",
        "Pruned by Infeasibility",
        "Pruned by Bound",
        "Pruned by Integrality",
        "Optimal"
    ]

    # Add legend to the plot
    legend = Legend(f[1, 2], elements, labels; tellheight=false)
    f[1, 1] = ax
    f[1, 2] = legend

    # Finalize layout and display the plot
    display(f)
end