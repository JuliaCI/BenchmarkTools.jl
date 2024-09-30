#########
# Trial #
#########

mutable struct Trial
    params::Parameters
    times::Vector{Float64}
    instructions::Vector{Float64}
    branches::Vector{Float64}
    gctimes::Vector{Float64}
    memory::Int
    allocs::Int
end

function Trial(params::Parameters)
    return Trial(
        params, Float64[], Float64[], Float64[], Float64[], typemax(Int), typemax(Int)
    )
end

function eq_including_nan(x::Float64, y::Float64)
    return x === y
end

function eq_including_nan(x::Vector{Float64}, y::Vector{Float64})
    return all(eq_including_nan.(x, y))
end

function Base.:(==)(a::Trial, b::Trial)
    return a.params == b.params &&
           a.times == b.times &&
           eq_including_nan(a.instructions, b.instructions) &&
           eq_including_nan(a.branches, b.branches) &&
           a.gctimes == b.gctimes &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

function Base.copy(t::Trial)
    return Trial(
        copy(t.params),
        copy(t.times),
        copy(t.instructions),
        copy(t.branches),
        copy(t.gctimes),
        t.memory,
        t.allocs,
    )
end

function Base.push!(t::Trial, time, instructions, branches, gctime, memory, allocs)
    push!(t.times, time)
    push!(t.instructions, instructions)
    push!(t.branches, branches)
    push!(t.gctimes, gctime)
    memory < t.memory && (t.memory = memory)
    allocs < t.allocs && (t.allocs = allocs)
    return t
end

function Base.deleteat!(t::Trial, i)
    deleteat!(t.times, i)
    deleteat!(t.instructions, i)
    deleteat!(t.branches, i)
    deleteat!(t.gctimes, i)
    return t
end

Base.length(t::Trial) = length(t.times)
function Base.getindex(t::Trial, i::Number)
    return push!(
        Trial(t.params),
        t.times[i],
        t.instructions[i],
        t.branches[i],
        t.gctimes[i],
        t.memory,
        t.allocs,
    )
end
function Base.getindex(t::Trial, i)
    return Trial(
        t.params,
        t.times[i],
        t.instructions[i],
        t.branches[i],
        t.gctimes[i],
        t.memory,
        t.allocs,
    )
end
Base.lastindex(t::Trial) = length(t)

function Base.sort!(t::Trial)
    inds = sortperm(t.times)
    t.times = t.times[inds]
    t.instructions = t.instructions[inds]
    t.branches = t.branches[inds]
    t.gctimes = t.gctimes[inds]
    return t
end

Base.sort(t::Trial) = sort!(copy(t))

Base.time(t::Trial) = time(minimum(t))
instructions(t::Trial) = instructions(minimum(t))
branches(t::Trial) = branches(minimum(t))
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

function trim(t::Trial, percentage=0.1)
    return t[1:max(1, floor(Int, length(t) - (length(t) * percentage)))]
end

#################
# TrialEstimate #
#################

mutable struct TrialEstimate
    params::Parameters
    time::Float64
    instructions::Float64
    branches::Float64
    gctime::Float64
    memory::Int
    allocs::Int
end

function TrialEstimate(trial::Trial, t, instructions, branches, gctime)
    return TrialEstimate(
        params(trial), t, instructions, branches, gctime, memory(trial), allocs(trial)
    )
end

function Base.:(==)(a::TrialEstimate, b::TrialEstimate)
    return a.params == b.params &&
           a.time == b.time &&
           eq_including_nan(a.instructions, b.instructions) &&
           eq_including_nan(a.branches, b.branches) &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

function Base.copy(t::TrialEstimate)
    return TrialEstimate(
        copy(t.params), t.time, t.instructions, t.branches, t.gctime, t.memory, t.allocs
    )
end

function Base.minimum(trial::Trial)
    i = argmin(trial.times)
    return TrialEstimate(
        trial, trial.times[i], trial.instructions[i], trial.branches[i], trial.gctimes[i]
    )
end

function Base.maximum(trial::Trial)
    i = argmax(trial.times)
    return TrialEstimate(
        trial, trial.times[i], trial.instructions[i], trial.branches[i], trial.gctimes[i]
    )
end

function Statistics.median(trial::Trial)
    return TrialEstimate(
        trial,
        median(trial.times),
        any(!isnan, trial.instructions) ? median(filter(!isnan, trial.instructions)) : NaN,
        any(!isnan, trial.branches) ? median(filter(!isnan, trial.branches)) : NaN,
        median(trial.gctimes),
    )
end
function Statistics.mean(trial::Trial)
    return TrialEstimate(
        trial,
        mean(trial.times),
        mean(filter(!isnan, trial.instructions)),
        mean(filter(!isnan, trial.branches)),
        mean(trial.gctimes),
    )
end
function Statistics.var(trial::Trial)
    return TrialEstimate(
        trial,
        var(trial.times),
        var(filter(!isnan, trial.instructions)),
        var(filter(!isnan, trial.branches)),
        var(trial.gctimes),
    )
end
function Statistics.std(trial::Trial)
    return TrialEstimate(
        trial,
        std(trial.times),
        std(filter(!isnan, trial.instructions)),
        std(filter(!isnan, trial.branches)),
        std(trial.gctimes),
    )
end

Base.isless(a::TrialEstimate, b::TrialEstimate) = isless(time(a), time(b))

Base.time(t::TrialEstimate) = t.time
instructions(t::TrialEstimate) = !isnan(t.instructions) ? t.instructions : nothing
branches(t::TrialEstimate) = !isnan(t.branches) ? t.branches : nothing
gctime(t::TrialEstimate) = t.gctime
memory(t::TrialEstimate) = t.memory
allocs(t::TrialEstimate) = t.allocs
params(t::TrialEstimate) = t.params

##############
# TrialRatio #
##############

mutable struct TrialRatio
    params::Parameters
    time::Float64
    instructions::Float64
    branches::Float64
    gctime::Float64
    memory::Float64
    allocs::Float64
end

function Base.:(==)(a::TrialRatio, b::TrialRatio)
    return a.params == b.params &&
           a.time == b.time &&
           eq_including_nan(a.instructions, b.instructions) &&
           eq_including_nan(a.branches, b.branches) &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

function Base.copy(t::TrialRatio)
    return TrialRatio(
        copy(t.params), t.time, t.instructions, t.branches, t.gctime, t.memory, t.allocs
    )
end

Base.time(t::TrialRatio) = t.time
instructions(t::TrialRatio) = !isnan(t.instructions) ? t.instructions : nothing
branches(t::TrialRatio) = !isnan(t.branches) ? t.branches : nothing
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
    p = Parameters(params(a); time_tolerance=ttol, memory_tolerance=mtol)
    instruction_ratio = if (instructions(a) === nothing || instructions(b) === nothing)
        NaN
    else
        ratio(instructions(a), instructions(b))
    end
    branch_ratio = if (branches(a) === nothing || branches(b) === nothing)
        NaN
    else
        ratio(branches(a), branches(b))
    end
    return TrialRatio(
        p,
        ratio(time(a), time(b)),
        instruction_ratio,
        branch_ratio,
        ratio(gctime(a), gctime(b)),
        ratio(memory(a), memory(b)),
        ratio(allocs(a), allocs(b)),
    )
end

gcratio(t::TrialEstimate) = ratio(gctime(t), time(t))

##################
# TrialJudgement #
##################

struct TrialJudgement
    ratio::TrialRatio
    time::Symbol
    instructions::Symbol
    branches::Symbol
    memory::Symbol
end

function TrialJudgement(r::TrialRatio)
    ttol = params(r).time_tolerance
    itol = params(r).instruction_tolerance
    btol = params(r).branch_tolerance
    mtol = params(r).memory_tolerance
    return TrialJudgement(
        r,
        judge(time(r), ttol),
        judge(instructions(r), itol),
        judge(branches(r), btol),
        judge(memory(r), mtol),
    )
end

function Base.:(==)(a::TrialJudgement, b::TrialJudgement)
    return a.ratio == b.ratio &&
           a.time == b.time &&
           a.instructions == b.instructions &&
           a.branches == b.branches &&
           a.memory == b.memory
end

Base.copy(t::TrialJudgement) = TrialJudgement(copy(t.params), t.time, t.memory)

Base.time(t::TrialJudgement) = t.time
instructions(t::TrialJudgement) = t.instructions
branches(t::TrialJudgement) = t.branches
memory(t::TrialJudgement) = t.memory
ratio(t::TrialJudgement) = t.ratio
params(t::TrialJudgement) = params(ratio(t))

judge(a::TrialEstimate, b::TrialEstimate; kwargs...) = judge(ratio(a, b); kwargs...)

function judge(r::TrialRatio; kwargs...)
    newr = copy(r)
    newr.params = Parameters(params(r); kwargs...)
    return TrialJudgement(newr)
end

judge(ratio::Nothing, tolerance::Float64) = :unknown

function judge(ratio::Real, tolerance::Float64)
    if isnan(ratio)
        return :unknown
    elseif (ratio - tolerance) > 1.0
        return :regression
    elseif (ratio + tolerance) < 1.0
        return :improvement
    else
        return :invariant
    end
end

isimprovement(f, t::TrialJudgement) = f(t) == :improvement
function isimprovement(t::TrialJudgement)
    return isimprovement(time, t) ||
           isimprovement(instructions, t) ||
           isimprovement(branches, t) ||
           isimprovement(memory, t)
end

isregression(f, t::TrialJudgement) = f(t) == :regression
function isregression(t::TrialJudgement)
    return isregression(time, t) ||
           isregression(instructions, t) ||
           isregression(branches, t) ||
           isregression(memory, t)
end

isinvariant(f, t::TrialJudgement) = f(t) == :invariant || f(t) == :unknown
function isinvariant(t::TrialJudgement)
    return isinvariant(time, t) &&
           isinvariant(instructions, t) &&
           isinvariant(branches, t) &&
           isinvariant(memory, t)
end

const colormap = (regression=:red, improvement=:green, invariant=:normal, unknown=:gray)

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

function prettycount(b; base_unit="")
    if b < 1000
        value, units = b, base_unit
    elseif b < 1000^2
        value, units = b / 1000, "K" * base_unit
    elseif b < 1000^3
        value, units = b / 1000^2, "M" * base_unit
    else
        value, units = b / 1000^3, "G" * base_unit
    end
    return string(@sprintf("%.2f", value), " ", units)
end

function withtypename(f, io, t)
    needtype = get(io, :typeinfo, Nothing) !== typeof(t)
    if needtype
        print(io, nameof(typeof(t)), '(')
    end
    f()
    if needtype
        print(io, ')')
    end
end

function bindata(sorteddata, nbins, min, max)
    Δ = (max - min) / nbins
    bins = zeros(nbins)
    lastpos = 0
    for i in 1:nbins
        pos = searchsortedlast(sorteddata, min + i * Δ)
        bins[i] = pos - lastpos
        lastpos = pos
    end
    return bins
end
bindata(sorteddata, nbins) = bindata(sorteddata, nbins, first(sorteddata), last(sorteddata))

function asciihist(bins, height=1)
    histbars = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
    if minimum(bins) == 0
        barheights =
            2 .+ round.(Int, (height * length(histbars) - 2) * bins ./ maximum(bins))
        barheights[bins .== 0] .= 1
    else
        barheights =
            1 .+ round.(Int, (height * length(histbars) - 1) * bins ./ maximum(bins))
    end
    heightmatrix = [
        min(length(histbars), barheights[b] - (h - 1) * length(histbars)) for
        h in height:-1:1, b in 1:length(bins)
    ]
    return map(height -> if height < 1
        ' '
    else
        histbars[height]
    end, heightmatrix)
end

_summary(io, t, args...) = withtypename(() -> print(io, args...), io, t)

Base.summary(io::IO, t::Trial) = _summary(io, t, prettytime(time(t)))
Base.summary(io::IO, t::TrialEstimate) = _summary(io, t, prettytime(time(t)))
Base.summary(io::IO, t::TrialRatio) = _summary(io, t, prettypercent(time(t)))
function Base.summary(io::IO, t::TrialJudgement)
    withtypename(io, t) do
        print(io, prettydiff(time(ratio(t))), " => ")
        printstyled(io, time(t); color=colormap[time(t)])
    end
end

_show(io, t) =
    if get(io, :compact, true)
        summary(io, t)
    else
        show(io, MIME"text/plain"(), t)
    end

Base.show(io::IO, t::Trial) = _show(io, t)
Base.show(io::IO, t::TrialEstimate) = _show(io, t)
Base.show(io::IO, t::TrialRatio) = _show(io, t)
Base.show(io::IO, t::TrialJudgement) = _show(io, t)

function Base.show(io::IO, ::MIME"text/plain", t::Trial)
    pad = get(io, :pad, "")
    print(
        io,
        "BenchmarkTools.Trial: ",
        length(t),
        " sample",
        if length(t) > 1
            "s"
        else
            ""
        end,
        " with ",
        t.params.evals,
        " evaluation",
        if t.params.evals > 1
            "s"
        else
            ""
        end,
        ".\n",
    )

    perm = sortperm(t.times)
    times = t.times[perm]
    instructions = t.instructions[perm]
    branches = t.branches[perm]
    gctimes = t.gctimes[perm]

    if length(t) > 1
        med = median(t)
        avg = mean(t)
        std = Statistics.std(t)
        min = minimum(t)
        max = maximum(t)

        medtime, medgc = prettytime(time(med)), prettypercent(gcratio(med))
        avgtime, avggc = prettytime(time(avg)), prettypercent(gcratio(avg))
        stdtime, stdgc = prettytime(time(std)),
        prettypercent(Statistics.std(gctimes ./ times))
        mintime, mingc = prettytime(time(min)), prettypercent(gcratio(min))
        maxtime, maxgc = prettytime(time(max)), prettypercent(gcratio(max))

        memorystr = string(prettymemory(memory(min)))
        allocsstr = string(allocs(min))
    elseif length(t) == 1
        print(io, pad, " Single result which took ")
        printstyled(io, prettytime(times[1]); color=:blue)
        print(io, " (", prettypercent(gctimes[1] / times[1]), " GC) ")
        print(io, "to evaluate,\n")
        print(io, pad, " with a memory estimate of ")
        printstyled(io, prettymemory(t.memory[1]); color=:yellow)
        print(io, ", over ")
        printstyled(io, t.allocs[1]; color=:yellow)
        print(io, " allocations.")
        return nothing
    else
        print(io, pad, " No results.")
        return nothing
    end

    lmaxtimewidth = maximum(length.((medtime, avgtime, mintime)))
    rmaxtimewidth = maximum(length.((stdtime, maxtime)))
    lmaxgcwidth = maximum(length.((medgc, avggc, mingc)))
    rmaxgcwidth = maximum(length.((stdgc, maxgc)))

    # Main stats

    print(io, pad, " Range ")
    printstyled(io, "("; color=:light_black)
    printstyled(io, "min"; color=:cyan, bold=true)
    print(io, " … ")
    printstyled(io, "max"; color=:magenta)
    printstyled(io, "):  "; color=:light_black)
    printstyled(io, lpad(mintime, lmaxtimewidth); color=:cyan, bold=true)
    print(io, " … ")
    printstyled(io, lpad(maxtime, rmaxtimewidth); color=:magenta)
    print(io, "  ")
    printstyled(io, "┊"; color=:light_black)
    print(io, " GC ")
    printstyled(io, "("; color=:light_black)
    print(io, "min … max")
    printstyled(io, "): "; color=:light_black)
    print(io, lpad(mingc, lmaxgcwidth), " … ", lpad(maxgc, rmaxgcwidth))

    print(io, "\n", pad, " Time  ")
    printstyled(io, "("; color=:light_black)
    printstyled(io, "median"; color=:blue, bold=true)
    printstyled(io, "):     "; color=:light_black)
    printstyled(
        io,
        lpad(medtime, lmaxtimewidth),
        rpad(" ", rmaxtimewidth + 5);
        color=:blue,
        bold=true,
    )
    printstyled(io, "┊"; color=:light_black)
    print(io, " GC ")
    printstyled(io, "("; color=:light_black)
    print(io, "median")
    printstyled(io, "):    "; color=:light_black)
    print(io, lpad(medgc, lmaxgcwidth))

    print(io, "\n", pad, " Time  ")
    printstyled(io, "("; color=:light_black)
    printstyled(io, "mean"; color=:green, bold=true)
    print(io, " ± ")
    printstyled(io, "σ"; color=:green)
    printstyled(io, "):   "; color=:light_black)
    printstyled(io, lpad(avgtime, lmaxtimewidth); color=:green, bold=true)
    print(io, " ± ")
    printstyled(io, lpad(stdtime, rmaxtimewidth); color=:green)
    print(io, "  ")
    printstyled(io, "┊"; color=:light_black)
    print(io, " GC ")
    printstyled(io, "("; color=:light_black)
    print(io, "mean ± σ")
    printstyled(io, "):  "; color=:light_black)
    print(io, lpad(avggc, lmaxgcwidth), " ± ", lpad(stdgc, rmaxgcwidth))

    # Histogram

    histquantile = 0.99
    # The height and width of the printed histogram in characters.
    histheight = 2
    histwidth = 42 + lmaxtimewidth + rmaxtimewidth

    histtimes = times[1:round(Int, histquantile * end)]
    histmin = get(io, :histmin, first(histtimes))
    histmax = get(io, :histmax, last(histtimes))
    logbins = get(io, :logbins, nothing)
    bins = bindata(histtimes, histwidth - 1, histmin, histmax)
    append!(bins, [1, floor((1 - histquantile) * length(times))])
    # if median size of (bins with >10% average data/bin) is less than 5% of max bin size, log the bin sizes
    if logbins === true || (
        logbins === nothing &&
        median(filter(b -> b > 0.1 * length(times) / histwidth, bins)) / maximum(bins) <
        0.05
    )
        bins, logbins = log.(1 .+ bins), true
    else
        logbins = false
    end
    hist = asciihist(bins, histheight)
    hist[:, end - 1] .= ' '
    maxbin = maximum(bins)

    delta1 = (histmax - histmin) / (histwidth - 1)
    if delta1 > 0
        medpos = 1 + round(Int, (histtimes[length(times) ÷ 2] - histmin) / delta1)
        avgpos = 1 + round(Int, (mean(times) - histmin) / delta1)
    else
        medpos, avgpos = 1, 1
    end

    print(io, "\n")
    for r in axes(hist, 1)
        print(io, "\n", pad, "  ")
        for (i, bar) in enumerate(view(hist, r, :))
            color = :default
            if i == avgpos
                color = :green
            end
            if i == medpos
                color = :blue
            end
            printstyled(io, bar; color=color)
        end
    end

    remtrailingzeros(timestr) = replace(timestr, r"\.?0+ " => " ")
    minhisttime, maxhisttime =
        remtrailingzeros.(prettytime.(round.([histmin, histmax], sigdigits=3)))

    print(io, "\n", pad, "  ", minhisttime)
    caption = "Histogram: " * (logbins ? "log(frequency)" : "frequency") * " by time"
    if logbins
        printstyled(
            io,
            " "^((histwidth - length(caption)) ÷ 2 - length(minhisttime));
            color=:light_black,
        )
        printstyled(io, "Histogram: "; color=:light_black)
        printstyled(io, "log("; bold=true, color=:light_black)
        printstyled(io, "frequency"; color=:light_black)
        printstyled(io, ")"; bold=true, color=:light_black)
        printstyled(io, " by time"; color=:light_black)
    else
        printstyled(
            io,
            " "^((histwidth - length(caption)) ÷ 2 - length(minhisttime)),
            caption;
            color=:light_black,
        )
    end
    print(io, lpad(maxhisttime, ceil(Int, (histwidth - length(caption)) / 2) - 1), " ")
    printstyled(io, "<"; bold=true)

    # Memory info

    print(io, "\n\n", pad, " Memory estimate")
    printstyled(io, ": "; color=:light_black)
    printstyled(io, memorystr; color=:yellow)
    print(io, ", allocs estimate")
    printstyled(io, ": "; color=:light_black)
    printstyled(io, allocsstr; color=:yellow)
    return print(io, ".")
end

function Base.show(io::IO, ::MIME"text/plain", t::TrialEstimate)
    println(io, "BenchmarkTools.TrialEstimate:")
    pad = get(io, :pad, "")
    println(io, pad, "  time:             ", prettytime(time(t)))
    if instructions(t) !== nothing
        println(
            io, pad, "  instructions:     ", prettycount(instructions(t); base_unit="insts")
        )
    end
    if branches(t) !== nothing
        println(
            io, pad, "  branches:         ", prettycount(branches(t); base_unit="branches")
        )
    end
    println(
        io,
        pad,
        "  gctime:           ",
        prettytime(gctime(t)),
        " (",
        prettypercent(gctime(t) / time(t)),
        ")",
    )
    println(io, pad, "  memory:           ", prettymemory(memory(t)))
    return print(io, pad, "  allocs:           ", allocs(t))
end

function Base.show(io::IO, ::MIME"text/plain", t::TrialRatio)
    println(io, "BenchmarkTools.TrialRatio: ")
    pad = get(io, :pad, "")
    println(io, pad, "  time:             ", time(t))
    if instructions(t) !== nothing
        println(io, pad, "  instructions:     ", instructions(t))
    end
    if branches(t) !== nothing
        println(io, pad, "  branches:         ", branches(t))
    end
    println(io, pad, "  gctime:           ", gctime(t))
    println(io, pad, "  memory:           ", memory(t))
    return print(io, pad, "  allocs:           ", allocs(t))
end

function Base.show(io::IO, ::MIME"text/plain", t::TrialJudgement)
    println(io, "BenchmarkTools.TrialJudgement: ")
    pad = get(io, :pad, "")
    print(io, pad, "  time:         ", prettydiff(time(ratio(t))), " => ")
    printstyled(io, time(t); color=colormap[time(t)])
    println(io, " (", prettypercent(params(t).time_tolerance), " tolerance)")
    if instructions(t) !== :unknown
        print(io, pad, "  instructions: ", prettydiff(instructions(ratio(t))), " => ")
        printstyled(io, instructions(t); color=colormap[instructions(t)])
        println(io, " (", prettypercent(params(t).instruction_tolerance), " tolerance)")
    end
    if branches(t) !== :unknown
        print(io, pad, "  branches:     ", prettydiff(instructions(ratio(t))), " => ")
        printstyled(io, branches(t); color=colormap[branches(t)])
        println(io, " (", prettypercent(params(t).instruction_tolerance), " tolerance)")
    end
    print(io, pad, "  memory:       ", prettydiff(memory(ratio(t))), " => ")
    printstyled(io, memory(t); color=colormap[memory(t)])
    return println(io, " (", prettypercent(params(t).memory_tolerance), " tolerance)")
end
