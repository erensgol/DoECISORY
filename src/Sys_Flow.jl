module Sys_Flow

# ======================================================================================
# DAISHODOE - SYSTEM FLOW (PROCESS & STATE)
# ======================================================================================
# Purpose: Navigation Routing, Session State Management, and Process Logic.
# Module Tag: FLOW
# ======================================================================================

using Dash
using JSON3
using DataFrames
using Main.Sys_Fast

export FLOW_RouteUrl_DDEF, FLOW_PackState_DDEF, FLOW_UnpackState_DDEF,
    FLOW_AskLeader_DDEF, FLOW_NextPhase_DDEF, FLOW_GetCandidates_DDEF

# --------------------------------------------------------------------------------------
# SECTION 1: ROUTING & STATE MANAGEMENT
# --------------------------------------------------------------------------------------

# Pre-built immutable route table
const _ROUTES = Dict{String,String}(
    "/"        => "PAGE_HOME",
    "/home"    => "PAGE_HOME",
    "/design"  => "PAGE_DESIGN",
    "/analysis"=> "PAGE_ANALYSIS",
)

"""
    FLOW_RouteUrl_DDEF(PathName)
Maps URL pathnames to internal page identifiers.
"""
function FLOW_RouteUrl_DDEF(PathName::String)
    return get(_ROUTES, PathName) do
        html_div("404: Page Not Found", className="text-danger")
    end
end

"""
    DaishoState
Session state structure for storage in dcc_store.
"""
struct DaishoState
    TargetFile::String
    ActivePhase::String
    CurrentConfig::Dict{String,Any}
end

const _EMPTY_STATE = DaishoState("", "Phase1", Dict{String,Any}())

"""
    FLOW_PackState_DDEF(TargetFile, ActivePhase, Config) -> String
Serializes the application state into a JSON string.
"""
FLOW_PackState_DDEF(TargetFile::String, ActivePhase::String, Config::Dict=Dict{String,Any}()) =
    JSON3.write(DaishoState(TargetFile, ActivePhase, Config))

"""
    FLOW_UnpackState_DDEF(JsonString) -> DaishoState
Deserializes the application state from a JSON string.
"""
function FLOW_UnpackState_DDEF(JsonString::String)
    (isempty(JsonString) || JsonString == "null") && return _EMPTY_STATE
    try
        return JSON3.read(JsonString, DaishoState)
    catch
        return _EMPTY_STATE
    end
end

# --------------------------------------------------------------------------------------
# SECTION 2: PROCESS FLOW LOGIC
# --------------------------------------------------------------------------------------

"""
    FLOW_AskLeader_DDEF(LeaderVal, CurrentRange) -> (Valid, Msg)
Validates leader point proximity to boundaries to prevent search space clipping.
"""
function FLOW_AskLeader_DDEF(LeaderVal::Float64, CurrentRange::Vector{Float64})
    min_val, _, max_val = CurrentRange
    tol = (max_val - min_val) * 0.05

    if abs(LeaderVal - min_val) < tol
        return (false, "Leader point too close to LOWER bound! Shift search space left?")
    elseif abs(LeaderVal - max_val) < tol
        return (false, "Leader point too close to UPPER bound! Shift search space right?")
    else
        return (true, "Leader point near center. Suggest zooming in for finer scan.")
    end
end

"""
    FLOW_NextPhase_DDEF(MasterFile, CurrentPhase, SelectedID) -> Dict
Calculates the configuration for the subsequent experimental phase.
"""
function FLOW_NextPhase_DDEF(MasterFile::String, CurrentPhase::String, SelectedLeaderID::String="")
    Leader = Main.Lib_Core.CORE_ExtractLeader_DDEF(MasterFile, CurrentPhase, SelectedLeaderID)
    isempty(Leader) && return Dict("Status" => "FAIL",
        "Message" => "No valid leader found in $CurrentPhase.")

    C = Sys_Fast.CONST_DATA
    df_config = Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.SHEET_CONFIG)
    OldConfig = Dict[]

    if !isempty(df_config)
        json_col = findfirst(c -> occursin("JSON", uppercase(c)), names(df_config))
        if !isnothing(json_col)
            try
                RawConf = JSON3.read(df_config[1, json_col])
                if haskey(RawConf, "Ingredients")
                    OldConfig = map(RawConf["Ingredients"]) do item
                        d = Dict{String,Any}(string(k) => v for (k, v) in pairs(item))
                        if haskey(d, "Levels")
                            d["Levels"] = Float64[isnothing(x) ? NaN : Float64(x) for x in d["Levels"]]
                        end
                        d
                    end
                end
            catch e
                Sys_Fast.FAST_Log_DDEF("FLOW", "Config Error", "Parse Failed: $e", "FAIL")
            end
        end
    end

    isempty(OldConfig) && return Dict("Status" => "FAIL",
        "Message" => "Could not restore configuration.")

    Leader["OldConfig"] = OldConfig
    NewConfig = Main.Lib_Core.CORE_CalcNextRange_DDEF(Leader)

    p_num = tryparse(Int, replace(CurrentPhase, "Phase" => ""))

    return Dict(
        "Status"      => "OK",
        "SourcePhase" => CurrentPhase,
        "TargetPhase" => "Phase$(isnothing(p_num) ? 2 : p_num + 1)",
        "NewConfig"   => NewConfig,
        "LeaderScore" => Leader["Score"],
    )
end

"""
    FLOW_GetCandidates_DDEF(MasterFile, CurrentPhase) -> Vector{Dict}
Extracts potential leaders from the specified phase.
"""
function FLOW_GetCandidates_DDEF(MasterFile::String, CurrentPhase::String)
    C = Sys_Fast.CONST_DATA
    df = Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.PREFIX_LEADERS * CurrentPhase)
    isempty(df) && return Dict{String,Any}[]

    cols = names(df)
    col_score = findfirst(c -> occursin("SCORE", uppercase(c)), cols)
    col_id    = findfirst(c -> occursin("ID", uppercase(c)), cols)

    isnothing(col_score) && return Dict{String,Any}[]

    candidates = map(eachrow(df)) do row
        Dict(
            "ID"    => isnothing(col_id) ? "Unknown" : row[col_id],
            "Score" => row[col_score],
            "Data"  => Dict{String,Any}(string(k) => v for (k, v) in pairs(row)),
        )
    end

    sort!(candidates; by=x -> x["Score"], rev=true)
    return candidates
end

end # module
