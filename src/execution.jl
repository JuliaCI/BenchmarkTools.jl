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

# How many evals do we need of a function that takes
# time `t` to raise the overall sample time above the
# clock resolution time `r`?
evals_given_resolution(t, r) = max(floor(Int, r / t), 1)

function samples_given_evals(e)
    if e > 10000
        return 50
    elseif e > 300
        return 150
    elseif e > 100
        return 300
    else
        return 50
    end
end

function tune!(b::Benchmark, seconds = b.params.seconds)
    times = Vector{Int}()
    evals = Vector{Int}()
    rate = 1.1
    current_evals = 1.0
    local unused_gcdiff::Base.GC_Diff
    start_time = time()
    while (time() - start_time) < seconds
        current_evals_floor = floor(Int, current_evals)
        t, unused_gcdiff = sample(b, current_evals_floor)
        push!(times, t)
        push!(evals, current_evals_floor)
        current_evals = 1.0 + rate*current_evals
        current_evals > 1e5 && break
    end
    best = minimum(ceil(times ./ evals))
    # assume 1_000_000ns == 1ms resolution to be safe
    b.params.evals = evals_given_resolution(best, 1000000)
    b.params.samples = samples_given_evals(b.params.evals)
    return b
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
            id = Expr(:quote, gensym("benchmark"))
            eval(current_module(), quote
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
                function BenchmarkTools.sample(b::BenchmarkTools.Benchmark{$(id)}, evals = b.params.evals)
                    return $(samplefn)(floor(Int, evals))
                end
                function BenchmarkTools.execute(b::BenchmarkTools.Benchmark{$(id)}, p::BenchmarkTools.Parameters = b.params; kwargs...)
                    params = BenchmarkTools.Parameters(p; kwargs...)
                    @assert params.seconds > 0.0 "time limit must be greater than 0.0"
                    params.gctrial && gc()
                    start_time = time()
                    trial = BenchmarkTools.Trial(params)
                    iters = 1
                    while (time() - start_time) < params.seconds
                        params.gcsample && gc()
                        push!(trial, $(samplefn)(params.evals)...)
                        iters += 1
                        iters > params.samples && break
                    end
                    return sort!(trial)
                end
                BenchmarkTools.Benchmark{$(id)}($($(Expr(:quote, paramsdef))))
            end)
        end
    end)
end
