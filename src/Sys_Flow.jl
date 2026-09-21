module Sys_Flow

# ==============================================================================
# DOECISORY - SYSTEM FLOW (PROCESS & STATE)
# ==============================================================================
# Description: Experimental phase management, transition logic, and state 
#              synchronisation bus.
# Module Tag:  FLOW
# ==============================================================================

using JSON3
using DataFrames
using PlotlyJS
using Printf
using ..Sys_Fast
using ..Lib_Core
using ..Lib_Mole

const Main = parentmodule(@__MODULE__)


export FLOW_AskLeader_DDEF, FLOW_NextPhase_DDEF, FLOW_GetCandidates_DDEF,
    FLOW_BuildNextPhase_DDEF, FLOW_CalcNextRange_DDEF, FLOW_WriteLeaders_DDEF,
    FLOW_CalcAdaptiveRange_DDEF, FLOW_RenderPhaseTransition_DDEF,
    FLOW_BridgeTransform_DDEF, FLOW_BridgeValidate_DDEF

# ==============================================================================
# PART A: TYPE DEFINITIONS & CONSTANTS & TRANSITION
# ==============================================================================

"""
    AbstractFLOW_BoundaryStatus (DDET)
Trait hierarchy for classifying leader proximity to search space edges.
"""
abstract type AbstractFLOW_BoundaryStatus end
struct FLOW_BoundarySafe_DDES  <: AbstractFLOW_BoundaryStatus end
struct FLOW_BoundaryLower_DDES <: AbstractFLOW_BoundaryStatus end
struct FLOW_BoundaryUpper_DDES <: AbstractFLOW_BoundaryStatus end

"""
    FLOW_BoundaryAlertMap_DDEC
Centralised map for translating boundary traits into user alerts and system flags.
"""
const FLOW_BoundaryAlertMap_DDEC = Dict{DataType, Tuple{Bool, String}}(
    FLOW_BoundarySafe_DDES  => (true,  "Optimal candidate point near centre. Suggest zooming in for finer scan."),
    FLOW_BoundaryLower_DDES => (false, "Optimal candidate point near LOWER boundary limit. Consider shifting search range downward."),
    FLOW_BoundaryUpper_DDES => (false, "Optimal candidate point near UPPER boundary limit. Consider shifting search range upward.")
)

"""
    FLOW_ActionTagMap_DDEC
Standardised action identifiers for search space adaptation telemetry.
"""
const FLOW_ActionTagMap_DDEC = Dict{DataType, String}(
    FLOW_BoundarySafe_DDES  => "ZOOM",
    FLOW_BoundaryLower_DDES => "SHIFT (AUTO)",
    FLOW_BoundaryUpper_DDES => "SHIFT (AUTO)"
)

# ------------------------------------------------------------------------------
# SECTION 1: PROCESS FLOW LOGIC
# ------------------------------------------------------------------------------

"""
    FLOW_DetermineBoundaryStatus_DDEF(Val, Min, Max) -> AbstractFLOW_BoundaryStatus
Classifies the spatial status of a value relative to boundary tolerances.
"""
function FLOW_DetermineBoundaryStatus_DDEF(Val::Real, Min::Real, Max::Real)::AbstractFLOW_BoundaryStatus
    rng  = Max - Min
    tol  = rng * 0.05
    Val < Min + tol && return FLOW_BoundaryLower_DDES()
    Val > Max - tol && return FLOW_BoundaryUpper_DDES()
    return FLOW_BoundarySafe_DDES()
end

"""
    FLOW_AskLeader_DDEF(LeaderVal, CurrentRange) -> (Valid, Msg)
Evaluates the proximity of the selected leader to existing boundaries to prevent search space clipping.
"""
function FLOW_AskLeader_DDEF(LeaderVal::Real, CurrentRange::Vector{Float64})
    status = FLOW_DetermineBoundaryStatus_DDEF(LeaderVal, CurrentRange[1], CurrentRange[3])
    return get(FLOW_BoundaryAlertMap_DDEC, typeof(status), (true, "Status OK."))
end

"""
    FLOW_NextPhase_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, ZoomFactor, ShiftFactor) -> Dict
Orchestrates the transition to the subsequent experimental phase based on leader performance.
"""
function FLOW_NextPhase_DDEF(MasterFile::Union{AbstractString,Nothing}, CurrentPhase::Union{AbstractString,Nothing},
    SelectedLeaderID::Union{AbstractString,Nothing}="", ZoomFactor::Real=0.5, ShiftFactor::Real=0.0)::Dict{String,Any}
    
    (isnothing(MasterFile) || isempty(MasterFile) || !isfile(MasterFile)) && return Dict("Status" => "FAIL", "Message" => "Invalid master file path provided.")
    (isnothing(CurrentPhase) || isempty(CurrentPhase)) && return Dict("Status" => "FAIL", "Message" => "Current phase not specified.")
    
    C         = Main.Sys_Fast.FAST_Data_DDEC
    df_config = Main.Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.SHEET_CONFIG)

    OldConfig  = Dict{String,Any}[]
    Outputs    = Dict{String,Any}[]
    GlobalInfo = Dict{String,Any}()
    InNames    = String[]

    if !isempty(df_config)
        json_col = findfirst(c -> occursin("JSON", uppercase(c)), names(df_config))
        if !isnothing(json_col)
            try
                RawConf = JSON3.read(df_config[1, json_col], Dict{String,Any})

                if haskey(RawConf, "Ingredients")
                    raw_ing  = RawConf["Ingredients"]
                    iter_ing = (raw_ing isa AbstractDict || raw_ing isa Dict) ? values(raw_ing) : raw_ing
                    OldConfig = map(iter_ing) do item
                        d = Dict{String,Any}(string(k) => v for (k, v) in pairs(item))
                        d["Levels"] = if haskey(d, "Levels")
                            Float64[isnothing(x) ? NaN : Float64(x) for x in d["Levels"]]
                        elseif all(k -> haskey(d, k), ("L1", "L2", "L3"))
                            Float64[Float64(d["L1"]), Float64(d["L2"]), Float64(d["L3"])]
                        else
                            Float64[0.0, 0.0, 0.0]
                        end

                        if get(d, "Role", "") == C.ROLE_VAR
                            push!(InNames, get(d, "Name", ""))
                        end
                        d
                    end
                end

                Outputs    = [Dict{String,Any}(string(k) => v for (k, v) in pairs(o)) for o in get(RawConf, "Outputs", [])]
                GlobalInfo = Dict{String,Any}(string(k) => v for (k, v) in pairs(get(RawConf, "Global", Dict())))

            catch e
                Main.Sys_Fast.FAST_Log_DDEF("FLOW", "STATE_RESTORE", "JSON configuration sync failed: $e", "FAIL")
            end
        end
    end

    isempty(OldConfig) && return Dict("Status" => "FAIL", "Message" => "Configuration state loss detected.")

    Leader = Main.Lib_Core.CORE_ExtractLeader_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, InNames)
    isempty(Leader) && return Dict("Status" => "FAIL", "Message" => "Leader extraction failed for $CurrentPhase.")

    Leader["OldConfig"] = OldConfig
    
    alerts = String[]
    vars_only = filter(c -> get(c, "Role", "") == C.ROLE_VAR, OldConfig)
    for (j, conf) in enumerate(vars_only)
        lvls = get(conf, "Levels", [0.0, 0.0, 0.0])
        val  = (j <= length(Leader["Vals"])) ? Leader["Vals"][j] : lvls[2]
        ok, msg = FLOW_AskLeader_DDEF(val, lvls)
        !ok && push!(alerts, "[Var $(j)]: " * msg)
    end

    NewConfig = FLOW_CalcNextRange_DDEF(Leader, ZoomFactor, ShiftFactor)

    p_num        = tryparse(Int, replace(CurrentPhase, "Phase" => ""))
    target_phase = "Phase$(isnothing(p_num) ? 2 : p_num + 1)"

    return Dict(
        "Status"       => "OK",
        "SourcePhase"  => CurrentPhase,
        "TargetPhase"  => target_phase,
        "NewConfig"    => NewConfig,
        "OldConfig"    => OldConfig,
        "LeaderValues" => collect(get(Leader, "Vals", Float64[])),
        "LeaderScore"  => get(Leader, "Score", 0.0),
        "Outputs"        => Outputs,
        "Global"         => GlobalInfo,
        "BoundaryAlerts" => alerts
    )
end

"""
    FLOW_GetCandidates_DDEF(MasterFile::String, CurrentPhase::String)::Vector{Dict{String, Any}}
Extracts potential leaders for the specified phase, sorted by scientific score.
"""
function FLOW_GetCandidates_DDEF(MasterFile::Union{AbstractString,Nothing}, CurrentPhase::Union{AbstractString,Nothing})::Vector{Dict{String,Any}}
    (isnothing(MasterFile) || isempty(MasterFile) || !isfile(MasterFile)) && return Dict{String,Any}[]
    (isnothing(CurrentPhase) || isempty(CurrentPhase)) && return Dict{String,Any}[]
    
    C  = Main.Sys_Fast.FAST_Data_DDEC
    df = Main.Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.PREFIX_LEADERS * CurrentPhase)
    isempty(df) && return Dict{String,Any}[]

    candidates = map(eachrow(df)) do row
        d          = Dict{String,Any}(string(k) => v for (k, v) in pairs(row))
        lookup     = Dict(uppercase(string(k)) => v for (k, v) in pairs(row))
        d["Score"] = Main.Sys_Fast.FAST_SafeNum_DDEF(get(lookup, "SCORE", 0.0))
        d
    end

    return sort!(candidates; by=x -> x["Score"], rev=true)
end

"""
    FLOW_CalcAdaptiveRange_DDEF(Val, L_Old, Zoom, Shift, [MinLimit]) -> Vector{Float64}
Internal helper for search space adaptation logic. Enforces MinLimit boundary clamping.
"""
function FLOW_CalcAdaptiveRange_DDEF(Val::Real, L_Old::Vector{Float64}, Zoom::Real, Shift::Real, MinLimit::Real=0.0)::Vector{Float64}
    rng      = L_Old[3] - L_Old[1]
    status   = FLOW_DetermineBoundaryStatus_DDEF(Val, L_Old[1], L_Old[3])
    
    new_rng = (status isa FLOW_BoundarySafe_DDES) ? rng * Zoom : rng

    shift_val = Shift * (new_rng * 0.5)
    new_mid   = Val + shift_val

    new_min = max(MinLimit, new_mid - new_rng / 2.0)
    new_max = new_min + new_rng
    
    org_max = L_Old[3] + rng * 0.5
    new_max = (org_max > 0.0) ? min(new_max, org_max) : new_max

    return Float64[new_min, new_mid, new_max]
end

# ------------------------------------------------------------------------------
# SECTION 2: EXCEL-CENTRIC PHASE TRANSITION
# ------------------------------------------------------------------------------

"""
    FLOW_BuildNextPhase_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, ZoomFactor, Method, ShiftFactor; Direction, CustomConfig) -> Dict
Generates the subsequent experimental phase by mapping adaptive ranges to a coded design matrix.
"""
function FLOW_BuildNextPhase_DDEF(MasterFile::Union{AbstractString,Nothing}, CurrentPhase::Union{AbstractString,Nothing},
    SelectedLeaderID::Union{AbstractString,Nothing}="", ZoomFactor::Real=0.5, Method::AbstractString="TL09", ShiftFactor::Real=0.0;
    Direction::Union{Vector{Int}, Nothing}=[-1, -1, -1],
    CustomConfig::Union{AbstractVector, Nothing}=nothing)::Dict{String,Any}
    
    (isnothing(MasterFile) || isempty(MasterFile) || !isfile(MasterFile)) && return Dict("Status" => "FAIL", "Message" => "Invalid master file path provided.")
    C   = Main.Sys_Fast.FAST_Data_DDEC
    Log = Main.Sys_Fast.FAST_Log_DDEF

    res = FLOW_NextPhase_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, ZoomFactor, ShiftFactor)
    res["Status"] != "OK" && return res

    NewConfig = if !isnothing(CustomConfig) && !isempty(CustomConfig)
        [Dict{String,Any}(string(k) => (v isa AbstractVector ? copy(v) : v) for (k,v) in pairs(c)) for c in CustomConfig]
    else
        res["NewConfig"]
    end
    TargetPhase = res["TargetPhase"]
    Log("FLOW", "PHASE_BUILD", "Designing $TargetPhase search space from $CurrentPhase leader...", "WAIT")

    GlobalData = get(res, "Global", Dict())
    vol        = Float64(get(GlobalData, "Volume", 5.0))
    conc       = Float64(get(GlobalData, "Concentration", 10.0))

    FLOW_GetSafeKey_DDEF(o, k, d) = Sys_Fast.FAST_GetSafe_DDEF(o, k, d)

    audit_rows = map(NewConfig) do c
        lvls = FLOW_GetSafeKey_DDEF(c, "Levels", [0.0, 0.0, 0.0])
        Dict(
            "Name" => string(FLOW_GetSafeKey_DDEF(c, "Name", "Unknown")), 
            "Role" => string(FLOW_GetSafeKey_DDEF(c, "Role", "Fixed")),
            "L1"   => Float64(lvls[1]), 
            "L2"   => Float64(lvls[2]), 
            "L3"   => Float64(lvls[3]), 
            "MW"   => Float64(FLOW_GetSafeKey_DDEF(c, "MW", 0.0)),
            "Unit" => string(FLOW_GetSafeKey_DDEF(c, "Unit", "-"))
        )
    end

    audit_ok, audit_report, audit_results, t_mass, _ = Main.Lib_Mole.MOLE_QuickAudit_DDEF(audit_rows, vol, conc)
    if !audit_ok && t_mass > 1e-4
        Log("FLOW", "CHEM_FAIL", "Proposed subspace violates stoichiometry!", "FAIL")
        return Dict("Status" => "FAIL", "Message" => "Stoichiometric invalidity in new search space.\n" * audit_report)
    elseif !audit_ok
        Log("FLOW", "CHEM_SKIP", "Stoichiometry not configured or zero mass. Proceeding...", "INFO")
    end

    if !isempty(audit_results)
        for c in NewConfig
            if FLOW_GetSafeKey_DDEF(c, "Role", "") == C.ROLE_FILL
                c_name = FLOW_GetSafeKey_DDEF(c, "Name", "")
                m_idx = findfirst(r -> r.Component == c_name, eachrow(audit_results))
                if !isnothing(m_idx)
                    c["Levels"] = [0.0, audit_results[m_idx, :TARGET_MASS_mg], 0.0]
                end
            end
        end
    end

    var_indices = findall(c -> FLOW_GetSafeKey_DDEF(c, "Role", "") == C.ROLE_VAR, NewConfig)
    length(var_indices) != 3 && return Dict("Status" => "FAIL", "Message" => "System requires 3 ingredients for phase transitions.")

    design_coded = Main.Lib_Core.CORE_GenDesign_DDEF(Method, 3, Direction)
    N_Runs       = size(design_coded, 1)

    configs     = [Dict("Levels" => FLOW_GetSafeKey_DDEF(NewConfig[i], "Levels", [0.0, 0.0, 0.0])) for i in var_indices]
    real_matrix = Main.Lib_Core.CORE_MapLevels_DDEF(design_coded, configs)

    p_num = something(tryparse(Int, replace(TargetPhase, "Phase" => "")), 2)

    df_sys = DataFrame(
        C.COL_EXP_ID    => ["EXP_P$(p_num)_$(lpad(i, 2, '0'))" for i in 1:N_Runs],
        C.COL_PHASE     => fill(TargetPhase, N_Runs),
        C.COL_STATUS    => fill("Pending", N_Runs),
        C.COL_NOTES     => fill("", N_Runs)
    )

    df_chem = Main.Lib_Mole.MOLE_ProcessDesign_DDEF(real_matrix, audit_rows, vol, conc)

    df = hcat(df_sys, df_chem)

    if haskey(res, "Outputs")
        for o in res["Outputs"]
            n = string(get(o, "Name", ""))
            u = string(get(o, "Unit", ""))
            isempty(n) && continue
            
            res_header  = (isempty(u) || u == "-") ? C.PRE_RESULT * n : C.PRE_RESULT * n * "_" * u
            pred_header = (isempty(u) || u == "-") ? C.PRE_PRED * n   : C.PRE_PRED * n   * "_" * u
            
            df[!, res_header] = Vector{Union{Missing,Float64}}(missing, N_Runs)
            df[!, pred_header] = Vector{Union{Missing,Float64}}(missing, N_Runs)
        end
    end
    df[!, C.COL_SCORE] = Vector{Union{Missing,Float64}}(missing, N_Runs)
    current_config                = Main.Sys_Fast.FAST_ReadConfig_DDEF(MasterFile)
    current_config["Ingredients"] = [Dict{String,Any}(string(k) => v for (k, v) in pairs(c)) for c in NewConfig]

    g_info                   = get(current_config, "Global", Dict{String,Any}())
    g_info["Method"]         = Method
    g_info["Direction"]      = (Method == "DF14" ? Direction : nothing)

    # PhaseHistory orchestration for scientific provenance and audit trail
    ph_raw = get(g_info, "PhaseHistory", Dict{String,Any}())
    ph_history = (ph_raw isa AbstractDict) ? Dict{String,Any}(string(k) => v for (k, v) in pairs(ph_raw)) : Dict{String,Any}()
    var_names = [string(FLOW_GetSafeKey_DDEF(NewConfig[i], "Name", "")) for i in var_indices]

    ph_entry = Dict{String,Any}(
        "Method"       => Method,
        "DirectionMap" => (Method == "DF14" && length(var_names) == 3 && !isnothing(Direction) && length(Direction) >= 3 ?
                           Dict{String,Any}(var_names[i] => Int(Direction[i]) for i in 1:3) : nothing),
        "LeaderID"     => string(SelectedLeaderID),
        "ZoomFactor"   => Float64(ZoomFactor),
        "ShiftFactor"  => Float64(ShiftFactor),
        "N_Runs"       => N_Runs
    )
    ph_history[TargetPhase] = ph_entry
    g_info["PhaseHistory"]  = ph_history
    current_config["Global"] = g_info

    out_names = String[string(get(o, "Name", "")) for o in get(res, "Outputs", []) if !isempty(get(o, "Name", ""))]
    in_names  = String[string(FLOW_GetSafeKey_DDEF(c, "Name", "")) for c in NewConfig]

    success = Main.Sys_Fast.FAST_InitialiseMaster_DDEF(MasterFile, in_names, out_names, df, current_config)
    !success && return Dict("Status" => "FAIL", "Message" => "Excel commit failed for $TargetPhase.")

    Log("FLOW", "PHASE_BUILD", "Protocol $TargetPhase ($N_Runs runs) committed to Vault.", "OK")
    return Dict("Status" => "OK", "TargetPhase" => TargetPhase, "N_Runs" => N_Runs, "LeaderScore" => res["LeaderScore"])
end

# ==============================================================================
# PART B: ADAPTIVE RANGE & COMMITMENT BUS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 3: ADAPTIVE SEARCH SPACE
# ------------------------------------------------------------------------------

"""
    FLOW_CalcNextRange_DDEF(LeaderInfo, ZoomFactor, ShiftFactor) -> Vector{Dict}
Calculates the adaptive search space for the subsequent phase using Zoom (compression) or Shift (translation).
"""
function FLOW_CalcNextRange_DDEF(LeaderInfo::Dict, ZoomFactor::Float64=0.5, ShiftFactor::Float64=0.0)
    C       = Main.Sys_Fast.FAST_Data_DDEC
    NewConf = deepcopy(LeaderInfo["OldConfig"])
    SelVals = LeaderInfo["Vals"]

    Main.Sys_Fast.FAST_Log_DDEF("FLOW", "SEARCH_SPACE", "Calculating adaptive design update (Z=$(ZoomFactor), S=$(ShiftFactor))...", "WAIT")

    vars     = [(i, conf) for (i, conf) in enumerate(NewConf) if get(conf, "Role", "Variable") == C.ROLE_VAR]
    n_update = min(length(vars), length(SelVals))

    @inbounds for j in 1:n_update
        i, conf = vars[j]
        L_Old   = conf["Levels"]
        Val     = SelVals[j]
        min_lim = Float64(get(conf, "Min", 0.0))

        conf["Levels"] = FLOW_CalcAdaptiveRange_DDEF(Val, L_Old, ZoomFactor, ShiftFactor, min_lim)

        status = FLOW_DetermineBoundaryStatus_DDEF(Val, L_Old[1], L_Old[3])
        action = (abs(ShiftFactor) > 0.05) ? "SHIFT (MANUAL)" : get(FLOW_ActionTagMap_DDEC, typeof(status), "UPDATE")
        
        Main.Sys_Fast.FAST_Log_DDEF("FLOW", action, "Var $i -> $(action)", "LIST")
    end
    Main.Sys_Fast.FAST_Log_DDEF("FLOW", "SEARCH_SPACE", "New space configured successfully.", "OK")
    return NewConf
end

"""
    FLOW_WriteLeaders_DDEF(File, Phase, LeadersDF) -> Bool
Persists prioritised candidates for the current phase to the shared master record.
"""
function FLOW_WriteLeaders_DDEF(File::Union{AbstractString,Nothing}, Phase::Union{AbstractString,Nothing}, LeadersDF::DataFrame)
    (isnothing(File) || isempty(File) || isnothing(Phase) || isempty(Phase)) && return false
    
    C          = Main.Sys_Fast.FAST_Data_DDEC
    sheet_name = C.PREFIX_LEADERS * Phase

    isempty(LeadersDF) && return false

    try
        Main.Sys_Fast.FAST_SafeExcelWrite_DDEF(File, Dict(sheet_name => LeadersDF))
        return true
    catch e
        Main.Sys_Fast.FAST_Log_DDEF("FLOW", "IO_ERROR", "WriteLeaders Failed: $e", "FAIL")
        return false
    end
end

# ------------------------------------------------------------------------------
# SECTION 4: CROSS-PROJECT BRIDGE TRANSFORMS
# ------------------------------------------------------------------------------

"""
    FLOW_BridgeTransform_DDEF(Val, Alpha, Beta) -> Float64
Applies an affine transformation to transfer a leader value across experimental systems.
"""
function FLOW_BridgeTransform_DDEF(Val::Real, Alpha::Real, Beta::Real)::Float64
    return Float64(Alpha * Val + Beta)
end

"""
    FLOW_BridgeValidate_DDEF(Val, MinLimit, MaxLimit) -> (Valid, ClampedVal, Warning)
Enforces physical laboratory constraints on a transformed value.
"""
function FLOW_BridgeValidate_DDEF(Val::Real, MinLimit::Real, MaxLimit::Real)::Tuple{Bool,Float64,String}
    min_f = MinLimit
    max_f = MaxLimit

    min_f >= max_f && return (true, Val, "")

    clamped = clamp(Val, min_f, max_f)
    if clamped != Val
        bound_name = (Val < min_f) ? "LOWER" : "UPPER"
        bound_val  = (Val < min_f) ? min_f : max_f
        msg = "Value $(round(Val; digits=2)) exceeds $bound_name bound $(round(bound_val; digits=2)). Clamped."
        return (false, clamped, msg)
    end

    return (true, Val, "")
end

# ------------------------------------------------------------------------------
# SECTION 5: PHASE TRANSITION VISUALISATION
# ------------------------------------------------------------------------------

"""
    FLOW_RenderPhaseTransition_DDEF(OldConfig, NewConfig, LeaderVals) -> Dict
Visualises the adaptation of search space boundaries between sequential experimental phases.
Standardised Coded Scale: Current boundaries are mapped to [-1, 1].
"""
function FLOW_RenderPhaseTransition_DDEF(OldConfig::AbstractVector, NewConfig::AbstractVector, LeaderVals::AbstractVector;
    Method::AbstractString="TL09", Direction::Vector{Int}=[-1, -1, -1])
    FD = Main.Sys_Fast.FAST_Data_DDEC

    vars = [(i, c) for (i, c) in enumerate(OldConfig) if get(c, "Role", "Variable") == FD.ROLE_VAR]
    n_vars = length(vars)
    if n_vars == 0
        return Dict("data" => [], "layout" => Layout(title="No variables detected."))
    end

    AXIS_LO = -2.0
    AXIS_HI = 2.0

    traces      = GenericTrace[]
    annotations = Dict{String,Any}[]
    new_vars = [c for c in NewConfig if get(c, "Role", "Variable") == FD.ROLE_VAR]

    y_nms       = [j <= length(new_vars) ? get(new_vars[j], "Name", "Var$j") : get(c, "Name", "Var$j") for (j, (i, c)) in enumerate(vars)]

    for (j, (i, conf)) in enumerate(vars)
        L_Old = Float64.(get(conf, "Levels", [0.0, 0.0, 0.0]))
        L_New = j <= length(new_vars) ? Float64.(get(new_vars[j], "Levels", L_Old)) : L_Old

        y_pos = n_vars - j + 1

        Val = (j <= length(LeaderVals)) ? Float64(LeaderVals[j]) : L_Old[2]
        
        base_mid  = (L_Old[1] + L_Old[3]) / 2.0
        base_span = max(L_Old[3] - L_Old[1], 1e-5)
        FLOW_NormaliseValue_DDEF(v) = (v - base_mid) / (base_span / 2.0)

        n_new_min = clamp(FLOW_NormaliseValue_DDEF(L_New[1]), AXIS_LO, AXIS_HI)
        n_new_max = clamp(FLOW_NormaliseValue_DDEF(L_New[3]), AXIS_LO, AXIS_HI)
        n_new_mid = clamp(FLOW_NormaliseValue_DDEF(L_New[2]), AXIS_LO, AXIS_HI)
        n_leader  = FLOW_NormaliseValue_DDEF(Val)

        push!(traces, scatter(; 
            x=[-1.0, 1.0], y=[y_pos, y_pos], mode="lines",
            name="Current", 
            legendgroup="Current",
            line=attr(color=FD.COLOUR_DARLOW, width=12),
            showlegend=(j == 1), 
            hoverinfo="skip"
        ))

        push!(traces, scatter(; 
            x=[n_new_min, n_new_max], y=[y_pos, y_pos], mode="lines",
            name="Target", 
            legendgroup="Target",
            line=attr(color=FD.COLOUR_HUEYEL, width=12),
            showlegend=(j == 1),
            hoverinfo="text",
            hovertext="New: $(round(L_New[1]; digits=2)) → $(round(L_New[3]; digits=2))"
        ))
        
        push!(traces, scatter(; 
            x=[n_new_mid], y=[y_pos], mode="markers", 
            name="Target Centre",
            legendgroup="Target", 
            marker=attr(symbol="circle", size=12, color=FD.COLOUR_TONGRE, line=attr(color=FD.COLOUR_PURWHI, width=2)),
            showlegend=false,
            hoverinfo="text",
            hovertext="Target Centre: $(round(L_New[2]; digits=2))"
        ))

        if Method == "DF14"
            dir_j = (j <= length(Direction)) ? Direction[j] : -1
            tip_x = (dir_j == -1) ? n_new_min : n_new_max
            tip_side = (dir_j == -1) ? "Lower (−1)" : "Upper (+1)"
            v_name = j <= length(new_vars) ? get(new_vars[j], "Name", "Var$j") : "Var$j"
            
            push!(traces, scatter(;
                x=[tip_x], y=[y_pos], mode="markers",
                name="DF14 Axial Focus",
                legendgroup="AxialFocus",
                marker=attr(
                    symbol="circle",
                    size=13,
                    color="#21918C",
                    line=attr(color=FD.COLOUR_PURWHI, width=2)
                ),
                showlegend=(j == 1),
                hoverinfo="text",
                hovertext="$v_name Axial Star Focus: $tip_side"
            ))
        end

        y_ann = y_pos - 0.35
        push!(annotations, Dict(
            "x" => n_new_min, "y" => y_ann, "xref" => "x", "yref" => "y",
            "text" => string(round(L_New[1]; digits=1)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => FD.COLOUR_DARHIG),
        ))
        push!(annotations, Dict(
            "x" => n_new_max, "y" => y_ann, "xref" => "x", "yref" => "y",
            "text" => string(round(L_New[3]; digits=1)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => FD.COLOUR_DARHIG),
        ))

        push!(traces, scatter(; 
            x=[n_leader], y=[y_pos], mode="markers", 
            name="Leader",
            legendgroup="Leader",
            marker=attr(
                symbol="circle", size=12, color=FD.COLOUR_SHAMAG,
                line=attr(color=FD.COLOUR_PURWHI, width=2)
            ),
            showlegend=(j == 1),
            hoverinfo="text",
            hovertext="Leader: $(round(Val; digits=2))"
        ))

        push!(annotations, Dict(
            "x" => -1.0, "y" => y_pos + 0.35, "xref" => "x", "yref" => "y",
            "text" => string(round(L_Old[1]; digits=1)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => FD.COLOUR_DARLOW),
        ))
        push!(annotations, Dict(
            "x" => 1.0, "y" => y_pos + 0.35, "xref" => "x", "yref" => "y",
            "text" => string(round(L_Old[3]; digits=1)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => FD.COLOUR_DARLOW),
        ))
    end

    ticks_vals = collect(AXIS_LO:0.5:AXIS_HI)
    ticks_text = [v == 0 ? "0" : (v == -1.0 ? "-1.0 (Lower)" : (v == 1.0 ? "+1.0 (Upper)" : Printf.@sprintf("%+.1f", v))) for v in ticks_vals]

    y_tick_vals = collect(n_vars:-1:1)

    layout = Layout(;
        height         = min(120 + n_vars * 50, 280),
        margin         = attr(l=120, r=40, t=10, b=40),
        plot_bgcolor   = FD.COLOUR_PURWHI,
        paper_bgcolor  = "rgba(0,0,0,0)",
        xaxis = attr(
            title      = attr(text="", font=attr(size=10, color=FD.COLOUR_DARHIG)),
            gridcolor  = FD.COLOUR_LIGHIG, 
            zeroline   = false,
            autorange  = false, 
            range      = [AXIS_LO - 0.05, AXIS_HI + 0.05],
            tickvals   = ticks_vals, 
            ticktext   = ticks_text,
            tickfont   = attr(size=9)
        ),
        yaxis = attr(
            tickvals   = y_tick_vals, 
            ticktext   = y_nms, 
            showgrid   = false,
            zeroline   = false, 
            fixedrange = true,
            tickfont   = attr(size=10, color=FD.COLOUR_DARHIG, weight="bold")
        ),
        legend      = attr(orientation="h", y=-0.4, x=0.5, xanchor="center", font=attr(size=9)),
        annotations = annotations,
        shapes      = [
            attr(type="line", x0=AXIS_LO, x1=AXIS_LO, y0=0, y1=1, yref="paper", line=attr(color=FD.COLOUR_HUERED, width=1.5, dash="dash")),
            attr(type="line", x0=AXIS_HI, x1=AXIS_HI, y0=0, y1=1, yref="paper", line=attr(color=FD.COLOUR_HUERED, width=1.5, dash="dash"))
        ]
    )

    if isempty(traces)
        push!(traces, scatter(x=[0], y=[1], text=["Visualisation engine standby."], mode="text"))
    end

    p = Plot(traces, layout)
    
    return Dict(
        "data"   => p.data,
        "layout" => p.layout
    )
end

end
