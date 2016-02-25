function trim(data, percent = 0.05)
    cut = floor(Int, length(data) * percent)
    return sort(data)[(1 + cut):(end - cut)]
end

function mmspread(v)
    avg = mean(v)
    return (avg, (maximum(v) - avg) / avg, (avg - minimum(v)) / avg)
end
