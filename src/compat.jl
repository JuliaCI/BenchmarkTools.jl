############################################
# Backwards-compatible JLD Deserialization #
############################################

type OldParameters
    seconds::Float64
    samples::Int
    evals::Int
    overhead::Int
    gctrial::Bool
    gcsample::Bool
    time_tolerance::Float64
    memory_tolerance::Float64
end

type OldTrial
    params::Parameters
    times::Vector{Float64}
    gctimes::Vector{Float64}
    memory::Int
    allocs::Int
end

function JLD.readas(p::OldParameters)
    return Parameters(p.seconds, p.samples, p.evals, Float64(p.overhead), p.gctrial,
                      p.gcsample, p.time_tolerance, p.memory_tolerance)
end

function JLD.readas(t::OldTrial)
    new_times = convert(Vector{Float64}, t.times)
    new_gctimes = convert(Vector{Float64}, t.gctimes)
    return Trial(t.params, new_times, new_gctimes, t.memory, t.allocs)
end

function loadold(args...)
    JLD.translate("BenchmarkTools.Parameters", "BenchmarkTools.OldParameters")
    JLD.translate("BenchmarkTools.Trial", "BenchmarkTools.OldTrial")
    result = JLD.load(args...)
    JLD.translate("BenchmarkTools.Parameters", "BenchmarkTools.Parameters")
    JLD.translate("BenchmarkTools.Trial", "BenchmarkTools.Trial")
    return result
end
