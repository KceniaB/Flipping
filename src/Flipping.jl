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

include("class.jl")
include("tools.jl")
include("saving&loading.jl")
include(joinpath("Behaviour","process_behaviour.jl"))
include(joinpath("Behaviour","searchfile.jl"))
include(joinpath("Photometry","bhv_photo_combine.jl"))
include(joinpath("Photometry","acquire_photo.jl"))
include(joinpath("Photometry","tools_photo.jl"))
plotly()

export PhotometryStructure, verify_names
export process_pokes,process_streaks
export get_FromStim, custom_bin
export gatherfilesphotometry, check_fiberlocation
export adjust_matfile, adjust_logfile
export read_log, compress_analog, find_events, observe_pokes
export process_photo, add_streaks,ghost_buster
export carica, create_processed_files, combine_PhotometryStructures




end #module
