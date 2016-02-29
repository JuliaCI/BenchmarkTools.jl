###########
# execute #
###########

execute(benchmark::Function, seconds::Number = NaN) = benchmark(Float64(seconds))

function execute(group::BenchmarkGroup, seconds::Number = NaN; verbose::Bool = false)
    result = similar(group)
    for (id, benchmark) in group
        verbose && (print("  benchmarking ", id, "..."); tic())
        result[id] = execute(benchmark, seconds)
        verbose && println("done (took ", toq(), " seconds)")
    end
    return result
end

function execute(groups::GroupCollection, seconds::Number = NaN; verbose::Bool = false)
    result = similar(groups)
    for (id, group) in groups
        verbose && (println("Running BenchmarkGroup \"", id, "\"..."); tic())
        result[id] = execute(group, seconds; verbose = verbose)
        verbose && println("  Completed BenchmarkGroup \"", id, "\" (took ", toq(), " seconds)")
    end
    return result
end

###########
# ntrials #
###########

ntrials(item, trials::Number, seconds = NaN; kwargs...) = flatten([execute(item, seconds; kwargs...) for _ in 1:trials])
ntrials(item, trials; kwargs...) = flatten([execute(item, t; kwargs...) for t in trials])

flatten(items) = flatten(items, typeof(first(items)))
flatten{T}(items, ::Type{T}) = convert(Vector{T}, items)

function flatten{C<:AbstractBenchmarkCollection}(items, ::Type{C})
    reference = first(items)
    result = similar(reference)
    T = typeof(first(values(reference)))
    for k in keys(reference)
        result[k] = flatten([i[k] for i in items], T)
    end
    return result
end
