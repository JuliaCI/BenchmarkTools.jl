print("Testing trial types..."); tic()
include("trials_tests.jl")
println("done (took ", toq(), " seconds)")

print("Testing collection types..."); tic()
include("collections_tests.jl")
println("done (took ", toq(), " seconds)")
