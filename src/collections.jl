abstract AbstractBenchmarkCollection

Base.isempty(c::AbstractBenchmarkCollection) = isempty(data(c))
Base.length(c::AbstractBenchmarkCollection) = length(data(c))
Base.getindex(c::AbstractBenchmarkCollection, k...) = getindex(data(c), k...)
Base.setindex!(c::AbstractBenchmarkCollection, v, k...) = setindex!(data(c), v, k...)
Base.delete!(c::AbstractBenchmarkCollection, v, k...) = delete!(data(c), v, k...)
Base.haskey(c::AbstractBenchmarkCollection, k) = haskey(data(c), k)
Base.keys(c::AbstractBenchmarkCollection) = keys(data(c))
Base.values(c::AbstractBenchmarkCollection) = values(data(c))
Base.start(c::AbstractBenchmarkCollection) = start(values(c))
Base.next(c::AbstractBenchmarkCollection, state) = next(values(c), state)
Base.done(c::AbstractBenchmarkCollection, state) = done(values(c), state)

@generated function Base.map!{C<:AbstractBenchmarkCollection}(f, dest::C, src::C...)
    getinds = [:(src[$i][k]) for i in 1:length(src)]
    return quote
        for k in keys(first(src))
            dest[k] = f($(getinds...))
        end
        return dest
    end
end

Base.map!(f, c::AbstractBenchmarkCollection) = map!(f, similar(c), c)
Base.map(f, c::AbstractBenchmarkCollection...) = map!(f, similar(first(c)), c...)
Base.filter!(f, c::AbstractBenchmarkCollection) = (filter!((k, v) -> f(v), data(c)); return c)
Base.filter(f, c::AbstractBenchmarkCollection) = filter!(f, copy(c))

Base.linreg(c::AbstractBenchmarkCollection) = map(linreg, c)
Base.minimum(c::AbstractBenchmarkCollection) = map(minimum, c)

Base.time(c::AbstractBenchmarkCollection) = map(time, c)
gctime(c::AbstractBenchmarkCollection) = map(gctime, c)
memory(c::AbstractBenchmarkCollection) = map(memory, c)
allocs(c::AbstractBenchmarkCollection) = map(allocs, c)
fitness(c::AbstractBenchmarkCollection) = map(fitness, c)
ratio(a::AbstractBenchmarkCollection, b::AbstractBenchmarkCollection) = map(ratio, a, b)
ratio(c::AbstractBenchmarkCollection) = map(ratio, c)
judge(a::AbstractBenchmarkCollection, b::AbstractBenchmarkCollection, args...) = map((x, y) -> judge(x, y, args...), a, b)
judge(c::AbstractBenchmarkCollection, args...) = map(x -> judge(x, args...), c)
hasregression(c::AbstractBenchmarkCollection) = any(hasregression, c)
hasimprovement(c::AbstractBenchmarkCollection) = any(hasimprovement, c)

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

Base.(:(==))(a::BenchmarkGroup, b::BenchmarkGroup) = a.id == b.id && a.tags == b.tags && data(a) == data(b)
Base.copy(group::BenchmarkGroup) = BenchmarkGroup(group.id, copy(group.tags), copy(data(group)))
Base.similar(group::BenchmarkGroup) = BenchmarkGroup(group.id, copy(group.tags), similar(data(group)))

regressions(group::BenchmarkGroup) = filter(hasregression, group)
improvements(group::BenchmarkGroup) = filter(hasimprovement, group)

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
    GroupCollection(args...) = new(Dict{Tag,BenchmarkGroup}(args...))
end

data(groups::GroupCollection) = groups.data

Base.(:(==))(a::GroupCollection, b::GroupCollection) = data(a) == data(b)
Base.copy(groups::GroupCollection) = GroupCollection(copy(data(groups)))
Base.similar(groups::GroupCollection) = GroupCollection(similar(data(groups)))
Base.getindex(groups::GroupCollection, filt::TagFilter) = filter(filt.pred, groups)

regressions(groups::GroupCollection) = filter!(g -> !(isempty(g)), map(regressions, groups))
improvements(groups::GroupCollection) = filter!(g -> !(isempty(g)), map(improvements, groups))

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

tagrepr(tags) = string("[", join(map(repr, tags), ", "), "]")

function Base.show(io::IO, group::BenchmarkGroup, pad = "")
    println(io, pad, "BenchmarkTools.BenchmarkGroup \"", group.id, "\":")
    print(io, pad, "  tags: ", tagrepr(group.tags))
    for k in keys(group)
        println(io)
        print(io, pad, "  ", repr(k), " => ")
        showcompact(io, group[k])
    end
end

function Base.show(io::IO, groups::GroupCollection)
    print(io, "BenchmarkTools.GroupCollection:")
    for group in groups
        println(io)
        show(io, group, "  ")
    end
end

# This definition is annoying on v0.5, where showcompact is used instead of show by default
# Base.showcompact(io::IO, group::BenchmarkGroup) = print(io, " BenchmarkGroup(\"$(group.id)\", $(tagrepr(group.tags)))")
