# This file is a part of BenchmarkTools.jl. License is MIT

#########
# Trial #
#########

mutable struct Trial
    params::Parameters
    realtimes::Vector{Float64}
    cputimes::Vector{Float64}
    gctimes::Vector{Float64}
    memory::Int
    allocs::Int
end

Trial(params::Parameters) = Trial(params, Float64[], Float64[], Float64[], typemax(Int), typemax(Int))

@compat function Base.:(==)(a::Trial, b::Trial)
    return a.params == b.params &&
           a.realtimes == b.realtimes &&
           a.cputimes == b.cputimes &&
           a.gctimes == b.gctimes &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.copy(t::Trial) = Trial(copy(t.params), copy(t.realtimes), copy(t.cputimes), copy(t.gctimes), t.memory, t.allocs)

function Base.push!(t::Trial, realtime, cputime, gctime, memory, allocs)
    push!(t.realtimes, realtime)
    push!(t.cputimes, cputime)
    push!(t.gctimes, gctime)
    memory < t.memory && (t.memory = memory)
    allocs < t.allocs && (t.allocs = allocs)
    return t
end

function Base.deleteat!(t::Trial, i)
    deleteat!(t.realtimes, i)
    deleteat!(t.cputimes, i)
    deleteat!(t.gctimes, i)
    return t
end

Base.length(t::Trial) = length(t.realtimes)
Base.getindex(t::Trial, i::Number) = push!(Trial(t.params), t.realtimes[i], t.cputimes[i], t.gctimes[i], t.memory, t.allocs)
Base.getindex(t::Trial, i) = Trial(t.params, t.realtimes[i], t.cputimes[i], t.gctimes[i], t.memory, t.allocs)
Base.endof(t::Trial) = length(t)

function Base.sort!(t::Trial)
    inds = sortperm(t.realtimes)
    t.realtimes = t.realtimes[inds]
    t.cputimes = t.cputimes[inds]
    t.gctimes = t.gctimes[inds]
    return t
end

Base.sort(t::Trial) = sort!(copy(t))

realtime(t::Trial) = realtime(minimum(t))
cputime(t::Trial) = cputime(minimum(t))
gctime(t::Trial) = gctime(minimum(t))
memory(t::Trial) = t.memory
allocs(t::Trial) = t.allocs
params(t::Trial) = t.params

# returns the index of the first outlier in `values`, if any outliers are detected.
# `values` is assumed to be sorted from least to greatest, and assumed to be right-skewed.
function skewcutoff(values)
    current_values = copy(values)
    while mean(current_values) > median(current_values)
        deleteat!(current_values, length(current_values))
    end
    return length(current_values) + 1
end

skewcutoff(t::Trial) = skewcutoff(t.realtimes)

function rmskew!(t::Trial)
    sort!(t)
    i = skewcutoff(t)
    i <= length(t) && deleteat!(t, i:length(t))
    return t
end

function rmskew(t::Trial)
    st = sort(t)
    return st[1:(skewcutoff(st) - 1)]
end

trim(t::Trial, percentage = 0.1) = t[1:max(1, floor(Int, length(t) - (length(t) * percentage)))]

#################
# TrialEstimate #
#################

mutable struct TrialEstimate
    params::Parameters
    realtime::Float64
    cputime::Float64
    gctime::Float64
    memory::Int
    allocs::Int
end

function TrialEstimate(trial::Trial, realtime, cputime, gctime)
    return TrialEstimate(params(trial), realtime, cputime, gctime, memory(trial), allocs(trial))
end

@compat function Base.:(==)(a::TrialEstimate, b::TrialEstimate)
    return a.params == b.params &&
           a.realtime == b.realtime &&
           a.cputime == b.cputime &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.copy(t::TrialEstimate) = TrialEstimate(copy(t.params), t.time, t.gctime, t.memory, t.allocs)

function Base.minimum(trial::Trial)
    i = indmin(trial.realtimes)
    return TrialEstimate(trial, trial.realtimes[i], trial.cputimes[i], trial.gctimes[i])
end

function Base.maximum(trial::Trial)
    i = indmax(trial.realtimes)
    return TrialEstimate(trial, trial.realtimes[i], trial.cputimes[i], trial.gctimes[i])
end

Base.median(trial::Trial) = TrialEstimate(trial, median(trial.realtimes), median(trial.cputimes), median(trial.gctimes))
Base.mean(trial::Trial) = TrialEstimate(trial, mean(trial.realtimes), mean(trial.cputimes), mean(trial.gctimes))

Base.isless(a::TrialEstimate, b::TrialEstimate) = isless(realtime(a), realtime(b))

realtime(t::TrialEstimate) = t.realtime
cputime(t::TrialEstimate) = t.cputime
gctime(t::TrialEstimate) = t.gctime
memory(t::TrialEstimate) = t.memory
allocs(t::TrialEstimate) = t.allocs
params(t::TrialEstimate) = t.params

##############
# TrialRatio #
##############

mutable struct TrialRatio
    params::Parameters
    realtime::Float64
    cputime::Float64
    gctime::Float64
    memory::Float64
    allocs::Float64
end

@compat function Base.:(==)(a::TrialRatio, b::TrialRatio)
    return a.params == b.params &&
           a.realtime == b.realtime &&
           a.cputime == b.cputime &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.copy(t::TrialRatio) = TrialRatio(copy(t.params), t.realtime, t.cputime, t.gctime, t.memory, t.allocs)

realtime(t::TrialRatio) = t.realtime
cputime(t::TrialRatio) = t.cputime
gctime(t::TrialRatio) = t.gctime
memory(t::TrialRatio) = t.memory
allocs(t::TrialRatio) = t.allocs
params(t::TrialRatio) = t.params

function ratio(a::Real, b::Real)
    if a == b # so that ratio(0.0, 0.0) returns 1.0
        return one(Float64)
    end
    return Float64(a / b)
end

function ratio(a::TrialEstimate, b::TrialEstimate)
    ttol = max(params(a).time_tolerance, params(b).time_tolerance)
    mtol = max(params(a).memory_tolerance, params(b).memory_tolerance)
    p = Parameters(params(a); time_tolerance = ttol, memory_tolerance = mtol)
    return TrialRatio(p, ratio(realtime(a), realtime(b)), ratio(cputime(a), cputime(b)),
                      ratio(gctime(a), gctime(b)), ratio(memory(a), memory(b)),
                      ratio(allocs(a), allocs(b)))
end

gcratio(t::TrialEstimate) =  ratio(gctime(t), realtime(t))
cpuratio(t::TrialEstimate) =  Timers.ACCURATE_CPUTIME ? ratio(cputime(t), realtime(t)) : NaN

##################
# TrialJudgement #
##################

struct TrialJudgement
    ratio::TrialRatio
    realtime::Symbol
    cputime::Symbol
    memory::Symbol
end

function TrialJudgement(r::TrialRatio)
    ttol = params(r).time_tolerance
    mtol = params(r).memory_tolerance
    return TrialJudgement(r, judge(realtime(r), ttol), judge(cputime(r), ttol), judge(memory(r), mtol))
end

@compat function Base.:(==)(a::TrialJudgement, b::TrialJudgement)
    return a.ratio == b.ratio &&
           a.realtime == b.realtime &&
           a.cputime == b.cputime &&
           a.memory == b.memory
end

Base.copy(t::TrialJudgement) = TrialJudgement(copy(t.params), t.realtime, t.cputime, t.memory)

realtime(t::TrialJudgement) = t.realtime
cputime(t::TrialJudgement) = t.cputime
memory(t::TrialJudgement) = t.memory
ratio(t::TrialJudgement) = t.ratio
params(t::TrialJudgement) = params(ratio(t))

judge(a::TrialEstimate, b::TrialEstimate; kwargs...) = judge(ratio(a, b); kwargs...)

function judge(r::TrialRatio; kwargs...)
    newr = copy(r)
    newr.params = Parameters(params(r); kwargs...)
    return TrialJudgement(newr)
end

function judge(ratio::Real, tolerance::Float64)
    if isnan(ratio) || (ratio - tolerance) > 1.0
        return :regression
    elseif (ratio + tolerance) < 1.0
        return :improvement
    else
        return :invariant
    end
end

isimprovement(t::TrialJudgement) = realtime(t) == :improvement || cputime(t) == :improvement || memory(t) == :improvement
isregression(t::TrialJudgement) = realtime(t) == :regression || cputime(t) == :regression || memory(t) == :regression
isinvariant(t::TrialJudgement) = realtime(t) == :invariant && cputime(t) == :invariant && memory(t) == :invariant

###################
# Pretty Printing #
###################

prettypercent(p) = string(@sprintf("%.2f", p * 100), "%")

function prettydiff(p)
    diff = p - 1.0
    return string(diff >= 0.0 ? "+" : "", @sprintf("%.2f", diff * 100), "%")
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
    return string(@sprintf("%.3f", value), " ", units)
end

function prettymemory(b)
    if b < 1024
        return string(b, " bytes")
    elseif b < 1024^2
        value, units = b / 1024, "KiB"
    elseif b < 1024^3
        value, units = b / 1024^2, "MiB"
    else
        value, units = b / 1024^3, "GiB"
    end
    return string(@sprintf("%.2f", value), " ", units)
end

Base.show(io::IO, t::Trial) = print(io, "Trial(", prettytime(realtime(t)), ")")
Base.show(io::IO, t::TrialEstimate) = print(io, "TrialEstimate(", prettytime(realtime(t)), ")")
Base.show(io::IO, t::TrialRatio) = print(io, "TrialRatio(", prettypercent(realtime(t)), ")")
Base.show(io::IO, t::TrialJudgement) = print(io, "TrialJudgement(", prettydiff(realtime(ratio(t))), " => ", realtime(t), ")")

@compat function Base.show(io::IO, ::MIME"text/plain", t::Trial)
    if length(t) > 0
        min = minimum(t)
        max = maximum(t)
        med = median(t)
        avg = mean(t)
        memorystr = string(prettymemory(memory(min)))
        allocsstr = string(allocs(min))
        minstr = string(prettytime(realtime(min)), " (", prettypercent(cpuratio(min)) ," CPU, ", prettypercent(gcratio(min)), " GC)")
        maxstr = string(prettytime(realtime(med)), " (", prettypercent(cpuratio(med)) ," CPU, ", prettypercent(gcratio(med)), " GC)")
        medstr = string(prettytime(realtime(avg)), " (", prettypercent(cpuratio(avg)) ," CPU, ", prettypercent(gcratio(avg)), " GC)")
        meanstr = string(prettytime(realtime(max)), " (", prettypercent(cpuratio(max)) ," CPU, ", prettypercent(gcratio(max)), " GC)")
    else
        memorystr = "N/A"
        allocsstr = "N/A"
        minstr = "N/A"
        maxstr = "N/A"
        medstr = "N/A"
        meanstr = "N/A"
    end
    println(io, "BenchmarkTools.Trial: ")
    println(io, "  memory estimate:  ", memorystr)
    println(io, "  allocs estimate:  ", allocsstr)
    println(io, "  --------------")
    println(io, "  minimum time:     ", minstr)
    println(io, "  median time:      ", maxstr)
    println(io, "  mean time:        ", medstr)
    println(io, "  maximum time:     ", meanstr)
    println(io, "  --------------")
    println(io, "  samples:          ", length(t))
    print(io,   "  evals/sample:     ", t.params.evals)
end

@compat function Base.show(io::IO, ::MIME"text/plain", t::TrialEstimate)
    println(io, "BenchmarkTools.TrialEstimate: ")
    println(io, "  realtime:         ", prettytime(realtime(t)))
    if Timers.ACCURATE_CPUTIME
        println(io, "  cputime:          ", prettytime(cputime(t)), " (", prettypercent(cpuratio(t)),")")
    else
        println(io, "  cputime:          ", "NA on Windows, see docs")
    end
    println(io, "  gctime:           ", prettytime(gctime(t)), " (", prettypercent(gcratio(t)),")")
    println(io, "  memory:           ", prettymemory(memory(t)))
    print(io,   "  allocs:           ", allocs(t))
end

@compat function Base.show(io::IO, ::MIME"text/plain", t::TrialRatio)
    println(io, "BenchmarkTools.TrialRatio: ")
    println(io, "  realtime:         ", realtime(t))
    if Timers.ACCURATE_CPUTIME
        println(io, "  cputime:          ", cputime(t))
    else
        println(io, "  cputime:          ", "NA on Windows, see docs")
    end
    println(io, "  gctime:           ", gctime(t))
    println(io, "  memory:           ", memory(t))
    print(io,   "  allocs:           ", allocs(t))
end

@compat function Base.show(io::IO, ::MIME"text/plain", t::TrialJudgement)
    println(io, "BenchmarkTools.TrialJudgement: ")
    println(io, "  realtime: ", prettydiff(realtime(ratio(t))), " => ", realtime(t), " (", prettypercent(params(t).time_tolerance), " tolerance)")
    if Timers.ACCURATE_CPUTIME
        println(io, "  cputime:  ", prettydiff(cputime(ratio(t))), " => ", cputime(t), " (", prettypercent(params(t).time_tolerance), " tolerance)")
    else
        println(io, "  cputime:  ", "NA on Windows, see docs")
    end
    print(io,   "  memory:   ", prettydiff(memory(ratio(t))), " => ", memory(t), " (", prettypercent(params(t).memory_tolerance), " tolerance)")
end
