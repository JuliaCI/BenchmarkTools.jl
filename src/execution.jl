#############
# Benchmark #
#############

type Benchmark{id}
    params::Parameters
end

parameters(b::Benchmark) = b.params
loadparams!(b::Benchmark, params::Parameters) = (b.params = params; return b)

#############
# execution #
#############

sample(b::Benchmark, args...) = error("`sample` not defined for $b")

Base.run(b::Benchmark, args...; kwargs...) = error("`execute` not defined for $b")

function Base.run(group::BenchmarkGroup, args...; verbose::Bool = false, pad = "", kwargs...)
    result = similar(group)
    gc() # run GC before running group, even if individual benchmarks don't manually GC
    i = 1
    for id in keys(group)
        verbose && (println(pad, "($(i)/$(length(group))) benchmarking ", id, "..."); tic())
        result[id] = run(group[id], args...; verbose = verbose, pad = pad*"  ", kwargs...)
        verbose && (println(pad, "done (took ", toq(), " seconds)"); i += 1)
    end
    return result
end

####################
# parameter tuning #
####################

# How many evals do we need of a function that takes
# time `t` to raise the overall sample time above the
# clock resolution time `r`?
evals_given_resolution(t, r) = max(ceil(Int, r / t), 1)

function tune!(group::BenchmarkGroup; verbose::Bool = false, pad = "")
    gc() # run GC before running group, even if individual benchmarks don't manually GC
    i = 1
    for id in keys(group)
        verbose && (println(pad, "($(i)/$(length(group))) tuning ", id, "..."); tic())
        tune!(group[id]; verbose = verbose, pad = pad*"  ")
        verbose && (println(pad, "done (took ", toq(), " seconds)"); i += 1)
    end
    return group
end

function tune!(b::Benchmark; kwargs...)
    b.params.gctrial && gc()
    times = Vector{Int}()
    evals = Vector{Int}()
    rate = 1.1
    current_evals = 1.0
    local unused::Base.GC_Diff
    start_time = time()
    while (time() - start_time) < b.params.seconds
        b.params.gcsample && gc()
        current_evals_floor = floor(Int, current_evals)
        t, unused = sample(b, current_evals_floor)
        push!(times, t)
        push!(evals, current_evals_floor)
        current_evals = 1.0 + rate*current_evals
        current_evals > 1e5 && break
    end
    # assume 1_000_000ns == 1ms resolution to be safe
    b.params.evals = evals_given_resolution(minimum(ceil(times ./ evals)), 1000000)
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
        BenchmarkTools.Base.run($(tmp))
    end)
end

macro benchmarkable(args...)
    arg1 = first(args)
    if isa(arg1, Expr) && arg1.head == :parameters
        @assert length(args) == 2 "wrong number of arguments supplied to @benchmarkable: $(args)"
        core = args[2]
        params = arg1.args
    else
        core = arg1
        params = collect(drop(args, 1))
        for ex in params
            if isa(ex, Expr) && ex.head == :(=)
                ex.head = :kw
            end
        end
    end
    return esc(quote
        let
            wrapfn = gensym("wrap")
            samplefn = gensym("sample")
            id = Expr(:quote, gensym("benchmark"))
            params = BenchmarkTools.Parameters($(params...))
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
                function Base.run(b::BenchmarkTools.Benchmark{$(id)}, p::BenchmarkTools.Parameters = b.params;
                                  verbose = false, pad = "", kwargs...)
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
                BenchmarkTools.Benchmark{$(id)}($(params))
            end)
        end
    end)
end
