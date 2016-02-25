using BenchmarkTools

ensemble = BenchmarkEnsemble()

addgroup!(ensemble, "eig", ["linalg", "factorization", "math"])

for i in 1:10
    ensemble["eig"][i] = @benchmarkable eig(rand($i, $i)) 1e-6
end

addgroup!(ensemble, "sin", ["trig", "math"])

for i in 1:10
    ensemble["sin"][i] = @benchmarkable sin($i) 1e-6
end
