#########
# Trial #
#########

type Trial
    evals::Vector{Float64}
    times::Vector{Float64}
    gctimes::Vector{Float64}
    memory::Vector{Float64}
    allocs::Vector{Float64}
end

function Trial(evals::Number, time::Number, gctime::Number, memory::Number, allocs::Number)
    return Trial(Float64[evals], Float64[time], Float64[gctime], Float64[memory], Float64[allocs])
end

Trial() = Trial(Float64[], Float64[], Float64[], Float64[], Float64[])

function Base.(:(==))(a::Trial, b::Trial)
    return a.evals == b.evals &&
           a.times == b.times &&
           a.gctimes == b.gctimes &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

function Base.push!(t::Trial, evals, time, gctime, memory, allocs)
    @assert isinteger(evals) && isinteger(memory) && isinteger(allocs)
    push!(t.evals, evals)
    push!(t.times, time)
    push!(t.gctimes, gctime)
    push!(t.memory, memory)
    push!(t.allocs, allocs)
    return t
end

Base.length(t::Trial) = length(t.evals)
Base.getindex(t::Trial, i) = Trial(t.evals[i], t.times[i], t.gctimes[i], t.memory[i], t.allocs[i])
Base.endof(t::Trial) = length(t)

Base.time(t::Trial) = t.times ./ t.evals
gctime(t::Trial) = t.gctimes ./ t.evals
memory(t::Trial) = [fld(t.memory[i], t.evals[i]) for i in 1:length(t)]
allocs(t::Trial) = [fld(t.allocs[i], t.evals[i]) for i in 1:length(t)]

#################
# TrialEstimate #
#################

immutable TrialEstimate
    time::Float64
    gctime::Float64
    memory::Int
    allocs::Int
    fitness::Float64
end

function Base.(:(==))(a::TrialEstimate, b::TrialEstimate)
    return a.time == b.times &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

function Base.minimum(trial::Trial)
    ts = time(trial)
    i = indmin(ts)
    t = ts[i]
    gct = gctime(trial)[i]
    bs = Int(minimum(memory(trial)))
    as = Int(minimum(allocs(trial)))
    return TrialEstimate(t, gct, bs, as, NaN)
end

function Base.linreg(trial::Trial)
    s, t = linreg(trial.evals, trial.times)
    rsqr = 1 - var(s .+ (t * trial.evals) .- trial.times) / var(trial.times)
    _, gct = linreg(trial.evals, trial.gctimes)
    bs = Int(minimum(memory(trial)))
    as = Int(minimum(allocs(trial)))
    return TrialEstimate(t, abs(gct), bs, as, rsqr)
end

Base.time(t::TrialEstimate) = t.time
gctime(t::TrialEstimate) = t.gctime
memory(t::TrialEstimate) = t.memory
allocs(t::TrialEstimate) = t.allocs

Base.isless(a::TrialEstimate, b::TrialEstimate) = isless(time(a), time(b))

##############
# TrialRatio #
##############

immutable TrialRatio
    time::Float64
    gctime::Float64
    memory::Float64
    allocs::Float64
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
                      ratio(allocs(a), allocs(b)))
end

##################
# TrialJudgement #
##################

const DEFAULT_TOLERANCE = 0.05

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

function TrialJudgement(ratio::TrialRatio, tolerance = DEFAULT_TOLERANCE)
    return TrialJudgement(ratio,
                          judge(time(ratio),   tolerance),
                          judge(memory(ratio), tolerance),
                          judge(allocs(ratio), tolerance))
end

function TrialJudgement(a::TrialEstimate, b::TrialEstimate, tolerance = DEFAULT_TOLERANCE)
    return TrialJudgement(ratio(a, b), tolerance)
end

judge(a::TrialEstimate, b::TrialEstimate, tolerance = DEFAULT_TOLERANCE) = TrialJudgement(a, b, tolerance)
judge(ratio::TrialRatio, tolerance = DEFAULT_TOLERANCE) = TrialJudgement(ratio, tolerance)

function judge(ratio::Real, tolerance = DEFAULT_TOLERANCE)
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
    i = minimum(t)
    r = linreg(t)
    println(io, "BenchmarkTools.Trial: ")
    println(io, "  # of samples:            ", length(t))
    println(io, "  max evals/sample:        ", Int(last(t.evals)))
    println(io, "  -------------------------")
    println(io, "  minimum time estimate:   ", prettytime(time(i)))
    println(io, "  minimum gctime estimate: ", prettytime(gctime(i)), " (", prettypercent(gctime(i) / time(i)),")")
    println(io, "  -------------------------")
    println(io, "  linreg time estimate:    ", prettytime(time(r)))
    println(io, "  linreg gctime estimate:  ", prettytime(gctime(r)), " (", prettypercent(gctime(r) / time(r)),")")
    println(io, "  linreg R²:               ", round(r.fitness, 4))
    println(io, "  -------------------------")
    println(io, "  memory estimate:         ", prettymemory(memory(i)))
    print(io,   "  allocs estimate:         ", allocs(i))
end

function Base.show(io::IO, t::TrialEstimate)
    println(io, "BenchmarkTools.TrialEstimate: ")
    println(io, "  time:    ", prettytime(time(t)))
    println(io, "  gctime:  ", prettytime(gctime(t)), " (", prettypercent(gctime(t) / time(t)),")")
    println(io, "  memory:  ", prettymemory(memory(t)))
    println(io, "  allocs:  ", allocs(t))
    print(io,   "  fitness: ", round(t.fitness, 4))

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
