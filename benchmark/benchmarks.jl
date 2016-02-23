using BenchmarkTools

ensemble = BenchmarkEnsemble()

addgroup!(ensemble, "eig", ["linalg", "factorization"])

for i in 1:10
    ensemble["eig"][i] = @benchmarkable eig(rand($i, $i)) 0.1
end
