"""
`carica`
since jld2 files are saved as dictionaries
it is painful to indicates always the variable name you want.
In this way it automatically calls the first key of the dictionary
and retunrs the variable stored
"""
function carica(filename)
    file = FileIO.load(filename)
    if isa(file, Dict)
        data = file[collect(keys(file))[1]]
    else
        data = FileIO.load(filename) |> DataFrame
    end
    return data
end
