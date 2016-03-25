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

function Parameters(; seconds = 5.0, samples = 100, evals = 1, gctrial = true,
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

#############
# Benchmark #
#############

immutable Benchmark{id}
    params::Parameters
end

#########
# Trial #
#########

type Trial
    params::Parameters
    outliers::Int
    times::Vector{Int}
    gctimes::Vector{Int}
    memory::Int
    allocs::Int
end

Trial(params::Parameters, args...) = push!(Trial(params), args...)
Trial(params::Parameters) = Trial(params, 0, Int[], Int[], typemax(Int), typemax(Int))

function Base.(:(==))(a::Trial, b::Trial)
    return a.params == b.params &&
           a.times == b.times &&
           a.gctimes == b.gctimes &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

function Base.push!(t::Trial, sample_time, gcdiff::Base.GC_Diff)
    time = ceil(sample_time / t.params.evals)
    gctime = ceil(gcdiff.total_time / t.params.evals)
    memory = fld(gcdiff.allocd, t.params.evals)
    allocs = fld(gcdiff.malloc + gcdiff.realloc + gcdiff.poolalloc + gcdiff.bigalloc, t.params.evals)
    return push!(t, time, gctime, memory, allocs)
end

function Base.push!(t::Trial, time, gctime, memory, allocs)
    push!(t.times, time)
    push!(t.gctimes, gctime)
    memory < t.memory && (t.memory = memory)
    allocs < t.allocs && (t.allocs = allocs)
    return t
end

function Base.deleteat!(t::Trial, i)
    deleteat!(t.times, i)
    deleteat!(t.gctimes, i)
    return t
end

Base.length(t::Trial) = length(t.times)
Base.getindex(t::Trial, i) = Trial(t.params, t.times[i], t.gctimes[i], t.memory, t.allocs)
Base.endof(t::Trial) = length(t)

function Base.sort!(t::Trial)
    inds = sortperm(t.times)
    t.times = t.times[inds]
    t.gctimes = t.gctimes[inds]
    return t
end

Base.time(t::Trial) = time(minimum(t))
gctime(t::Trial) = gctime(minimum(t))
memory(t::Trial) = t.memory
allocs(t::Trial) = t.allocs

function outliers(t::Trial, tolerance = t.params.tolerance)
    cutoff = length(t)
    threshold = 1.0 + tolerance
    for i in length(t):-1:2
        cutoff = ratio(t.times[i], t.times[i-1]) > threshold ? i : cutoff
    end
    return cutoff:length(t)
end

trim!(t::Trial, args...) = deleteat!(t, outliers(t, args...))
trim(t::Trial, args...) = t[1:first(outliers(t, args...))]

#################
# TrialEstimate #
#################

immutable TrialEstimate
    time::Float64
    gctime::Float64
    memory::Int
    allocs::Int
    tolerance::Float64
end

function TrialEstimate(trial::Trial, t, gct)
    return TrialEstimate(t, gct, memory(trial), allocs(trial), trial.params.tolerance)
end

function Base.(:(==))(a::TrialEstimate, b::TrialEstimate)
    return a.time == b.time &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

function Base.minimum(trial::Trial)
    i = indmin(trial.times)
    return TrialEstimate(trial, trial.times[i], trial.gctimes[i])
end

function Base.maximum(trial::Trial)
    i = indmax(trial.times)
    return TrialEstimate(trial, trial.times[i], trial.gctimes[i])
end

Base.median(trial::Trial) = TrialEstimate(trial, median(trial.times), median(trial.gctimes))
Base.mean(trial::Trial) = TrialEstimate(trial, mean(trial.times), mean(trial.gctimes))

Base.isless(a::TrialEstimate, b::TrialEstimate) = isless(time(a), time(b))

Base.time(t::TrialEstimate) = t.time
gctime(t::TrialEstimate) = t.gctime
memory(t::TrialEstimate) = t.memory
allocs(t::TrialEstimate) = t.allocs

##############
# TrialRatio #
##############

immutable TrialRatio
    time::Float64
    gctime::Float64
    memory::Float64
    allocs::Float64
    tolerance::Float64
end

function Base.(:(==))(a::TrialRatio, b::TrialRatio)
    return a.time == b.time &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.time(t::TrialRatio) = t.time
gctime(t::TrialRatio) = t.gctime
memory(t::TrialRatio) = t.memory
allocs(t::TrialRatio) = t.allocs

function ratio(a::Real, b::Real)
    if a == b # so that ratio(0.0, 0.0) returns 1.0
        return one(Float64)
    end
    return Float64(a / b)
end

function ratio(a::TrialEstimate, b::TrialEstimate)
    return TrialRatio(ratio(time(a),   time(b)),
                      ratio(gctime(a), gctime(b)),
                      ratio(memory(a), memory(b)),
                      ratio(allocs(a), allocs(b)),
                      max(a.tolerance, b.tolerance))
end

spread(t::Trial, est = mean) = ratio(est(t), minimum(t))

gcratio(t::TrialEstimate) =  gctime(t) / time(t)

##################
# TrialJudgement #
##################

immutable TrialJudgement
    ratio::TrialRatio
    time::Symbol
    memory::Symbol
    allocs::Symbol
end

function Base.(:(==))(a::TrialJudgement, b::TrialJudgement)
    return a.ratio == b.ratio &&
           a.time == b.time &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.time(t::TrialJudgement) = t.time
memory(t::TrialJudgement) = t.memory
allocs(t::TrialJudgement) = t.allocs
ratio(t::TrialJudgement) = t.ratio

function TrialJudgement(ratio::TrialRatio, tolerance::Float64)
    return TrialJudgement(ratio,
                          judge(time(ratio),   tolerance),
                          judge(memory(ratio), tolerance),
                          judge(allocs(ratio), tolerance))
end

function TrialJudgement(a::TrialEstimate, b::TrialEstimate, tolerance::Float64)
    return TrialJudgement(ratio(a, b), tolerance)
end

judge(a::TrialEstimate, b::TrialEstimate, tolerance = max(a.tolerance, b.tolerance)) = TrialJudgement(a, b, tolerance)
judge(ratio::TrialRatio, tolerance = ratio.tolerance) = TrialJudgement(ratio, tolerance)

function judge(ratio::Real, tolerance::Float64)
    if isnan(ratio) || (ratio - tolerance) > 1.0
        return :regression
    elseif (ratio + tolerance) < 1.0
        return :improvement
    else
        return :invariant
    end
end

hasjudgement(t::TrialJudgement, sym::Symbol) = time(t) == sym || memory(t) == sym || allocs(t) == sym
hasimprovement(t::TrialJudgement) = hasjudgement(t, :improvement)
hasregression(t::TrialJudgement) = hasjudgement(t, :regression)
isinvariant(t::TrialJudgement) = time(t) == :invariant && memory(t) == :invariant && allocs(t) == :invariant

###################
# Pretty Printing #
###################

prettypercent(p) = string(round(p * 100, 2), "%")

function prettydiff(p)
    diff = p - 1.0
    return string(diff >= 0.0 ? "+" : "", round(diff * 100, 2), "%")
end

function prettytime(t)
    if t < 1e3
        value, units = t, "ns"
    elseif t < 1e6
        value, units = t / 1e3, "μs"
    elseif t < 1e9
        value, units = t / 1e6, "ms"
    else
        value, units = t / 1e9, "s"
    end
    return string(round(value, 2), " ", units)
end

function prettymemory(b)
    if b < 1024
        value, units = b, "bytes"
    elseif b < 1024^2
        value, units = b / 1024, "kb"
    elseif b < 1024^3
        value, units = b / 1024^2, "mb"
    else
        value, units = b / 1024^3, "gb"
    end
    return string(round(value, 2), " ", units)
end

function Base.show(io::IO, t::Trial)
    min = minimum(t)
    max = maximum(t)
    med = median(t)
    avg = mean(t)
    println(io, "BenchmarkTools.Trial: ")
    println(io, "  noise tolerance: ", prettypercent(t.params.tolerance))
    println(io, "  # of samples:    ", length(t), " (", t.outliers, " outliers removed)")
    println(io, "  evals/sample:    ", t.params.evals)
    println(io, "  memory:          ", prettymemory(memory(min)))
    println(io, "  allocs:          ", allocs(min))
    println(io, "  minimum time:    ", prettytime(time(min)), " (", prettypercent(gcratio(min))," GC)")
    println(io, "  median time:     ", prettytime(time(med)), " (", prettypercent(gcratio(med))," GC)")
    println(io, "  mean time:       ", prettytime(time(avg)), " (", prettypercent(gcratio(avg))," GC)")
    print(io,   "  maximum time:    ", prettytime(time(max)), " (", prettypercent(gcratio(max))," GC)")

end

function Base.show(io::IO, t::TrialEstimate)
    println(io, "BenchmarkTools.TrialEstimate: ")
    println(io, "  time:    ", prettytime(time(t)))
    println(io, "  gctime:  ", prettytime(gctime(t)), " (", prettypercent(gctime(t) / time(t)),")")
    println(io, "  memory:  ", prettymemory(memory(t)))
    print(io,   "  allocs:  ", allocs(t))
end

function Base.show(io::IO, t::TrialRatio)
    println(io, "BenchmarkTools.TrialRatio: ")
    println(io, "  time:   ", time(t))
    println(io, "  gctime: ", gctime(t))
    println(io, "  memory: ", memory(t))
    print(io,   "  allocs: ", allocs(t))
end

function Base.show(io::IO, t::TrialJudgement)
    println(io, "BenchmarkTools.TrialJudgement: ")
    println(io, "  time:   ", prettydiff(time(ratio(t))), " => ", time(t))
    println(io, "  gctime: ", prettydiff(gctime(ratio(t))), " => N/A")
    println(io, "  memory: ", prettydiff(memory(ratio(t))), " => ", memory(t))
    print(io,   "  allocs: ", prettydiff(allocs(ratio(t))), " => ", allocs(t))
end

Base.showcompact(io::IO, t::TrialEstimate) = print(io, "TrialEstimate(", prettytime(time(t)), ")")
Base.showcompact(io::IO, t::TrialRatio) = print(io, "TrialRatio(", prettypercent(time(t)), ")")
Base.showcompact(io::IO, t::TrialJudgement) = print(io, "TrialJudgement(", prettydiff(time(ratio(t))), " => ", time(t), ")")
