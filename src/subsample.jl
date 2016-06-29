#############################
# significance calculations #
#############################

reject(p, threshold) = p < threshold

function pvalue(estsamps, nullval, testval)
    flipval = 2testval - nullval # nullval flipped around testval
    leftbound = min(flipval, nullval)
    rightbound = max(flipval, nullval)
    return 1 - mean(leftbound .< estsamps .< rightbound)
end

# For a given benchmark trial, estimate the minimum percent shift in the trial's location
# necessary to achieve a rejection with a given threshold and subsample parameters.
reject_effect(trial::BenchmarkTools.Trial; kwargs...) = reject_effect(trial.times; kwargs...)

function reject_effect(trial; threshold = 0.01, kwargs...)
    percent_unit = 0.001
    shift_unit = ceil(Int, minimum(trial) * percent_unit)
    total_percent = percent_unit
    trial_shifted = copy(trial)
    while total_percent < 1.0
        for i in eachindex(trial_shifted)
            trial_shifted[i] += shift_unit
        end
        if subsample_pvalue(trial, trial_shifted; kwargs...) < threshold
            return total_percent
        else
            total_percent += percent_unit
        end
    end
    return total_percent
end

# inverse of reject_effect; returns the appropriate threshold to reject at a given effect size
reject_threshold(trial::BenchmarkTools.Trial; kwargs...) = reject_threshold(trial.times; kwargs...)

function reject_threshold(trial; effect = 0.05, kwargs...)
    shift_unit = ceil(Int, minimum(trial) * effect)
    trial_shifted = copy(trial)
    for i in eachindex(trial_shifted)
        trial_shifted[i] += shift_unit
    end
    return subsample_pvalue(trial, trial_shifted; kwargs...)
end

################################
# subsample hypothesis testing #
################################

function subsample(a::BenchmarkTools.Trial, b::BenchmarkTools.Trial; kwargs...)
    return subsample(a.times, b.times; kwargs...)
end

function subsample(a, b; effect = 0.05, threshold = 0.01, auto = :threshold, kwargs...)
    p = subsample_pvalue(a, b; kwargs...)
    if auto == :threshold
        threshold_value = reject_threshold(a; effect = effect, kwargs...)
        effect_value = effect
    elseif auto == :effect
        threshold_value = threshold
        effect_value = reject_effect(a; threshold = threshold, kwargs...)
    else
        error("bad value for keyword argument auto: $auto")
    end
    return p, threshold_value, effect_value
end

function subsample_pvalue{T}(a::T, b::T; kwargs...)
    estsamps = subsample_dist(a, b; kwargs...)
    return pvalue(estsamps, 1.0, minimum(a) / minimum(b))
end

function subsample(a, b; trials = min(1000, length(a), length(b)))
    result = zeros(trials)
    a_block_size = pick_block_size(a)
    b_block_size = pick_block_size(b)
    a_subsample_indices = rand(1:(length(a)-a_block_size), trials)
    b_subsample_indices = rand(1:(length(b)-b_block_size), trials)
    for t in 1:trials
        x, y = Inf, Inf
        i, j = a_subsample_indices[t], b_subsample_indices[t]
        for k in i:(i + a_block_size)
            x = min(a[k], x)
        end
        for k in j:(j + b_block_size)
            y = min(b[k], y)
        end
        result[t] = x / y
    end
    return result
end


# uses n^(1/5), recommended for block subsample of two-sided distributions by Hall 1995,
# Politis (1999) confirmed this approach is reasonable for subsampling as well.
pick_block_size(times) = ceil(Int, length(times)^(1//5))
