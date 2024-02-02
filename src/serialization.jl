const VERSIONS = Dict(
    "Julia" => string(VERSION), "BenchmarkTools" => string(BENCHMARKTOOLS_VERSION)
)

# TODO: Add any new types as they're added
const SUPPORTED_TYPES = Dict{Symbol,Type}(
    Base.typename(x).name => x for x in [
        BenchmarkGroup,
        Parameters,
        TagFilter,
        Trial,
        TrialEstimate,
        TrialJudgement,
        TrialRatio,
    ]
)
# n.b. Benchmark type not included here, since it is gensym'd

function JSON.lower(x::Union{values(SUPPORTED_TYPES)...})
    d = Dict{String,Any}()
    T = typeof(x)
    for i in 1:nfields(x)
        name = String(fieldname(T, i))
        field = getfield(x, i)
        ft = typeof(field)
        value = ft <: get(SUPPORTED_TYPES, nameof(ft), Union{}) ? JSON.lower(field) : field
        d[name] = value
    end
    return [string(nameof(typeof(x))), d]
end

# a minimal 'eval' function, mirroring KeyTypes, but being slightly more lenient
safeeval(@nospecialize x) = x
safeeval(x::QuoteNode) = x.value
function safeeval(x::Expr)
    x.head === :quote && return x.args[1]
    x.head === :inert && return x.args[1]
    x.head === :tuple && return ((safeeval(a) for a in x.args)...,)
    return x
end
function recover(x::Vector)
    length(x) == 2 || throw(ArgumentError("Expecting a vector of length 2"))
    typename = x[1]::String
    fields = x[2]::Dict
    startswith(typename, "BenchmarkTools.") &&
        (typename = typename[(sizeof("BenchmarkTools.") + 1):end])
    T = SUPPORTED_TYPES[Symbol(typename)]
    fc = fieldcount(T)
    xs = Vector{Any}(undef, fc)
    for i in 1:fc
        ft = fieldtype(T, i)
        fn = String(fieldname(T, i))
        if ft <: get(SUPPORTED_TYPES, nameof(ft), Union{})
            xsi = recover(fields[fn])
        else
            xsi = if fn == "evals_set" && !haskey(fields, fn)
                false
            elseif fn in ("seconds", "overhead", "time_tolerance", "memory_tolerance") &&
                fields[fn] === nothing
                # JSON spec doesn't support Inf
                # These fields should all be >= 0, so we can ignore -Inf case
                typemax(ft)
            else
                convert(ft, fields[fn])
            end
        end
        if T == BenchmarkGroup && xsi isa Dict
            for (k, v) in copy(xsi)
                k = k::String
                if startswith(k, "(") || startswith(k, ":")
                    kt = Meta.parse(k; raise=false)
                    if !(kt isa Expr && kt.head === :error)
                        delete!(xsi, k)
                        k = safeeval(kt)
                        xsi[k] = v
                    end
                end
                if v isa Vector && length(v) == 2 && v[1] isa String
                    xsi[k] = recover(v)
                end
            end
        end
        xs[i] = xsi
    end
    return T(xs...)
end

function badext(filename)
    noext, ext = splitext(filename)
    msg = if ext == ".jld"
        "JLD serialization is no longer supported. Benchmarks should now be saved in\n" *
        "JSON format using `save(\"$noext.json\", args...)` and loaded from JSON using\n" *
        "`load(\"$noext.json\", args...)`. You will need to convert existing saved\n" *
        "benchmarks to JSON in order to use them with this version of BenchmarkTools."
    else
        "Only JSON serialization is supported."
    end
    throw(ArgumentError(msg))
end

"""
    BenchmarkTools.save(filename, args...)

Save serialized benchmarking objects (e.g. results or parameters) to a JSON file.
"""
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

"""
    BenchmarkTools.load(filename)

Load serialized benchmarking objects (e.g. results or parameters) from a JSON file.
"""
function load(filename::AbstractString, args...)
    endswith(filename, ".json") || badext(filename)
    open(filename, "r") do f
        load(f, args...)
    end
end

function load(io::IO, args...)
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
        !isa(parsed[1], Dict) ||
        !isa(parsed[2], Vector)
        error("Unexpected JSON format. Was this file originally written by BenchmarkTools?")
    end
    versions = parsed[1]::Dict
    values = parsed[2]::Vector
    return map!(recover, values, values)
end
