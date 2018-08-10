const VERSIONS = Dict("Julia" => string(VERSION),
                      "BenchmarkTools" => string(BENCHMARKTOOLS_VERSION))

# TODO: Add any new types as they're added
const SUPPORTED_TYPES = [Benchmark, BenchmarkGroup, Parameters, TagFilter, Trial,
                         TrialEstimate, TrialJudgement, TrialRatio]

for T in SUPPORTED_TYPES
    @eval function JSON.lower(x::$T)
        d = Dict{String,Any}()
        for i = 1:nfields(x)
            name = String(fieldname($T, i))
            field = getfield(x, i)
            value = typeof(field) in SUPPORTED_TYPES ? JSON.lower(field) : field
            push!(d, name => value)
        end
        [string(typeof(x)), d]
    end
end

function recover(x::Vector)
    length(x) == 2 || throw(ArgumentError("Expecting a vector of length 2"))
    typename = x[1]::String
    fields = x[2]::Dict
    T = Core.eval(@__MODULE__, Meta.parse(typename))::Type
    fc = fieldcount(T)
    xs = Vector{Any}(undef, fc)
    for i = 1:fc
        ft = fieldtype(T, i)
        fn = String(fieldname(T, i))
        xs[i] = if ft in SUPPORTED_TYPES
            recover(fields[fn])
        else
            convert(ft, fields[fn])
        end
        if T == BenchmarkGroup && xs[i] isa Dict
            for (k, v) in xs[i]
                if v isa Vector && length(v) == 2 && v[1] isa String
                    xs[i][k] = recover(v)
                end
            end
        end
    end
    T(xs...)
end

function badext(filename)
    noext, ext = splitext(filename)
    msg = if ext == ".jld"
        "JLD serialization is no longer supported. Benchmarks should now be saved in\n" *
        "JSON format using `save(\"$noext\".json, args...)` and loaded from JSON using\n" *
        "using `load(\"$noext\".json, args...)`. You will need to convert existing\n" *
        "saved benchmarks to JSON in order to use them with this version of BenchmarkTools."
    else
        "Only JSON serialization is supported."
    end
    throw(ArgumentError(msg))
end

function save(filename::AbstractString, args...)
    endswith(filename, ".json") || badext(filename)
    open(filename, "w") do io
        save(io, args...)
    end
end

function save(io::IO, args...)
    isempty(args) && throw(ArgumentError("Nothing to save"))
    goodargs = Any[]
    for arg in args
        if arg isa String
            @warn("Naming variables in serialization is no longer supported.\n" *
                  "The name will be ignored and the object will be serialized " *
                  "in the order it appears in the input.")
            continue
        elseif !any(T->arg isa T, SUPPORTED_TYPES)
            throw(ArgumentError("Only BenchmarkTools types can be serialized."))
        end
        push!(goodargs, arg)
    end
    isempty(goodargs) && error("Nothing to save")
    JSON.print(io, [VERSIONS, goodargs])
end

function load(filename::AbstractString, args...)
    endswith(filename, ".json") || badext(filename)
    open(filename, "r") do f
        load(f, args...)
    end
end

function load(io::IO, args...)
    if !isempty(args)
        throw(ArgumentError("Looking up deserialized values by name is no longer supported, " *
                            "as names are no longer saved."))
    end
    parsed = JSON.parse(io)
    if !isa(parsed, Vector) || length(parsed) != 2 || !isa(parsed[1], Dict) || !isa(parsed[2], Vector)
        error("Unexpected JSON format. Was this file originally written by BenchmarkTools?")
    end
    versions = parsed[1]::Dict
    values = parsed[2]::Vector
    map!(recover, values, values)
end
