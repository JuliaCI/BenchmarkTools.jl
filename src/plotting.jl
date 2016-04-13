using KernelDensity
using PyPlot

KernelDensity.kde(t::BenchmarkTools.Trial; kwargs...) = kde(t.times; kwargs...)
PyPlot.plot(t::BenchmarkTools.Trial) = plt[:scatter](0:length(t)-1, t.times)
PyPlot.plot(k::KernelDensity.UnivariateKDE) = PyPlot.plot(k.x, k.density)

function pltlintrial(times, evals, logscale = true)
    plt[:scatter](evals, times ./ evals)
    logscale && (plt[:yscale]("log"); plt[:xscale]("log"))
end
