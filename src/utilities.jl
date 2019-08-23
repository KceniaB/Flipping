"""
`iscolumn`
"""
function iscolumn(df::DataFrames.AbstractDataFrame,what::Symbol)
    if in(what,names(df))
        return true
    else
        return false
    end
end

"""
`count_sequence`
count when along an array the value of i+1 is different from i
"""
function count_sequence(series::AbstractArray)
    v_count = [1]
    count = 1
    for i = 2:size(series,1)
        if series[i] == series[i-1]
            count = count
        else
            count = count+1
        end
        push!(v_count,count)
    end
    return v_count
end

"""
"count_series"
useful to count an ordered series of categorical values, wheter they are the same or
they change
"""
function count_trues(count::T, same) where {T <: Number}
    if same
        count+1
    else
        1
    end
end

function check_series(x)
    Vector = [false]
    for i = 2:size(x,1)
        push!(Vector,x[i] == x[i-1] ? true : false)
    end
    return Vector
end

function count_series(vector)
    x = check_series(vector)
    res = accumulate(count_trues,x;init=0)
    return res
end
