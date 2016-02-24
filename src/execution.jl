###########
# @tagged #
###########

macro tagged(pred)
    return :(x -> $(tagpred!(pred, :x)))
end

tagpred!(item::AbstractString, sym::Symbol) = :(hastag($sym, $item))
tagpred!(item::Symbol, sym::Symbol) = item == :ALL ? true : item

function tagpred!(expr::Expr, sym::Symbol)
    for i in eachindex(expr.args)
        expr.args[i] = tagpred!(expr.args[i], sym)
    end
    return expr
end

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

function execute(ensemble::BenchmarkEnsemble, pred, seconds::Number = NaN; verbose::Bool = false)
    result_ensemble = BenchmarkEnsemble()
    for (id, group) in ensemble.groups
        if pred(group)
            verbose && (println("Running BenchmarkGroup \"", group.id, "\"..."); tic())
            result_ensemble[id] = execute(group, seconds; verbose = verbose)
            verbose && println("  Completed BenchmarkGroup \"", group.id, "\" (took ", toq(), " seconds)")
        end
    end
    return result_ensemble
end

###########
# ntrials #
###########

function ntrials(f::Function, trials::Number; seconds::Number = NaN, verbose::Bool = true)
    return Trial[execute(f; seconds = seconds, verbose = verbose) for _ in 1:trials]
end
