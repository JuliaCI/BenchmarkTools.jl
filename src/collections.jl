abstract AbstractBenchmarkCollection <: Associative

Base.length(c::AbstractBenchmarkCollection) = length(data(c))
Base.getindex(c::AbstractBenchmarkCollection, k...) = getindex(data(c), k...)
Base.setindex!(c::AbstractBenchmarkCollection, v, k...) = setindex!(data(c), v, k...)
Base.delete!(c::AbstractBenchmarkCollection, v, k...) = delete!(data(c), v, k...)
Base.haskey(c::AbstractBenchmarkCollection, k) = haskey(data(c), k)
Base.keys(c::AbstractBenchmarkCollection) = keys(data(c))
Base.values(c::AbstractBenchmarkCollection) = values(data(c))
Base.start(c::AbstractBenchmarkCollection) = start(data(c))
Base.next(c::AbstractBenchmarkCollection, state) = next(data(c), state)
Base.done(c::AbstractBenchmarkCollection, state) = done(data(c), state)

function Base.map{C<:AbstractBenchmarkCollection}(f, a::C, b::C)
    result = similar(a)
    for id in keys(a)
        if haskey(b, id)
            result[id] = f(a[id], b[id])
        end
    end
    return result
end

function Base.map(f, c::AbstractBenchmarkCollection)
    result = similar(c)
    for (k, v) in c
        result[k] = f(v)
    end
    return result
end

Base.filter!(f, c::AbstractBenchmarkCollection) = (filter!((k, v) -> f(v), data(c)); return c)
Base.filter(f, c::AbstractBenchmarkCollection) = filter!(f, copy(c))
Base.count(f, c::AbstractBenchmarkCollection) = count(f, values(data(c)))

Base.time(c::AbstractBenchmarkCollection) = map(time, c)
gctime(c::AbstractBenchmarkCollection) = map(gctime, c)
memory(c::AbstractBenchmarkCollection) = map(memory, c)
allocs(c::AbstractBenchmarkCollection) = map(allocs, c)
ratio(a::AbstractBenchmarkCollection, b::AbstractBenchmarkCollection) = map(ratio, a, b)
ratio(c::AbstractBenchmarkCollection) = map(ratio, c)
judge(a::AbstractBenchmarkCollection, b::AbstractBenchmarkCollection, args...) = map((x, y) -> judge(x, y, args...), a, b)
hasjudgement(c::AbstractBenchmarkCollection, sym::Symbol) = count(trial -> hasjudgement(trial, sym), c) > 0
hasimprovement(c::AbstractBenchmarkCollection) = count(hasimprovement, c) > 0
hasregression(c::AbstractBenchmarkCollection) = count(hasregression, c) > 0
Base.minimum(c::AbstractBenchmarkCollection) = map(minimum, c)

##################
# BenchmarkGroup #
##################

immutable BenchmarkGroup <: AbstractBenchmarkCollection
    id::Tag
    tags::Vector{Tag}
    data::Dict{Any,Any}
end

BenchmarkGroup(id, tags) = BenchmarkGroup(id, tags, Dict())

data(group::BenchmarkGroup) = group.data

Base.copy(group::BenchmarkGroup) = BenchmarkGroup(group.id, copy(group.tags), copy(data(group)))
Base.similar(group::BenchmarkGroup) = BenchmarkGroup(group.id, copy(group.tags), similar(data(group)))

###########
# tagging #
###########

immutable TagFilter{P}
    pred::P
end

hastag(group::BenchmarkGroup, tag) = tag == group.id || in(tag, group.tags)

macro tagged(pred)
    return :(BenchmarkTools.TagFilter(g -> $(tagpred!(pred, :g))))
end

tagpred!(item::AbstractString, sym::Symbol) = :(hastag($sym, $item))
tagpred!(item::Symbol, sym::Symbol) = item == :ALL ? true : item

function tagpred!(expr::Expr, sym::Symbol)
    for i in eachindex(expr.args)
        expr.args[i] = tagpred!(expr.args[i], sym)
    end
    return expr
end

###################
# GroupCollection #
###################

immutable GroupCollection <: AbstractBenchmarkCollection
    data::Dict{Tag,BenchmarkGroup}
end

GroupCollection() = GroupCollection(Dict{Tag,BenchmarkGroup}())

data(groups::GroupCollection) = groups.data

Base.copy(groups::GroupCollection) = GroupCollection(copy(data(groups)))
Base.similar(groups::GroupCollection) = GroupCollection(similar(data(groups)))
Base.getindex(groups::GroupCollection, filt::TagFilter) = filter(filt.pred, groups)

addgroup!(groups::GroupCollection, id, tags::AbstractString...) = addgroup!(groups, id, collect(tags))
addgroup!(groups::GroupCollection, id, tags::Vector) = addgroup!(groups, BenchmarkGroup(id, tags))

function addgroup!(groups::GroupCollection, group::BenchmarkGroup)
    @assert !(haskey(groups, group.id)) "GroupCollection already has group with ID \"$(group.id)\""
    groups[group.id] = group
    return group
end

###################
# Pretty Printing #
###################

tagrepr(tags) = string("[", join(map(x -> "\"$x\"", tags), ", "), "]")

function Base.show(io::IO, group::BenchmarkGroup, pad = "")
    println(io, pad, "BenchmarkTools.BenchmarkGroup \"", group.id, "\":")
    print(io, pad, "  tags: ", tagrepr(group.tags))
    for (k, v) in group
        println(io)
        print(io, pad, "  ", k, " => ")
        showcompact(io, v)
    end
end

function Base.show(io::IO, groups::GroupCollection)
    print(io, "BenchmarkTools.GroupCollection:")
    for group in values(groups)
        println(io)
        showcompact(io, group, "  ")
    end
end

# This definition is annoying on v0.5, where showcompact is used instead of show by default
# Base.showcompact(io::IO, group::BenchmarkGroup) = print(io, " BenchmarkGroup(\"$(group.id)\", $(tagrepr(group.tags)))")
