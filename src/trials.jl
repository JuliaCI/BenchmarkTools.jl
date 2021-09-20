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
# mean absolute deviation
meanad(xs::AbstractArray; mean = Statistics.mean(xs)) = Statistics.mean(x -> abs(x - mean), xs)
meanad(trial::Trial) = TrialEstimate(trial, meanad(trial.times), meanad(trial.gctimes))

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

function prettycount(n::Integer)
    join(reverse(join.(reverse.(Iterators.partition(digits(n), 3)))), '_')
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

_percentile() = 99  # to tweak this live, TODO remove

function Base.show(io::IO, ::MIME"text/plain", t::Trial)

    pad = get(io, :pad, "")

    showpercentile = _percentile()

    perm = sortperm(t.times)
    times = t.times[perm]
    gctimes = t.gctimes[perm]

    if length(t) > 1
        med = median(t)
        avg = mean(t)
        min = minimum(t)
        max = maximum(t)
        q99 = quantile(t, showpercentile/100)

        mintime = prettytime(time(min))
        medtime = prettytime(time(med))
        avgtime = prettytime(time(avg))
        q99time = prettytime(time(q99))

        # Mean GC time is just that; then we take the percentage of the mean time
        avggctime, avegcpercent = prettytime(mean(gctimes)), prettypercent(mean(gctimes) / mean(times))
        q99gctime = prettytime(quantile(gctimes, showpercentile/100))
        # Maximum GC time has a percentage which is of the same run, not necc. the longest run
        _t, _i = findmax(gctimes)
        maxgctime, maxgcpercent = prettytime(_t), prettypercent(_t / times[_i])

        memorystr = prettymemory(memory(min))
        allocsstr = prettycount(allocs(min)) * (allocs(min)==1 ? " allocation" : " allocations")
    elseif length(t) == 1
        # TODO update this!

        print(io, pad, " Single result which took ")
        printstyled(io, prettytime(times[1]); color=:light_blue)
        print(io, " (", prettypercent(gctimes[1]/times[1]), " GC) ")
        print(io, "to evaluate,\n")
        print(io, pad, " with a memory estimate of ")
        printstyled(io, prettymemory(t.memory[1]); color=:yellow)
        print(io, ", over ")
        printstyled(io, t.allocs[1]; color=:yellow)
        print(io, " allocations.")
        return
    else
        print(io, pad, " No results.")
        return
    end

    # New block
    # println(io, "┌ BenchmarkTools.Trial:")
    println(io, "BenchmarkTools.Trial:")

    print(io, pad, "│  ")
    printstyled(io, "min "; color=:default)
    printstyled(io, mintime; color=:default, bold=true)
    print(io, ", ")
    printstyled(io, "median "; color=:light_blue)
    printstyled(io, medtime; color=:light_blue, bold=true)
    printstyled(io, " (½)"; color=:light_blue)
    print(io, ", ")
    printstyled(io, "mean "; color=:green)
    printstyled(io, avgtime; color=:green, bold=true)
    printstyled(io, " (*)"; color=:green)
    print(io, ", ")
    print(io, showpercentile, "ᵗʰ ")
    printstyled(q99time; bold=true)
    println(io)

    print(io, pad, "│  ", allocsstr)
    if allocs(min) != 0
        println(io, ", ", memorystr)
    else
        println(io)
    end
    if !all(iszero, gctimes)
        print(io, pad, "│  ", "GC time: mean ", avggctime)
        printstyled(io, " (", avegcpercent, ")"; color=:green)
        println(io, ", max ", maxgctime, " (", maxgcpercent, ")")
    end

    print(io, pad, "│  ", prettycount(length(t)), " sample", if length(t) > 1 "s" else "" end,
          ", each ", prettycount(t.params.evals), " evaluation", if t.params.evals > 1 "s" else "" end , ":")

    # Histogram

    # Axis ends at this quantile, same as displayed time, ideally:
    histquantile = showpercentile/100
    # The height and width of the printed histogram in characters:
    histheight = 2
    histwidth = 74  # fits into 78 chars, as does 1st line with 4 times

    # This needs sorted times:
    histtimes = times[1:round(Int, histquantile*end)]
    histmin = get(io, :histmin, low_edge(histtimes))
    histmax = get(io, :histmax, high_edge(histtimes))
    logbins = get(io, :logbins, nothing)
    bins = bindata(histtimes, histwidth - 1, histmin, histmax)
    append!(bins, [1, floor((1-histquantile) * length(times))])
    # if median size of (bins with >10% average data/bin) is less than 5% of max bin size, log the bin sizes
    if logbins === true # || (logbins === nothing && median(filter(b -> b > 0.1 * length(times) / histwidth, bins)) / maximum(bins) < 0.05)
        bins, logbins = log.(1 .+ bins), true
    else
        logbins = false
    end
    hist = asciihist(bins, histheight)
    hist[:,end-1] .= ' '
    maxbin = maximum(bins)

    delta1 = (histmax - histmin) / (histwidth - 1)
    if delta1 > 0
        medpos = 1 + round(Int, (histtimes[length(times) ÷ 2] - histmin) / delta1)
        avgpos = 1 + round(Int, (mean(times) - histmin) / delta1)
    else
        medpos, avgpos = 1, 1
    end

    # Above the histogram bars, print markers for special ones:
    print(io, "\n", pad, "│  ")
    for i in axes(hist, 2)
        if i == avgpos
            printstyled(io, "*", color=:green, bold=true) # or μ, or t̄?
        elseif i == medpos || (medpos==avgpos && i==medpos-1)
            # marker for "median" is moved one to the left if they collide
            printstyled(io, "½", color=:light_blue) # sadly "㊿" is often double wide. ½, |, ‖, ↓ maybe?
        else
            print(io, " ")
        end
    end

    for r in axes(hist, 1)
        print(io, "\n", pad, "│  ")
        for (i, bar) in enumerate(view(hist, r, :))
            color = :default
            if i == avgpos
                color = :green
            elseif i == medpos  # if the bars co-incide, colour the mean? matches labels
                color = :light_blue
            elseif bins[i] == 0
                color = :light_black
            end
            printstyled(io, bar; color=color)
        end
    end

    remtrailingzeros(timestr) = replace(timestr, r"\.?0+ " => " ")
    minhisttime, maxhisttime = remtrailingzeros.(prettytime.(round.([histmin, histmax], sigdigits=3)))

    print(io, "\n", pad, "└  ", minhisttime)
    # Caption is only printed if logbins has been selected:
    caption = logbins ? "log(counts) by time" : ""
    printstyled(io, " " ^ ((histwidth - length(caption)) ÷ 2 - length(minhisttime)), caption; color=:light_black)
    print(io, lpad(maxhisttime, ceil(Int, (histwidth - length(caption)) / 2) - 1), " ")
    printstyled(io, "+")
end

# These two functions allow endpoints 6, 7, 8, 10, 15, 20, 30, 40, ... perhaps too coarse?
# exp.(range(log(1), log(10), length=11)) ≈ [1, 1.25, 1.6, 2, 2.5, 3.2, 4, 5, 6.3, 8, 10] 

# round.(0:0.01:10, sigdigits=3, base=2) |> unique # looks good in 1:10, not great outside
function low_edge(times)
    # return 0
    min = minimum(times)
    # return round(min, RoundDown; sigdigits = 3, base = 2)
    return round(min, RoundDown; sigdigits = 2)
    # dec = round(min, RoundDown; sigdigits = 1)
    # if first(string(dec)) == '1'
    #     min > 1.5 * dec && return 1.5 * dec
    #     # min > 1.2 * dec && return 1.2 * dec
    # elseif first(string(dec)) == '9'
    #     return round((8//9) * dec, sigdigits = 2)
    # end
    # dec
end
function high_edge(times)
    max = maximum(times)
    # return round(max, RoundUp; sigdigits = 3, base = 2)
    return round(max, RoundUp; sigdigits = 2)
    # dec = round(max, RoundUp; sigdigits = 1)
    # if first(string(dec)) == '2'
    #     max < 0.75 * dec && return 0.75 * dec
    # elseif first(string(dec)) == '9'
    #     return round((10//9) * dec, sigdigits = 2)
    # end
    # dec
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
