
using BenchmarkTools

# Define a parent BenchmarkGroup to contain our suite
const suite = BenchmarkGroup()

# Add some child groups to our benchmark suite.
suite["string"] = BenchmarkGroup(["unicode"])
suite["trig"] = BenchmarkGroup(["math", "triangles"])
suite["dot"] = BenchmarkGroup(["broadcast", "elementwise"])

# This string will be the same every time because we're seeding the RNG
teststr = join(rand(MersenneTwister(1), 'a':'d', 10^4))

# Add some benchmarks to the "string" group
suite["string"]["replace"] = @benchmarkable replace($teststr, "a", "b") seconds = Float64(π)
suite["string"]["join"] = @benchmarkable join($teststr, $teststr) samples = 42

# Add some benchmarks to the "trig"/"dot" group
for f in (sin, cos, tan)
    for x in (0.0, pi)
        suite["trig"][string(f), x] = @benchmarkable $(f)($x)
        suite["dot"][string(f), x] = @benchmarkable $(f).([$x, $x, $x])
    end
end

# If a cache of tuned parameters already exists, use it, otherwise, tune and cache
# the benchmark parameters. Reusing cached parameters is faster and more reliable
# than re-tuning `suite` every time the file is included.
paramspath = joinpath(dirname(@__FILE__), "params.json")

if isfile(paramspath)
    loadparams!(suite, BenchmarkTools.load(paramspath)[1], :evals)
else
    tune!(suite)
    BenchmarkTools.save(paramspath, params(suite))
end
