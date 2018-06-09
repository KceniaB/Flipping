module Flipping

using Reexport
#using Preprocess
#using ProcessPhotometry
@reexport using Reexport
@reexport using DataFrames
@reexport using MAT
@reexport using FileIO
@reexport using CSVFiles
@reexport using GLM
@reexport using TextParse
@reexport using ShiftedArrays
@reexport using IterableTables
@reexport using JLD2
@reexport using StaticArrays
@reexport using DSP
@reexport using Plots
@reexport using StatsBase
@reexport using FFTViews
@reexport using DataArrays

include("acquire_photo.jl");
include("process_behaviour.jl")
include("bhv_photo_combine.jl")
include("searchfile.jl")
include("tools.jl")
include("tools_photo.jl")
plotly()

export Photometry_Struct
export process_pokes,gatherfilesphotometry, check_fiberlocation
export adjust_matfile, adjust_logfile
export read_log, compress_analog, find_events, observe_pokes
export create_processed_files,process_photo, add_streaks
export ghost_buster


struct Photometry_Struct
           behaviour::DataFrames.AbstractDataFrame
           traces::DataFrames.AbstractDataFrame
       end


end #module
