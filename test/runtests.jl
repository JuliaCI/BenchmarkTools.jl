print("Testing Parameters..."); tic()
include("ParametersTests.jl")
println("done (took ", toq(), " seconds)")

print("Testing Trial/TrialEstimate/TrialRatio/TrialJudgement..."); tic()
include("TrialsTests.jl")
println("done (took ", toq(), " seconds)")

print("Testing BenchmarkGroup..."); tic()
include("GroupsTests.jl")
println("done (took ", toq(), " seconds)")

print("Testing execution..."); tic()
include("ExecutionTests.jl")
println("done (took ", toq(), " seconds)")

# This test fails due to a weird JLD scoping error. See JuliaCI/BenchmarkTools.jl#23.
#
# print("Testing serialization..."); tic()
# include("SerializationTests.jl")
# println("done (took ", toq(), " seconds)")
