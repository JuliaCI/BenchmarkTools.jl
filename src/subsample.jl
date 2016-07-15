################################
# subsample hypothesis testing #
################################

reject_pvalue(p, threshold) = p < threshold

function pvalue(samps, nullval, testval)
    flipval = 2testval - nullval # nullval flipped around testval
    leftbound = min(flipval, nullval)
    rightbound = max(flipval, nullval)
    return 1 - mean(leftbound .< samps .< rightbound)
end

function subsample_pvalue(a, b; kwargs...)
    samps = subsample_estimate(a, b; kwargs...)
    return pvalue(samps, 1.0, minimum(a) / minimum(b))
end

function subsample_estimate(a, b; trials = nothing, block_size = nothing)
    trials = trials == nothing ? min(10000, length(a), length(b)) : trials
    a_block_size = block_size == nothing ? pick_block_size(a) : block_size
    b_block_size = block_size == nothing ? pick_block_size(b) : block_size

    estimate_samples = zeros(trials)
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
        estimate_samples[t] = x / y
    end

    return estimate_samples
end

pick_block_size(times) = ceil(Int, length(times)^(1//5))
