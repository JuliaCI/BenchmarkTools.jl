# most machines will be higher resolution than this, but we're playing it safe
const RESOLUTION = 1000 # 1 μs = 1000 ns

##############
# Parameters #
##############

mutable struct Parameters
    seconds::Float64
    samples::Int
    evals::Int
    evals_set::Bool
    overhead::Float64
    gctrial::Bool
    gcsample::Bool
    time_tolerance::Float64
    memory_tolerance::Float64
    enable_linux_perf::Bool
    linux_perf_groups::String
    linux_perf_spaces::NTuple{3,Bool}
    linux_perf_threads::Bool
    linux_perf_gcscrub::Bool
end

# Task clock has large overhead so is not useful for the short time we run functions under perf
# Further we benchmark anyways so no need for cycles or task clock
# I've tried to only use one group by getting rid of noisy or not useful metrics
const DEFAULT_PARAMETERS = Parameters(
    5.0,
    10000,
    1,
    false,
    0,
    true,
    false,
    0.05,
    0.01,
    false,
    "(instructions,branch-instructions)",
    (true, false, false),
    true,
    true,
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
    enable_linux_perf=DEFAULT_PARAMETERS.enable_linux_perf,
    linux_perf_groups=DEFAULT_PARAMETERS.linux_perf_groups,
    linux_perf_spaces=DEFAULT_PARAMETERS.linux_perf_spaces,
    linux_perf_threads=DEFAULT_PARAMETERS.linux_perf_threads,
    linux_perf_gcscrub=DEFAULT_PARAMETERS.linux_perf_gcscrub,
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
        enable_linux_perf,
        linux_perf_groups,
        linux_perf_spaces,
        linux_perf_threads,
        linux_perf_gcscrub,
    )
end

function Parameters(
    default::Parameters;
    seconds=nothing,
    samples=nothing,
    evals=nothing,
    overhead=nothing,
    gctrial=nothing,
    gcsample=nothing,
    time_tolerance=nothing,
    memory_tolerance=nothing,
    enable_linux_perf=nothing,
    linux_perf_groups=nothing,
    linux_perf_spaces=nothing,
    linux_perf_threads=nothing,
    linux_perf_gcscrub=nothing,
)
    params = Parameters()
    params.seconds = seconds != nothing ? seconds : default.seconds
    params.samples = samples != nothing ? samples : default.samples
    params.evals = evals != nothing ? evals : default.evals
    params.overhead = overhead != nothing ? overhead : default.overhead
    params.gctrial = gctrial != nothing ? gctrial : default.gctrial
    params.gcsample = gcsample != nothing ? gcsample : default.gcsample
    params.time_tolerance =
        time_tolerance != nothing ? time_tolerance : default.time_tolerance
    params.memory_tolerance =
        memory_tolerance != nothing ? memory_tolerance : default.memory_tolerance
    params.enable_linux_perf = if enable_linux_perf != nothing
        enable_linux_perf
    else
        default.enable_linux_perf
    end
    params.linux_perf_groups = if linux_perf_groups != nothing
        linux_perf_groups
    else
        default.linux_perf_groups
    end
    params.linux_perf_spaces = if linux_perf_spaces != nothing
        linux_perf_spaces
    else
        default.linux_perf_spaces
    end
    params.linux_perf_threads = if linux_perf_threads != nothing
        linux_perf_threads
    else
        default.linux_perf_threads
    end
    params.linux_perf_gcscrub = if linux_perf_gcscrub != nothing
        linux_perf_gcscrub
    else
        default.linux_perf_gcscrub
    end
    return params::BenchmarkTools.Parameters
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
           a.enable_linux_perf == b.enable_linux_perf &&
           a.linux_perf_groups == b.linux_perf_groups &&
           a.linux_perf_spaces == b.linux_perf_spaces &&
           a.linux_perf_threads == b.linux_perf_threads &&
           a.linux_perf_gcscrub == b.linux_perf_gcscrub
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
        p.enable_linux_perf,
        p.linux_perf_groups,
        p.linux_perf_spaces,
        p.linux_perf_threads,
        p.linux_perf_gcscrub,
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
