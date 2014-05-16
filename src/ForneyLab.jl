module ForneyLab

export Message, Node, Interface, Edge
export calculateMessage!, calculateMessages!, calculateForwardMessage!, calculateBackwardMessage!, calculateMarginal, clearMessages!

# Verbosity
verbose = false
setVerbose(verbose_mode=true) = global verbose=verbose_mode
printVerbose(msg) = if verbose println(msg) end

# Helpers
include("helpers.jl")

# Other includes
import Base.show

# Top-level abstracts
abstract Message

abstract Node
show(io::IO, node::Node) = println(io, typeof(node), " with name ", node.name, ".")

type Interface
    # An Interface belongs to a node and is used to send/receive messages.
    # An Interface has exactly one partner interface, with wich it forms an edge.
    # An Interface can be seen as a half-edge, that connects to a partner Interface to form a complete edge.
    # A message from node a to node b is stored at the Interface of node a that connects to an Interface of node b.
    node::Node
    partner::Union(Interface, Nothing)
    message::Union(Message, Nothing)
    message_valid::Bool # false indicates that message has already been consumed

    # Sanity check for matching message types
    function Interface(node::Node, partner::Union(Interface, Nothing), message::Union(Message, Nothing))
        if typeof(partner) == Nothing || typeof(message) == Nothing # Check if message or partner exist
            new(node, partner, message, typeof(message)!=Nothing)
        elseif typeof(message) != typeof(partner.message) # Compare message types
            error("Message type of partner does not match with interface message type")
        else
            new(node, partner, message, typeof(message)!=Nothing)
        end
    end
end
Interface(node::Node, message::Message) = Interface(node, nothing, message)
Interface(node::Node) = Interface(node, nothing, nothing)
show(io::IO, interface::Interface) = println(io, "Interface of $(typeof(interface.node)) with node name $(interface.node.name) holds ", interface.message_valid ? "VALID" : "INVALID", " message of type $(typeof(interface.message)).")

type Edge
    # An Edge joins two interfaces and has a direction (from tail to head).
    # Edges are mostly useful for code readability, they are not used internally.
    # Forward messages flow in the direction of the Edge (tail to head).
    tail::Interface
    head::Interface

    function Edge(tail::Interface, head::Interface)
        if  typeof(head.message) == Nothing ||
            typeof(tail.message) == Nothing ||
            typeof(head.message) == typeof(tail.message)
            if !is(head.node, tail.node)
                tail.partner = head
                head.partner = tail
                new(tail, head)
            else
                error("Cannot connect two interfaces of the same node: ", typeof(head.node), " ", head.node.name)
            end
        else
            error("Head and tail message types do not match: ", typeof(head.message), " and ", typeof(tail.message))
        end
    end
end

function Edge(tail_node::Node, head_node::Node)
    # Create an Edge from tailNode to headNode.
    # Use the first free interface on each node.
    tail = nothing
    head = nothing
    for interface in tail_node.interfaces
        if interface.partner==nothing
            tail = interface
            break
        end
    end
    if tail==nothing
        error("Cannot create edge: no free interface on tail node: ", typeof(tail_node), " ", tail_node.name)
    end
    for interface in head_node.interfaces
        if interface.partner==nothing
            head = interface
            break
        end
    end
    if head==nothing
        error("Cannot create edge: no free interface on head node: ", typeof(head_node), " ", head_node.name)
    end

    return Edge(tail, head)
end
show(io::IO, edge::Edge) = println(io, "Edge from ", typeof(edge.tail.node), " with node name ", edge.tail.node.name, " to ", typeof(edge.head.node), " with node name ", edge.head.node.name, ". Forward message type: ", typeof(edge.tail.message), ". Backward message type: ", typeof(edge.head.message), ".")

# Messages
include("messages.jl")

# Nodes
include("nodes/addition.jl")
include("nodes/constant.jl")
include("nodes/equality.jl")
include("nodes/fixed_gain.jl")
# Composite nodes
include("nodes/composite/gain_addition.jl")
include("nodes/composite/gain_equality.jl")

#############################
# Generic methods
#############################

function calculateMessage!(outbound_interface::Interface, node::Node, call_count::Int64)
    # Calculate the outbound message on a specific interface of a specified node.
    # The message is stored in the specified interface.

    # Sanity check
    if !is(outbound_interface.node, node)
        error("Specified interface does not belong to the specified node (", typeof(node), " ", node.name,")")
    end

    # Increment and stopping condition for recursion
    call_count += 1
    if call_count > 10 #TODO: pick something better; let user decide the convergence criterium
        uninformative_message = GaussianMessage(m=[10.0], V=[100.0]) # Return something uninformative TODO: make user pass this message
        outbound_interface.message = uninformative_message
        outbound_interface.message_valid = true # Validate
        printVerbose("Stopping condition reached for calculateMessage at call count $(call_count).")
        return uninformative_message
    end

    # Calculate all inbound messages
    inbound_message_types = Union() # Union of all inbound message types
    outbound_interface_id = 0
    for node_interface_id = 1:length(node.interfaces) #TODO: define a schedule; outbound edge dependent?
        node_interface = node.interfaces[node_interface_id]
        if is(node_interface, outbound_interface) #TODO: substract from 1:length...
            outbound_interface_id = node_interface_id
            continue
        end
        if node_interface.partner == nothing
            error("Cannot receive messages on disconnected interface ", node_interface_id, " of ", typeof(node), " ", node.name)
        end
        if !(node_interface.partner.message_valid) # When the required inbound message is invalid, calculate it anew
            # Calculate required inbound message by recursive call
            printVerbose("Calling calculateMessage! on node $(typeof(node_interface.partner.node)) $(node_interface.partner.node.name)")
            calculateMessage!(node_interface.partner, call_count)
            if !(node_interface.partner.message_valid)
                error("Could not calculate required inbound message on interface ", node_interface_id, " of ", typeof(node), " ", node.name)
            end
            inbound_message_types = Union(inbound_message_types, typeof(node_interface.partner.message))
        end
    end

    # Collect all inbound messages
    inbound_messages = Array(inbound_message_types, length(node.interfaces))
    if (inbound_message_types!=None)
        for node_interface_id = 1:length(node.interfaces)
            if node_interface_id!=outbound_interface_id
                inbound_messages[node_interface_id] = node.interfaces[node_interface_id].partner.message
            end
        end
    end

    # Calculate the actual message
    printVerbose("Calculate outbound message on $(typeof(node)) $(node.name) interface $outbound_interface_id")
    msg = updateNodeMessage!(outbound_interface_id, node, inbound_messages)
    printVerbose(" >> $(msg)")

    # Validate the outbound message
    outbound_interface.message_valid = (typeof(outbound_interface.message)<:Message)

    return msg
end
calculateMessage!(outbound_interface::Interface, call_count::Int64) = calculateMessage!(outbound_interface, outbound_interface.node, call_count)
calculateMessage!(outbound_interface::Interface) = calculateMessage!(outbound_interface, outbound_interface.node, 0)

function calculateMessages!(node::Node)
    # Calculate the outbound messages on all interfaces of node.
    for interface in node.interfaces
        calculateMessage!(interface, node)
    end
end

# Calculate forward/backward messages on an Edge
calculateForwardMessage!(edge::Edge) = calculateMessage!(edge.tail)
calculateBackwardMessage!(edge::Edge) = calculateMessage!(edge.head)

function calculateMarginal(forward_msg::Message, backward_msg::Message)
    # Calculate the marginal from a forward/backward message pair.
    # We calculate the marginal by using an EqualityNode.
    # The forward and backward messages are inbound messages to the EqualityNode.
    # The outbound message is the marginal.
    @assert(typeof(forward_msg)==typeof(backward_msg), "Cannot create marginal from forward/backward messages of different types.")
    eq_node = EqualityNode(3)
    inbound_messages = Array(typeof(forward_msg), 3)
    inbound_messages[1] = forward_msg
    inbound_messages[2] = backward_msg
    marginal_msg = deepcopy(ForneyLab.updateNodeMessage!(3, eq_node, inbound_messages))
    return marginal_msg
end

function calculateMarginal(edge::Edge)
    # Calculate the marginal message on an edge
    # This method assumes that the tail and head interfaces hold (valid or invalid) messages.
    @assert(typeof(edge.tail)==Interface, "Edge should be bound to a tail interface.")
    @assert(typeof(edge.head)==Interface, "Edge should be bound to a head interface.")
    @assert(typeof(edge.tail.message)<:Message, "Tail interface does not hold a message. First call calculateForwardMessage!(edge) or calculate the forward message in another way.")
    @assert(typeof(edge.head.message)<:Message, "Head interface does not hold a message. First call calculateBackwardMessage!(edge) or calculate the forward message in another way.")
    return calculateMarginal(edge.tail.message, edge.head.message)
end

function clearMessages!(node::Node)
    # Clear all outbound messages on the interfaces of node
    for interface in node.interfaces
        interface.message = nothing
        interface.message_valid = false
    end
end

function clearMessages!(edge::Edge)
   # Clear all messages on an edge.
   edge.head.message = nothing
   edge.head.message_valid = false
   edge.tail.message = nothing
   edge.tail.message_valid = false
end

function pushMessageInvalidations!(outbound_interface::Interface)
    # Invalidate all messages that depend on the message on outbound_interface.
    # We call two messages dependent when one message (parent message) is used for the calculation of the other (child message).
    # Dependence implies that alteration of the parent message invalidates the child message. 

    # This method invalidates all outbound messages of a node except the message for the argument interface's partner (partner of outbound_interface),
    # and makes a recursive call to all connected nodes to do the same.
    outbound_interface.message_valid = false
    if typeof(outbound_interface.partner)==Interface
        connected_node = outbound_interface.partner.node
        for interface_id = 1:length(connected_node.interfaces)
            if is(outbound_interface.partner, connected_node.interfaces[interface_id]) continue end # skip the inbound interface
            was_valid = connected_node.interfaces[interface_id].message_valid
            connected_node.interfaces[interface_id].message_valid = false
            # was_valid ensured that recursion stops when an already invalid message is encountered.
            if was_valid && typeof(connected_node.interfaces[interface_id].message)!=Nothing # Recurse into the children only when the message was valid and present.
                # This performs a DFS through the graph, invalidating all messages that depend on connected_node.interfaces[interface_id].message
                pushMessageInvalidations!(connected_node.interfaces[interface_id])
            end
        end
    end
end

end # module ForneyLab