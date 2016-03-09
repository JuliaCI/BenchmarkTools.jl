###########
# execute #
###########

execute(benchmark::Function) = benchmark()
execute(benchmark::Function, seconds::Number) = benchmark(Float64(seconds))
execute(benchmark::Function, seconds::Number, gcbool::Bool) = benchmark(Float64(seconds), gcbool)

function execute(group::BenchmarkGroup, args...; verbose::Bool = false)
    result = similar(group)
    gc() # run GC before running group, even if individual benchmarks don't manually GC
    i = 1
    for id in keys(group)
        verbose && (print(" ($(i)/$(length(group))) benchmarking ", id, "..."); tic())
        result[id] = execute(group[id], args...)
        verbose && (println("done (took ", toq(), " seconds)"); i += 1)
    end
    return result
end

function execute(groups::GroupCollection, args...; verbose::Bool = false)
    result = similar(groups)
    i = 1
    for group in groups
        verbose && (println("($(i)/$(length(groups))) Running BenchmarkGroup \"", group.id, "\"..."); tic())
        result[group.id] = execute(group, args...; verbose = verbose)
        verbose && (println("  Completed BenchmarkGroup \"", group.id, "\" (took ", toq(), " seconds)"); i += 1)
    end
    return result
end

#############################
# @benchmark/@benchmarkable #
#############################

const DEFAULT_TIME_LIMIT = 10.0

macro benchmark(args...)
    tmp = gensym()
    return esc(quote
        $(tmp) = BenchmarkTools.@benchmarkable $(args...)
        BenchmarkTools.execute($(tmp), 1e-3) # precompile
        BenchmarkTools.execute($(tmp))
    end)
end

macro benchmarkable(args...)
    if length(args) == 1
        core = first(args)
        default_seconds = DEFAULT_TIME_LIMIT
        default_gcbool = true
    elseif length(args) == 2
        core, default_seconds = args
        default_gcbool = true
    elseif length(args) == 3
        core, default_seconds, default_gcbool = args
    else
        error("wrong number of arguments for @benchmark")
    end
    return esc(quote
        let
            _wrapfn = gensym("wrap")
            _trialfn = gensym("trial")
            _samplefn = gensym("sample!")
            eval(current_module(), quote
                @noinline $(_wrapfn)() = $($(Expr(:quote, core)))
                @noinline function $(_samplefn)(trial::BenchmarkTools.Trial, evals)
                    gc_start = Base.gc_num()
                    start_time = time_ns()
                    for _ in 1:evals
                        $(_wrapfn)()
                    end
                    sample_time = time_ns() - start_time
                    gcdiff = Base.GC_Diff(Base.gc_num(), gc_start)
                    bytes = gcdiff.allocd
                    allocs = gcdiff.malloc + gcdiff.realloc + gcdiff.poolalloc + gcdiff.bigalloc
                    gctime = gcdiff.total_time
                    push!(trial, evals, sample_time, gctime, bytes, allocs)
                    return trial
                end
                @noinline function $(_trialfn)(time_limit::Float64 = Float64($($(Expr(:quote, default_seconds)))),
                                               gcbool::Bool = $($(Expr(:quote, default_gcbool))))
                    @assert time_limit > 0.0 "time limit must be greater than 0.0"
                    gcbool && gc()
                    growth_rate = 1.1
                    sample_evals = 1.0
                    start_time = time()
                    trial = BenchmarkTools.Trial()
                    while (time() - start_time) < time_limit
                        $(_samplefn)(trial, floor(sample_evals))
                        sample_evals = 1.0 + (sample_evals * growth_rate)
                        sample_evals > 1e6 && break
                    end
                    return trial
                end
            end)
        end
    end)
end
