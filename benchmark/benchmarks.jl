using BenchmarkTools

# Define a parent BenchmarkGroup to contain our suite
const suite = BenchmarkGroup()

# Add some child groups to our benchmark suite.
suite["string"] = BenchmarkGroup(["unicode"])
suite["trigonometry"] = BenchmarkGroup(["math", "triangles"])

# This string will be the same every time because we're seeding the RNG
teststr = join(rand(MersenneTwister(1), 'a':'d', 10^4))

# Add some benchmarks to the "utf8" group
suite["string"]["replace"] = @benchmarkable replace($teststr, "a", "b")
suite["string"]["join"] = @benchmarkable join($teststr, $teststr)

# Add some benchmarks to the "trigonometry" group
for f in (sin, cos, tan)
    for x in (0.0, pi)
        suite["trigonometry"][string(f), x] = @benchmarkable $(f)($x)
    end
end

# If a cache of tuned parameters already exists, use it, otherwise, tune and cache
# the benchmark parameters. Reusing cached parameters is faster and more reliable
# than re-tuning `suite` every time the file is included.
paramspath = joinpath(dirname(@__FILE__), "params.jld")

if isfile(paramspath)
    loadparams!(suite, BenchmarkTools.load(paramspath, "suite"), :evals, :samples);
else
    tune!(suite)
    BenchmarkTools.save(paramspath, "suite", params(suite));
end
