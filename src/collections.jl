##################
# BenchmarkGroup #
##################

type BenchmarkGroup
    id::Tag
    tags::Vector{Tag}
    benchmarks::Dict{Any,Any}
end

BenchmarkGroup(id, tags) = BenchmarkGroup(id, tags, Dict())

Base.length(group::BenchmarkGroup) = length(group.benchmarks)
Base.copy(group::BenchmarkGroup) = BenchmarkGroup(group.id, copy(group.tags), copy(group.benchmarks))
Base.getindex(group::BenchmarkGroup, x...) = group.benchmarks[x...]
Base.setindex!(group::BenchmarkGroup, x, y...) = setindex!(group.benchmarks, x, y...)

hastag(group::BenchmarkGroup, tag) = tag == group.id || in(tag, group.tags)

function Base.map(f, a::BenchmarkGroup, b::BenchmarkGroup)
    result = BenchmarkGroup(a.id, a.tags)
    for id in keys(a.benchmarks)
        if haskey(b.benchmarks, id)
            result[id] = f(a[id], b[id])
        end
    end
    return result
end

function Base.map!(f, result::BenchmarkGroup, group::BenchmarkGroup)
    for (id, val) in group.benchmarks
        result[id] = f(val)
    end
    return result
end

Base.map!(f, group::BenchmarkGroup) = Base.map!(f, group, copy(group))
Base.map(f, group::BenchmarkGroup) = Base.map!(f, BenchmarkGroup(group.id, group.tags), group)

Base.filter!(f, group::BenchmarkGroup) = (filter!(f, group.benchmarks); return group)
Base.filter(f, group::BenchmarkGroup) = BenchmarkGroup(group.id, group.tags, filter(f, group.benchmarks))

Base.time(group::BenchmarkGroup) = map(time, group)
gctime(group::BenchmarkGroup) = map(gctime, group)
memory(group::BenchmarkGroup) = map(memory, group)
allocs(group::BenchmarkGroup) = map(allocs, group)
ratio(a::BenchmarkGroup, b::BenchmarkGroup) = map(ratio, a, b)
judge(a::BenchmarkGroup, b::BenchmarkGroup, args...) = map((a, b) -> judge(a, b, args...), a, b)
regressions(group::BenchmarkGroup) = filter((id, t) -> hasregression(t), group)
improvements(group::BenchmarkGroup) = filter((id, t) -> hasimprovement(t), group)

#####################
# BenchmarkEnsemble #
#####################

type BenchmarkEnsemble
    groups::Dict{Tag,BenchmarkGroup}
end

BenchmarkEnsemble() = BenchmarkEnsemble(Dict{Tag,BenchmarkGroup}())

Base.length(ensemble::BenchmarkEnsemble) = length(ensemble.groups)
Base.copy(ensemble::BenchmarkEnsemble) = BenchmarkEnsemble(copy(ensemble.groups))
Base.getindex(ensemble::BenchmarkEnsemble, id) = ensemble.groups[id]
Base.setindex!(ensemble::BenchmarkEnsemble, group::BenchmarkGroup, id) = setindex!(ensemble.groups, group, id)

function addgroup!(ensemble::BenchmarkEnsemble, id, tags)
    @assert !(haskey(ensemble.groups, id)) "BenchmarkEnsemble already has group with ID \"$(id)\""
    group = BenchmarkGroup(id, tags)
    ensemble[id] = group
    return group
end

rmgroup!(ensemble::BenchmarkEnsemble, id) = delete!(ensemble.groups, id)

function Base.map(f, a::BenchmarkEnsemble, b::BenchmarkEnsemble)
    result_ensemble = BenchmarkEnsemble()
    for id in keys(a.groups)
        if haskey(b.groups, id)
            result_ensemble[id] = map(f, a[id], b[id])
        end
    end
    return result_ensemble
end

function Base.map!(f, result::BenchmarkEnsemble, ensemble::BenchmarkEnsemble)
    for (id, group) in ensemble.groups
        result[id] = map(f, group)
    end
    return result
end

Base.map!(f, ensemble::BenchmarkEnsemble) = Base.map!(f, ensemble, copy(ensemble))
Base.map(f, ensemble::BenchmarkEnsemble) = Base.map!(f, BenchmarkEnsemble(), ensemble)

function Base.filter!(f, ensemble::BenchmarkEnsemble)
    for (id, group) in ensemble.groups
        ensemble[id] = filter!(f, group)
    end
    return ensemble
end

Base.filter(f, ensemble::BenchmarkEnsemble) = filter!(f, ensemble)

Base.time(ensemble::BenchmarkEnsemble) = map(time, ensemble)
gctime(ensemble::BenchmarkEnsemble) = map(gctime, ensemble)
memory(ensemble::BenchmarkEnsemble) = map(memory, ensemble)
allocs(ensemble::BenchmarkEnsemble) = map(allocs, ensemble)
ratio(a::BenchmarkEnsemble, b::BenchmarkEnsemble) = map(ratio, a, b)
judge(a::BenchmarkEnsemble, b::BenchmarkEnsemble, args...) = map((a, b) -> judge(a, b, args...), a, b)
regressions(ensemble::BenchmarkEnsemble) = filter((id, t) -> hasregression(t), ensemble)
improvements(ensemble::BenchmarkEnsemble) = filter((id, t) -> hasimprovement(t), ensemble)

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
