##################
# BenchmarkGroup #
##################

immutable BenchmarkGroup
    id::Tag
    tags::Vector{Tag}
    benchmarks::Dict{Any,Any}
end

BenchmarkGroup(id, tags) = BenchmarkGroup(id, tags, Dict())

# indexing #
#----------#

Base.length(group::BenchmarkGroup) = length(group.benchmarks)
Base.copy(group::BenchmarkGroup) = BenchmarkGroup(group.id, copy(group.tags), copy(group.benchmarks))
Base.getindex(group::BenchmarkGroup, x...) = group.benchmarks[x...]
Base.setindex!(group::BenchmarkGroup, x, y...) = setindex!(group.benchmarks, x, y...)

# mapping/filtering #
#-------------------#

function mapvals(f, a::BenchmarkGroup, b::BenchmarkGroup)
    result = BenchmarkGroup(a.id, a.tags)
    for id in keys(a.benchmarks)
        if haskey(b.benchmarks, id)
            result[id] = f(a[id], b[id])
        end
    end
    return result
end

function mapvals!(f, result::BenchmarkGroup, group::BenchmarkGroup)
    for (id, val) in group.benchmarks
        result[id] = f(val)
    end
    return result
end

mapvals!(f, group::BenchmarkGroup) = mapvals!(f, group, copy(group))
mapvals(f, group::BenchmarkGroup) = mapvals!(f, BenchmarkGroup(group.id, group.tags), group)

Base.filter!(f, group::BenchmarkGroup) = (filter!(f, group.benchmarks); return group)
Base.filter(f, group::BenchmarkGroup) = BenchmarkGroup(group.id, group.tags, filter(f, group.benchmarks))

# value retrieval #
#-----------------#

Base.time(group::BenchmarkGroup) = mapvals(time, group)
gctime(group::BenchmarkGroup) = mapvals(gctime, group)
memory(group::BenchmarkGroup) = mapvals(memory, group)
allocs(group::BenchmarkGroup) = mapvals(allocs, group)
ratio(a::BenchmarkGroup, b::BenchmarkGroup) = mapvals(ratio, a, b)
judge(a::BenchmarkGroup, b::BenchmarkGroup, args...) = mapvals((a, b) -> judge(a, b, args...), a, b)
regressions(group::BenchmarkGroup) = filter((id, t) -> hasregression(t), group)
improvements(group::BenchmarkGroup) = filter((id, t) -> hasimprovement(t), group)

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

#####################
# BenchmarkEnsemble #
#####################

type BenchmarkEnsemble
    groups::Dict{Tag,BenchmarkGroup}
end

BenchmarkEnsemble() = BenchmarkEnsemble(Dict{Tag,BenchmarkGroup}())

# indexing #
#----------#

Base.length(ensemble::BenchmarkEnsemble) = length(ensemble.groups)
Base.copy(ensemble::BenchmarkEnsemble) = BenchmarkEnsemble(copy(ensemble.groups))
Base.getindex(ensemble::BenchmarkEnsemble, id...) = ensemble.groups[id...]
Base.getindex(ensemble::BenchmarkEnsemble, filt::TagFilter) = filter((id, g) -> filt.pred(g), ensemble)
Base.setindex!(ensemble::BenchmarkEnsemble, group::BenchmarkGroup, id...) = setindex!(ensemble.groups, group, id...)

# adding/removing groups #
#------------------------#

function addgroup!(ensemble::BenchmarkEnsemble, id, tags)
    @assert !(haskey(ensemble.groups, id)) "BenchmarkEnsemble already has group with ID \"$(id)\""
    group = BenchmarkGroup(id, tags)
    ensemble[id] = group
    return group
end

delete!(ensemble::BenchmarkEnsemble, id) = delete!(ensemble.groups, id)

# mapping/filtering #
#-------------------#

function mapvals(f, a::BenchmarkEnsemble, b::BenchmarkEnsemble)
    result_ensemble = BenchmarkEnsemble()
    for id in keys(a.groups)
        if haskey(b.groups, id)
            result_ensemble[id] = mapvals(f, a[id], b[id])
        end
    end
    return result_ensemble
end

function mapvals!(f, result::BenchmarkEnsemble, ensemble::BenchmarkEnsemble)
    for (id, group) in ensemble.groups
        result[id] = mapvals(f, group)
    end
    return result
end

mapvals!(f, ensemble::BenchmarkEnsemble) = mapvals!(f, ensemble, copy(ensemble))
mapvals(f, ensemble::BenchmarkEnsemble) = mapvals!(f, BenchmarkEnsemble(), ensemble)

function filtervals!(f, ensemble::BenchmarkEnsemble)
    for (id, group) in ensemble.groups
        ensemble[id] = filtervals!(f, group)
    end
    return ensemble
end

filtervals(f, ensemble::BenchmarkEnsemble) = filtervals!(f, ensemble)

Base.filter!(f, ensemble::BenchmarkEnsemble) = (filter!(f, ensemble.groups); return ensemble)
Base.filter(f, ensemble::BenchmarkEnsemble) = BenchmarkEnsemble(filter(f, ensemble.groups))

# value retrieval #
#-----------------#

Base.time(ensemble::BenchmarkEnsemble) = mapvals(time, ensemble)
gctime(ensemble::BenchmarkEnsemble) = mapvals(gctime, ensemble)
memory(ensemble::BenchmarkEnsemble) = mapvals(memory, ensemble)
allocs(ensemble::BenchmarkEnsemble) = mapvals(allocs, ensemble)
ratio(a::BenchmarkEnsemble, b::BenchmarkEnsemble) = mapvals(ratio, a, b)
judge(a::BenchmarkEnsemble, b::BenchmarkEnsemble, args...) = mapvals((a, b) -> judge(a, b, args...), a, b)
regressions(ensemble::BenchmarkEnsemble) = filtervals((id, t) -> hasregression(t), ensemble)
improvements(ensemble::BenchmarkEnsemble) = filtervals((id, t) -> hasimprovement(t), ensemble)

###################
# Pretty Printing #
###################

tagrepr(tags) = string("[", join(map(x -> "\"$x\"", tags), ", "), "]")

function Base.show(io::IO, group::BenchmarkGroup)
    println(io, "BenchmarkTools.BenchmarkGroup \"", group.id, "\":")
    print(io, "  tags: ", tagrepr(group.tags))
    for benchmark in keys(group.benchmarks)
        println(io)
        print(io, "  ", benchmark, " => ")
        compactshow(io, group[benchmark])
    end
end

function Base.show(io::IO, ensemble::BenchmarkEnsemble)
    print(io, "BenchmarkTools.BenchmarkEnsemble:")
    for group in values(ensemble.groups)
        println(io)
        print(io, "  ")
        compactshow(io, group)
    end
end

compactshow(io::IO, group::BenchmarkGroup) = print(io, "BenchmarkGroup(\"", group.id, "\")")
