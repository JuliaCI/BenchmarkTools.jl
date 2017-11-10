print("Testing Parameters...")
took_seconds = @elapsed include("ParametersTests.jl")
println("done (took ", took_seconds, " seconds)")

print("Testing Trial/TrialEstimate/TrialRatio/TrialJudgement...")
took_seconds = @elapsed include("TrialsTests.jl")
println("done (took ", took_seconds, " seconds)")

print("Testing BenchmarkGroup...")
took_seconds = @elapsed include("GroupsTests.jl")
println("done (took ", took_seconds, " seconds)")

print("Testing execution...")
took_seconds = @elapsed include("ExecutionTests.jl")
println("done (took ", took_seconds, " seconds)")

print("Testing serialization...")
took_seconds = @elapsed include("SerializationTests.jl")
println("done (took ", took_seconds, " seconds)")
