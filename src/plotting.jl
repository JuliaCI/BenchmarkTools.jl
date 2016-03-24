using KernelDensity
using PyPlot

KernelDensity.kde(t::BenchmarkTools.Trial) = kde(time(t))
PyPlot.plot(t::BenchmarkTools.Trial) = plt[:scatter](0:length(t)-1, time(t))
PyPlot.plot(k::KernelDensity.UnivariateKDE) = PyPlot.plot(k.x, k.density)
