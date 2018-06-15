mutable struct PhotometryStructure
           pokes::DataFrames.AbstractDataFrame
           streaks::DataFrames.AbstractDataFrame
           traces::DataFrames.AbstractDataFrame
       end

"""
`verify_names`
check that all the Dataframes in an Array of PhotometryStructures
have the same names for a given field
"""
function verify_names(data::Array{Flipping.PhotometryStructure,1},field::Symbol)
   verify = Array{Bool,1}(0)
   for i = 2:size(data,1)
       first = names(getfield(data[i], field))
       second = names(getfield(data[i-1], field))
       push!(verify,first != second)
   end
   return find(verify)
end

function Base.unique(data::Array{Flipping.PhotometryStructure,1},column::Symbol, field::Symbol)
    result = []
    for i=1:size(data,1)
        session = getfield(data[i], field)
        values = unique(session[column])
        for value in values
            push!(result,value)
        end
    end
    result = unique(result)
end

function Base.maximum(data::Array{Flipping.PhotometryStructure,1},column::Symbol, field::Symbol)
    result = []
    for i=1:size(data,1)
        session = getfield(data[i], field)
        value = maximum(session[column])
        push!(result,value)
    end
    result = maximum(result)
end

function Base.minimum(data::Array{Flipping.PhotometryStructure,1},column::Symbol, field::Symbol)
    result = []
    for i=1:size(data,1)
        session = getfield(data[i], field)
        value = minimum(session[column])
        push!(result,value)
    end
    result = minimum(result)
end
