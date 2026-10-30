module BenchmarkToolsJSONExt

using BenchmarkTools: BenchmarkTools, VERSIONS, SUPPORTED_TYPES, badext, recover
using JSON: JSON

function JSON.lower(x::Union{values(SUPPORTED_TYPES)...})
    d = Dict{String,Any}()
    T = typeof(x)
    for i in 1:nfields(x)
        name = String(fieldname(T, i))
        field = getfield(x, i)
        ft = typeof(field)
        value = ft <: get(SUPPORTED_TYPES, nameof(ft), Union{}) ? JSON.lower(field) : field
        d[name] = value isa Float64 && !isfinite(value) ? nothing : value
    end
    return [string(nameof(typeof(x))), d]
end

function BenchmarkTools.save(filename::AbstractString, args...)
    endswith(filename, ".json") || badext(filename)
    open(filename, "w") do io
        BenchmarkTools.save(io, args...)
    end
end

function BenchmarkTools.save(io::IO, args...)
    isempty(args) && throw(ArgumentError("Nothing to save"))
    goodargs = Any[]
    for arg in args
        if arg isa String
            @warn(
                "Naming variables in serialization is no longer supported.\n" *
                    "The name will be ignored and the object will be serialized " *
                    "in the order it appears in the input."
            )
            continue
        elseif !(arg isa get(SUPPORTED_TYPES, nameof(typeof(arg)), Union{}))
            throw(ArgumentError("Only BenchmarkTools types can be serialized."))
        end
        push!(goodargs, arg)
    end
    isempty(goodargs) && error("Nothing to save")
    return JSON.print(io, [VERSIONS, goodargs])
end

function BenchmarkTools.load(filename::AbstractString, args...)
    endswith(filename, ".json") || badext(filename)
    open(filename, "r") do f
        BenchmarkTools.load(f, args...)
    end
end

function BenchmarkTools.load(io::IO, args...)
    if !isempty(args)
        throw(
            ArgumentError(
                "Looking up deserialized values by name is no longer supported, " *
                "as names are no longer saved.",
            ),
        )
    end
    parsed = JSON.parse(io)
    if !isa(parsed, Vector) ||
        length(parsed) != 2 ||
        !isa(parsed[1], AbstractDict) ||
        !isa(parsed[2], Vector)
        error("Unexpected JSON format. Was this file originally written by BenchmarkTools?")
    end
    versions = parsed[1]::AbstractDict
    values = parsed[2]::Vector
    return map!(recover, values, values)
end

end # module
