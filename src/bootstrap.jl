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
# necessary to achieve a rejection with a given threshold and bootstrap parameters.
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
        if bootstrap_pvalue(trial, trial_shifted; kwargs...) < threshold
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
    return bootstrap_pvalue(trial, trial_shifted; kwargs...)
end

################################
# bootstrap hypothesis testing #
################################

function bootstrap(a::BenchmarkTools.Trial, b::BenchmarkTools.Trial; kwargs...)
    return bootstrap(a.times, b.times; kwargs...)
end

function bootstrap(a, b; effect = 0.05, threshold = 0.01, auto = :threshold, kwargs...)
    p = bootstrap_pvalue(a, b; kwargs...)
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

function bootstrap_pvalue{T}(a::T, b::T; kwargs...)
    estsamps = bootstrap_dist(a, b; kwargs...)
    return pvalue(estsamps, 1.0, minimum(a) / minimum(b))
end

# bootstrap with replacement
function bootstrap_dist(a, b; resample = 0.01, trials = min(1000, length(a), length(b)))
    estsamps = zeros(trials)
    a_resample_size = ceil(Int, resample*length(a))
    b_resample_size = ceil(Int, resample*length(b))
    for i in 1:trials
        x = Inf
        y = Inf
        for _ in 1:a_resample_size
            x = min(rand(a), x)
        end
        for _ in 1:b_resample_size
            y = min(rand(b), y)
        end
        estsamps[i] = x / y
    end
    return estsamps
end
