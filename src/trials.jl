#########
# Trial #
#########

type Trial
    params::Parameters
    times::Vector{Int}
    gctimes::Vector{Int}
    memory::Int
    allocs::Int
end

Trial(params::Parameters) = Trial(params, Int[], Int[], typemax(Int), typemax(Int))

function Base.(:(==))(a::Trial, b::Trial)
    return a.params == b.params &&
           a.times == b.times &&
           a.gctimes == b.gctimes &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.copy(t::Trial) = Trial(copy(t.params), copy(t.times), copy(t.gctimes), t.memory, t.allocs)

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
Base.getindex(t::Trial, i::Number) = push!(Trial(t.params), t.times[i], t.gctimes[i], t.memory, t.allocs)
Base.getindex(t::Trial, i) = Trial(t.params, t.times[i], t.gctimes[i], t.memory, t.allocs)
Base.endof(t::Trial) = length(t)

function Base.sort!(t::Trial)
    inds = sortperm(t.times)
    t.times = t.times[inds]
    t.gctimes = t.gctimes[inds]
    return t
end

Base.sort(t::Trial) = sort!(copy(t))

Base.time(t::Trial) = time(minimum(t))
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

skewcutoff(t::Trial) = skewcutoff(t.times)

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

#################
# TrialEstimate #
#################

type TrialEstimate
    params::Parameters
    time::Float64
    gctime::Float64
    memory::Int
    allocs::Int
end

function TrialEstimate(trial::Trial, t, gct)
    return TrialEstimate(params(trial), t, gct, memory(trial), allocs(trial))
end

function Base.(:(==))(a::TrialEstimate, b::TrialEstimate)
    return a.params == b.params &&
           a.time == b.time &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.copy(t::TrialEstimate) = TrialEstimate(copy(t.params), t.time, t.gctime, t.memory, t.allocs)

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
params(t::TrialEstimate) = t.params

##############
# TrialRatio #
##############

type TrialRatio
    params::Parameters
    time::Float64
    gctime::Float64
    memory::Float64
    allocs::Float64
end

function Base.(:(==))(a::TrialRatio, b::TrialRatio)
    return a.params == b.params &&
           a.time == b.time &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.copy(t::TrialRatio) = TrialRatio(copy(t.params), t.time, t.gctime, t.memory, t.allocs)

Base.time(t::TrialRatio) = t.time
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
    return TrialRatio(p, ratio(time(a), time(b)), ratio(gctime(a), gctime(b)),
                      ratio(memory(a), memory(b)), ratio(allocs(a), allocs(b)))
end

gcratio(t::TrialEstimate) =  ratio(gctime(t), time(t))

##################
# TrialJudgement #
##################

immutable TrialJudgement
    ratio::TrialRatio
    time::Symbol
    memory::Symbol
end

function TrialJudgement(r::TrialRatio)
    ttol = params(r).time_tolerance
    mtol = params(r).memory_tolerance
    return TrialJudgement(r, judge(time(r), ttol), judge(memory(r), mtol))
end

function Base.(:(==))(a::TrialJudgement, b::TrialJudgement)
    return a.ratio == b.ratio &&
           a.time == b.time &&
           a.memory == b.memory
end

Base.copy(t::TrialJudgement) = TrialJudgement(copy(t.params), t.time, t.memory)

Base.time(t::TrialJudgement) = t.time
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

hasjudgement(t::TrialJudgement, sym::Symbol) = time(t) == sym || memory(t) == sym
isimprovement(t::TrialJudgement) = hasjudgement(t, :improvement)
isregression(t::TrialJudgement) = hasjudgement(t, :regression)
isinvariant(t::TrialJudgement) = time(t) == :invariant && memory(t) == :invariant

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
    if length(t) > 0
        min = minimum(t)
        max = maximum(t)
        med = median(t)
        avg = mean(t)
        memorystr = string(prettymemory(memory(min)))
        allocsstr = string(allocs(min))
        minstr = string(prettytime(time(min)), " (", prettypercent(gcratio(min)), " GC)")
        maxstr = string(prettytime(time(med)), " (", prettypercent(gcratio(med)), " GC)")
        medstr = string(prettytime(time(avg)), " (", prettypercent(gcratio(avg)), " GC)")
        meanstr = string(prettytime(time(max)), " (", prettypercent(gcratio(max)), " GC)")
    else
        memorystr = "N/A"
        allocsstr = "N/A"
        minstr = "N/A"
        maxstr = "N/A"
        medstr = "N/A"
        meanstr = "N/A"
    end
    println(io, "BenchmarkTools.Trial: ")
    println(io, "  samples:          ", length(t))
    println(io, "  evals/sample:     ", t.params.evals)
    println(io, "  time tolerance:   ", prettypercent(params(t).time_tolerance))
    println(io, "  memory tolerance: ", prettypercent(params(t).memory_tolerance))
    println(io, "  memory estimate:  ", memorystr)
    println(io, "  allocs estimate:  ", allocsstr)
    println(io, "  minimum time:     ", minstr)
    println(io, "  median time:      ", maxstr)
    println(io, "  mean time:        ", medstr)
    print(io,   "  maximum time:     ", meanstr)
end

function Base.show(io::IO, t::TrialEstimate)
    println(io, "BenchmarkTools.TrialEstimate: ")
    println(io, "  time:             ", prettytime(time(t)))
    println(io, "  gctime:           ", prettytime(gctime(t)), " (", prettypercent(gctime(t) / time(t)),")")
    println(io, "  memory:           ", prettymemory(memory(t)))
    println(io, "  allocs:           ", allocs(t))
    println(io, "  time tolerance:   ", prettypercent(params(t).time_tolerance))
    print(io,   "  memory tolerance: ", prettypercent(params(t).memory_tolerance))
end

function Base.show(io::IO, t::TrialRatio)
    println(io, "BenchmarkTools.TrialRatio: ")
    println(io, "  time:             ", time(t))
    println(io, "  gctime:           ", gctime(t))
    println(io, "  memory:           ", memory(t))
    println(io, "  allocs:           ", allocs(t))
    println(io, "  time tolerance:   ", prettypercent(params(t).time_tolerance))
    print(io,   "  memory tolerance: ", prettypercent(params(t).memory_tolerance))
end

function Base.show(io::IO, t::TrialJudgement)
    println(io, "BenchmarkTools.TrialJudgement: ")
    println(io, "  time:   ", prettydiff(time(ratio(t))), " => ", time(t), " (", prettypercent(params(t).time_tolerance), " tolerance)")
    print(io,   "  memory: ", prettydiff(memory(ratio(t))), " => ", memory(t), " (", prettypercent(params(t).memory_tolerance), " tolerance)")
end

Base.showcompact(io::IO, t::Trial) = print(io, "Trial(", prettytime(time(t)), ")")
Base.showcompact(io::IO, t::TrialEstimate) = print(io, "TrialEstimate(", prettytime(time(t)), ")")
Base.showcompact(io::IO, t::TrialRatio) = print(io, "TrialRatio(", prettypercent(time(t)), ")")
Base.showcompact(io::IO, t::TrialJudgement) = print(io, "TrialJudgement(", prettydiff(time(ratio(t))), " => ", time(t), ")")
