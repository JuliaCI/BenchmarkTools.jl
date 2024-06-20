# most machines will be higher resolution than this, but we're playing it safe
const RESOLUTION = 1000 # 1 μs = 1000 ns

##############
# Parameters #
##############

mutable struct Parameters{A,B}
    seconds::Float64
    samples::Int
    evals::Int
    evals_set::Bool
    overhead::Float64
    gctrial::Bool
    gcsample::Bool
    time_tolerance::Float64
    memory_tolerance::Float64
    run_customisable_func_only::Bool
    enable_customisable_func::Symbol
    customisable_gcsample::Bool
    setup_prehook
    teardown_posthook
    sample_result
    prehook::A
    posthook::B

    function Parameters{A,B}(
        seconds,
        samples,
        evals,
        evals_set,
        overhead,
        gctrial,
        gcsample,
        time_tolerance,
        memory_tolerance,
        run_customisable_func_only,
        enable_customisable_func,
        customisable_gcsample,
        setup_prehook,
        teardown_posthook,
        sample_result,
        prehook::A,
        posthook::B,
    ) where {A,B}
        if enable_customisable_func ∉ (:FALSE, :ALL, :LAST)
            throw(
                ArgumentError(
                    "invalid value $(enable_customisable_func) for enable_customisable_func which must be :FALSE, :ALL or :LAST",
                ),
            )
        end
        if run_customisable_func_only && enable_customisable_func == :FALSE
            throw(
                ArgumentError(
                    "run_customisable_func_only is set to true, but enable_customisable_func is set to :FALSE",
                ),
            )
        end
        return new(
            seconds,
            samples,
            evals,
            evals_set,
            overhead,
            gctrial,
            gcsample,
            time_tolerance,
            memory_tolerance,
            run_customisable_func_only,
            enable_customisable_func,
            customisable_gcsample,
            setup_prehook,
            teardown_posthook,
            sample_result,
            prehook,
            posthook,
        )
    end
end

# https://github.com/JuliaLang/julia/issues/17186
function Parameters(
    seconds,
    samples,
    evals,
    evals_set,
    overhead,
    gctrial,
    gcsample,
    time_tolerance,
    memory_tolerance,
    run_customisable_func_only,
    enable_customisable_func,
    customisable_gcsample,
    setup_prehook,
    teardown_posthook,
    sample_result,
    prehook::A,
    posthook::B,
) where {A,B}
    return Parameters{A,B}(
        seconds,
        samples,
        evals,
        evals_set,
        overhead,
        gctrial,
        gcsample,
        time_tolerance,
        memory_tolerance,
        run_customisable_func_only,
        enable_customisable_func,
        customisable_gcsample,
        setup_prehook,
        teardown_posthook,
        sample_result,
        prehook,
        posthook,
    )
end

_nothing_func(args...) = nothing
DEFAULT_PARAMETERS = Parameters(
    5.0,
    10000,
    1,
    false,
    0,
    true,
    false,
    0.05,
    0.01,
    # Customisable Parameters
    false,
    :FALSE,
    false,
    # Customisable functions
    _nothing_func,
    _nothing_func,
    _nothing_func,
    _nothing_func,
    _nothing_func,
)

function Parameters(;
    seconds=DEFAULT_PARAMETERS.seconds,
    samples=DEFAULT_PARAMETERS.samples,
    evals=DEFAULT_PARAMETERS.evals,
    evals_set=DEFAULT_PARAMETERS.evals_set,
    overhead=DEFAULT_PARAMETERS.overhead,
    gctrial=DEFAULT_PARAMETERS.gctrial,
    gcsample=DEFAULT_PARAMETERS.gcsample,
    time_tolerance=DEFAULT_PARAMETERS.time_tolerance,
    memory_tolerance=DEFAULT_PARAMETERS.memory_tolerance,
    run_customisable_func_only=DEFAULT_PARAMETERS.run_customisable_func_only,
    enable_customisable_func=DEFAULT_PARAMETERS.enable_customisable_func,
    customisable_gcsample=DEFAULT_PARAMETERS.customisable_gcsample,
    setup_prehook=DEFAULT_PARAMETERS.setup_prehook,
    teardown_posthook=DEFAULT_PARAMETERS.teardown_posthook,
    sample_result=DEFAULT_PARAMETERS.sample_result,
    prehook=DEFAULT_PARAMETERS.prehook,
    posthook=DEFAULT_PARAMETERS.posthook,
)
    return Parameters(
        seconds,
        samples,
        evals,
        evals_set,
        overhead,
        gctrial,
        gcsample,
        time_tolerance,
        memory_tolerance,
        run_customisable_func_only,
        enable_customisable_func,
        customisable_gcsample,
        setup_prehook,
        teardown_posthook,
        sample_result,
        prehook,
        posthook,
    )
end

function Parameters(
    default::Parameters;
    seconds=nothing,
    samples=nothing,
    evals=nothing,
    evals_set=nothing,
    overhead=nothing,
    gctrial=nothing,
    gcsample=nothing,
    time_tolerance=nothing,
    memory_tolerance=nothing,
    run_customisable_func_only=nothing,
    enable_customisable_func=nothing,
    customisable_gcsample=nothing,
    setup_prehook=nothing,
    teardown_posthook=nothing,
    sample_result=nothing,
    prehook=nothing,
    posthook=nothing,
)
    params_seconds = seconds != nothing ? seconds : default.seconds
    params_samples = samples != nothing ? samples : default.samples
    params_evals = evals != nothing ? evals : default.evals
    params_evals_set = evals_set != nothing ? evals_set : default.evals_set
    params_overhead = overhead != nothing ? overhead : default.overhead
    params_gctrial = gctrial != nothing ? gctrial : default.gctrial
    params_gcsample = gcsample != nothing ? gcsample : default.gcsample
    params_time_tolerance =
        time_tolerance != nothing ? time_tolerance : default.time_tolerance
    params_memory_tolerance =
        memory_tolerance != nothing ? memory_tolerance : default.memory_tolerance
    params_run_customisable_func_only = if run_customisable_func_only != nothing
        run_customisable_func_only
    else
        default.run_customisable_func_only
    end
    params_enable_customisable_func = if enable_customisable_func != nothing
        enable_customisable_func
    else
        default.enable_customisable_func
    end
    params_customisable_gcscrub = if customisable_gcsample != nothing
        customisable_gcsample
    else
        default.customisable_gcsample
    end
    params_setup_prehook = if setup_prehook != nothing
        setup_prehook
    else
        default.setup_prehook
    end
    params_teardown_posthook = if teardown_posthook != nothing
        teardown_posthook
    else
        default.teardown_posthook
    end
    params_sample_result = if sample_result != nothing
        sample_result
    else
        default.sample_result
    end
    params_prehook = prehook != nothing ? prehook : default.prehook
    params_posthook = posthook != nothing ? posthook : default.posthook
    return Parameters(
        params_seconds,
        params_samples,
        params_evals,
        params_evals_set,
        params_overhead,
        params_gctrial,
        params_gcsample,
        params_time_tolerance,
        params_memory_tolerance,
        params_run_customisable_func_only,
        params_enable_customisable_func,
        params_customisable_gcscrub,
        params_setup_prehook,
        params_teardown_posthook,
        params_sample_result,
        params_prehook,
        params_posthook,
    )::BenchmarkTools.Parameters
end

function Base.:(==)(a::Parameters, b::Parameters)
    return a.seconds == b.seconds &&
           a.samples == b.samples &&
           a.evals == b.evals &&
           a.overhead == b.overhead &&
           a.gctrial == b.gctrial &&
           a.gcsample == b.gcsample &&
           a.time_tolerance == b.time_tolerance &&
           a.memory_tolerance == b.memory_tolerance &&
           a.run_customisable_func_only == b.run_customisable_func_only &&
           a.enable_customisable_func == b.enable_customisable_func &&
           a.customisable_gcsample == b.customisable_gcsample &&
           a.setup_prehook == b.setup_prehook &&
           a.teardown_posthook == b.teardown_posthook &&
           a.sample_result == b.sample_result &&
           a.prehook == b.prehook &&
           a.posthook == b.posthook
end

function Base.copy(p::Parameters)
    return Parameters(
        p.seconds,
        p.samples,
        p.evals,
        p.evals_set,
        p.overhead,
        p.gctrial,
        p.gcsample,
        p.time_tolerance,
        p.memory_tolerance,
        p.run_customisable_func_only,
        p.enable_customisable_func,
        p.customisable_gcsample,
        p.setup_prehook,
        p.teardown_posthook,
        p.sample_result,
        p.prehook,
        p.posthook,
    )
end

function loadparams!(a::Parameters, b::Parameters, fields...)
    fields = isempty(fields) ? fieldnames(Parameters) : fields
    for f in fields
        setfield!(a, f, getfield(b, f))
    end
    return a
end

################################
# RESOLUTION/OVERHEAD settings #
################################

@noinline nullfunc() = Base.inferencebarrier(nothing)::Nothing

@noinline function overhead_sample(evals)
    start_time = time_ns()
    for _ in 1:evals
        nullfunc()
    end
    sample_time = time_ns() - start_time
    return (sample_time / evals)
end

function estimate_overhead()
    x = typemax(Float64)
    for _ in 1:10000
        x = min(x, overhead_sample(RESOLUTION))
    end
    return x
end
