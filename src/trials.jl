#########
# Trial #
#########

mutable struct Trial
    params::Parameters
    times::Vector{Float64}
    gctimes::Vector{Float64}
    memory::Int
    allocs::Int
end

Trial(params::Parameters) = Trial(params, Float64[], Float64[], typemax(Int), typemax(Int))

function Base.:(==)(a::Trial, b::Trial)
    return a.params == b.params &&
           a.times == b.times &&
           a.gctimes == b.gctimes &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.copy(t::Trial) = Trial(copy(t.params), copy(t.times), copy(t.gctimes), t.memory, t.allocs)

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
Base.lastindex(t::Trial) = length(t)

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

trim(t::Trial, percentage = 0.1) = t[1:max(1, floor(Int, length(t) - (length(t) * percentage)))]

#################
# TrialEstimate #
#################

mutable struct TrialEstimate
    params::Parameters
    time::Float64
    gctime::Float64
    memory::Int
    allocs::Int
end

function TrialEstimate(trial::Trial, t, gct)
    return TrialEstimate(params(trial), t, gct, memory(trial), allocs(trial))
end

function Base.:(==)(a::TrialEstimate, b::TrialEstimate)
    return a.params == b.params &&
           a.time == b.time &&
           a.gctime == b.gctime &&
           a.memory == b.memory &&
           a.allocs == b.allocs
end

Base.copy(t::TrialEstimate) = TrialEstimate(copy(t.params), t.time, t.gctime, t.memory, t.allocs)

function Base.minimum(trial::Trial)
    i = argmin(trial.times)
    return TrialEstimate(trial, trial.times[i], trial.gctimes[i])
end

function Base.maximum(trial::Trial)
    i = argmax(trial.times)
    return TrialEstimate(trial, trial.times[i], trial.gctimes[i])
end

Statistics.quantile(trial::Trial, p::Real) = TrialEstimate(trial, quantile(trial.times, p), quantile(trial.gctimes, p))
Statistics.median(trial::Trial) = TrialEstimate(trial, median(trial.times), median(trial.gctimes))
Statistics.mean(trial::Trial) = TrialEstimate(trial, mean(trial.times), mean(trial.gctimes))
Statistics.std(trial::Trial) = TrialEstimate(trial, std(trial.times), std(trial.gctimes))

Base.isless(a::TrialEstimate, b::TrialEstimate) = isless(time(a), time(b))

Base.time(t::TrialEstimate) = t.time
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
    gctime::Float64
    memory::Float64
    allocs::Float64
end

function Base.:(==)(a::TrialRatio, b::TrialRatio)
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

struct TrialJudgement
    ratio::TrialRatio
    time::Symbol
    memory::Symbol
end

function TrialJudgement(r::TrialRatio)
    ttol = params(r).time_tolerance
    mtol = params(r).memory_tolerance
    return TrialJudgement(r, judge(time(r), ttol), judge(memory(r), mtol))
end

function Base.:(==)(a::TrialJudgement, b::TrialJudgement)
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

isimprovement(f, t::TrialJudgement) = f(t) == :improvement
isimprovement(t::TrialJudgement) = isimprovement(time, t) || isimprovement(memory, t)

isregression(f, t::TrialJudgement) = f(t) == :regression
isregression(t::TrialJudgement) = isregression(time, t) || isregression(memory, t)

isinvariant(f, t::TrialJudgement) = f(t) == :invariant
isinvariant(t::TrialJudgement) = isinvariant(time, t) && isinvariant(memory, t)

const colormap = (
    regression = :red,
    improvement = :green,
    invariant = :normal,
)

printtimejudge(io, t::TrialJudgement) =
    printstyled(io, time(t); color=colormap[time(t)])
printmemoryjudge(io, t::TrialJudgement) =
    printstyled(io, memory(t); color=colormap[memory(t)])

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

# This returns a string like "16_384", used for number of samples & allocations.
function prettycount(n::Integer)
    groups = map(join, Iterators.partition(digits(n), 3))
    return reverse(join(groups, '_'))
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
    for i ∈ 1:nbins
        pos = searchsortedlast(sorteddata, min + i * Δ)
        bins[i] = pos - lastpos
        lastpos = pos
    end
    bins
end
bindata(sorteddata, nbins) = bindata(sorteddata, nbins, first(sorteddata), last(sorteddata))

function asciihist(bins, height=1)
    histbars = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
    if minimum(bins) == 0
        barheights = 2 .+ round.(Int, (height * length(histbars) - 2) * bins ./ maximum(bins))
        barheights[bins .== 0] .= 1
    else
        barheights = 1 .+ round.(Int, (height * length(histbars) - 1) * bins ./ maximum(bins))
    end
    heightmatrix = [min(length(histbars), barheights[b] - (h-1) * length(histbars))
                    for h in height:-1:1, b in 1:length(bins)]
    map(height -> if height < 1; ' ' else histbars[height] end, heightmatrix)
end

_summary(io, t, args...) = withtypename(() -> print(io, args...), io, t)

Base.summary(io::IO, t::Trial) = _summary(io, t, prettytime(time(t)))
Base.summary(io::IO, t::TrialEstimate) = _summary(io, t, prettytime(time(t)))
Base.summary(io::IO, t::TrialRatio) = _summary(io, t, prettypercent(time(t)))
Base.summary(io::IO, t::TrialJudgement) = withtypename(io, t) do
    print(io, prettydiff(time(ratio(t))), " => ")
    printtimejudge(io, t)
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
    padcolor = :light_black

    showpercentile = 99  # used both for display time, and to set right cutoff of histogram

    allocsstr = if allocs(t) == 0
        "0 allocations"
    elseif allocs(t) == 1
        "1 allocation, " * prettymemory(memory(t))
    else
        prettycount(allocs(t)) * " allocations, total " * prettymemory(memory(t))
    end

    samplesstr = string(
        prettycount(length(t)),
        if length(t) == 1  " sample, with " else " samples, each " end,
        prettycount(t.params.evals), 
        if t.params.evals == 1  " evaluation" else " evaluations" end,
    )

    if length(t) == 0
        print(io, "BenchmarkTools.Trial: 0 samples")
        return
    elseif length(t) == 1
        printstyled(io, "┌ BenchmarkTools.Trial:\n"; color=padcolor)
        # Time
        printstyled(io, pad, "│   "; color=padcolor)
        print(io, "time ")
        printstyled(io, prettytime(t.times[1]); color=:green, bold=true)

        # Memory
        println(io)
        printstyled(io, pad, "│   "; color=padcolor)
        print(io, allocsstr)

        # GC time
        if t.gctimes[1] > 0
            println(io)
            printstyled(io, pad, "│   "; color=padcolor)
            print(io, "GC time: ", prettytime(t.gctimes[1]))
            printstyled(io, " (", prettypercent(t.gctimes[1] / t.times[1]),")"; color=:green)
        end

        # 
        println(io)
        printstyled(io, pad, "└   ", samplesstr; color=padcolor)

        return
    end # done with trivial cases.

    # Main text block:
    printstyled(io, "┌ BenchmarkTools.Trial:\n"; color=padcolor)

    printstyled(io, pad, "│   "; color=padcolor)
    printstyled(io, "min "; color=:default)
    printstyled(io, prettytime(minimum(t.times)); color=:default, bold=true)
    print(io, ", ")
    printstyled(io, "median "; color=:blue)
    printstyled(io, prettytime(median(t.times)); color=:blue, bold=true)
    # printstyled(io, " (½)"; color=:blue)
    print(io, ", ")
    printstyled(io, "mean "; color=:green)
    printstyled(io, prettytime(mean(t.times)); color=:green, bold=true)
    # printstyled(io, " (*)"; color=:green)
    print(io, ", ")
    print(io, showpercentile, "ᵗʰ ")
    printstyled(prettytime(quantile(t.times, showpercentile/100)); bold=true)
    println(io)

    printstyled(io, pad, "│   "; color=padcolor)
    println(io, allocsstr)

    if !all(iszero, t.gctimes)
        # Mean GC time is just that; then we take the percentage of the mean time
        avggctime = prettytime(mean(t.gctimes))
        avegcpercent = prettypercent(mean(t.gctimes) / mean(t.times))

        # Maximum GC time is not taken as the GC time of the slowst run, max(t).
        # The percentage shown is of the same max-GC run, again not the percentage of longest time.
        # Of course, very often the slowest run is due to GC, and these concerns won't matter.
        _t, _i = findmax(t.gctimes)
        maxgctime = prettytime(_t)
        maxgcpercent = prettypercent(_t / t.gctimes[_i])

        printstyled(io, pad, "│   "; color=padcolor)
        print(io, "GC time: mean ", avggctime)
        printstyled(io, " (", avegcpercent, ")"; color=:green)
        println(io, ", max ", maxgctime, " (", maxgcpercent, ")")
    end

    # Histogram

    # Axis ends at this quantile, same as displayed time, ideally:
    histquantile = showpercentile/100
    # The height and width of the printed histogram in characters:
    histheight = 2
    histwidth = max(min(90, displaysize(io)[2]), length(samplesstr) + 24) - 8
    # This should fit it within your terminal, but stops growing at 90 columns. Below about
    # 55 columns it will stop shrinking, by which point the first line has already wrapped.

    perm = sortperm(t.times)
    times = t.times[perm]
    gctimes = t.gctimes[perm]

    # This needs sorted times:
    histtimes = times[1:round(Int, histquantile*end)]
    histmin = get(io, :histmin, low_edge(histtimes))
    histmax = get(io, :histmax, high_edge(histtimes))

    logbins = get(io, :logbins, nothing)
    bins = bindata(histtimes, histwidth - 1, histmin, histmax)
    append!(bins, [1, floor((1-histquantile) * length(times))])
    if logbins === true
        bins, logbins = log.(1 .+ bins), true
    else
        logbins = false
    end
    hist = asciihist(bins, histheight)
    hist[:,end-1] .= ' '
    maxbin = maximum(bins)

    # delta1 = (histmax - histmin) / (histwidth - 1)
    # if delta1 > 0
    #     medpos = 1 + round(Int, (histtimes[length(times) ÷ 2] - histmin) / delta1)
    #     avgpos = 1 + round(Int, (mean(times) - histmin) / delta1)
    #     # TODO replace with searchsortedfirst & range?
    #     q25pos = 1 + round(Int, (histtimes[max(1,length(times) ÷ 4)] - histmin) / delta1)
    #     q75pos = 1 + round(Int, (histtimes[3*length(times) ÷ 4] - histmin) / delta1)
    # else
    #     medpos, avgpos = 1, 1
    #     q25pos, q75pos = 1, 1
    # end
    _centres = range(histmin, histmax, length=length(bins)-2)
    fences = _centres .+ step(_centres)/2
    avgpos = searchsortedfirst(fences, mean(times))
    medpos = searchsortedfirst(fences, median(times))
    # @show medpos medpos2
    q25pos = searchsortedfirst(fences, quantile(times, 0.25))
    q75pos = searchsortedfirst(fences, quantile(times, 0.75))
    # @show q25pos q25pos2
    # @show q75pos q75pos2

    # Above the histogram bars, print markers for special ones:
    printstyled(io, pad, "│   "; color=padcolor)
    istop = maximum(filter(i -> i in axes(hist,2), [avgpos, medpos+1, q75pos]))
    for i in axes(hist, 2)
        i > istop && break
        if i == avgpos
            printstyled(io, "*", color=:green, bold=true)
        elseif i == medpos || 
                (medpos==avgpos && i==medpos-1 && median(times)<=mean(times)) ||
                (medpos==avgpos && i==medpos+1 && median(times)>mean(times))
            # marker for "median" is moved one to the left if they collide exactly
            # printstyled(io, "½", color=:blue)
            printstyled(io, "◑", color=:blue)
        elseif i == q25pos
            # printstyled(io, "¼", color=:light_black)
            printstyled(io, "◔", color=:light_black)
        elseif i == q75pos
            # printstyled(io, "¾", color=:light_black)
            printstyled(io, "◕", color=:light_black)
        else
            print(io, " ")
        end
    end

    for r in axes(hist, 1)
        println(io)
        printstyled(io, pad, "│   "; color=padcolor)
        istop = findlast(!=(' '), view(hist, r, :))
        for (i, bar) in enumerate(view(hist, r, :))
            i > istop && break  # don't print trailing spaces, as they waste space when line-wrapped
            color = :default
            if i == avgpos
                color = :green
            elseif i == medpos  # if the bars co-incide, colour the mean? matches labels
                color = :blue
            elseif bins[i] == 0
                color = :light_black
            end
            printstyled(io, bar; color=color)
        end
    end

    remtrailingzeros(timestr) = replace(timestr, r"\.?0+ " => " ")
    minhisttime, maxhisttime = remtrailingzeros.(prettytime.(round.([histmin, histmax], sigdigits=3)))

    println(io)
    printstyled(io, pad, "└   "; color=padcolor)
    print(io, minhisttime)
    # Caption is only printed if logbins has been selected:
    caption = logbins ? ("log(counts) from " * samplesstr) : samplesstr
    printstyled(io, " " ^ ((histwidth - length(caption)) ÷ 2 - length(minhisttime)), caption; color=:light_black)
    print(io, lpad(maxhisttime, ceil(Int, (histwidth - length(caption)) / 2) - 1), " ")
    print(io, "+")
    # printstyled(io, "●", color=:light_black)  # other options...
    # print(io, "⋯")
    # printstyled(io, "¹⁰⁰", color=:light_black)
end

# I wondered about rounding to a few steps per decade. This looks good in 1:10, not great outside:
# round.(0:0.01:10, sigdigits=3, base=2) |> unique
function low_edge(times)
    # _min = minimum(times)
    _min = min(minimum(times), mean(times) / 1.03)  # demand low edge 3% below mean
    return round(_min, RoundDown; sigdigits = 2)

end
function high_edge(times)
    # _max = maximum(times)
    # _max = Base.max(maximum(times), 1.07 * low_edge(times))  # demand total width at least 7%
    _max = max(maximum(times), 1.03 * mean(times))  # demand high edge 3% above mean
    return round(_max, RoundUp; sigdigits = 2)
end

function Base.show(io::IO, ::MIME"text/plain", t::TrialEstimate)
    println(io, "BenchmarkTools.TrialEstimate: ")
    pad = get(io, :pad, "")
    println(io, pad, "  time:             ", prettytime(time(t)))
    println(io, pad, "  gctime:           ", prettytime(gctime(t)), " (", prettypercent(gctime(t) / time(t)),")")
    println(io, pad, "  memory:           ", prettymemory(memory(t)))
    print(io,   pad, "  allocs:           ", allocs(t))
end

function Base.show(io::IO, ::MIME"text/plain", t::TrialRatio)
    println(io, "BenchmarkTools.TrialRatio: ")
    pad = get(io, :pad, "")
    println(io, pad, "  time:             ", time(t))
    println(io, pad, "  gctime:           ", gctime(t))
    println(io, pad, "  memory:           ", memory(t))
    print(io,   pad, "  allocs:           ", allocs(t))
end

function Base.show(io::IO, ::MIME"text/plain", t::TrialJudgement)
    println(io, "BenchmarkTools.TrialJudgement: ")
    pad = get(io, :pad, "")
    print(io, pad, "  time:   ", prettydiff(time(ratio(t))), " => ")
    printtimejudge(io, t)
    println(io, " (", prettypercent(params(t).time_tolerance), " tolerance)")
    print(io,   pad, "  memory: ", prettydiff(memory(ratio(t))), " => ")
    printmemoryjudge(io, t)
    println(io, " (", prettypercent(params(t).memory_tolerance), " tolerance)")
end
