# test whether two set-like collections have the same elements
seteq(a, b) = length(a) == length(b) == length(intersect(a, b))

print("Testing trial types..."); tic()
include("trials_tests.jl")
println("done (took ", toq(), " seconds)")

print("Testing collection types..."); tic()
include("collections_tests.jl")
println("done (took ", toq(), " seconds)")

print("Testing execution..."); tic()
include("execution_tests.jl")
println("done (took ", toq(), " seconds)")
