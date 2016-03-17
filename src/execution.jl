
###########
# execute #
###########

sample(b::Benchmark, args...) = error("`sample` not defined for $b")
execute(b::Benchmark; kwargs...) = error("`execute` not defined for $b")

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

####################
# Parameter Tuning #
####################

function tune!(b::Benchmark, seconds = b.params.seconds)
    times = Vector{Float64}()
    evals = Vector{Int}()
    rate = 1.1
    i = 1.0
    ifloor = floor(Int, i)
    local gcdiff::Base.GC_Diff
    start_time = time()
    while (time() - start_time) < seconds
        ifloor = floor(Int, i)
        t, gcdiff = sample(b, ifloor)
        push!(times, t)
        push!(evals, ifloor)
        i = 1.0 + rate*i
        i > 1e5 && break
    end
    revmeans = reverse(round(times ./ evals, 2))
    i = findfirst(x -> revmeans[x] > revmeans[x-1], 2:length(revmeans)) - 1
    j = length(times) - min(i, 0)
    b.params.evals = evals[j]
    b.params.samples = min(50, floor(Int, b.params.seconds / (times[j]*1e-9)))
    return times, evals
end

#############################
# @benchmark/@benchmarkable #
#############################

macro benchmark(args...)
    tmp = gensym()
    return esc(quote
        $(tmp) = BenchmarkTools.@benchmarkable $(args...)
        BenchmarkTools.tune!($(tmp))
        BenchmarkTools.execute($(tmp))
    end)
end

macro benchmarkable(args...)
    if length(args) == 1
        core = args[1]
        paramsdef = :(BenchmarkTools.Parameters())
    elseif length(args) == 2
        core = args[1]
        paramsdef = args[2]
    else
        error("wrong number of arguments for @benchmarkable")
    end
    return esc(quote
        let
            wrapfn = gensym("wrap")
            samplefn = gensym("sample")
            benchmark = gensym("benchmark")
            eval(current_module(), quote
                immutable $(benchmark) <: BenchmarkTools.Benchmark
                    params::BenchmarkTools.Parameters
                end
                @noinline $(wrapfn)() = $($(Expr(:quote, core)))
                @noinline function $(samplefn)(evals::Int)
                    gc_start = Base.gc_num()
                    start_time = time_ns()
                    for _ in 1:evals
                        $(wrapfn)()
                    end
                    sample_time = time_ns() - start_time
                    gcdiff = Base.GC_Diff(Base.gc_num(), gc_start)
                    return sample_time, gcdiff
                end
                @noinline function BenchmarkTools.sample(b::$(benchmark), evals = b.params.evals)
                    return $(samplefn)(floor(Int, evals))
                end
                @noinline function BenchmarkTools.execute(b::$(benchmark), p::BenchmarkTools.Parameters = b.params; kwargs...)
                    params = BenchmarkTools.Parameters(p; kwargs...)
                    @assert params.seconds > 0.0 "time limit must be greater than 0.0"
                    params.gcbool && gc()
                    start_time = time()
                    trial = BenchmarkTools.Trial(params)
                    iters = 1
                    while (time() - start_time) < params.seconds
                        push!(trial, $(samplefn)(params.evals)...)
                        iters += 1
                        iters > params.samples && break
                    end
                    return trial
                end
                $(benchmark)($($(Expr(:quote, paramsdef))))
            end)
        end
    end)
end
