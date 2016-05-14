#############
# Benchmark #
#############

type Benchmark{id}
    params::Parameters
end

params(b::Benchmark) = b.params

function loadparams!(b::Benchmark, params::Parameters, fields...)
    loadparams!(b.params, params, fields...)
    return b
end

#############
# execution #
#############
# Note that trials executed via `run` and `lineartrial` are always executed at the top-level
# scope of the module returned by `current_module()`. This is to avoid any weird quirks
# when calling the experiment from within other contexts.

sample(b::Benchmark, args...) = error("no execution method defined on type $(typeof(b))")
_run(b::Benchmark, args...; kwargs...) = error("no execution method defined on type $(typeof(b))")

function Base.run(b::Benchmark, p::Parameters = b.params; kwargs...)
    return eval(current_module(), :(BenchmarkTools._run($(b), $(p); $(kwargs...))))
end

function Base.run(group::BenchmarkGroup, args...; verbose::Bool = false, pad = "", kwargs...)
    result = similar(group)
    gc() # run GC before running group, even if individual benchmarks don't manually GC
    i = 1
    for id in keys(group)
        verbose && (println(pad, "($(i)/$(length(group))) benchmarking ", repr(id), "..."); tic())
        result[id] = run(group[id], args...; verbose = verbose, pad = pad*"  ", kwargs...)
        verbose && (println(pad, "done (took ", toq(), " seconds)"); i += 1)
    end
    return result
end

function _lineartrial(b::Benchmark, p::Parameters = b.params; maxevals = RESOLUTION, kwargs...)
    params = Parameters(p; kwargs...)
    estimates = zeros(Int, maxevals)
    completed = 0
    params.gctrial && gc()
    start_time = time()
    for evals in eachindex(estimates)
        params.gcsample && gc()
        params.evals = evals
        estimates[evals] = first(sample(b, params))
        completed += 1
        ((time() - start_time) > params.seconds) && break
    end
    return estimates[1:completed]
end

function lineartrial(b::Benchmark, p::Parameters = b.params; kwargs...)
    return eval(current_module(), :(BenchmarkTools._lineartrial($(b), $(p); $(kwargs...))))
end

warmup(item, verbose = true) = run(item; verbose = verbose, samples = 1, evals = 1,
                                   gctrial = false, gcsample = false)

####################
# parameter tuning #
####################

# The tuning process is as follows:
#
#   1. Using `lineartrial`, take one sample of the benchmark for each `evals` in `1:RESOLUTION`.
#
#   2. Extract the minimum sample found in this trial. Hopefully, this value will be
#      reasonably close to the the true benchmark time. At the very least, we can be certain
#      that the minimum sample overcomes discretization noise, assuming a sufficient time
#      budget for the trial (which technically should never need to be more than a couple of
#      seconds if `RESOLUTION` ∼ 1μs).
#
#   3. Using the sample from step 2 as a reasonable estimate `t`, calculate `evals`. This
#      is done by indexing into a pregenerated table that maps potential `t` values to the
#      appropriate `evals` values. The actual generation of this table is accomplished via
#      heuristic, driven mainly by empircal insight. It's built on the following postulates:
#          - Small variations in `t` should not cause large variations in `evals`
#          - `RESOLUTION` <= 1000ns
#          - `evals` <= `RESOLUTION` if `RESOLUTION` is in nanoseconds and `t` >= 1ns
#          - Increasing `t` should generally decrease `evals`
#
#   4. By default, tune the `samples` parameter as a function of `t`, `evals`, and the time
#      budget for the benchmark.

# the logistic function is useful for determining `evals` for `1 < t < RESOLUTION`
logistic(u, l, k, t, t0) = round(Int, ((u - l) / (1 + exp(-k * (t - t0)))) + l)

const EVALS = Vector{Int}(9000) # any `t > length(EVALS)` should get an `evals` of 1
for t in 1:400    (EVALS[t] = logistic(1006, 195, -0.025, t, 200)) end # EVALS[1] == 1000, EVALS[400] == 200
for t in 401:1000 (EVALS[t] = logistic(204, -16, -0.01, t, 800))   end # EVALS[401] == 200, EVALS[1000] == 10
for i in 1:8      (EVALS[((i*1000)+1):((i+1)*1000)] = 11 - i)      end # linearly decrease from EVALS[1000]

guessevals(t) = t <= length(EVALS) ? EVALS[t] : 1

function tune!(group::BenchmarkGroup; verbose::Bool = false, pad = "", kwargs...)
    gc() # run GC before running group, even if individual benchmarks don't manually GC
    i = 1
    for id in keys(group)
        verbose && (println(pad, "($(i)/$(length(group))) tuning ", repr(id), "..."); tic())
        tune!(group[id]; verbose = verbose, pad = pad*"  ", kwargs...)
        verbose && (println(pad, "done (took ", toq(), " seconds)"); i += 1)
    end
    return group
end

function tune!(b::Benchmark, p::Parameters = b.params;
               verbose::Bool = false, pad = "", kwargs...)
    estimate = minimum(lineartrial(b, p; kwargs...))
    b.params.evals = guessevals(estimate)
    return b
end

#####################################
# warmup/@benchmark/@benchmarkable #
#####################################

function prunekwargs(args)
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
    return core, params
end

function hasevals(params)
    for p in params
        if isa(p, Expr) && p.head == :kw && first(p.args) == :evals
            return true
        end
    end
    return false
end

function collectvars(setup::Expr, vars::Vector{Symbol} = Symbol[])
    if setup.head == :(=)
        lhs = first(setup.args)
        if isa(lhs, Symbol)
            push!(vars, lhs)
        elseif isa(lhs, Expr) && lhs.head == :tuple
            append!(vars, lhs.args)
        end
    elseif setup.head == :comprehension
        arg = setup.args[1]
        isa(arg, Expr) && collectvars(arg, vars)
    else
        for arg in setup.args
            isa(arg, Expr) && collectvars(arg, vars)
        end
    end
    return vars
end

macro benchmark(args...)
    tmp = gensym()
    _, params = prunekwargs(args)
    tune_expr = hasevals(params) ? :() : :(BenchmarkTools.tune!($(tmp)))
    return esc(quote
        $(tmp) = BenchmarkTools.@benchmarkable $(args...)
        BenchmarkTools.warmup($(tmp))
        $(tune_expr)
        BenchmarkTools.Base.run($(tmp))
    end)
end

macro benchmarkable(args...)
    core, params = prunekwargs(args)
    setup, teardown = :(), :()
    delinds = Int[]
    for i in eachindex(params)
        ex = params[i]
        if ex.args[1] == :setup
            setup = ex.args[2]
            push!(delinds, i)
        elseif ex.args[1] == :teardown
            teardown = ex.args[2]
            push!(delinds, i)
        end
    end
    deleteat!(params, delinds)
    vars = collectvars(setup)
    outvars = isa(core,Expr) ? collectvars(core) : []
    outvars = filter(var -> var in vars, outvars)   # only return vars defined in setup
    if length(outvars) == 0
        returns = :(return)
    elseif length(outvars) == 1
        returns = :(return $(outvars[1]))
    else
        outtuple = Expr(:tuple, outvars...)
        returns = :(return $outtuple)
    end
    return esc(quote
        let
            func = gensym("func")
            samplefunc = gensym("sample")
            vars = $(Expr(:quote, vars))
            outvars = $(Expr(:quote, outvars))
            if length(outvars) == 0
                invocation = :($(func)($(vars...)))
            elseif length(outvars) == 1
                invocation = :($(outvars[1]) = $(func)($(vars...)))
            else
                outtuple = Expr(:tuple, outvars...)
                invocation = :($outtuple = $(func)($(vars...)))
            end
            id = Expr(:quote, gensym("benchmark"))
            params = BenchmarkTools.Parameters($(params...))
            eval(current_module(), quote
                @noinline $(func)($(vars...)) = $($(Expr(:quote, Expr(:block, core, returns))))
                @noinline function $(samplefunc)(params::BenchmarkTools.Parameters)
                    $($(Expr(:quote, setup)))
                    evals = params.evals
                    gc_start = Base.gc_num()
                    start_time = time_ns()
                    for _ in 1:evals
                        $invocation
                    end
                    sample_time = time_ns() - start_time
                    gcdiff = Base.GC_Diff(Base.gc_num(), gc_start)
                    $($(Expr(:quote, teardown)))
                    time = max(Int(cld(sample_time, evals)) - params.overhead, 1)
                    gctime = max(Int(cld(gcdiff.total_time, evals)) - params.overhead, 0)
                    memory = Int(fld(gcdiff.allocd, evals))
                    allocs = Int(fld(gcdiff.malloc + gcdiff.realloc + gcdiff.poolalloc + gcdiff.bigalloc, evals))
                    return time, gctime, memory, allocs
                end
                function BenchmarkTools.sample(b::BenchmarkTools.Benchmark{$(id)},
                                               p::BenchmarkTools.Parameters = b.params)
                    return $(samplefunc)(p)
                end
                function BenchmarkTools._run(b::BenchmarkTools.Benchmark{$(id)},
                                             p::BenchmarkTools.Parameters;
                                             verbose = false, pad = "", kwargs...)
                    params = BenchmarkTools.Parameters(p; kwargs...)
                    @assert params.seconds > 0.0 "time limit must be greater than 0.0"
                    params.gctrial && gc()
                    start_time = time()
                    trial = BenchmarkTools.Trial(params)
                    iters = 1
                    while (time() - start_time) < params.seconds
                        params.gcsample && gc()
                        push!(trial, $(samplefunc)(params)...)
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
