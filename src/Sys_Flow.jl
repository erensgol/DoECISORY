module Sys_Flow

# ======================================================================================
# DAISHODOE - SYSTEM FLOW (PROCESS & STATE)
# ======================================================================================
# Purpose: Experimental phase management, transition logic, and state synchronisation bus.
# Module Tag: FLOW
# ======================================================================================

using JSON3
using DataFrames
using PlotlyJS
using Main.Sys_Fast
using Main.Lib_Arts

export FLOW_AskLeader_DDEF, FLOW_NextPhase_DDEF, FLOW_GetCandidates_DDEF,
    FLOW_BuildNextPhase_DDEF, FLOW_CalcNextRange_DDEF, FLOW_WriteLeaders_DDEF,
    FLOW_CalcAdaptiveRange_DDEF, FLOW_RenderPhaseTransition_DDEF



# --------------------------------------------------------------------------------------
# --- PROCESS FLOW LOGIC ---
# --------------------------------------------------------------------------------------

"""
    FLOW_AskLeader_DDEF(LeaderVal, CurrentRange) -> (Valid, Msg)
Validates leader point proximity to boundaries to prevent search space clipping.
"""
function FLOW_AskLeader_DDEF(LeaderVal::Float64, CurrentRange::Vector{Float64})
    min_val, _, max_val = CurrentRange
    tol                 = (max_val - min_val) * 0.05

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
function FLOW_NextPhase_DDEF(MasterFile::Union{String,Nothing}, CurrentPhase::Union{String,Nothing},
    SelectedLeaderID::Union{String,Nothing}="", ZoomFactor::Float64=0.5, ShiftFactor::Float64=0.0)::Dict{String,Any}
    
    (isnothing(MasterFile) || isempty(MasterFile) || !isfile(MasterFile)) && return Dict("Status" => "FAIL", "Message" => "Invalid master file path provided.")
    (isnothing(CurrentPhase) || isempty(CurrentPhase)) && return Dict("Status" => "FAIL", "Message" => "Current phase not specified.")
    
    # 1. Reconstruct session state from MasterVault FIRST to get correct variable order
    C         = Sys_Fast.FAST_Data_DDEC
    df_config = Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.SHEET_CONFIG)

    OldConfig  = Dict{String,Any}[]
    Outputs    = Dict{String,Any}[]
    GlobalInfo = Dict{String,Any}()
    InNames    = String[]

    if !isempty(df_config)
        # Idiomatic search for JSON payload column
        json_col = findfirst(c -> occursin("JSON", uppercase(c)), names(df_config))
        if !isnothing(json_col)
            try
                RawConf = JSON3.read(df_config[1, json_col], Dict{String,Any})

                # Functional restoration of ingredients
                if haskey(RawConf, "Ingredients")
                    raw_ing  = RawConf["Ingredients"]
                    iter_ing = raw_ing isa Dict ? values(raw_ing) : raw_ing
                    OldConfig = map(iter_ing) do item
                        d = Dict{String,Any}(string(k) => v for (k, v) in pairs(item))
                        # Unified level restoration
                        d["Levels"] = if haskey(d, "Levels")
                            Float64[isnothing(x) ? NaN : Float64(x) for x in d["Levels"]]
                        elseif all(k -> haskey(d, k), ("L1", "L2", "L3"))
                            Float64[Float64(d["L1"]), Float64(d["L2"]), Float64(d["L3"])]
                        else
                            Float64[0.0, 0.0, 0.0]
                        end

                        # Collect names of variables to ensure extraction order
                        if get(d, "Role", "") == C.ROLE_VAR
                            push!(InNames, get(d, "Name", ""))
                        end
                        d
                    end
                end

                # Carry forward session metadata
                Outputs    = [Dict{String,Any}(string(k) => v for (k, v) in pairs(o)) for o in get(RawConf, "Outputs", [])]
                GlobalInfo = Dict{String,Any}(string(k) => v for (k, v) in pairs(get(RawConf, "Global", Dict())))

            catch e
                Sys_Fast.FAST_Log_DDEF("FLOW", "STATE_RESTORE", "JSON configuration sync failed: $e", "FAIL")
            end
        end
    end

    isempty(OldConfig) && return Dict("Status" => "FAIL", "Message" => "Configuration state loss detected.")

    # 2. Now extract leader using the strict InNames order
    Leader = Main.Lib_Core.CORE_ExtractLeader_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, InNames)
    isempty(Leader) && return Dict("Status" => "FAIL", "Message" => "Leader extraction failed for $CurrentPhase.")

    # 3. Calculate Adaptive Search Space
    Leader["OldConfig"] = OldConfig
    NewConfig           = FLOW_CalcNextRange_DDEF(Leader, ZoomFactor, ShiftFactor)

    # 4. Phase Sequencing
    p_num        = tryparse(Int, replace(CurrentPhase, "Phase" => ""))
    target_phase = "Phase$(isnothing(p_num) ? 2 : p_num + 1)"

    return Dict(
        "Status"      => "OK",
        "SourcePhase" => CurrentPhase,
        "TargetPhase" => target_phase,
        "NewConfig"   => NewConfig,
        "OldConfig"   => OldConfig,
        "LeaderScore" => get(Leader, "Score", 0.0),
        "Outputs"     => Outputs,
        "Global"      => GlobalInfo,
    )
end

"""
    FLOW_GetCandidates_DDEF(MasterFile::String, CurrentPhase::String)::Vector{Dict{String, Any}}
Extracts potential leaders for the specified phase, sorted by scientific score.
"""
function FLOW_GetCandidates_DDEF(MasterFile::Union{String,Nothing}, CurrentPhase::Union{String,Nothing})::Vector{Dict{String,Any}}
    (isnothing(MasterFile) || isempty(MasterFile) || !isfile(MasterFile)) && return Dict{String,Any}[]
    (isnothing(CurrentPhase) || isempty(CurrentPhase)) && return Dict{String,Any}[]
    
    C  = Sys_Fast.FAST_Data_DDEC
    df = Sys_Fast.FAST_ReadExcel_DDEF(MasterFile, C.PREFIX_LEADERS * CurrentPhase)
    isempty(df) && return Dict{String,Any}[]

    # Functional extraction and numeric coercion
    candidates = map(eachrow(df)) do row
        d          = Dict{String,Any}(string(k) => v for (k, v) in pairs(row))
        # Case-insensitive score extraction
        lookup     = Dict(uppercase(string(k)) => v for (k, v) in pairs(row))
        d["Score"] = Sys_Fast.FAST_SafeNum_DDEF(get(lookup, "SCORE", 0.0))
        d
    end

    # Idiomatic reverse sort by score
    return sort!(candidates; by=x -> x["Score"], rev=true)
end

"""
    FLOW_CalcAdaptiveRange_DDEF(Val, L_Old, Zoom, Shift) -> Vector{Float64}
Internal helper for search space adaptation logic.
"""
function FLOW_CalcAdaptiveRange_DDEF(Val::Float64, L_Old::Vector{Float64}, Zoom::Real, Shift::Real)
    Range = L_Old[3] - L_Old[1]

    # Automatic shift logic for boundary leaders
    Tol      = Range * 0.05
    at_limit = abs(Val - L_Old[1]) < Tol || abs(Val - L_Old[3]) < Tol

    New_Range = at_limit ? Range : Range * Zoom

    # Manual Shift applied relative to half of the NEW range
    ShiftVal = Shift * (New_Range * 0.5)
    New_Mid  = Val + ShiftVal

    New_Min = New_Mid - New_Range / 2
    New_Max = New_Mid + New_Range / 2

    # Boundary clamping with conservation of range
    if New_Min < 0.0
        overshoot = -New_Min
        New_Min   = 0.0
        New_Max  += overshoot
    end

    org_max = L_Old[3] + Range * 0.5
    if New_Max > org_max && org_max > 0.0
        New_Max = org_max
    end

    return Float64[New_Min, New_Mid, New_Max]
end

# --------------------------------------------------------------------------------------
# --- EXCEL-CENTRIC PHASE TRANSITION ---
# --------------------------------------------------------------------------------------

"""
    FLOW_BuildNextPhase_DDEF(MasterFile::String, CurrentPhase::String, SelectedLeaderID::String="", ZoomFactor::Float64=0.5, Method::String="TL09")::Dict{String, Any}
Constructs the next experimental phase by mapping adaptive ranges to a coded design matrix.
"""
function FLOW_BuildNextPhase_DDEF(MasterFile::Union{String,Nothing}, CurrentPhase::Union{String,Nothing},
    SelectedLeaderID::Union{String,Nothing}="", ZoomFactor::Float64=0.5, Method::String="TL09", ShiftFactor::Float64=0.0)::Dict{String,Any}
    
    (isnothing(MasterFile) || isempty(MasterFile) || !isfile(MasterFile)) && return Dict("Status" => "FAIL", "Message" => "Invalid master file path provided.")
    C   = Sys_Fast.FAST_Data_DDEC
    Log = Sys_Fast.FAST_Log_DDEF

    # 1. Orchestrate Adaptive Search Space
    res = FLOW_NextPhase_DDEF(MasterFile, CurrentPhase, SelectedLeaderID, ZoomFactor, ShiftFactor)
    res["Status"] != "OK" && return res

    NewConfig   = res["NewConfig"]
    TargetPhase = res["TargetPhase"]
    Log("FLOW", "PHASE_BUILD", "Designing $TargetPhase search space from $CurrentPhase leader...", "WAIT")

    # 1.5 Stoichiometric Validation Bridge
    GlobalData = get(res, "Global", Dict())
    vol        = Float64(get(GlobalData, "Volume", 5.0))
    conc       = Float64(get(GlobalData, "Concentration", 10.0))

    # Robust key access helper (JSON3 compatibility)
    _get(o, k, d) = haskey(o, string(k)) ? o[string(k)] : (haskey(o, Symbol(k)) ? o[Symbol(k)] : d)

    # Declarative audit row generation
    audit_rows = map(NewConfig) do c
        lvls = _get(c, "Levels", [0.0, 0.0, 0.0])
        Dict(
            "Name" => string(_get(c, "Name", "Unknown")), 
            "Role" => string(_get(c, "Role", "Variable")),
            "L1"   => Float64(lvls[1]), 
            "L2"   => Float64(lvls[2]), 
            "L3"   => Float64(lvls[3]), 
            "MW"   => Float64(_get(c, "MW", 0.0))
        )
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
    N_Runs       = size(design_coded, 1)

    # 3. Level Mapping
    configs     = [Dict("Levels" => get(NewConfig[i], "Levels", [0.0, 0.0, 0.0])) for i in var_indices]
    real_matrix = Main.Lib_Core.CORE_MapLevels_DDEF(design_coded, configs)

    # 4. Canonical DataFrame Construction
    p_num = something(tryparse(Int, replace(TargetPhase, "Phase" => "")), 2)

    df = DataFrame(
        C.COL_EXP_ID    => ["EXP_P$(p_num)_$(lpad(i, 2, '0'))" for i in 1:N_Runs],
        C.COL_PHASE     => fill(TargetPhase, N_Runs),
        C.COL_STATUS    => fill("Pending", N_Runs),
        C.COL_NOTES     => fill("", N_Runs)
    )

    # Vectorized column insertion
    for (k, idx) in enumerate(var_indices)
        df[!, C.PRE_INPUT*get(NewConfig[idx], "Name", "Var$k")] = round.(real_matrix[:, k]; digits=3)
    end

    foreach(NewConfig) do c
        role, name = get(c, "Role", ""), get(c, "Name", "")
        if role == C.ROLE_FIX
            lvls = get(c, "Levels", [0.0, 0.0, 0.0])
            df[!, C.PRE_FIXED*name] = fill(length(lvls) >= 2 ? lvls[2] : 0.0, N_Runs)
        elseif role == C.ROLE_FILL
            df[!, C.PRE_FILL*name] = fill(0.0, N_Runs)
        end
    end

    # result structures
    if haskey(res, "Outputs")
        for o in res["Outputs"]
            n = string(get(o, "Name", ""))
            isempty(n) && continue
            df[!, C.PRE_RESULT*n] = Vector{Union{Missing,Float64}}(missing, N_Runs)
            df[!, C.PRE_PRED*n]   = Vector{Union{Missing,Float64}}(missing, N_Runs)
        end
    end
    df[!, C.COL_SCORE] = Vector{Union{Missing,Float64}}(missing, N_Runs)

    # 5. MasterVault Finalization
    current_config                = Sys_Fast.FAST_ReadConfig_DDEF(MasterFile)
    current_config["Ingredients"] = [Dict{String,Any}(string(k) => v for (k, v) in pairs(c)) for c in NewConfig]

    g_info                   = get(current_config, "Global", Dict{String,Any}())
    g_info["Method"]         = Method
    current_config["Global"] = g_info

    out_names = [string(get(o, "Name", "")) for o in get(res, "Outputs", []) if !isempty(get(o, "Name", ""))]
    in_names  = [get(c, "Name", "") for c in NewConfig]

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
function FLOW_CalcNextRange_DDEF(LeaderInfo::Dict, ZoomFactor::Float64=0.5, ShiftFactor::Float64=0.0)
    C       = Sys_Fast.FAST_Data_DDEC
    NewConf = deepcopy(LeaderInfo["OldConfig"])
    SelVals = LeaderInfo["Vals"]

    Sys_Fast.FAST_Log_DDEF("FLOW", "SEARCH_SPACE", "Calculating adaptive design update (Z=$(ZoomFactor), S=$(ShiftFactor))...", "WAIT")

    vars     = [(i, conf) for (i, conf) in enumerate(NewConf) if get(conf, "Role", "Variable") == C.ROLE_VAR]
    n_update = min(length(vars), length(SelVals))

    @inbounds for j in 1:n_update
        i, conf = vars[j]
        L_Old   = conf["Levels"]
        Val     = SelVals[j]
        Range   = L_Old[3] - L_Old[1]

        # Automatic shift logic for boundary leaders
        Tol      = Range * 0.05
        at_limit = abs(Val - L_Old[1]) < Tol || abs(Val - L_Old[3]) < Tol

        New_Range = at_limit ? Range : Range * ZoomFactor

        # Manual Shift applied relative to half of the NEW range
        # ShiftFactor = 1 means leader becomes Min, ShiftFactor = -1 means leader becomes Max
        ShiftVal = ShiftFactor * (New_Range * 0.5)
        New_Mid  = Val + ShiftVal

        action = at_limit ? "SHIFT (AUTO)" : (abs(ShiftFactor) > 0.05 ? "SHIFT (MANUAL)" : "ZOOM")
        Sys_Fast.FAST_Log_DDEF("FLOW", action, "Var $i -> $(action)", "LIST")

        New_Min = New_Mid - New_Range / 2
        New_Max = New_Mid + New_Range / 2

        # Boundary clamping with conservation of range
        if New_Min < 0.0
            overshoot = -New_Min
            New_Min   = 0.0
            New_Max  += overshoot
            Sys_Fast.FAST_Log_DDEF("FLOW", "CLAMP", "Var $i hit lower boundary.", "WARN")
        end

        org_max = L_Old[3] + Range * 0.5
        if New_Max > org_max && org_max > 0.0
            New_Max = org_max
            # If we hit the top, we might need to push Min down if Range must be preserved
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
    
    C          = Sys_Fast.FAST_Data_DDEC
    sheet_name = C.PREFIX_LEADERS * Phase

    isempty(LeadersDF) && return false

    try
        Sys_Fast.FAST_SafeExcelWrite_DDEF(File, Dict(sheet_name => LeadersDF))
        return true
    catch e
        Sys_Fast.FAST_Log_DDEF("FLOW", "IO_ERROR", "WriteLeaders Failed: $e", "FAIL")
        return false
    end
end

"""
    FLOW_RenderPhaseTransition_DDEF(Config, LeaderVals, Zoom, Shift) -> Plot
Visualizes the adaptation of search space boundaries between experimental phases.
"""
function FLOW_RenderPhaseTransition_DDEF(Config::AbstractVector, LeaderVals::AbstractVector, Zoom::Real, Shift::Real)
    # Premium Palette - Strict binding to Sys_Fast standard constants
    FD = Sys_Fast.FAST_Data_DDEC

    vars = [(i, c) for (i, c) in enumerate(Config) if get(c, "Role", "Variable") == FD.ROLE_VAR]
    n_vars = length(vars)
    if n_vars == 0
        return Plot([], Layout(title="No variables detected."))
    end

    # --- Fixed axis bounds ---
    AXIS_LO = -200.0
    AXIS_HI = 200.0

    traces      = GenericTrace[]
    annotations = Dict{String,Any}[]
    y_nms       = [get(c, "Name", "Var$i") for (i, c) in vars]

    for (j, (i, conf)) in enumerate(vars)
        L_Old = Float64.(get(conf, "Levels", [0.0, 0.0, 0.0]))
        Val   = (j <= length(LeaderVals)) ? Float64(LeaderVals[j]) : L_Old[2]
        L_New = FLOW_CalcAdaptiveRange_DDEF(Val, L_Old, Zoom, Shift)

        # NORMALISATION: Map [L_Old_Min, L_Old_Max] → [-100, 100]
        base_mid  = (L_Old[1] + L_Old[3]) / 2.0
        base_span = max(L_Old[3] - L_Old[1], 1e-5)
        norm(v)   = (v - base_mid) / (base_span / 2.0) * 100.0

        n_new_min = norm(L_New[1])
        n_new_max = norm(L_New[3])
        n_leader  = norm(Val)

        # 1. Current (Old Space) — always [-100, 100]
        push!(traces, scatter(; 
            x=[-100.0, 100.0], y=[j, j], mode="lines",
            name="Current", 
            line=attr(color=FD.COLOUR_DARLOW, width=18),
            showlegend=(j == 1), 
            hoverinfo="skip"
        ))

        # 2. Target Space (New Boundaries)
        push!(traces, scatter(; 
            x=[n_new_min, n_new_max], y=[j, j], mode="lines",
            name="Target", 
            line=attr(color=FD.COLOUR_HUEYEL, width=18),
            showlegend=(j == 1),
            hoverinfo="text",
            hovertext="New: $(round(L_New[1]; digits=2)) → $(round(L_New[3]; digits=2))"
        ))

        # --- Boundary Annotations ---
        y_ann = j - 0.32
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

        # 3. Leader Point
        push!(traces, scatter(; 
            x=[n_leader], y=[j], mode="markers", 
            name="Leader",
            marker=attr(
                symbol="circle", size=12, color=FD.COLOUR_SHAMAG,
                line=attr(color=FD.COLOUR_PURWHI, width=2)
            ),
            showlegend=(j == 1),
            hoverinfo="text",
            hovertext="Leader: $(round(Val; digits=2))"
        ))

        # Annotations for Old Space (Current) - Top boundaries
        push!(annotations, Dict(
            "x" => -100.0, "y" => j + 0.35, "xref" => "x", "yref" => "y",
            "text" => string(round(L_Old[1]; digits=3)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => FD.COLOUR_DARLOW),
        ))
        push!(annotations, Dict(
            "x" => 100.0, "y" => j + 0.35, "xref" => "x", "yref" => "y",
            "text" => string(round(L_Old[3]; digits=3)),
            "showarrow" => false, "xanchor" => "center",
            "font" => Dict("size" => 8, "color" => FD.COLOUR_DARLOW),
        ))
    end

    ticks_vals = collect(AXIS_LO:50:AXIS_HI)
    ticks_text = [v == -100 ? "-100 (Min)" : (v == 0 ? "0 (Mid)" : (v == 100 ? "100 (Max)" : string(Int(v)))) for v in ticks_vals]

    layout = Layout(;
        height         = min(120 + n_vars * 50, 280),
        margin         = attr(l=100, r=40, t=10, b=40),
        plot_bgcolor   = FD.COLOUR_PURWHI,
        paper_bgcolor  = "rgba(0,0,0,0)",
        xaxis = attr(
            title      = attr(text="Relative Design Space (%)", font=attr(size=10, color=FD.COLOUR_DARHIG)),
            gridcolor  = FD.COLOUR_LIGHIG, 
            zeroline   = false,
            autorange  = false, 
            range      = [AXIS_LO - 2, AXIS_HI + 2],
            tickvals   = ticks_vals, 
            ticktext   = ticks_text,
            tickfont   = attr(size=9)
        ),
        yaxis = attr(
            tickvals   = collect(1:n_vars), 
            ticktext   = y_nms, 
            showgrid   = false,
            zeroline   = false, 
            fixedrange = true, 
            tickfont   = attr(size=10, color=FD.COLOUR_DARHIG, weight="bold")
        ),
        legend      = attr(orientation="h", y=-0.4, x=0.5, xanchor="center", font=attr(size=9)),
        annotations = annotations,
        shapes      = [
            # Boundary Walls (LIME/RED) for scientific awareness
            attr(type="line", x0=AXIS_LO, x1=AXIS_LO, y0=0, y1=1, yref="paper", line=attr(color=FD.COLOUR_HUERED, width=1, dash="dot")),
            attr(type="line", x0=AXIS_HI, x1=AXIS_HI, y0=0, y1=1, yref="paper", line=attr(color=FD.COLOUR_HUERED, width=1, dash="dot"))
        ]
    )

    if isempty(traces)
        push!(traces, scatter(x=[50], y=[1], text=["Invalid Data"], mode="text"))
    end

    p = Plot(traces, layout)
    
    return Dict(
        "data"   => p.data,
        "layout" => p.layout
    )
end

end # module Sys_Flow
