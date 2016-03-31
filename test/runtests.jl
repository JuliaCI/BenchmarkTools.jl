print("Testing Parameters..."); tic()
include("parameters_tests.jl")
println("done (took ", toq(), " seconds)")

print("Testing Trial/TrialEstimate/TrialRatio/TrialJudgement..."); tic()
include("trials_tests.jl")
println("done (took ", toq(), " seconds)")

print("Testing BenchmarkGroup..."); tic()
include("groups_tests.jl")
println("done (took ", toq(), " seconds)")

print("Testing execution..."); tic()
include("execution_tests.jl")
println("done (took ", toq(), " seconds)")
