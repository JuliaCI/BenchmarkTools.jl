# This file outlines a JSON serialization format for BenchmarkTools types.

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
