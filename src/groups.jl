##################
# BenchmarkGroup #
##################

struct BenchmarkGroup
    tags::Vector{Any}
    data::Dict{Any,Any}
end

BenchmarkGroup(tags::Vector, args::Pair...) = BenchmarkGroup(tags, Dict(args...))
BenchmarkGroup(args::Pair...) = BenchmarkGroup([], args...)

function addgroup!(suite::BenchmarkGroup, id, args...)
    g = BenchmarkGroup(args...)
    suite[id] = g
    return g
end

# Dict-like methods #
#-------------------#

Base.:(==)(a::BenchmarkGroup, b::BenchmarkGroup) = a.tags == b.tags && a.data == b.data
Base.copy(group::BenchmarkGroup) = BenchmarkGroup(copy(group.tags), copy(group.data))
Base.similar(group::BenchmarkGroup) = BenchmarkGroup(copy(group.tags), empty(group.data))
Base.isempty(group::BenchmarkGroup) = isempty(group.data)
Base.length(group::BenchmarkGroup) = length(group.data)
Base.getindex(group::BenchmarkGroup, i...) = getindex(group.data, i...)
Base.setindex!(group::BenchmarkGroup, i...) = setindex!(group.data, i...)
Base.delete!(group::BenchmarkGroup, k...) = delete!(group.data, k...)
Base.haskey(group::BenchmarkGroup, k) = haskey(group.data, k)
Base.keys(group::BenchmarkGroup) = keys(group.data)
Base.values(group::BenchmarkGroup) = values(group.data)
Base.iterate(group::BenchmarkGroup, i=1) = iterate(group.data, i)

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

filtervals!(f, group::BenchmarkGroup) = (filter!(kv -> f(kv[2]), group.data); return group)
filtervals(f, group::BenchmarkGroup) = filtervals!(f, copy(group))

Base.filter!(f, group::BenchmarkGroup) = (filter!(f, group.data); return group)
Base.filter(f, group::BenchmarkGroup) = filter!(f, copy(group))

# benchmark-related methods #
#---------------------------#

Base.minimum(group::BenchmarkGroup) = mapvals(minimum, group)
Base.maximum(group::BenchmarkGroup) = mapvals(maximum, group)
Statistics.mean(group::BenchmarkGroup) = mapvals(mean, group)
Statistics.median(group::BenchmarkGroup) = mapvals(median, group)
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

function loadparams!(group::BenchmarkGroup, paramsgroup::BenchmarkGroup, fields...)
    for (k, v) in group
        haskey(paramsgroup, k) && loadparams!(v, paramsgroup[k], fields...)
    end
    return group
end

# leaf iteration/indexing #
#-------------------------#

leaves(group::BenchmarkGroup) = leaves!(Any[], Any[], group)

function leaves!(results, parents, group::BenchmarkGroup)
    for (k, v) in group
        keys = vcat(parents, k)
        if isa(v, BenchmarkGroup)
            leaves!(results, keys, v)
        else
            push!(results, (keys, v))
        end
    end
    return results
end

function Base.getindex(group::BenchmarkGroup, keys::Vector)
    k = first(keys)
    v = length(keys) == 1 ? group[k] : group[k][keys[2:end]]
    return v
end

function Base.setindex!(group::BenchmarkGroup, x, keys::Vector)
    k = first(keys)
    if length(keys) == 1
        group[k] = x
        return x
    else
        if !haskey(group, k)
            group[k] = BenchmarkGroup()
        end
        return setindex!(group[k], x, keys[2:end])
    end
end

# tagging #
#---------#

struct TagFilter{P}
    predicate::P
end

macro tagged(expr)
    return esc(:(BenchmarkTools.TagFilter(tags -> $(tagpredicate!(expr)))))
end

tagpredicate!(tag) = :(in($tag, tags))

function tagpredicate!(sym::Symbol)
    sym == :! && return sym
    sym == :ALL && return true
    return :(in($sym, tags))
end

# build the body of the tag predicate in place
function tagpredicate!(expr::Expr)
    expr.head == :quote && return :(in($expr, tags))
    for i in eachindex(expr.args)
        expr.args[i] = tagpredicate!(expr.args[i])
    end
    return expr
end

function Base.getindex(src::BenchmarkGroup, f::TagFilter)
    dest = similar(src)
    loadtagged!(f, dest, src, src, Any[], src.tags)
    return dest
end

# normal union doesn't have the behavior we want
# (e.g. union(["1"], "2") === ["1", '2'])
keyunion(args...) = unique(vcat(args...))

function tagunion(args...)
    unflattened = keyunion(args...)
    result = Any[]
    for i in unflattened
        if isa(i, Tuple)
            for j in i
                push!(result, j)
            end
        else
            push!(result, i)
        end
    end
    return result
end

function loadtagged!(f::TagFilter, dest::BenchmarkGroup, src::BenchmarkGroup,
                     group::BenchmarkGroup, keys::Vector, tags::Vector)
    if f.predicate(tags)
        child_dest = createchild!(dest, src, keys)
        for (k, v) in group
            if isa(v, BenchmarkGroup)
                loadtagged!(f, dest, src, v, keyunion(keys, k), tagunion(tags, k, v.tags))
            elseif isa(child_dest, BenchmarkGroup)
                child_dest[k] = v
            end
        end
    else
        for (k, v) in group
            if isa(v, BenchmarkGroup)
                loadtagged!(f, dest, src, v, keyunion(keys, k), tagunion(tags, k, v.tags))
            elseif f.predicate(tagunion(tags, k))
                createchild!(dest, src, keyunion(keys, k))
            end
        end
    end
    return dest
end

function createchild!(dest, src, keys)
    if isempty(keys)
        return dest
    else
        k = first(keys)
        src_child = src[k]
        if !(haskey(dest, k))
            isgroup = isa(src_child, BenchmarkGroup)
            dest_child = isgroup ? similar(src_child) : src_child
            dest[k] = dest_child
            !(isgroup) && return
        else
            dest_child = dest[k]
        end
        return createchild!(dest_child, src_child, keys[2:end])
    end
end

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

Base.summary(io::IO, group::BenchmarkGroup) = print(io, "$(length(group))-element BenchmarkGroup($(tagrepr(group.tags)))")

function Base.show(io::IO, group::BenchmarkGroup)
    println(io, "$(length(group))-element BenchmarkTools.BenchmarkGroup:")
    pad = get(io, :pad, "")
    print(io, pad, "  tags: ", tagrepr(group.tags))
    count = 1
    for (k, v) in group
        println(io)
        print(io, pad, "  ", repr(k), " => ")
        show(IOContext(io, :pad => "\t"*pad), v)
        count > get(io, :limit, 10) && (println(io); print(io, pad, "  ⋮"); break)
        count += 1
    end
end
