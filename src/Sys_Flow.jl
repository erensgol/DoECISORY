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

export    FLOW_AskLeader_DDEF, FLOW_NextPhase_DDEF, FLOW_GetCandidates_DDEF,
    FLOW_BuildNextPhase_DDEF



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
    FLOW_NextPhase_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, ZoomFactor=0.5) -> Dict
Calculates the configuration for the subsequent experimental phase.
"""
function FLOW_NextPhase_DDEF(MasterFile::String, CurrentPhase::String, SelectedLeaderID::String="", ZoomFactor::Float64=0.5)
    Leader = Main.Lib_Core.CORE_ExtractLeader_DDEF(MasterFile, CurrentPhase, SelectedLeaderID)
    isempty(Leader) && return Dict("Status" => "FAIL",
        "Message" => "No valid leader found in $CurrentPhase.")

    C = Sys_Fast.CONST_DATA
    df_config = Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.SHEET_CONFIG)
    OldConfig = Dict[]
    Outputs = []
    GlobalInfo = Dict{String,Any}()

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
                        elseif haskey(d, "L1") && haskey(d, "L2") && haskey(d, "L3")
                            d["Levels"] = Float64[Float64(d["L1"]), Float64(d["L2"]), Float64(d["L3"])]
                        end
                        d
                    end
                end
                # Carry forward Outputs and Global for design page handshake
                Outputs = [Dict{String,Any}(string(k) => v for (k, v) in pairs(o))
                           for o in get(RawConf, "Outputs", [])]
                g = get(RawConf, "Global", Dict())
                GlobalInfo = Dict{String,Any}(string(k) => v for (k, v) in pairs(g))
            catch e
                Sys_Fast.FAST_Log_DDEF("FLOW", "Config Error", "Parse Failed: $e", "FAIL")
            end
        end
    end

    isempty(OldConfig) && return Dict("Status" => "FAIL",
        "Message" => "Could not restore configuration.")

    Leader["OldConfig"] = OldConfig
    NewConfig = Main.Lib_Core.CORE_CalcNextRange_DDEF(Leader, ZoomFactor)

    p_num = tryparse(Int, replace(CurrentPhase, "Phase" => ""))

    return Dict(
        "Status" => "OK",
        "SourcePhase" => CurrentPhase,
        "TargetPhase" => "Phase$(isnothing(p_num) ? 2 : p_num + 1)",
        "NewConfig" => NewConfig,
        "LeaderScore" => Leader["Score"],
        "Outputs" => Outputs,
        "Global" => GlobalInfo,
    )
end

"""
    FLOW_GetCandidates_DDEF(MasterFile, CurrentPhase) -> Vector{Dict}
Extracts potential leaders from the specified phase from the leaders sheet.
"""
function FLOW_GetCandidates_DDEF(MasterFile::String, CurrentPhase::String)
    C = Sys_Fast.CONST_DATA
    df = Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.PREFIX_LEADERS * CurrentPhase)
    isempty(df) && return Dict{String,Any}[]

    cols = names(df)
    col_score = findfirst(c -> occursin("SCORE", uppercase(c)), cols)
    col_id = findfirst(c -> occursin("ID", uppercase(c)), cols)

    isnothing(col_score) && return Dict{String,Any}[]

    candidates = map(eachrow(df)) do row
        d = Dict{String,Any}(string(k) => v for (k, v) in pairs(row))
        # Ensure Score is numeric for sorting if needed
        d["Score"] = Sys_Fast.FAST_SafeNum_DDEF(get(d, "SCORE", 0.0))
        d
    end

    sort!(candidates; by=x -> x["Score"], rev=true)
    return candidates
end

# --------------------------------------------------------------------------------------
# --- EXCEL-CENTRIC PHASE TRANSITION ---
# --------------------------------------------------------------------------------------

"""
    FLOW_BuildNextPhase_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, ZoomFactor=0.5, Method="TL9") -> Dict
Calculates new ranges, generates design matrix for the next phase, and writes to Excel.
"""
function FLOW_BuildNextPhase_DDEF(MasterFile::String, CurrentPhase::String, SelectedLeaderID::String="", ZoomFactor::Float64=0.5, Method::String="TL9")
    C = Sys_Fast.CONST_DATA
    Log = Sys_Fast.FAST_Log_DDEF

    # 1. Calculate new ranges via existing logic
    res = FLOW_NextPhase_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, ZoomFactor)
    if res["Status"] != "OK"
        return res
    end

    NewConfig = res["NewConfig"]
    TargetPhase = res["TargetPhase"]
    Log("FLOW", "PHASE_BUILD", "Building $TargetPhase design from $CurrentPhase leader...", "WAIT")

    # 1.5 CHEMICAL PRE-FLIGHT AUDIT (Bridge Lib_Mole -> Sys_Flow)
    vol = Float64(get(res["Global"], "Volume", 5.0))
    conc = Float64(get(res["Global"], "Concentration", 10.0))

    # Lib_Mole expects a specific format: names, roles, l1, l2, l3, mw
    dummy_chem_rows = map(NewConfig) do c
        lvls = get(c, "Levels", [0.0, 0.0, 0.0])
        Dict(
            "Name" => get(c, "Name", "Unknown"),
            "Role" => get(c, "Role", "Variable"),
            "L1" => lvls[1], "L2" => lvls[2], "L3" => lvls[3],
            "MW" => get(c, "MW", 0.0)
        )
    end

    audit_ok, audit_report, _, _, _ = Main.Lib_Mole.MOLE_QuickAudit_DDEF(dummy_chem_rows, vol, conc)
    if !audit_ok
        Log("FLOW", "CHEM_FAIL", "Proposed search space is stoichiometrically invalid!", "FAIL")
        return Dict("Status" => "FAIL", "Message" => "Phase build aborted: Stoichiometric invalidity detected in new space.\n" * audit_report)
    end
    Log("FLOW", "CHEM_OK", "Stoichiometry validated for $TargetPhase", "OK")

    # 2. Identify variable indices and names
    var_indices = [i for (i, c) in enumerate(NewConfig) if get(c, "Role", "Variable") == C.ROLE_VAR]
    num_vars = length(var_indices)
    if num_vars != 3
        return Dict("Status" => "FAIL", "Message" => "System requires exactly 3 Variable ingredients (Found: $num_vars).")
    end

    # 3. Generate coded design matrix
    design_coded = Main.Lib_Core.CORE_GenDesign_DDEF(Method, num_vars)
    N_Runs = size(design_coded, 1)

    # 4. Build level configs for mapping
    configs = [Dict("Levels" => get(NewConfig[i], "Levels", [0.0, 0.0, 0.0])) for i in var_indices]
    real_matrix = Main.Lib_Core.CORE_MapLevels_DDEF(design_coded, configs)

    # 5. Extract phase number
    p_num = tryparse(Int, replace(TargetPhase, "Phase" => ""))
    p_num = isnothing(p_num) ? 2 : p_num

    # 6. Build DataFrame
    df = DataFrame(
        C.COL_EXP_ID => ["EXP_P$(p_num)_$(lpad(i, 2, '0'))" for i in 1:N_Runs],
        C.COL_PHASE => fill(TargetPhase, N_Runs),
        C.COL_STATUS => fill("Pending", N_Runs),
        C.COL_NOTES => fill("", N_Runs),
    )

    # Add variable columns
    for (k, idx) in enumerate(var_indices)
        col_name = C.PRE_INPUT * get(NewConfig[idx], "Name", "Var$k")
        df[!, col_name] = round.(real_matrix[:, k]; digits=3)
    end

    # Add fixed columns
    for (i, c) in enumerate(NewConfig)
        role = get(c, "Role", "Variable")
        name = get(c, "Name", "")
        if role == C.ROLE_FIX
            lvls = get(c, "Levels", [0.0, 0.0, 0.0])
            df[!, C.PRE_FIXED*name] = fill(length(lvls) >= 2 ? lvls[2] : 0.0, N_Runs)
        elseif role == C.ROLE_FILL
            df[!, C.PRE_FILL*name] = fill(0.0, N_Runs)
        end
    end

    # Add output columns from existing config
    out_names = String[]
    if haskey(res, "Outputs")
        for o in res["Outputs"]
            n = string(get(o, "Name", ""))
            isempty(n) && continue
            push!(out_names, n)
            df[!, C.PRE_RESULT*n] = Vector{Union{Missing,Float64}}(missing, N_Runs)
            df[!, C.PRE_PRED*n] = Vector{Union{Missing,Float64}}(missing, N_Runs)
        end
    end
    df[!, C.COL_SCORE] = Vector{Union{Missing,Float64}}(missing, N_Runs)

    # 7. Update config with new ingredient levels
    existing_config = Sys_Fast.FAST_ReadConfig_DDEF(MasterFile)
    updated_ingredients = [Dict{String,Any}(string(k) => v for (k, v) in pairs(c)) for c in NewConfig]
    existing_config["Ingredients"] = updated_ingredients
    g = get(existing_config, "Global", Dict{String,Any}())
    g["Method"] = C.METHOD_TL9
    existing_config["Global"] = g

    # 8. Write Phase2 to Excel (append to existing data)
    all_in_names = [get(c, "Name", "") for c in NewConfig]
    success = Sys_Fast.FAST_InitMaster_DDEF(MasterFile, all_in_names, out_names, df, existing_config)

    if !success
        return Dict("Status" => "FAIL", "Message" => "Failed to write $TargetPhase to Excel.")
    end

    Log("FLOW", "PHASE_BUILD", "$TargetPhase design ($N_Runs runs) written to MasterVault.", "OK")
    return Dict(
        "Status" => "OK",
        "TargetPhase" => TargetPhase,
        "SourcePhase" => CurrentPhase,
        "N_Runs" => N_Runs,
        "LeaderScore" => res["LeaderScore"],
    )
end

end # module Sys_Flow
