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
# """
# 'combine_PhotometryStructures'
# given the path of the single session PhotometryStructures
# it combine them in an array. keywars argument are
# saving::Bool
#  default false, if true save the array of PhotometryStructures
# datatype::String
#     by default it assumes datas to be pokes specify otherwise
# """
# function combine_PhotometryStructures(Directory_path,Exp_name;saving = false,run_path = "run_task_photo/")
#     Structure_pokes = Array{PhotometryStructure, 1}(0)
#     Structure_folder = Directory_path*run_path*Exp_name*"/Structures/"
#     Single_Structures_folder = joinpath(Structure_folder,"single_session")
#     files = readdir(Single_Structures_folder)
#     jls = occursin.(files, ".jld2")
#     files = files[jls]
#     for file in files
#         structure = carica(joinpath(Single_Structures_folder,file))
#         push!(Structure_pokes,structure)
#     end
#     if saving
#         saving_folder = joinpath(Directory_path,"Datasets","Photometry",Exp_name)
#         if !ispath(saving_folder)
#             mkdir(saving_folder)
#         end
#         filename = "Struct_"*Exp_name*".jld2"
#         struct_file = joinpath(saving_folder,filename)
#         @save struct_file Structure_pokes
#     end
#     return Structure_pokes
# end

# """
# `create_processed_files`
# given a DataIndex proceed to process all the sessions and save
# the single session behaviour, traces, events and structures
# keywar arguments is saving: Bool default true, if false
# doesn't save the single session files and only returns
# the array of PhotometryStructures
# """
# function create_processed_files(DataIndex;saving = true)
#     if saving
#         exp_dir = joinpath(DataIndex[1,:Saving_path],"Structures")
#         if !ispath(exp_dir)
#             mkdir(exp_dir)
#         end
#         saving_path = DataIndex[1,:Saving_path]*"/Structures/single_session/"
#         if !ispath(saving_path)
#             mkdir(saving_path)
#         end
#     end
#     Structure_pokes = Array{PhotometryStructure, 1}(0)
#     for idx = 1:size(DataIndex,1)
#         println("processing session structure ",DataIndex[idx,:Session], " idx = ",idx)
#         structure = process_photo(DataIndex,idx)
#         # trace_file = DataIndex[idx,:Exp_Path]*"Traces/"*"Trace_"*DataIndex[idx,:Session]*".csv"
#         # events_file = DataIndex[idx,:Exp_Path]*"Traces/"*"Events_"*DataIndex[idx,:Session]*".csv"
#         # bhv_file = DataIndex[idx,:Exp_Path]*"Bhv/"*DataIndex[idx,:Session]*".csv"
#         ongoing_session = "Struct"*DataIndex[idx,:Session]*".jld2"
#         struct_file = joinpath(saving_path,ongoing_session)
#         # FileIO.save(trace_file,trace)
#         # FileIO.save(events_file,events)
#         # FileIO.save(bhv_file,bhv)
#         @save struct_file structure
#         push!(Structure_pokes,structure)
#     end
#     return  Structure_pokes
# end
