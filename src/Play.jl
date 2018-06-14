using Flipping
plotly()
####
path="/Users/dariosarra/Google Drive/Flipping/run_task_photo/Sert-Gcamp DRN/Structures/Struct_Sert-Gcamp DRN.jld2"
sert=carica(path);
##
data = sert
column = :MouseID
field = :streaks
result = []
for i=1:size(data,1)
    session = getfield(data[i], field)
    values = unique(session[column])
    for value in values
        push!(result,value)
    end
end
result
#result = union(result)
unique(result)
##
data = sert
column = :MouseID
field = :streaks
result = []

result
##
union(data[100].streaks[:MouseID])
result
session = getfield(data[1], field)
