##########
# warmup #
##########

warmup(item; kwargs...) = (execute(item, 1e-6, false; kwargs...); return nothing)

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

const DEFAULT_TIME_LIMIT = 5.0

macro benchmark(args...)
    tmp = gensym()
    return esc(quote
        $(tmp) = BenchmarkTools.@benchmarkable $(args...)
        BenchmarkTools.warmup($(tmp)) # precompile
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
    # println(gcbool)
    return esc(quote
        let
            _wrapfn = gensym("wrap")
            _trialfn = gensym("trial")
            eval(current_module(), quote
                @noinline $(_wrapfn)() = $($(Expr(:quote, core)))
                @noinline function $(_trialfn)(seconds::Float64 = Float64($($(Expr(:quote, default_seconds)))),
                                               gcbool::Bool = $($(Expr(:quote, default_gcbool))))
                    @assert seconds > 0.0 "time limit must be greater than 0.0"
                    gcbool && gc()
                    time_limit_ns = seconds * 1e9
                    total_evals = 0.0
                    gc_start = Base.gc_num()
                    start_time = time_ns()
                    growth_rate = 1.01
                    iter_evals = 2.0
                    while (time_ns() - start_time) < time_limit_ns
                        for _ in 1:floor(iter_evals)
                            $(_wrapfn)()
                        end
                        total_evals += iter_evals
                        iter_evals *= growth_rate
                    end
                    elapsed_time = time_ns() - start_time
                    gcdiff = Base.GC_Diff(Base.gc_num(), gc_start)
                    bytes = gcdiff.allocd
                    allocs = gcdiff.malloc + gcdiff.realloc + gcdiff.poolalloc + gcdiff.bigalloc
                    gctime = gcdiff.total_time
                    return BenchmarkTools.Trial(total_evals, elapsed_time, gctime, bytes, allocs)
                end
            end)
        end
    end)
end
