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
include("saving&loading.jl")
plotly()

export PhotometryStructure
export process_pokes,process_streaks
export gatherfilesphotometry, check_fiberlocation
export adjust_matfile, adjust_logfile
export read_log, compress_analog, find_events, observe_pokes
export process_photo, add_streaks,ghost_buster
export carica, create_processed_files, combine_PhotometryStructures


mutable struct PhotometryStructure
           pokes::DataFrames.AbstractDataFrame
           streaks::DataFrames.AbstractDataFrame
           traces::DataFrames.AbstractDataFrame
       end


end #module
