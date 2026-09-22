const VERSIONS = Dict(
    "Julia" => string(VERSION), "BenchmarkTools" => pkgversion(BenchmarkTools)
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
    fields = x[2]::AbstractDict
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
        if T == BenchmarkGroup && xsi isa AbstractDict
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

!!! note
    This function requires the JSON.jl package. Run `using JSON` (or `import JSON`)
    to load the serialization extension before calling this function.
"""
function save(args...)
    return error(
        "BenchmarkTools.save requires the JSON.jl package. Run `using JSON` (or `import JSON`) first to enable JSON serialization.",
    )
end

"""
    BenchmarkTools.load(filename)

Load serialized benchmarking objects (e.g. results or parameters) from a JSON file.

!!! note
    This function requires the JSON.jl package. Run `using JSON` (or `import JSON`)
    to load the serialization extension before calling this function.
"""
function load(args...)
    return error(
        "BenchmarkTools.load requires the JSON.jl package. Run `using JSON` (or `import JSON`) first to enable JSON serialization.",
    )
end
