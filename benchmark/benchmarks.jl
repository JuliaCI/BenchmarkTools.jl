using BenchmarkTools

groups = BenchmarkGroup()
groups["eig"] = BenchmarkGroup("linalg", "factorization", "math")

for i in 1:10
    groups["eig"][i] = @benchmarkable eig(rand($i, $i))
end

groups["sin"] = BenchmarkGroup("trig", "math")

for i in 1:10
    groups["sin"][i] = @benchmarkable sin($i)
end
