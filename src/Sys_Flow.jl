module Sys_Flow

# ======================================================================================
# DAISHODOE - SYSTEM FLOW (PROCESS & STATE)
# ======================================================================================
# Purpose: Experimental Phase Transitions and Process Logic.
# Module Tag: FLOW
# ======================================================================================

using JSON3
using DataFrames
using Main.Sys_Fast

export FLOW_AskLeader_DDEF, FLOW_NextPhase_DDEF, FLOW_GetCandidates_DDEF,
    FLOW_BuildNextPhase_DDEF, FLOW_CalcNextRange_DDEF, FLOW_WriteLeaders_DDEF



# --------------------------------------------------------------------------------------
# --- PROCESS FLOW LOGIC ---
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
        return (true, "Leader point near centre. Suggest zooming in for finer scan.")
    end
end

"""
    FLOW_NextPhase_DDEF(MasterFile::String, CurrentPhase::String, SelectedLeaderID::String="", ZoomFactor::Float64=0.5)::Dict{String, Any}
Orchestrates transition to the next experimental phase based on selected leader performance.
"""
function FLOW_NextPhase_DDEF(MasterFile::Union{String,Nothing}, CurrentPhase::Union{String,Nothing}, SelectedLeaderID::Union{String,Nothing}="", ZoomFactor::Float64=0.5)::Dict{String, Any}
    (isnothing(MasterFile) || isempty(MasterFile) || !isfile(MasterFile)) && return Dict("Status" => "FAIL", "Message" => "Invalid master file path provided.")
    (isnothing(CurrentPhase) || isempty(CurrentPhase)) && return Dict("Status" => "FAIL", "Message" => "Current phase not specified.")
    # 1. Extract performance leader
    Leader = Main.Lib_Core.CORE_ExtractLeader_DDEF(MasterFile, CurrentPhase, SelectedLeaderID)
    isempty(Leader) && return Dict("Status" => "FAIL", "Message" => "Leader extraction failed for $CurrentPhase.")

    # 2. Reconstruct session state from MasterVault
    C = Sys_Fast.FAST_Data_DDEC
    df_config = Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.SHEET_CONFIG)
    
    OldConfig = Dict{String, Any}[]
    Outputs = Dict{String, Any}[]
    GlobalInfo = Dict{String, Any}()

    if !isempty(df_config)
        # Idiomatic search for JSON payload column
        json_col = findfirst(c -> occursin("JSON", uppercase(c)), names(df_config))
        if !isnothing(json_col)
            try
                RawConf = JSON3.read(df_config[1, json_col], Dict{String, Any})
                
                # Functional restoration of ingredients
                if haskey(RawConf, "Ingredients")
                    OldConfig = map(RawConf["Ingredients"]) do item
                        d = Dict{String, Any}(string(k) => v for (k, v) in pairs(item))
                        # Unified level restoration
                        d["Levels"] = if haskey(d, "Levels")
                            Float64[isnothing(x) ? NaN : Float64(x) for x in d["Levels"]]
                        elseif all(k -> haskey(d, k), ("L1", "L2", "L3"))
                            Float64[Float64(d["L1"]), Float64(d["L2"]), Float64(d["L3"])]
                        else
                            Float64[0.0, 0.0, 0.0]
                        end
                        d
                    end
                end

                # Carry forward session metadata
                Outputs = [Dict{String, Any}(string(k) => v for (k, v) in pairs(o)) for o in get(RawConf, "Outputs", [])]
                GlobalInfo = Dict{String, Any}(string(k) => v for (k, v) in pairs(get(RawConf, "Global", Dict())))
                
            catch e
                Sys_Fast.FAST_Log_DDEF("FLOW", "STATE_RESTORE", "JSON configuration sync failed: $e", "FAIL")
            end
        end
    end

    isempty(OldConfig) && return Dict("Status" => "FAIL", "Message" => "Configuration state loss detected.")

    # 3. Calculate Adaptive Search Space
    Leader["OldConfig"] = OldConfig
    NewConfig = FLOW_CalcNextRange_DDEF(Leader, ZoomFactor)

    # 4. Phase Sequencing
    p_num = tryparse(Int, replace(CurrentPhase, "Phase" => ""))
    target_phase = "Phase$(isnothing(p_num) ? 2 : p_num + 1)"

    return Dict(
        "Status" => "OK",
        "SourcePhase" => CurrentPhase,
        "TargetPhase" => target_phase,
        "NewConfig" => NewConfig,
        "LeaderScore" => get(Leader, "Score", 0.0),
        "Outputs" => Outputs,
        "Global" => GlobalInfo,
    )
end

"""
    FLOW_GetCandidates_DDEF(MasterFile::String, CurrentPhase::String)::Vector{Dict{String, Any}}
Extracts potential leaders for the specified phase, sorted by scientific score.
"""
function FLOW_GetCandidates_DDEF(MasterFile::Union{String,Nothing}, CurrentPhase::Union{String,Nothing})::Vector{Dict{String, Any}}
    (isnothing(MasterFile) || isempty(MasterFile) || !isfile(MasterFile)) && return Dict{String, Any}[]
    (isnothing(CurrentPhase) || isempty(CurrentPhase)) && return Dict{String, Any}[]
    C = Sys_Fast.FAST_Data_DDEC
    df = Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.PREFIX_LEADERS * CurrentPhase)
    isempty(df) && return Dict{String, Any}[]
 
    # Functional extraction and numeric coercion
    candidates = map(eachrow(df)) do row
        d = Dict{String, Any}(string(k) => v for (k, v) in pairs(row))
        d["Score"] = Sys_Fast.FAST_SafeNum_DDEF(get(d, "SCORE", 0.0))
        d
    end
 
    # Idiomatic reverse sort by score
    return sort!(candidates; by=x -> x["Score"], rev=true)
end

# --------------------------------------------------------------------------------------
# --- EXCEL-CENTRIC PHASE TRANSITION ---
# --------------------------------------------------------------------------------------

"""
    FLOW_BuildNextPhase_DDEF(MasterFile::String, CurrentPhase::String, SelectedLeaderID::String="", ZoomFactor::Float64=0.5, Method::String="TL9")::Dict{String, Any}
Constructs the next experimental phase by mapping adaptive ranges to a coded design matrix.
"""
function FLOW_BuildNextPhase_DDEF(MasterFile::Union{String,Nothing}, CurrentPhase::Union{String,Nothing}, SelectedLeaderID::Union{String,Nothing}="", ZoomFactor::Float64=0.5, Method::String="TL9")::Dict{String, Any}
    (isnothing(MasterFile) || isempty(MasterFile) || !isfile(MasterFile)) && return Dict("Status" => "FAIL", "Message" => "Invalid master file path provided.")
    C = Sys_Fast.FAST_Data_DDEC
    Log = Sys_Fast.FAST_Log_DDEF

    # 1. Orchestrate Adaptive Search Space
    res = FLOW_NextPhase_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, ZoomFactor)
    res["Status"] != "OK" && return res

    NewConfig = res["NewConfig"]
    TargetPhase = res["TargetPhase"]
    Log("FLOW", "PHASE_BUILD", "Designing $TargetPhase search space from $CurrentPhase leader...", "WAIT")

    # 1.5 Stoichiometric Validation Bridge
    GlobalData = get(res, "Global", Dict())
    vol = Float64(get(GlobalData, "Volume", 5.0))
    conc = Float64(get(GlobalData, "Concentration", 10.0))

    # Robust key access helper (JSON3 compatibility)
    _get(o, k, d) = haskey(o, string(k)) ? o[string(k)] : (haskey(o, Symbol(k)) ? o[Symbol(k)] : d)

    # Declarative audit row generation
    audit_rows = map(NewConfig) do c
        lvls = _get(c, "Levels", [0.0, 0.0, 0.0])
        Dict("Name" => string(_get(c, "Name", "Unknown")), "Role" => string(_get(c, "Role", "Variable")), 
             "L1" => Float64(lvls[1]), "L2" => Float64(lvls[2]), "L3" => Float64(lvls[3]), "MW" => Float64(_get(c, "MW", 0.0)))
    end

    audit_ok, audit_report, _, t_mass, _ = Main.Lib_Mole.MOLE_QuickAudit_DDEF(audit_rows, vol, conc)
    if !audit_ok && t_mass > 1e-4
        Log("FLOW", "CHEM_FAIL", "Proposed subspace violates stoichiometry!", "FAIL")
        return Dict("Status" => "FAIL", "Message" => "Stoichiometric invalidity in new search space.\n" * audit_report)
    elseif !audit_ok
        Log("FLOW", "CHEM_SKIP", "Stoichiometry not configured or zero mass. Proceeding...", "INFO")
    end

    # 2. Design Matrix Generation
    var_indices = findall(c -> get(c, "Role", "Variable") == C.ROLE_VAR, NewConfig)
    length(var_indices) != 3 && return Dict("Status" => "FAIL", "Message" => "System requires 3 ingredients for phase transitions.")

    design_coded = Main.Lib_Core.CORE_GenDesign_DDEF(Method, 3)
    N_Runs = size(design_coded, 1)
    
    # 3. Level Mapping
    configs = [Dict("Levels" => get(NewConfig[i], "Levels", [0.0, 0.0, 0.0])) for i in var_indices]
    real_matrix = Main.Lib_Core.CORE_MapLevels_DDEF(design_coded, configs)

    # 4. Canonical DataFrame Construction
    p_num = something(tryparse(Int, replace(TargetPhase, "Phase" => "")), 2)
    
    df = DataFrame(
        C.COL_EXP_ID => ["EXP_P$(p_num)_$(lpad(i, 2, '0'))" for i in 1:N_Runs],
        C.COL_PHASE => fill(TargetPhase, N_Runs),
        C.COL_STATUS => fill("Pending", N_Runs),
        C.COL_NOTES => fill("", N_Runs)
    )

    # Vectorized column insertion
    for (k, idx) in enumerate(var_indices)
        df[!, C.PRE_INPUT * get(NewConfig[idx], "Name", "Var$k")] = round.(real_matrix[:, k]; digits=3)
    end

    foreach(NewConfig) do c
        role, name = get(c, "Role", ""), get(c, "Name", "")
        if role == C.ROLE_FIX
            lvls = get(c, "Levels", [0.0, 0.0, 0.0])
            df[!, C.PRE_FIXED * name] = fill(length(lvls) >= 2 ? lvls[2] : 0.0, N_Runs)
        elseif role == C.ROLE_FILL
            df[!, C.PRE_FILL * name] = fill(0.0, N_Runs)
        end
    end

    # result structures
    if haskey(res, "Outputs")
        for o in res["Outputs"]
            n = string(get(o, "Name", ""))
            isempty(n) && continue
            df[!, C.PRE_RESULT * n] = Vector{Union{Missing, Float64}}(missing, N_Runs)
            df[!, C.PRE_PRED * n] = Vector{Union{Missing, Float64}}(missing, N_Runs)
        end
    end
    df[!, C.COL_SCORE] = Vector{Union{Missing, Float64}}(missing, N_Runs)

    # 5. MasterVault Finalization
    current_config = Sys_Fast.FAST_ReadConfig_DDEF(MasterFile)
    current_config["Ingredients"] = [Dict{String, Any}(string(k) => v for (k, v) in pairs(c)) for c in NewConfig]
    
    g_info = get(current_config, "Global", Dict{String, Any}())
    g_info["Method"] = Method
    current_config["Global"] = g_info

    out_names = [string(get(o, "Name", "")) for o in get(res, "Outputs", []) if !isempty(get(o, "Name", ""))]
    in_names = [get(c, "Name", "") for c in NewConfig]
    
    success = Sys_Fast.FAST_InitMaster_DDEF(MasterFile, in_names, out_names, df, current_config)
    !success && return Dict("Status" => "FAIL", "Message" => "Excel commit failed for $TargetPhase.")

    Log("FLOW", "PHASE_BUILD", "Protocol $TargetPhase ($N_Runs runs) committed to Vault.", "OK")
    return Dict("Status" => "OK", "TargetPhase" => TargetPhase, "N_Runs" => N_Runs, "LeaderScore" => res["LeaderScore"])
end

# --------------------------------------------------------------------------------------
# --- ADAPTIVE SEARCH SPACE ---
# --------------------------------------------------------------------------------------

"""
    FLOW_CalcNextRange_DDEF(LeaderInfo, ZoomFactor=0.5) -> Vector{Dict}
Calculates the search space for the next phase using Zoom (reduction) or Shift (translation).
(Moved from Lib_Core.jl)
"""
function FLOW_CalcNextRange_DDEF(LeaderInfo::Dict, ZoomFactor::Float64=0.5)
    C = Sys_Fast.FAST_Data_DDEC
    NewConf = deepcopy(LeaderInfo["OldConfig"])
    SelVals = LeaderInfo["Vals"]

    Sys_Fast.FAST_Log_DDEF("FLOW", "SEARCH_SPACE", "Calculating adaptive design update...", "WAIT")

    vars = [(i, conf) for (i, conf) in enumerate(NewConf) if get(conf, "Role", "Variable") == C.ROLE_VAR]

    n_update = min(length(vars), length(SelVals))
    @inbounds for j in 1:n_update
        i, conf = vars[j]
        L_Old = conf["Levels"]
        Val = SelVals[j]
        Range = L_Old[3] - L_Old[1]

        Tol = Range * 0.05
        at_limit = abs(Val - L_Old[1]) < Tol || abs(Val - L_Old[3]) < Tol

        New_Mid = Val
        New_Range = at_limit ? Range : Range * ZoomFactor
        action = at_limit ? "SHIFT" : "ZOOM"
        Sys_Fast.FAST_Log_DDEF("FLOW", action,
            "Var $i -> $(action == "SHIFT" ? "Centre shifted" : "Range reduced")", "LIST")

        New_Min = New_Mid - New_Range / 2
        New_Max = New_Mid + New_Range / 2

        # Symmetrical boundary clamping: guard both lower and upper physical limits
        if New_Min < 0.0
            overshoot = -New_Min
            New_Min = 0.0
            New_Max += overshoot  # Compensate to preserve range width
            Sys_Fast.FAST_Log_DDEF("FLOW", "CLAMP", "Var $i hit lower boundary. Range shifted upward.", "WARN")
        end

        # If upper limit is defined in old config, respect it as a hard ceiling
        org_max = L_Old[3] + Range * 0.1  # Allow 10% overshoot beyond original max
        if New_Max > org_max && org_max > 0.0
            New_Max = org_max
            Sys_Fast.FAST_Log_DDEF("FLOW", "CLAMP", "Var $i hit upper boundary ceiling.", "WARN")
        end

        conf["Levels"] = [New_Min, New_Mid, New_Max]
    end

    Sys_Fast.FAST_Log_DDEF("FLOW", "SEARCH_SPACE", "New space configured successfully.", "OK")
    return NewConf
end

"""
    FLOW_WriteLeaders_DDEF(File, Phase, LeadersDF) -> Bool
Persists potential leaders for the current phase to the shared Excel vault.
(Moved from Sys_Fast.jl)
"""
function FLOW_WriteLeaders_DDEF(File::Union{String,Nothing}, Phase::Union{String,Nothing}, LeadersDF::DataFrame)
    (isnothing(File) || isempty(File) || isnothing(Phase) || isempty(Phase)) && return false
    C = Sys_Fast.FAST_Data_DDEC
    isempty(LeadersDF) && return false

    sheet_name = C.PREFIX_LEADERS * Phase
    try
        Sys_Fast.FAST_SafeExcelWrite_DDEF(File, Dict(sheet_name => LeadersDF))
        return true
    catch e
        Sys_Fast.FAST_Log_DDEF("FLOW", "IO_ERROR", "WriteLeaders Failed: $e", "FAIL")
        return false
    end
end

end # module Sys_Flow
