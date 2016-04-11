##############
# Parameters #
##############

type Parameters
    seconds::Float64
    samples::Int
    evals::Int
    gctrial::Bool
    gcsample::Bool
    time_tolerance::Float64
    memory_tolerance::Float64
end

const DEFAULT_PARAMETERS = Parameters(5.0, 300, 1, true, false, 0.05, 0.05)

function Parameters(; seconds = DEFAULT_PARAMETERS.seconds,
                    samples = DEFAULT_PARAMETERS.samples,
                    evals = DEFAULT_PARAMETERS.evals,
                    gctrial = DEFAULT_PARAMETERS.gctrial,
                    gcsample = DEFAULT_PARAMETERS.gcsample,
                    time_tolerance = DEFAULT_PARAMETERS.time_tolerance,
                    memory_tolerance = DEFAULT_PARAMETERS.memory_tolerance)
    return Parameters(seconds, samples, evals, gctrial, gcsample, time_tolerance, memory_tolerance)
end

function Parameters(default::Parameters; seconds = nothing, samples = nothing,
                    evals = nothing, gctrial = nothing, gcsample = nothing,
                    time_tolerance = nothing, memory_tolerance = nothing)
    params = Parameters()
    params.seconds = seconds != nothing ? seconds : default.seconds
    params.samples = samples != nothing ? samples : default.samples
    params.evals = evals != nothing ? evals : default.evals
    params.gctrial = gctrial != nothing ? gctrial : default.gctrial
    params.gcsample = gcsample != nothing ? gcsample : default.gcsample
    params.time_tolerance = time_tolerance != nothing ? time_tolerance : default.time_tolerance
    params.memory_tolerance = memory_tolerance != nothing ? memory_tolerance : default.memory_tolerance
    return params::BenchmarkTools.Parameters
end

function Base.(:(==))(a::Parameters, b::Parameters)
    return a.seconds == b.seconds &&
           a.samples == b.samples &&
           a.evals == b.evals &&
           a.gctrial == b.gctrial &&
           a.gcsample == b.gcsample &&
           a.time_tolerance == b.time_tolerance &&
           a.memory_tolerance == b.memory_tolerance
end

Base.copy(p::Parameters) = Parameters(p.seconds, p.samples, p.evals, p.gctrial,
                                      p.gcsample, p.time_tolerance, p.memory_tolerance)

evals(x) = evals(params(x))
evals(p::Parameters) = p.evals

loadevals!(p::Parameters, evals) = (p.evals = evals; return p)
