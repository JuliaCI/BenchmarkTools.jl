using KernelDensity
using PyPlot

function PyPlot.plot(t::BenchmarkTools.Trial)
    a, b = linreg(t.evals, t.times)
    plt[:scatter](t.evals, t.times)
    plot(t.evals, t.times)
    return plot(t.evals, [a + b*i for i in t.evals])
end

PyPlot.plot(k::KernelDensity.UnivariateKDE) = PyPlot.plot(k.x, k.density)
