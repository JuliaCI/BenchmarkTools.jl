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

ntrials(exe, trials::Number, seconds = NaN; kwargs...) = [execute(exe, seconds; kwargs...) for _ in 1:trials]
ntrials(exe, trials; kwargs...) = [execute(exe, t; kwargs...) for t in trials]
