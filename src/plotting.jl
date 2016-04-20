using KernelDensity
using PyPlot

KernelDensity.kde(t::BenchmarkTools.Trial; kwargs...) = kde(t.times; kwargs...)
PyPlot.plot(t::BenchmarkTools.Trial) = plt[:scatter](0:length(t)-1, t.times)
PyPlot.plot(k::KernelDensity.UnivariateKDE) = PyPlot.plot(k.x, k.density)

# function plotlintrial(times, evals, logscale = true)
#     plt[:scatter](evals, times ./ evals)
#     logscale && (plt[:yscale]("log"); plt[:xscale]("log"))
# end

function plotkde(b::BenchmarkTools.Benchmark, rep = 1; cut = 0.1, bandwidth = nothing,  kwargs...)
    trials = Vector{BenchmarkTools.Trial}()
    for _ in 1:rep
        t = run(b; kwargs...)
        push!(trials, t)
    end
    plotkde(trials; cut = cut, bandwidth = bandwidth)
    return trials
end

function plotkde(trials::Vector; kwargs...)
    for t in trials
        plotkde(t; kwargs...)
    end
end

function plotkde(trial::BenchmarkTools.Trial; cut = 0.1, bandwidth = nothing, kwargs...)
    trial = BenchmarkTools.trim(trial, cut)
    k = bandwidth == nothing ? kde(trial) : kde(trial; bandwidth = bandwidth)
    plot(k)
end
