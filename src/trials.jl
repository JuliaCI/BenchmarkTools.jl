#########
# Trial #
#########

immutable Trial
    evals::Float64
    time::Float64
    gctime::Float64
    memory::Float64
    allocs::Float64
end

function Trial(time::Number, gctime::Number, memory::Number, allocs::Number)
    return Trial(1.0, time, gctime, memory, allocs)
end

Base.time(t::Trial) = t.time / t.evals
gctime(t::Trial) = t.gctime / t.evals
memory(t::Trial) = fld(t.memory, t.evals)
allocs(t::Trial) = fld(t.allocs, t.evals)

Base.isless(a::Trial, b::Trial) = isless(time(a), time(b))

##############
# TrialRatio #
##############

immutable TrialRatio
    time::Float64
    gctime::Float64
    memory::Float64
    allocs::Float64
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

function ratio(a::Trial, b::Trial)
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

function TrialJudgement(a::Trial, b::Trial, tolerance = DEFAULT_TOLERANCE)
    return TrialJudgement(ratio(a, b), tolerance)
end

judge(a::Trial, b::Trial, tolerance = DEFAULT_TOLERANCE) = TrialJudgement(a, b, tolerance)
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
    if t < 1e4
        value, units = t, "ns"
    elseif t < 1e6
        value, units = t / 1e4, "μs"
    elseif t < 1e9
        value, units = t / 1e6, "ms"
    elseif t < 1e12
        value, units = t / 1e9, "s"
    else
        error("invalid time $t")
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
    elseif b < 1024^4
        value, units = b / 1024^3, "gb"
    else
        error("invalid memory $b")
    end
    return string(round(value, 2), " ", units)
end

function Base.show(io::IO, t::Trial)
    println(io, "BenchmarkTools.Trial: ")
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

Base.showcompact(io::IO, t::Trial) = print(io, "Trial(", prettytime(time(t)), ")")
Base.showcompact(io::IO, t::TrialRatio) = print(io, "TrialRatio(", prettypercent(time(t)), ")")
Base.showcompact(io::IO, t::TrialJudgement) = print(io, "TrialJudgement(", prettydiff(time(ratio(t))), " => ", time(t), ")")
