using BenchmarkTools

groups = BenchmarkTools.GroupCollection()

addgroup!(groups, "eig", ["linalg", "factorization", "math"])

for i in 1:10
    groups["eig"][i] = @benchmarkable eig(rand($i, $i)) 1e-6
end

addgroup!(groups, "sin", ["trig", "math"])

for i in 1:10
    groups["sin"][i] = @benchmarkable sin($i) 1e-6
end
