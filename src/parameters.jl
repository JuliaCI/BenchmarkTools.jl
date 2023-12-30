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
    experimental_enable_linux_perf::Bool
    linux_perf_options::@NamedTuple{events::Expr, spaces::Expr, threads::Bool}
end

function perf_available()
    if !Sys.islinux()
        return false
    end

    try
        opts = LinuxPerf.parse_pstats_options([])
        groups = BenchmarkTools.LinuxPerf.set_default_spaces(
            opts.events,
            opts.spaces,
        )
        bench = make_bench_threaded(groups, threads = opts.threads)
        return true
    catch
        return false
    end
end

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
    perf_available(),
    LinuxPerf.parse_pstats_options([]),
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
    experimental_enable_linux_perf=DEFAULT_PARAMETERS.experimental_enable_linux_perf,
    linux_perf_options=DEFAULT_PARAMETERS.linux_perf_options,
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
        experimental_enable_linux_perf,
        linux_perf_options,
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
    experimental_enable_linux_perf=nothing,
    linux_perf_options=nothing,
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
    params.experimental_enable_linux_perf = if experimental_enable_linux_perf != nothing
        experimental_enable_linux_perf
    else
        default.experimental_enable_linux_perf
    end
    params.linux_perf_options =
        linux_perf_options != nothing ? linux_perf_options : default.linux_perf_options
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
           a.experimental_enable_linux_perf == b.experimental_enable_linux_perf &&
           a.linux_perf_options == b.linux_perf_options
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
        p.experimental_enable_linux_perf,
        (
            events = copy(p.linux_perf_options.events),
            spaces = copy(p.linux_perf_options.spaces),
            threads = copy(p.linux_perf_options.threads)
        ),
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
