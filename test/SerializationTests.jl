module SerializationTests

using Base.Test
using BenchmarkTools

old_data = BenchmarkTools.load(joinpath(dirname(@__FILE__), "data_pre_v006.jld"), "results")
BenchmarkTools.save(joinpath(dirname(@__FILE__), "tmp.jld"), "results", old_data)
new_data = BenchmarkTools.load(joinpath(dirname(@__FILE__), "tmp.jld"), "results")

@test old_data == new_data

rm(joinpath(dirname(@__FILE__), "tmp.jld"))

end # module
