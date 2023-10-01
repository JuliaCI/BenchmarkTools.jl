##################
# BenchmarkGroup #
##################

const KeyTypes = Union{String,Int,Float64}
makekey(v::KeyTypes) = v
makekey(v::Real) = (v2 = Float64(v); v2 == v ? v2 : string(v))
makekey(v::Integer) = typemin(Int) <= v <= typemax(Int) ? Int(v) : string(v)
function makekey(v::Tuple)
    return (
        Any[i isa Tuple ? string(i) : makekey(i) for i in v]...,
    )::Tuple{Vararg{KeyTypes}}
end
makekey(v::Any) = string(v)::String

struct BenchmarkGroup
    tags::Vector{Any}
    data::Dict{Any,Any}
end

function BenchmarkGroup(tags::Vector, args::Pair...)
    return BenchmarkGroup(tags, Dict{Any,Any}((makekey(k) => v for (k, v) in args)))
end
BenchmarkGroup(args::Pair...) = BenchmarkGroup([], args...)

function addgroup!(suite::BenchmarkGroup, id, args...)
    g = BenchmarkGroup(args...)
    suite[id] = g
    return g
end

"""
    clear_empty!(group::BenchmarkGroup)

Recursively remove any empty subgroups from `group`.

Use this to prune a `BenchmarkGroup` after accessing the incorrect
fields, such as `g=BenchmarkGroup(); g[1]`, without storing
anything to `g[1]`, which will create an empty subgroup `g[1]`.
"""
function clear_empty!(group::BenchmarkGroup)
    for (k, v) in pairs(group)
        if v isa BenchmarkGroup && isempty(v)
            delete!(group, k)
        end
    end
    return group
end
clear_empty!(x) = x

# Dict-like methods #
#-------------------#

Base.:(==)(a::BenchmarkGroup, b::BenchmarkGroup) = a.tags == b.tags && a.data == b.data
Base.copy(group::BenchmarkGroup) = BenchmarkGroup(copy(group.tags), copy(group.data))
Base.similar(group::BenchmarkGroup) = BenchmarkGroup(copy(group.tags), empty(group.data))

"""
    isempty(group::BenchmarkGroup)

Return `true` if `group` is empty. This will first
run `clear_empty!` on `group` to recursively remove any empty subgroups.
"""
Base.isempty(group::BenchmarkGroup) = isempty(clear_empty!(group).data)

Base.length(group::BenchmarkGroup) = length(group.data)
Base.getindex(group::BenchmarkGroup, k) = get!(group.data, makekey(k), BenchmarkGroup())
Base.getindex(group::BenchmarkGroup, k...) = get!(group.data, makekey(k), BenchmarkGroup())
Base.setindex!(group::BenchmarkGroup, v, k) = setindex!(group.data, v, makekey(k))
Base.setindex!(group::BenchmarkGroup, v, k...) = setindex!(group.data, v, makekey(k))
Base.delete!(group::BenchmarkGroup, k) = delete!(group.data, makekey(k))
Base.delete!(group::BenchmarkGroup, k...) = delete!(group.data, makekey(k))
Base.haskey(group::BenchmarkGroup, k) = haskey(group.data, makekey(k))
Base.haskey(group::BenchmarkGroup, k...) = haskey(group.data, makekey(k))
Base.keys(group::BenchmarkGroup) = keys(group.data)
Base.values(group::BenchmarkGroup) = values(group.data)
Base.iterate(group::BenchmarkGroup, i=1) = iterate(group.data, i)

# mapping/filtering #
#-------------------#

andexpr(a, b) = :($a && $b)
andreduce(preds) = reduce(andexpr, preds)

function mapvals!(f, dest::BenchmarkGroup, srcs::BenchmarkGroup...)
    for k in keys(first(srcs))
        if all(s -> haskey(s, k), srcs)
            dest[k] = f((s[k] for s in srcs)...)
        end
    end
    return dest
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
Statistics.std(group::BenchmarkGroup) = mapvals(std, group)
Statistics.var(group::BenchmarkGroup) = mapvals(var, group)
Base.min(groups::BenchmarkGroup...) = mapvals(min, groups...)
Base.max(groups::BenchmarkGroup...) = mapvals(max, groups...)

Base.time(group::BenchmarkGroup) = mapvals(time, group)
gctime(group::BenchmarkGroup) = mapvals(gctime, group)
memory(group::BenchmarkGroup) = mapvals(memory, group)
allocs(group::BenchmarkGroup) = mapvals(allocs, group)
params(group::BenchmarkGroup) = mapvals(params, group)

ratio(groups::BenchmarkGroup...) = mapvals(ratio, groups...)
function judge(groups::BenchmarkGroup...; kwargs...)
    return mapvals((x...) -> judge(x...; kwargs...), groups...)
end

rmskew!(group::BenchmarkGroup) = mapvals!(rmskew!, group)
rmskew(group::BenchmarkGroup) = mapvals(rmskew, group)

isregression(f, group::BenchmarkGroup) = any((x) -> isregression(f, x), values(group))
isregression(group::BenchmarkGroup) = any(isregression, values(group))

isimprovement(f, group::BenchmarkGroup) = any((x) -> isimprovement(f, x), values(group))
isimprovement(group::BenchmarkGroup) = any(isimprovement, values(group))

isinvariant(f, group::BenchmarkGroup) = all((x) -> isinvariant(f, x), values(group))
isinvariant(group::BenchmarkGroup) = all(isinvariant, values(group))

invariants(f, x) = x
invariants(x) = x

regressions(f, x) = x
regressions(x) = x

improvements(f, x) = x
improvements(x) = x

function invariants(f, group::BenchmarkGroup)
    return mapvals!((x) -> invariants(f, x), filtervals((x) -> isinvariant(f, x), group))
end
invariants(group::BenchmarkGroup) = mapvals!(invariants, filtervals(isinvariant, group))

function regressions(f, group::BenchmarkGroup)
    return mapvals!((x) -> regressions(f, x), filtervals((x) -> isregression(f, x), group))
end
regressions(group::BenchmarkGroup) = mapvals!(regressions, filtervals(isregression, group))

function improvements(f, group::BenchmarkGroup)
    return mapvals!(
        (x) -> improvements(f, x), filtervals((x) -> isimprovement(f, x), group)
    )
end
function improvements(group::BenchmarkGroup)
    return mapvals!(improvements, filtervals(isimprovement, group))
end

function loadparams!(group::BenchmarkGroup, paramsgroup::BenchmarkGroup, fields...)
    for (k, v) in group
        haskey(paramsgroup, k) && loadparams!(v, paramsgroup[k], fields...)
    end
    return group
end

# leaf iteration/indexing #
#-------------------------#

leaves(group::BenchmarkGroup) = leaves!([], [], group)

function leaves!(results, parents, group::BenchmarkGroup)
    for (k, v) in group
        keys = Base.typed_vcat(Any, parents, k)
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

struct TagFilter
    predicate
end

macro tagged(expr)
    return :(BenchmarkTools.TagFilter(tags -> $(tagpredicate!(expr))))
end

tagpredicate!(@nospecialize tag) = :(in(makekey($(esc(tag))), tags))

function tagpredicate!(sym::Symbol)
    sym == :ALL && return true
    return :(in(makekey($(esc(sym))), tags))
end

# build the body of the tag predicate in place
function tagpredicate!(expr::Expr)
    expr.head == :quote && return :(in(makekey($(esc(expr))), tags))
    for i in 1:length(expr.args)
        f = (i == 1 && expr.head === :call ? esc : tagpredicate!)
        expr.args[i] = f(expr.args[i])
    end
    return expr
end

function Base.getindex(src::BenchmarkGroup, f::TagFilter)
    dest = similar(src)
    loadtagged!(f, dest, src, src, [], src.tags)
    return dest
end

# normal union doesn't have the behavior we want
# (e.g. union(["1"], "2") === ["1", '2'])
keyunion(args...) = unique(Base.typed_vcat(Any, args...))

function tagunion(args...)
    unflattened = keyunion(args...)
    result = []
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

function loadtagged!(
    f::TagFilter,
    dest::BenchmarkGroup,
    src::BenchmarkGroup,
    group::BenchmarkGroup,
    keys::Vector,
    tags::Vector,
)
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
            !(isgroup) && return nothing
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

function Base.setindex!(group::BenchmarkGroup, v, k::BenchmarkGroup)
    return error("A BenchmarkGroup cannot be a key in a BenchmarkGroup")
end

# pretty printing #
#-----------------#

tagrepr(tags) = string("[", join(map(repr, tags), ", "), "]")

function Base.summary(io::IO, group::BenchmarkGroup)
    return print(io, "$(length(group))-element BenchmarkGroup($(tagrepr(group.tags)))")
end

function Base.show(io::IO, group::BenchmarkGroup)
    limit = get(io, :limit, true)
    if !(limit isa Bool)
        msg = (
            "`show(IOContext(io, :limit => number), group::BenchmarkGroup)` is" *
            " deprecated. Please use `IOContext(io, :boundto => number)` to" *
            " bound the number of elements to be shown."
        )
        Base.depwarn(msg, :show)
        nbound = get(io, :boundto, limit)
    elseif limit === false
        nbound = Inf
    else
        nbound = get(io, :boundto, 10)
    end

    println(io, "$(length(group))-element BenchmarkTools.BenchmarkGroup:")
    pad = get(io, :pad, "")
    print(io, pad, "  tags: ", tagrepr(group.tags))
    count = 1
    for (k, v) in group
        println(io)
        print(io, pad, "  ", repr(k), " => ")
        show(IOContext(io, :pad => "\t" * pad), v)
        count += 1
        count > nbound &&
            length(group) > count &&
            (println(io); print(io, pad, "  ⋮"); break)
    end
end

const benchmark_stack = []

"""
    @benchmarkset "title" begin ... end

Create a benchmark set, or multiple benchmark sets if a `for` loop is provided.

# Examples

```julia
@benchmarkset "suite" for k in 1:5
    @case "case \$k" rand(\$k, \$k)
end
```
"""
macro benchmarkset(title, ex)
    return esc(benchmarkset_m(title, ex))
end

"""
    @case title <expr to benchmark> [setup=<setup expr>]

Mark an expression as a benchmark case. Must be used inside [`@benchmarkset`](@ref).
"""
macro case(title, xs...)
    return esc(:($(Symbol("#suite#"))[$title] = @benchmarkable $(xs...)))
end

function benchmarkset_m(title, ex::Expr)
    stack = GlobalRef(BenchmarkTools, :benchmark_stack)
    init = quote
        if isempty($stack)
            push!($stack, $BenchmarkGroup())
        end
    end
    exec = quote
        if length($stack) == 1
            pop!($stack)
        end
    end
    return if ex.head === :block
        quote
            $init
            $(benchmarkset_block(title, ex))
            $exec
        end
    elseif ex.head === :for
        quote
            $init
            $(Expr(ex.head, ex.args[1], benchmarkset_block(title, ex.args[2])))
            $exec
        end
    end
end

function benchmarkset_block(title, ex::Expr)
    stack = GlobalRef(BenchmarkTools, :benchmark_stack)
    quote
        let $(Symbol("#root#")) = last($stack)
            $(Symbol("#suite#")) = $(Symbol("#root#"))[$title]
            push!($stack, $(Symbol("#suite#")))
            $ex
            pop!($stack)
        end
    end
end
