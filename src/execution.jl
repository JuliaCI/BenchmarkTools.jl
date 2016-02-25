###########
# execute #
###########

execute(benchmark::Function, seconds::Number = NaN) = benchmark(Float64(seconds))

function execute(group::BenchmarkGroup, seconds::Number = NaN; verbose::Bool = false)
    result = BenchmarkGroup(group.id, group.tags)
    for id in keys(group.benchmarks)
        verbose && (print("  benchmarking ", id, "..."); tic())
        result[id] = execute(group[id], seconds)
        verbose && println("done (took ", toq(), " seconds)")
    end
    return result
end

function execute(ensemble::BenchmarkEnsemble, seconds::Number = NaN; verbose::Bool = false)
    result_ensemble = BenchmarkEnsemble()
    for (id, group) in ensemble.groups
        verbose && (println("Running BenchmarkGroup \"", group.id, "\"..."); tic())
        result_ensemble[id] = execute(group, seconds; verbose = verbose)
        verbose && println("  Completed BenchmarkGroup \"", group.id, "\" (took ", toq(), " seconds)")
    end
    return result_ensemble
end

###########
# ntrials #
###########

ntrials(exe, trials::Number, seconds = NaN; kwargs...) = flatten([execute(exe, seconds; kwargs...) for _ in 1:trials])
ntrials(exe, trials; kwargs...) = flatten([execute(exe, t; kwargs...) for t in trials])

flatten(items) = flatten(items, typeof(first(items)))
flatten(trials, ::Type{Trial}) = trials

function flatten(groups, ::Type{BenchmarkGroup})
    ngroups = length(groups)
    reference = first(groups)
    group = BenchmarkGroup(reference.id, reference.tags)
    for id in keys(reference.benchmarks)
        trials = Vector{Trial}(ngroups)
        for g in 1:ngroups
            trials[g] = groups[g][id]
        end
        group[id] = trials
    end
    return group
end

function flatten(ensembles, ::Type{BenchmarkEnsemble})
    nensembles = length(ensembles)
    ensemble = BenchmarkEnsemble()
    for id in keys(first(ensembles).groups)
        ensemble[id] = restruct([e[id] for e in ensembles], BenchmarkGroup)
    end
    return ensemble
end
