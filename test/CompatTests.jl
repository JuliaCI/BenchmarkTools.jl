module CompatTests

using Base.Test
using BenchmarkTools
using JLD

old_data = BenchmarkTools.loadold(joinpath(dirname(@__FILE__), "old_data.jld"))
new_data = JLD.load(joinpath(dirname(@__FILE__), "new_data.jld"))

@test old_data["params"] == old_data["trial"].params
@test new_data["params"] == new_data["trial"].params

@test old_data["params"] == new_data["params"]
@test old_data["trial"] == new_data["trial"]

end # module
