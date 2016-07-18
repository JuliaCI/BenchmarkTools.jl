#######################################
# resampling-based hypothesis testing #
#######################################

two_tailed_pvalue(null_estimate, estimate) = mean(abs(null_estimate) .>= abs(estimate))

# Welch's t-statistic scaled by a normalization coefficient to prevent collapse to a degenerate distribution
function test_statistic(a, b, beta = 0.0)
    numerator = (length(a)^beta * location(a)) - (length(b)^beta * location(b))
    denominator = sqrt(standard_error(a)^2 + standard_error(b)^2)
    return numerator / denominator
end

location(x) = mean(x)

standard_error(x) = std(x) / sqrt(length(x))

#####################
# block subsampling #
#####################

subsample(a::Trial, b::Trial, beta; kwargs...) = subsample(a.times, b.times, beta; kwargs...)

function subsample(a, b, beta; kwargs...)
    estimate = test_statistic(a, b, beta)
    a_null = a .- location(a)
    b_null = b .- location(b)
    null_estimate = subsample_distribution(a_null, b_null, beta; kwargs...)
    return null_estimate, estimate
end

function subsample_distribution(a, b, beta; trials = 10000, block_size = nothing)
    subsample_estimates = zeros(trials)
    a_block_size = subsample_block_size(a, block_size)
    b_block_size = subsample_block_size(b, block_size)
    a_subsample_indices = rand(1:(length(a) - a_block_size), trials)
    b_subsample_indices = rand(1:(length(b) - b_block_size), trials)
    for t in 1:trials
        i, j = a_subsample_indices[t], b_subsample_indices[t]
        a_subsample = sub(a, i:(i + a_block_size))
        b_subsample = sub(b, j:(j + b_block_size))
        subsample_estimates[t] = test_statistic(a_subsample, b_subsample, beta)
    end
    return subsample_estimates
end

# Use block size recommended by Hall 1995 for two-tailed tests
function subsample_block_size(times, default = nothing)
    return default == nothing ? ceil(Int, length(times)^(1//5)) : default
end

#########################################
# m-out-of-n bootstrap with replacement #
#########################################

# bootstrap(a::Trial, b::Trial; kwargs...) = bootstrap(a.times, b.times; kwargs...)
#
# # several alternative ways of simulating the null are shown
# function bootstrap(a, b; kwargs...)
#     estimate = test_statistic(a, b)
#
#     # location-shifting to the null #
#     #-------------------------------#
#     a_null = a .- location(a)
#     b_null = b .- location(b)
#     null_estimate = bootstrap_distribution(a_null, b_null; kwargs...)
#
#     # prior mixing #
#     #--------------#
#     # pool = vcat(a, b)
#     # null_estimate = bootstrap_distribution(pool, pool; kwargs...)
#
#     # posterior mixing #
#     #------------------#
#     # a_null = bootstrap_distribution(a, a; kwargs...)
#     # b_null = bootstrap_distribution(b, b; kwargs...)
#     # weight = length(b) / (length(a) + length(b))
#     # null_estimate = (sqrt(weight) .* a_null) .+ (sqrt(1 - weight) .* a_null)
#
#     return null_estimate, estimate
# end
#
# function bootstrap_distribution(a, b; trials = 10000, resample_size = nothing)
#     resample_estimates = zeros(trials)
#     a_resample = similar(a, bootstrap_resample_size(a, resample_size))
#     b_resample = similar(b, bootstrap_resample_size(a, resample_size))
#     for t in 1:trials
#         resample_estimates[t] = test_statistic(rand!(a_resample, a), rand!(b_resample, b))
#     end
#     return resample_estimates
# end
#
# function bootstrap_resample_size(times, default = nothing)
#     return default == nothing ? length(times) : default
# end
