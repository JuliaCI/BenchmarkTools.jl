using BenchmarkTools
using JLD

# Define a parent BenchmarkGroup to contain our suite
const suite = BenchmarkGroup()

# Add some child groups to our benchmark suite.
suite["utf8"] = BenchmarkGroup("string", "unicode")
suite["trigonometry"] = BenchmarkGroup("math", "triangles")

# This string will be the same every time because we're seeding the RNG
teststr = UTF8String(join(rand(MersenneTwister(1), 'a':'d', 10^4)))

# Add some benchmarks to the "utf8" group
suite["utf8"]["replace"] = @benchmarkable replace($teststr, "a", "b")
suite["utf8"]["join"] = @benchmarkable join($teststr, $teststr)

# Add some benchmarks to the "trigonometry" group
for f in (sin, cos, tan)
    for x in (0.0, pi)
        suite["trigonometry"][string(f), x] = @benchmarkable $(f)($x)
    end
end

# Load the suite's cached `evals` parameters as part of including the file. This is much
# faster and more reliable than re-tuning `suite` every time the file is included
evalspath = joinpath(Pkg.dir("BenchmarkTools"), "benchmark", "evals.jld")
# tune!(suite); JLD.save(evalspath, "suite", evals(suite));
loadevals!(suite, JLD.load(evalspath, "suite"));
