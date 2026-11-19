using BenchmarkTools, Plots, BenchmarkPlots, StatsPlots

function runalgorithm(x, alg)
    alg == :default && return sort(x)
    alg == :insertion && return sort(x; alg=InsertionSort)
    alg == :quick && return sort(x; alg=QuickSort)
    alg == :merge && return sort(x; alg=MergeSort)
end

g = BenchmarkGroup()
for key in [:default, :insertion, :quick, :merge]
    g[key] = @benchmarkable runalgorithm(x, $key) setup=(x=randn(1000))
end
res = run(g)
plot(res; yscale=:log10)
savefig("$(pkgdir(BenchmarkTools))/docs/src/assets/violins.png")

g = BenchmarkGroup()
for key in [:default, :insertion, :quick, :merge]
    g[key] = BenchmarkGroup()
    for size in 2 .^ (1:15)
        g[key][size] = @benchmarkable runalgorithm(x, $key) setup=(x=randn($size))
    end
end
res = run(g)
plot(res; scale=:log10, xguide=:size, legendposition=:topleft)
savefig("$(pkgdir(BenchmarkTools))/docs/src/assets/algorithms.png")

