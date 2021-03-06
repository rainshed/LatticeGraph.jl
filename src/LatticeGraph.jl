module LatticeGraph

greet() = print("Hello World!")
using LinearAlgebra
import Base: display

#-------------------------------------------------------
export Node,Edge,LatGraph

mutable struct Node{T}
    pos::Vector{Int64}  # coordinate of the node
    edges::Vector{T}     # edges start from the node
end

function display(node::Node)
    println("position:",node.pos)
    if node.edges==[]
        println("no edges.")
    else
        println("Edges:")
        for i in 1:length(node.edges)
            display(node.edges[i])
        end
    end
end


mutable struct Edge{T<:Number,T1}
    node::Node{T1}        # node at which the edge end
    weight::T         # the weright of Edge
end

function display(E::Edge)
    println("->",E.node.pos,"  ","weight:",E.weight)
end


"""
LatGraph consists of nodes. It is embedded in a 2D rectangle or 3d cubiod which is decided by "size".
The nodes in LatGraph is listed in "nodes", and their coordinates are listed in "pos".

For example, if size = [5,8], the graph is embedded in a 5*8 rectangle. Some of integer coordinates like (3,2) are placed a node, and then [3,2] is an element of "pos".
"""
mutable struct LatGraph{T<:Node}
    size::Vector{Int64}
    pos::Vector{Vector{Int64}}
    nodes::Array{T}
end

function Base.display(G::LatGraph)
    if length(G.size)==2
        for j in 1:G.size[2]
            for i in 1:G.size[1]
                if [i,j] in G.pos
                   print(".")
                else
                   print(" ")
                end
            end
            println()
        end
    elseif length(G.size)==1
        println("one dimension chain with $(length(G.pos)) sites")
    else
        println("display function is to be finished")
    end
end

#------------------------------------------------------------
export AddEdge!, SquareGraph, ConMat

"""
Place a isolate node (a node without edges) at pos.
"""
function Node(pos::Vector{Int64})
    Node(pos,Edge[])
end

function AddEdge!(
    node::Node,
    edge::Edge
    )
    push!(node.edges,edge)
    node
end

"""
Add a edge point from "node1" to "node2" with weight "weight"
"""

function AddEdge!(
    node1::Node,
    node2::Node,
    weight::Number
)
    AddEdge!(node1,Edge(node2,weight))
end



function LatGraph(
    nodes::Vector{Node},
    size::Vector{<:Integer}
)
    pos = Vector{Int}[]
    nArray = Array{Node}(undef,size...)
    for i in 1:length(nodes)
        tpos = nodes[i].pos; 
        push!(pos,tpos);
        nArray[tpos...] = nodes[i]; 
    end
    LatGraph(size,pos,nArray)
end

Base.getindex(G::LatGraph,i::Integer...) = G.nodes[i...]
Base.size(G::LatGraph) = Tuple(G.size)
position(G::LatGraph) = G.pos

function AddEdge!(
    graph::LatGraph,
    relapos::Vector,
    weight::Number;
    BC::String = "OBC"
)
    length(graph.size) == length(relapos) || error("The length of 'graph.size' and 'relapos' doesn't match")

    if BC == "OBC"
        posi = graph.pos;
        nodes = graph.nodes;
        for i in 1:length(posi)
            initpos = posi[i];
            targpos = posi[i]+relapos;
            try
                nodes[targpos...];
            catch
                continue
            end
            AddEdge!(nodes[initpos...],nodes[targpos...],weight);
        end
    elseif BC == "PBC"
        posi = graph.pos;
        nodes = graph.nodes;
        for i in 1:length(posi)
            initpos = posi[i];
            targpos = mod.((posi[i]+relapos).-1,graph.size).+1;
            try
                nodes[targpos...];
            catch
                continue
            end
            AddEdge!(nodes[initpos...],nodes[targpos...],weight);
        end
    else
        error("'BC' can only be 'PBC' or 'OBC'.")
    end
end

function AddEdge!(
    graph::LatGraph,
    relapos::Vector,
    weight::Number,
    BC::Vector{String}
)
    length(BC) == length(graph.size) == length(relapos) || error("The length of 'BC', 'graph.size' and 'relapos' doesn't match")

    bc = Int[]
    for i in 1:length(BC)
        if BC[i] == "PBC"
            push!(bc,graph.size[i])
        elseif BC[i] == "OBC"
            push!(bc,1000000000)
        else
            error("Element of 'BC' can only be 'PBC' or 'OBC'.")
        end
    end

    posi = graph.pos;
    nodes = graph.nodes;
    for i in 1:length(posi)
        initpos = posi[i];
        targpos = mod.((posi[i]+relapos).-1,bc).+1;
        try
            nodes[targpos...];
        catch
            continue
        end
        AddEdge!(nodes[initpos...],nodes[targpos...],weight);
    end

end

function DelAllEdge!(G::LatGraph,pos::Vector{<:Integer})
    G[pos...].edges = Edge[]
end

function LatGraph(size::Vector{<:Integer})
    return LatGraph(x->true,size)
end
function SquareGraph(
    L::Integer
)
    pos = Vector{Int}[];
    nMatrix = Array{Node}(undef,L,L);
    for i in 1:L
        for j in 1:L
            push!(pos,[i,j]);
            nMatrix[i,j] = Node([i,j]);
        end
    end
    LatGraph([L,L],pos,nMatrix)
end

function LatGraph(f,size::Vector{Int64})
    pos = Vector{Int}[];
    nArray = Array{Node}(undef,size...);
    cube = Iterators.product([1:s for s in size]... )
    for coor in cube
        co = [i for i in coor]
        if f(co)
            push!(pos,co)
            nArray[coor...] = Node(co)
        end
    end
    LatGraph(size,pos,nArray)
end

function LatGraph(poly::Vector{Vector{Int}},size::Vector{Int64})
    a = 0
    for i in 1:length(poly)
        a += sum(poly[i].>size);
    end
    if a>0
        error("a point of 'poly' is out of size")
    end

    f = x->PointInPoly(x,poly);
    LatGraph(f,size);
end

function StateOnGraph(G::LatGraph, state::Vector)
    length(G.pos)==length(state) || error("dimension of LatGraph and state doesn't match.")
    sONg = zeros(eltype(state),G.size...)
    for i in 1:length(G.pos)
        sONg[G.pos[i]...] = state[i]
    end
    sONg
end

function LinearAlgebra.eigen(G::LatGraph)
    H = ConMat(G)
    vals,vec =  eigen(H)
    eigvec = [zeros(eltype(vec),G.size...) for i in 1:length(G.pos)]
    for i in 1:length(G.pos)
        eigvec[i] = StateOnGraph(G,vec[:,i])
    end
    vals,eigvec
end


"""
    test if point "pt" is in the polygon form by "plist".
"""
function PointInPoly(
    pt::Vector{<:Integer},             # test points
    plist::Vector{<:Vector{<:Integer}}   # the vertexes of polygon, two adjacent points form a edge of the polygon.
)

    LenMatch = false;
    for i in 1:length(plist)
        LenMatch = LenMatch && (length(pt) =! length(plist[i]));
    end

    if LenMatch
        error("dimension of points doesn't match")
    end

    if length(plist) < 3
        error("At least 3 points are needed to form a ploygon.")
    end

    nCorss = 0;
 
    for i in 1:length(plist)
        p1 = plist[i];
        p2 = plist[mod(i,length(plist))+1];


        if p1[2]==p2[2]
            if pt[2] == p1[2] && min(p1[1],p2[1])<pt[1]<max(p1[1],p2[1])
                return true;
            else
                continue;
            end
        end


        if pt[2]>max(p1[2],p2[2])
            continue;
        elseif pt[2]<min(p1[2],p2[2])
            continue;
        else
            
            x = (pt[2]-p1[2])*(p1[1]-p2[1])/(p1[2]-p2[2])+p1[1];
            if abs(x-pt[1])<1e-7
                return true
            end
            
            if x<=pt[1]
                nCorss +=1;
                if norm([x-p2[1],pt[2]-p2[2]])<1e-7 && p1[2]<p2[2]
                    nCorss -=1;
                elseif  norm([x-p1[1],pt[2]-p1[2]])<1e-7 && p1[2]>p2[2]
                    nCorss -=1;
                end
            end

        end
    end
    isodd(nCorss)
end

function ConMat(G::LatGraph)
    """
        Return connective matrix of LatGraph G.
        The bases are ranked by G.pos.  
    """
    H = zeros(ComplexF64,length(G.pos),length(G.pos));
    edgerepe = false
    for m in 1:length(G.pos)
        node = G.nodes[G.pos[m]...];
        edges = node.edges;
        for j in 1:length(edges)
            n = findfirst(x->x==edges[j].node.pos,G.pos)
            edgerepe = edgerepe || H[m,n]!=0
            H[m,n] = edges[j].weight
        end
    end
    if edgerepe
        @warn "There are two or more edges share two vertexes"
    end
    H
end

end # module
