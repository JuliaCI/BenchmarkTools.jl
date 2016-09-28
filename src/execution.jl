# Trigger several successive GC sweeps. This is more comprehensive than running just a
# single sweep, since freeable objects may need more than one sweep to be appropriately
# marked and freed.
gcscrub() = (gc(); gc(); gc(); gc())

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
    gcscrub() # run GC before running group, even if individual benchmarks don't manually GC
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
    params.gctrial && gcscrub()
    start_time = time()
    for evals in eachindex(estimates)
        params.gcsample && gcscrub()
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
    gcscrub() # run GC before running group, even if individual benchmarks don't manually GC
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
    warmup(b, false)
    estimate = minimum(lineartrial(b, p; kwargs...))
    b.params.evals = guessevals(estimate)
    return b
end

#############################
# @benchmark/@benchmarkable #
#############################

function prunekwargs(args...)
    firstarg = first(args)
    if isa(firstarg, Expr) && firstarg.head == :parameters
        return prunekwargs(drop(args, 1)..., firstarg.args...)
    else
        core = firstarg
        params = collect(drop(args, 1))
        for ex in params
            if isa(ex, Expr) && ex.head == :(=)
                ex.head = :kw
            end
        end
        if isa(core, Expr) && core.head == :kw
            core.head = :(=)
        end
        return core, params
    end
end

function hasevals(params)
    for p in params
        if isa(p, Expr) && p.head == :kw && first(p.args) == :evals
            return true
        end
    end
    return false
end

function collectvars(ex::Expr, vars::Vector{Symbol} = Symbol[])
    if ex.head == :(=)
        lhs = first(ex.args)
        if isa(lhs, Symbol)
            push!(vars, lhs)
        elseif isa(lhs, Expr) && lhs.head == :tuple
            append!(vars, lhs.args)
        end
    elseif (ex.head == :comprehension || ex.head == :generator)
        arg = ex.args[1]
        isa(arg, Expr) && collectvars(arg, vars)
    else
        for arg in ex.args
            isa(arg, Expr) && collectvars(arg, vars)
        end
    end
    return vars
end

macro benchmark(args...)
    tmp = gensym()
    _, params = prunekwargs(args...)
    tune_expr = hasevals(params) ? :() : :(BenchmarkTools.tune!($(tmp)))
    return esc(quote
        $(tmp) = BenchmarkTools.@benchmarkable $(args...)
        BenchmarkTools.warmup($(tmp))
        $(tune_expr)
        BenchmarkTools.Base.run($(tmp))
    end)
end

macro benchmarkable(args...)
    core, params = prunekwargs(args...)

    # extract setup/teardown if present, removing them from the original expression
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

    # extract any variable bindings shared between the core and setup expressions
    setup_vars = collectvars(setup)
    core_vars = isa(core, Expr) ? collectvars(core) : []
    out_vars = filter(var -> var in setup_vars, core_vars)

    # generate the benchmark definition
    return esc(quote
        BenchmarkTools.generate_benchmark_definition(current_module(),
                                                     $(Expr(:quote, out_vars)),
                                                     $(Expr(:quote, setup_vars)),
                                                     $(Expr(:quote, core)),
                                                     $(Expr(:quote, setup)),
                                                     $(Expr(:quote, teardown)),
                                                     BenchmarkTools.Parameters($(params...)))
    end)
end

# `eval` an expression that forcibly defines the specified benchmark at
# top-level of `eval_module`, hopefully ensuring that the "location" of the benchmark's
# definition will not be a factor for the sake of performance testing.
#
# The double-underscore-prefixed variable names are not particularly hygienic - it's
# possible for them to conflict with names used in the setup or teardown expressions.
# A more robust solution would be preferable.
function generate_benchmark_definition(eval_module, out_vars, setup_vars,
                                       core, setup, teardown, params)
    id = Expr(:quote, gensym("benchmark"))
    corefunc = gensym("core")
    samplefunc = gensym("sample")
    signature = Expr(:call, corefunc, setup_vars...)
    if length(out_vars) == 0
        returns = :(return)
        invocation = signature
    elseif length(out_vars) == 1
        returns = :(return $(out_vars[1]))
        invocation = :($(out_vars[1]) = $(signature))
    else
        returns = :(return $(Expr(:tuple, out_vars...)))
        invocation = :($(Expr(:tuple, out_vars...)) = $(signature))
    end
    eval(eval_module, quote
        @noinline $(signature) = ($(core); $(returns))
        @noinline function $(samplefunc)(__params::BenchmarkTools.Parameters)
            $(setup)
            __evals = __params.evals
            __gc_start = Base.gc_num()
            __start_time = time_ns()
            for __iter in 1:__evals
                $(invocation)
            end
            __sample_time = time_ns() - __start_time
            __gcdiff = Base.GC_Diff(Base.gc_num(), __gc_start)
            $(teardown)
            __time = max(Int(cld(__sample_time, __evals)) - __params.overhead, 1)
            __gctime = max(Int(cld(__gcdiff.total_time, __evals)) - __params.overhead, 0)
            __memory = Int(fld(__gcdiff.allocd, __evals))
            __allocs = Int(fld(__gcdiff.malloc + __gcdiff.realloc +
                               __gcdiff.poolalloc + __gcdiff.bigalloc,
                               __evals))
            return __time, __gctime, __memory, __allocs
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
            params.gctrial && BenchmarkTools.gcscrub()
            start_time = time()
            trial = BenchmarkTools.Trial(params)
            iters = 1
            while (time() - start_time) < params.seconds
                params.gcsample && gcscrub()
                push!(trial, $(samplefunc)(params)...)
                iters += 1
                iters > params.samples && break
            end
            return sort!(trial)
        end
        BenchmarkTools.Benchmark{$(id)}($(params))
    end)
end
