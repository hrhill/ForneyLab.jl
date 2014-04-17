############################################
# ConstantNode
############################################
# Description:
#   Simple node with just 1 interface.
#   Always sends out a constant (predefined) message.
#
# Interface ids, (names) and supported message types:
#   1. (interface):
#       Message
############################################

export ConstantNode

type ConstantNode <: Node
    constant::Message
    interfaces::Array{Interface,1}
    name::ASCIIString
    interface::Interface

    function ConstantNode(constant::Message, name::ASCIIString="#undef")
        self = new(constant, Array(Interface, 1), name)
        # Create interface
        self.interfaces[1] = Interface(self)
        # Init named interface handle
        self.interface = self.interfaces[1]
        return self
    end
end
ConstantNode() = ConstantNode(GeneralMessage(1.0))

function calculatemessage!{T<:Message}(
                            outbound_interface_id::Int,
                            node::ConstantNode,
                            inbound_messages::Array{T,1})

    # Just pass the unaltered message through
    node.interfaces[outbound_interface_id].message = node.constant
end