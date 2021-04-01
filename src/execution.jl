# Trigger several successive GC sweeps. This is more comprehensive than running just a
# single sweep, since freeable objects may need more than one sweep to be appropriately
# marked and freed.
gcscrub() = (GC.gc(); GC.gc(); GC.gc(); GC.gc())

#############
# Benchmark #
#############

mutable struct Benchmark
    samplefunc
    params::Parameters
end

params(b::Benchmark) = b.params

function loadparams!(b::Benchmark, params::Parameters, fields...)
    loadparams!(b.params, params, fields...)
    return b
end

function Base.show(io::IO, b::Benchmark)
    str = string("Benchmark(evals=", params(b).evals,
                 ", seconds=", params(b).seconds,
                 ", samples=", params(b).samples, ")")
    print(io, str)
end

######################
# compatiblity hacks #
######################

run_result(b::Benchmark, p::Parameters = b.params; kwargs...) = Base.invokelatest(_run, b, p; kwargs...)
lineartrial(b::Benchmark, p::Parameters = b.params; kwargs...) = Base.invokelatest(_lineartrial, b, p; kwargs...)

##############################
# progress logging utilities #
##############################

# As used in ProgressLogging.jl
# https://github.com/JunoLab/ProgressLogging.jl/blob/v0.1.0/src/ProgressLogging.jl#L11
const ProgressLevel = LogLevel(-1)

"""
    _withprogress(
        name::AbstractString,
        group::BenchmarkGroup;
        kwargs...,
    ) do progressid, nleaves, ndone
        ...
    end

Execute do block with following arguments:

* `progressid`: logging ID to be used for `@logmsg`.
* `nleaves`: total number of benchmarks counted at the root benchmark group.
* `ndone`: number of completed benchmarks

They are either extracted from `kwargs` (for sub-groups) or newly created
(for root benchmark group).
"""
function _withprogress(
    f,
    name::AbstractString,
    group::BenchmarkGroup;
    progressid = nothing,
    nleaves = NaN,
    ndone = NaN,
    _...,
)
    if progressid !== nothing
        return f(progressid, nleaves, ndone)
    end
    progressid = uuid4()
    nleaves = length(leaves(group))
    @logmsg(ProgressLevel, name, progress = NaN, _id = progressid)
    try
        return f(progressid, nleaves, 0)
    finally
        @logmsg(ProgressLevel, name, progress = "done", _id = progressid)
    end
end

#############
# execution #
#############

# Note that trials executed via `run` and `lineartrial` are always executed at top-level
# scope, in order to allow transfer of locally-scoped variables into benchmark scope.

function _run(b::Benchmark, p::Parameters; verbose = false, pad = "", kwargs...)
    params = Parameters(p; kwargs...)
    @assert params.seconds > 0.0 "time limit must be greater than 0.0"
    params.gctrial && gcscrub()
    start_time = Base.time()
    trial = Trial(params)
    params.gcsample && gcscrub()
    s = b.samplefunc(params)
    push!(trial, s[1:end-1]...)
    return_val = s[end]
    iters = 2
    while (Base.time() - start_time) < params.seconds && iters ≤ params.samples
         params.gcsample && gcscrub()
         push!(trial, b.samplefunc(params)[1:end-1]...)
         iters += 1
    end
    return sort!(trial), return_val
end


"""
    run(b::Benchmark[, p::Parameters = b.params]; kwargs...)

Run the benchmark defined by [`@benchmarkable`](@ref).
"""
Base.run(b::Benchmark, p::Parameters = b.params; progressid=nothing, nleaves=NaN, ndone=NaN, kwargs...) =
    run_result(b, p; kwargs...)[1]

"""
    run(group::BenchmarkGroup[, args...]; verbose::Bool = false, pad = "", kwargs...)

Run the benchmark group, with benchmark parameters set to `group`'s by default.
"""
Base.run(group::BenchmarkGroup, args...; verbose::Bool = false, pad = "", kwargs...) =
    _withprogress("Benchmarking", group; kwargs...) do progressid, nleaves, ndone
        result = similar(group)
        gcscrub() # run GC before running group, even if individual benchmarks don't manually GC
        i = 1
        for id in keys(group)
            @logmsg(ProgressLevel, "Benchmarking", progress = ndone / nleaves, _id = progressid)
            verbose &&
                println(pad, "($(i)/$(length(group))) benchmarking ", repr(id), "...")
            took_seconds = @elapsed begin
                result[id] = run(
                    group[id],
                    args...;
                    verbose = verbose,
                    pad = pad * "  ",
                    kwargs...,
                    progressid = progressid,
                    nleaves = nleaves,
                    ndone = ndone,
                )
            end
            ndone += group[id] isa BenchmarkGroup ? length(leaves(group[id])) : 1
            verbose && (println(pad, "done (took ", took_seconds, " seconds)"); i += 1)
        end
        return result
    end

function _lineartrial(b::Benchmark, p::Parameters = b.params; maxevals = RESOLUTION, kwargs...)
    params = Parameters(p; kwargs...)
    estimates = zeros(maxevals)
    completed = 0
    params.gctrial && gcscrub()
    start_time = time()
    for evals in eachindex(estimates)
        params.gcsample && gcscrub()
        params.evals = evals
        estimates[evals] = first(b.samplefunc(params))
        completed += 1
        ((time() - start_time) > params.seconds) && break
    end
    return estimates[1:completed]
end

function warmup(item; verbose::Bool = true)
    return run(item;
               verbose = verbose, samples = 1,
               evals = 1, gctrial = false,
               gcsample = false)
end

####################
# parameter tuning #
####################

# The tuning process is as follows:
#
#   1. Using `lineartrial`, take one sample of the benchmark for each `evals` in `1:RESOLUTION`.
#
#   2. Extract the minimum sample found in this trial. Hopefully, this value will be
#      reasonably close to the true benchmark time. At the very least, we can be certain
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

const EVALS = Vector{Int}(undef, 9000) # any `t > length(EVALS)` should get an `evals` of 1
for t in 1:400    (EVALS[t] = logistic(1006, 195, -0.025, t, 200)) end # EVALS[1] == 1000, EVALS[400] == 200
for t in 401:1000 (EVALS[t] = logistic(204, -16, -0.01, t, 800))   end # EVALS[401] == 200, EVALS[1000] == 10
for i in 1:8      (EVALS[((i*1000)+1):((i+1)*1000)] .= 11 - i)     end # linearly decrease from EVALS[1000]

guessevals(t) = t <= length(EVALS) ? EVALS[t] : 1

"""
    tune!(group::BenchmarkGroup; verbose::Bool = false, pad = "", kwargs...)

Tune a `BenchmarkGroup` instance. For most benchmarks, `tune!` needs to perform many
evaluations to determine the proper parameters for any given benchmark - often more
evaluations than are performed when running a trial. In fact, the majority of total
benchmarking time is usually spent tuning parameters, rather than actually running
trials.
"""
tune!(group::BenchmarkGroup; verbose::Bool = false, pad = "", kwargs...) =
    _withprogress("Tuning", group; kwargs...) do progressid, nleaves, ndone
        gcscrub() # run GC before running group, even if individual benchmarks don't manually GC
        i = 1
        for id in keys(group)
            @logmsg(ProgressLevel, "Tuning", progress = ndone / nleaves, _id = progressid)
            verbose && println(pad, "($(i)/$(length(group))) tuning ", repr(id), "...")
            took_seconds = @elapsed tune!(
                group[id];
                verbose = verbose,
                pad = pad * "  ",
                kwargs...,
                progressid = progressid,
                nleaves = nleaves,
                ndone = ndone,
            )
            ndone += group[id] isa BenchmarkGroup ? length(leaves(group[id])) : 1
            verbose && (println(pad, "done (took ", took_seconds, " seconds)"); i += 1)
        end
        return group
    end

"""
    tune!(b::Benchmark, p::Parameters = b.params; verbose::Bool = false, pad = "", kwargs...)

Tune a `Benchmark` instance.
"""
function tune!(b::Benchmark, p::Parameters = b.params;
               progressid=nothing, nleaves=NaN, ndone=NaN,  # ignored
               verbose::Bool = false, pad = "", kwargs...)
    warmup(b, verbose = false)
    estimate = ceil(Int, minimum(lineartrial(b, p; kwargs...)))
    b.params.evals = guessevals(estimate)
    return b
end

#############################
# @benchmark/@benchmarkable #
#############################

function prunekwargs(args...)
    @nospecialize
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

function quasiquote!(ex::Expr, vars::Vector{Expr})
    if ex.head === :($)
        lhs = ex.args[1]
        rhs = isa(lhs, Symbol) ? gensym(lhs) : gensym()
        push!(vars, Expr(:(=), rhs, ex))
        return rhs
    elseif ex.head !== :quote
        for i in 1:length(ex.args)
            arg = ex.args[i]
            if isa(arg, Expr)
                ex.args[i] = quasiquote!(arg, vars)
            end
        end
    end
    return ex
end

raw"""
    @benchmark <expr to benchmark> [setup=<setup expr>]

Run benchmark on a given expression.

# Example

The simplest usage of this macro is to put it in front of what you want
to benchmark.

```julia-repl
julia> @benchmark sin(1)
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     13.610 ns (0.00% GC)
  median time:      13.622 ns (0.00% GC)
  mean time:        13.638 ns (0.00% GC)
  maximum time:     21.084 ns (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     998
```

You can interpolate values into `@benchmark` expressions:

```julia
# rand(1000) is executed for each evaluation
julia> @benchmark sum(rand(1000))
BenchmarkTools.Trial:
  memory estimate:  7.94 KiB
  allocs estimate:  1
  --------------
  minimum time:     1.566 μs (0.00% GC)
  median time:      2.135 μs (0.00% GC)
  mean time:        3.071 μs (25.06% GC)
  maximum time:     296.818 μs (95.91% GC)
  --------------
  samples:          10000
  evals/sample:     10

# rand(1000) is evaluated at definition time, and the resulting
# value is interpolated into the benchmark expression
julia> @benchmark sum($(rand(1000)))
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     101.627 ns (0.00% GC)
  median time:      101.909 ns (0.00% GC)
  mean time:        103.834 ns (0.00% GC)
  maximum time:     276.033 ns (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     935
```
"""
macro benchmark(args...)
    _, params = prunekwargs(args...)
    tmp = gensym()
    return esc(quote
        local $tmp = $BenchmarkTools.@benchmarkable $(args...)
        $BenchmarkTools.warmup($tmp)
        $(hasevals(params) ? :() : :($BenchmarkTools.tune!($tmp)))
        $BenchmarkTools.run($tmp)
    end)
end

function benchmarkable_parts(args)
    @nospecialize
    core, params = prunekwargs(args...)

    # extract setup/teardown if present, removing them from the original expression
    setup, teardown = nothing, nothing
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

    if isa(core, Expr)
        quote_vars = Expr[]
        core = quasiquote!(core, quote_vars)
        if !isempty(quote_vars)
            setup = Expr(:block, setup, quote_vars...)
        end
    end

    return core, setup, teardown, params
end

"""
    @benchmarkable <expr to benchmark> [setup=<setup expr>]

Create a `Benchmark` instance for the given expression. `@benchmarkable`
has similar syntax with `@benchmark`. See also [`@benchmark`](@ref).
"""
macro benchmarkable(args...)
    core, setup, teardown, params = benchmarkable_parts(args)
    map!(esc, params, params)

    # extract any variable bindings shared between the core and setup expressions
    setup_vars = isa(setup, Expr) ? collectvars(setup) : []
    core_vars = isa(core, Expr) ? collectvars(core) : []
    out_vars = filter(var -> var in setup_vars, core_vars)

    # generate the benchmark definition
    return quote
        generate_benchmark_definition($__module__,
                                      $(Expr(:quote, out_vars)),
                                      $(Expr(:quote, setup_vars)),
                                      $(esc(Expr(:quote, core))),
                                      $(esc(Expr(:quote, setup))),
                                      $(esc(Expr(:quote, teardown))),
                                      Parameters($(params...)))
    end
end

# `eval` an expression that forcibly defines the specified benchmark at
# top-level in order to allow transfer of locally-scoped variables into
# benchmark scope.
#
# The double-underscore-prefixed variable names are not particularly hygienic - it's
# possible for them to conflict with names used in the setup or teardown expressions.
# A more robust solution would be preferable.
function generate_benchmark_definition(eval_module, out_vars, setup_vars, core, setup, teardown, params)
    @nospecialize
    corefunc = gensym("core")
    samplefunc = gensym("sample")
    type_vars = [gensym() for i in 1:length(setup_vars)]
    signature = Expr(:call, corefunc, setup_vars...)
    signature_def = Expr(:where, Expr(:call, corefunc,
                                  [Expr(:(::), setup_var, type_var) for (setup_var, type_var) in zip(setup_vars, type_vars)]...)
                    , type_vars...)
    if length(out_vars) == 0
        invocation = signature
        core_body = core
    elseif length(out_vars) == 1
        returns = :(return $(out_vars[1]))
        invocation = :($(out_vars[1]) = $(signature))
        core_body = :($(core); $(returns))
    else
        returns = :(return $(Expr(:tuple, out_vars...)))
        invocation = :($(Expr(:tuple, out_vars...)) = $(signature))
        core_body = :($(core); $(returns))
    end
    return Core.eval(eval_module, quote
        @noinline $(signature_def) = begin $(core_body) end
        @noinline function $(samplefunc)(__params::$BenchmarkTools.Parameters)
            $(setup)
            __evals = __params.evals
            __gc_start = Base.gc_num()
            __start_time = time_ns()
            __return_val = $(invocation)
            for __iter in 2:__evals
                $(invocation)
            end
            __sample_time = time_ns() - __start_time
            __gcdiff = Base.GC_Diff(Base.gc_num(), __gc_start)
            $(teardown)
            __time = max((__sample_time / __evals) - __params.overhead, 0.001)
            __gctime = max((__gcdiff.total_time / __evals) - __params.overhead, 0.0)
            __memory = Int(fld(__gcdiff.allocd, __evals))
            __allocs = Int(fld(__gcdiff.malloc + __gcdiff.realloc +
                               __gcdiff.poolalloc + __gcdiff.bigalloc,
                               __evals))
            return __time, __gctime, __memory, __allocs, __return_val
        end
        $BenchmarkTools.Benchmark($(samplefunc), $(params))
    end)
end

######################
# convenience macros #
######################

# These macros provide drop-in replacements for the
# Base.@time, Base.@elapsed macros and Base.@allocated, which use
# @benchmark but yield only the minimum time.

"""
    @belapsed expression [other parameters...]

Similar to the `@elapsed` macro included with Julia,
this returns the elapsed time (in seconds) to
execute a given expression.   It uses the `@benchmark`
macro, however, and accepts all of the same additional
parameters as `@benchmark`.  The returned time
is the *minimum* elapsed time measured during the benchmark.
"""
macro belapsed(args...)
    return esc(quote
        $BenchmarkTools.time($BenchmarkTools.minimum($BenchmarkTools.@benchmark $(args...)))/1e9
    end)
end

"""
    @ballocated expression [other parameters...]

Similar to the `@allocated` macro included with Julia,
this returns the number of bytes allocated when executing
a given expression.   It uses the `@benchmark`
macro, however, and accepts all of the same additional
parameters as `@benchmark`.  The returned allocations
correspond to the trial with the *minimum* elapsed time measured
during the benchmark.
"""
macro ballocated(args...)
    return esc(quote
        $BenchmarkTools.memory($BenchmarkTools.minimum($BenchmarkTools.@benchmark $(args...)))
    end)
end

"""
    @btime expression [other parameters...]

Similar to the `@time` macro included with Julia,
this executes an expression, printing the time
it took to execute and the memory allocated before
returning the value of the expression.

Unlike `@time`, it uses the `@benchmark`
macro, and accepts all of the same additional
parameters as `@benchmark`.  The printed time
is the *minimum* elapsed time measured during the benchmark.
"""
macro btime(args...)
    _, params = prunekwargs(args...)
    bench, trial, result = gensym(), gensym(), gensym()
    trialmin, trialallocs = gensym(), gensym()
    tune_phase = hasevals(params) ? :() : :($BenchmarkTools.tune!($bench))
    return esc(quote
        local $bench = $BenchmarkTools.@benchmarkable $(args...)
        $BenchmarkTools.warmup($bench)
        $tune_phase
        local $trial, $result = $BenchmarkTools.run_result($bench)
        local $trialmin = $BenchmarkTools.minimum($trial)
        local $trialallocs = $BenchmarkTools.allocs($trialmin)
        println("  ",
                $BenchmarkTools.prettytime($BenchmarkTools.time($trialmin)),
                " (", $trialallocs , " allocation",
                $trialallocs == 1 ? "" : "s", ": ",
                $BenchmarkTools.prettymemory($BenchmarkTools.memory($trialmin)), ")")
        $result
    end)
end
