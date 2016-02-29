function trim(indexable, percent = 0.05)
    cut = floor(Int, length(indexable) * percent)
    return sort(indexable)[(1 + cut):(end - cut)]
end

function mmspread(iterable)
    avg = mean(iterable)
    return (avg, (maximum(iterable) - avg) / avg, (avg - minimum(iterable)) / avg)
end
