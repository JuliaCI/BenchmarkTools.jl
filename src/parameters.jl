##############
# Parameters #
##############

type Parameters
    seconds::Float64
    samples::Int
    evals::Int
    gctrial::Bool
    gcsample::Bool
    tolerance::Float64
end

const DEFAULT_PARAMETERS = Parameters(5.0, 300, 1, true, false, 0.05)

function Parameters(; seconds = DEFAULT_PARAMETERS.seconds,
                    samples = DEFAULT_PARAMETERS.samples,
                    evals = DEFAULT_PARAMETERS.evals,
                    gctrial = DEFAULT_PARAMETERS.gctrial,
                    gcsample = DEFAULT_PARAMETERS.gcsample,
                    tolerance = DEFAULT_PARAMETERS.tolerance)
    return Parameters(seconds, samples, evals, gctrial, gcsample, tolerance)
end

function Parameters(default::Parameters; seconds = nothing, samples = nothing,
                    evals = nothing, gctrial = nothing, gcsample = nothing,
                    tolerance = nothing)
    params = Parameters()
    params.seconds = seconds != nothing ? seconds : default.seconds
    params.samples = samples != nothing ? samples : default.samples
    params.evals = evals != nothing ? evals : default.evals
    params.gctrial = gctrial != nothing ? gctrial : default.gctrial
    params.gcsample = gcsample != nothing ? gcsample : default.gcsample
    params.tolerance = tolerance != nothing ? tolerance : default.tolerance
    return params::BenchmarkTools.Parameters
end

function Base.(:(==))(a::Parameters, b::Parameters)
    return a.seconds == b.seconds &&
           a.samples == b.samples &&
           a.evals == b.evals &&
           a.gctrial == b.gctrial &&
           a.gcsample == b.gcsample &&
           a.tolerance == b.tolerance
end

Base.copy(p::Parameters) = deepcopy(p)
