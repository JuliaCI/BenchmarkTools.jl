using KernelDensity
using PyPlot

KernelDensity.kde(t::BenchmarkTools.Trial; kwargs...) = kde(t.times; kwargs...)
PyPlot.plot(t::BenchmarkTools.Trial; kwargs...) = scatter(0:length(t)-1, t.times; kwargs...)
PyPlot.plot(k::KernelDensity.UnivariateKDE; kwargs...) = PyPlot.plot(k.x, k.density; kwargs...)

function plotkde(trials::Vector; kwargs...)
    for t in trials
        plotkde(t; kwargs...)
    end
end

function plotkde(trial::BenchmarkTools.Trial; cut = 0.1, bandwidth = nothing, kwargs...)
    trial = BenchmarkTools.maxtrim(trial, cut)
    k = bandwidth == nothing ? kde(trial) : kde(trial; bandwidth = bandwidth)
    plot(k; kwargs...)
end
