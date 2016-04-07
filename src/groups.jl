##################
# BenchmarkGroup #
##################

immutable BenchmarkGroup
    tags::Vector{UTF8String}
    data::Dict{Any,Any}
end

BenchmarkGroup(tags::Vector) = BenchmarkGroup(tags, Dict())
BenchmarkGroup(tags::AbstractString...) = BenchmarkGroup(collect(UTF8String, tags))

function newgroup!(suite::BenchmarkGroup, id, args...)
    g = BenchmarkGroup(args...)
    suite[id] = g
    return g
end

# Dict-like methods #
#-------------------#

Base.(:(==))(a::BenchmarkGroup, b::BenchmarkGroup) = a.tags == b.tags && a.data == b.data
Base.copy(group::BenchmarkGroup) = BenchmarkGroup(copy(group.tags), copy(group.data))
Base.similar(group::BenchmarkGroup) = BenchmarkGroup(copy(group.tags), similar(group.data))
Base.isempty(group::BenchmarkGroup) = isempty(group.data)
Base.length(group::BenchmarkGroup) = length(group.data)
Base.getindex(group::BenchmarkGroup, k...) = getindex(group.data, k...)
Base.setindex!(group::BenchmarkGroup, v, k...) = setindex!(group.data, v, k...)
Base.delete!(group::BenchmarkGroup, v, k...) = delete!(group.data, v, k...)
Base.haskey(group::BenchmarkGroup, k) = haskey(group.data, k)
Base.keys(group::BenchmarkGroup) = keys(group.data)
Base.values(group::BenchmarkGroup) = values(group.data)
Base.start(group::BenchmarkGroup) = start(group.data)
Base.next(group::BenchmarkGroup, state) = next(group.data, state)
Base.done(group::BenchmarkGroup, state) = done(group.data, state)

# mapping/filtering #
#-------------------#

andexpr(a, b) = :($a && $b)
andreduce(preds) = reduce(andexpr, preds)

@generated function mapvals!(f, dest::BenchmarkGroup, srcs::BenchmarkGroup...)
    haskeys = andreduce([:(haskey(srcs[$i], k)) for i in 1:length(srcs)])
    getinds = [:(srcs[$i][k]) for i in 1:length(srcs)]
    return quote
        for k in keys(first(srcs))
            if $(haskeys)
                dest[k] = f($(getinds...))
            end
        end
        return dest
    end
end

mapvals!(f, group::BenchmarkGroup) = mapvals!(f, similar(group), group)
mapvals(f, groups::BenchmarkGroup...) = mapvals!(f, similar(first(groups)), groups...)

filtervals!(f, group::BenchmarkGroup) = (filter!((k, v) -> f(v), group.data); return group)
filtervals(f, group::BenchmarkGroup) = filtervals!(f, copy(group))

Base.filter!(f, group::BenchmarkGroup) = (filter!(f, group.data); return group)
Base.filter(f, group::BenchmarkGroup) = filter!(f, copy(group))

# benchmark-related methods #
#---------------------------#

Base.minimum(group::BenchmarkGroup) = mapvals(minimum, group)
Base.maximum(group::BenchmarkGroup) = mapvals(maximum, group)
Base.mean(group::BenchmarkGroup) = mapvals(mean, group)
Base.median(group::BenchmarkGroup) = mapvals(median, group)
Base.min(groups::BenchmarkGroup...) = mapvals(min, groups...)
Base.max(groups::BenchmarkGroup...) = mapvals(max, groups...)

Base.time(group::BenchmarkGroup) = mapvals(time, group)
gctime(group::BenchmarkGroup) = mapvals(gctime, group)
memory(group::BenchmarkGroup) = mapvals(memory, group)
allocs(group::BenchmarkGroup) = mapvals(allocs, group)
params(group::BenchmarkGroup) = mapvals(params, group)

ratio(groups::BenchmarkGroup...) = mapvals(ratio, groups...)
judge(groups::BenchmarkGroup...; kwargs...) = mapvals((x...) -> judge(x...; kwargs...), groups...)

rmskew!(group::BenchmarkGroup) = mapvals!(rmskew!, group)
rmskew(group::BenchmarkGroup) = mapvals(rmskew, group)

isregression(group::BenchmarkGroup) = any(isregression, values(group))
isimprovement(group::BenchmarkGroup) = any(isimprovement, values(group))
isinvariant(group::BenchmarkGroup) = all(isinvariant, values(group))

invariants(x) = x
regressions(x) = x
improvements(x) = x
invariants(group::BenchmarkGroup) = mapvals!(invariants, filtervals(isinvariant, group))
regressions(group::BenchmarkGroup) = mapvals!(regressions, filtervals(isregression, group))
improvements(group::BenchmarkGroup) = mapvals!(improvements, filtervals(isimprovement, group))

function loadparams!(group::BenchmarkGroup, paramgroup::BenchmarkGroup)
    for (k, v) in paramgroup
        loadparams!(group[k], v)
    end
    return group
end


# tagging #
#---------#

immutable TagFilter{P}
    pred::P
end

istagged(id, group::BenchmarkGroup, tag) = tag == id || in(tag, group.tags)

macro tagged(pred)
    return :(BenchmarkTools.TagFilter((id, group) -> $(tagpred!(pred, :id, :group))))
end

tagpred!(item::AbstractString, id::Symbol, group::Symbol) = :(istagged($id, $group, $item))
tagpred!(item::Symbol, id::Symbol, group::Symbol) = item == :ALL ? true : item

function tagpred!(expr::Expr, id::Symbol, group::Symbol)
    for i in eachindex(expr.args)
        expr.args[i] = tagpred!(expr.args[i], id, group)
    end
    return expr
end

Base.getindex(group::BenchmarkGroup, f::TagFilter) = filter(f.pred, group)

# indexing by BenchmarkGroup #
#----------------------------#

function Base.getindex(group::BenchmarkGroup, x::BenchmarkGroup)
    result = BenchmarkGroup()
    for (k, v) in x
        result[k] = isa(v, BenchmarkGroup) ? group[k][v] : group[k]
    end
    return result
end

Base.setindex!(group::BenchmarkGroup, v, k::BenchmarkGroup) = error("A BenchmarkGroup cannot be a key in a BenchmarkGroup")

# pretty printing #
#-----------------#

tagrepr(tags) = string("[", join(map(repr, tags), ", "), "]")

function Base.show(io::IO, group::BenchmarkGroup, pad = ""; verbose = false)
    println(io, "BenchmarkTools.BenchmarkGroup:")
    print(io, pad, "  tags: ", tagrepr(group.tags))
    for (k, v) in group
        println(io)
        print(io, pad, "  ", repr(k), " => ")
        if verbose
            isa(v, BenchmarkGroup) ? show(io, v, "\t"*pad) : show(io, v)
        else
            showcompact(io, v)
        end
    end
end

Base.showall(io::IO, group::BenchmarkGroup) = show(io, group, verbose = true)

Base.showcompact(io::IO, group::BenchmarkGroup) = print(io, "BenchmarkGroup($(tagrepr(group.tags)))")
