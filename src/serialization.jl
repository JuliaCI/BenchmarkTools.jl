const VERSION_KEY = "__versions__"

const VERSIONS = Dict("Julia" => string(VERSION), "BenchmarkTools" => string(BENCHMARKTOOLS_VERSION))

type ParametersPreV006
    seconds::Float64
    samples::Int
    evals::Int
    overhead::Int
    gctrial::Bool
    gcsample::Bool
    time_tolerance::Float64
    memory_tolerance::Float64
end

type TrialPreV006
    params::Parameters
    times::Vector{Int}
    gctimes::Vector{Int}
    memory::Int
    allocs::Int
end

function JLD.readas(p::ParametersPreV006)
    return Parameters(p.seconds, p.samples, p.evals, Float64(p.overhead), p.gctrial,
                      p.gcsample, p.time_tolerance, p.memory_tolerance)
end

function JLD.readas(t::TrialPreV006)
    new_times = convert(Vector{Float64}, t.times)
    new_gctimes = convert(Vector{Float64}, t.gctimes)
    return Trial(t.params, new_times, new_gctimes, t.memory, t.allocs)
end

function save(filename, args...)
    JLD.save(filename, VERSION_KEY, VERSIONS, args...)
    JLD.jldopen(filename, "r+") do io
        JLD.addrequire(io, BenchmarkTools)
    end
    return nothing
end

@inline function load(filename, args...)
    # no version-based rules are needed for now, we just need
    # to check that version information exists in the file.
    if JLD.jldopen(file -> JLD.exists(file, VERSION_KEY), filename, "r")
        result = JLD.load(filename, args...)
    else
        JLD.translate("BenchmarkTools.Parameters", "BenchmarkTools.ParametersPreV006")
        JLD.translate("BenchmarkTools.Trial", "BenchmarkTools.TrialPreV006")
        result = JLD.load(filename, args...)
        JLD.translate("BenchmarkTools.Parameters", "BenchmarkTools.Parameters")
        JLD.translate("BenchmarkTools.Trial", "BenchmarkTools.Trial")
    end
    return result
end
