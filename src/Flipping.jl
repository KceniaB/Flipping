module Flipping

using Reexport
#using Preprocess
#using ProcessPhotometry
#@reexport using FFTViews
#@reexport using Reexport
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
@reexport using DataArrays
@reexport using JuliaDBMeta
@reexport using NaNMath

include("class.jl")
include("tools.jl")
include("saving&loading.jl")
include(joinpath("Behaviour","process_behaviour.jl"))
include(joinpath("Behaviour","searchfile.jl"))
include(joinpath("Photometry","bhv_photo_combine.jl"))
include(joinpath("Photometry","acquire_photo.jl"))
include(joinpath("Photometry","tools_photo.jl"))


export PhotometryStructure, verify_names, listvalues, convertin_DB
export process_pokes,process_streaks, concat_data!
export get_hierarchy, custom_bin, pharm
export get_data, create_DataIndex, create_exp_dataframes, gatherfilesphotometry, check_fiberlocation
export adjust_matfile, adjust_logfile, sliding_f0
export read_log, compress_analog, find_events, observe_pokes,check_burst,get_sequence
export process_photo, add_streaks,check_accordance!,ghost_buster
export carica, create_processed_files, combine_PhotometryStructures




end #module
