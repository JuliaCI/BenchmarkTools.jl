# This file contains JSON (de)serialization methods for BenchmarkTools types. The `load`
# and `save` methods here are slower than JLD's, but don't rely on nearly as much machinery
# as JLD. This implementation could probably be sped up significantly by avoiding a bunch of
# temporary Dicts/Arrays, but this works as a naive implementation for now.

# Let's start with an example of the JSON format. Imagine you called the following:

# BenchmarkTools.save("data.json", trial::Trial, group::BenchmarkGroup, estimates::Vector{TrialEstimate})

# The below JSON would be written to data.json (note that the actual JSON won't have
# whitespace or comments):

# [
#     { // version info
#         "Julia": "0.5.0-pre+5632",
#         "BenchmarkTools": "0.0.3"
#     }
#     [ // serialized values
#         // `trial` from our example
#         [
#             "BenchmarkTools.Trial",
#             {
#                 "params": [...],
#                 "times": [...],
#                 "gctimes": [...],
#                 "memory": 0,
#                 "allocs": 0
#             }
#         ],
#         // `group` from our example
#         [
#             "BenchmarkTools.BenchmarkGroup",
#             {
#                 "tags": [...],
#                 "data": {...}
#             }
#         ],
#         // `estimates` from our example
#         [
#             "Array{BenchmarkTools.TrialEstimate,1}"
#             [
#                 [
#                     "BenchmarkTools.TrialEstimate",
#                     {
#                         ⋮
#                     }
#                 ],
#                 [
#                     "BenchmarkTools.TrialEstimate",
#                     {
#                         ⋮
#                     }
#                 ],
#                 ⋮
#             ]
#         ]
#     ]
# ]

# Let's make this explicit: BenchmarkTools.save will always write out a JSON array of two
# elements. The first element is version info, while the second element is a JSON object
# containing the serialized versions of the input values.

# The serialization format of each input value is also a JSON array of two elements, where
# the first element is the type name and the second element is a JSON object which stores
# the fields. If the type doesn't have fields (e.g., an Array or Tuple), then the second
# element is a JSON array instead.

# Finally, I'd like to note why JSON arrays are used rather than JSON objects for storing
# types. By using an array, it is guaranteed that the type information will always appear
# before the value. This makes the format friendly for stream parsers by allowing them
# to linearly seek through a file stream without having to perform a "lookahead" operation
# to figure out how to parse future data.

############################################################################################
# old code - does NOT implement the serialization format defined above
############################################################################################

# const VERSIONS_DICT = Dict("Julia" => VERSION, "BenchmarkTools" => BENCHMARKTOOLS_VERSION)
#
# const TYPE_UUID = "2fc55eb5786042ee90b8db45a62a698f"
#
# is_serialized_type(json) = haskey(json, "type_uuid") && json["type_uuid"] == TYPE_UUID
#
# #######
# # API #
# #######
#
# save(filename, item) = open(io -> save(io, item), filename, "w")
# save(io::IO, item) = JSON.print(io, type2json(item))
#
# load(filename) = open(load, filename, "r")
# load(io::IO) = json2type(JSON.parse(io))
#
# #################################
# # BenchmarkTools Types --> JSON #
# #################################
#
# function type2json{T}(::Type{T}, fields, include_version = true)
#     result = Dict("type" => T, "fields" => fields)
#     if include_version
#         result["versions"] = VERSIONS_DICT
#     end
#     return result
# end
#
# type2json(::Benchmark) = error("cannot de(serialize) benchmark definitions, only data")
#
# type2json(x) = x
# type2json{T<:String}(arr::Array{T}) = arr
# type2json{T<:Number}(arr::Array{T}) = arr
# type2json(arr::Array) = map(type2json, arr)
#
# function type2json(dict::Dict)
#     result = Dict()
#     for (k, v) in dict
#         result[k] = (type2json(k), type2json(v))
#     end
#     return type2json(result
# end
#
# type2json(tup::Tuple) = type2json(Tuple, map(type2json, tup))
#
# function type2json(group::BenchmarkGroup)
#     fields = Dict("tags" => type2json(group.tags), "data" => type2json(group.data))
#     return type2json(BenchmarkGroup, fields)
# end
#
# function type2json(params::Parameters)
#     fields = Dict("seconds" => params.seconds,
#                   "samples" => params.samples,
#                   "evals" => params.evals,
#                   "overhead" => params.overhead,
#                   "gctrial" => params.gctrial,
#                   "gcsample" => params.gcsample,
#                   "time_tolerance" => params.time_tolerance,
#                   "memory_tolerance" => params.memory_tolerance)
#     return type2json(Parameters, fields)
# end
#
# function type2json(t::Trial)
#     fields = Dict("params" => type2json(t.params),
#                   "times" => t.times,
#                   "gctimes" => t.gctimes,
#                   "memory" => t.memory,
#                   "allocs" => t.allocs)
#     return type2json(Trial, fields)
# end
#
# function type2json(t::TrialEstimate)
#     fields = Dict("params" => type2json(t.params),
#                   "time" => t.time,
#                   "gctime" => t.gctime,
#                   "memory" => t.memory,
#                   "allocs" => t.allocs)
#     return type2json(TrialEstimate, fields)
# end
#
# function type2json(t::TrialRatio)
#     fields = Dict("params" => type2json(t.params),
#                   "time" => t.time,
#                   "gctime" => t.gctime,
#                   "memory" => t.memory,
#                   "allocs" => t.allocs)
#     return type2json(TrialRatio, fields)
# end
#
# function type2json(t::TrialJudgement)
#     fields = Dict("ratio" => type2json(t.ratio),
#                   "time" => t.time,
#                   "memory" => t.memory)
#     return type2json(TrialJudgement, fields)
# end
#
# #################################
# # JSON --> BenchmarkTools Types #
# #################################
#
# json2type(x) = x
# json2type{T<:String}(arr::Array{T}) = arr
# json2type{T<:Number}(arr::Array{T}) = arr
# json2type(arr::Array) = map(json2type, arr)
#
# function json2type(json::Dict)
#     if is_serialized_type(json)
#         return json2type(json["type"], json)
#     else
#         result = Dict()
#         for (k, v) in values(json)
#             result[json2type(k)] = json2type(v)
#         end
#         return result
#     end
# end
#
# function json2type(typestr::String, json::Dict)
#     if typestr == "BenchmarkTools.Benchmark"
#         error("cannot de(serialize) benchmark definitions, only data")
#     else
#         fields = json["fields"]
#         if typestr == "Tuple"
#             return map(json2type, tuple(fields...))
#         elseif typestr == "BenchmarkTools.BenchmarkGroup"
#             return BenchmarkGroup(fields["tags"], json2type(fields["data"]))
#         elseif typestr == "BenchmarkTools.Parameters"
#             return Parameters(fields["seconds"], fields["samples"], fields["evals"],
#                               fields["overhead"], fields["gctrial"], fields["gcsample"],
#                               fields["time_tolerance"], fields["memory_tolerance"])
#         elseif typestr == "BenchmarkTools.Trial"
#             return Trial(json2type("BenchmarkTools.Parameters", fields["params"]),
#                          fields["times"], fields["gctimes"],
#                          fields["memory"], fields["allocs"])
#         elseif typestr == "BenchmarkTools.TrialEstimate"
#             return TrialEstimate(json2type("BenchmarkTools.Parameters", fields["params"]),
#                                  fields["time"], fields["gctime"],
#                                  fields["memory"], fields["allocs"])
#         elseif typestr == "BenchmarkTools.TrialRatio"
#             return TrialRatio(json2type("BenchmarkTools.Parameters", fields["params"]),
#                               fields["time"], fields["gctime"],
#                               fields["memory"], fields["allocs"])
#         elseif typestr == "BenchmarkTools.TrialJudgement"
#             return TrialJudgement(json2type("BenchmarkTools.TrialRatio", fields["ratio"]),
#                                   fields["time"], fields["memory"])
#         end
#     end
# end
