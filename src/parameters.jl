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

function Parameters(; seconds = 5.0, samples = 300, evals = 1, gctrial = true,
                    gcsample = false, tolerance = 0.05)
    return Parameters(seconds, samples, evals, gctrial, gcsample, tolerance)
end

function Parameters(default::Parameters; seconds = nothing, samples = nothing,
                    evals = nothing, gctrial =nothing, gcsample = nothing,
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
