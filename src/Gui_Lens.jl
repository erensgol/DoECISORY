module Gui_Lens

# ==============================================================================
# DOECISORY - GUI LENS (STATISTICAL ANALYSIS)
# ==============================================================================
# Description: Data analysis, model fitting (OLS), and high-fidelity 
#              visualisation.
# Module Tag:  LENS
# ==============================================================================

using Dash
using DashBootstrapComponents
using Dates
using ..Sys_Fast
using ..Sys_Flow
using ..Lib_Vise
using ..Lib_Arts
using ..Lib_Mole
using ..Gui_Base

const Main = parentmodule(@__MODULE__)
using DataFrames
using Printf
using PlotlyJS
using PlotlyJS: savefig, Plot, GenericTrace, Layout
using ZipFile
using Base64
using XLSX
using JSON3

export LENS_Layout_DDEF, LENS_RegisterCallbacks_DDEF

# Infrastructure: Thread-safe in-memory payload bridges for deferred batch rendering.
# Single-writer (background thread) / single-reader (callback) guarantees safety.
const LENS_BatchPayload_DDEC     = Ref{Any}(nothing)
const LENS_LastPayloadTime_DDEC  = Ref{Float64}(0.0)

const LENS_PosCells_DDEC = Set{String}([
    "***", "**", "*",
    "High efficiency", "Satisfactory efficiency", "Adequate efficiency (D ≥ 60%)",
    "Well-conditioned (κ < 100)", "Orthogonal factors (VIF = 1.0)", "Low collinearity (VIF ≤ 5.0)",
    "Adequate fit (p ≥ 0.05)", "High (Q² ≥ 0.70)", "Moderate (Q² ≥ 0.50)",
    "Interior design point"
])

const LENS_NegCells_DDEC = Set{String}([
    "Marginal efficiency", "Low efficiency (D < 60%)",
    "Severe ill-conditioning (κ ≥ 1,000)", "High collinearity (VIF > 5.0)",
    "Significant lack of fit (p < 0.05)", "Low (0 ≤ Q² < 0.50)", "Overfitted (Q² < 0)",
    "Boundary proximity"
])

# ------------------------------------------------------------------------------
# SECTION 0: SYSTEM BRIDGES & ALIASES
# ------------------------------------------------------------------------------

const LENS_GetSafe_DDEF           = Sys_Fast.FAST_GetSafe_DDEF
const LENS_ExtractDirections_DDEF = Sys_Fast.FAST_ExtractDirections_DDEF

# ==============================================================================
# PART A: UI INFRASTRUCTURE & LAYOUT
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: PHASE EVOLUTION SLOT BUILDER
# ------------------------------------------------------------------------------

"""
    LENS_BuildLeadersHTML_DDEF(ldf::DataFrame, res::AbstractDict) -> Union{HTMLTable, String}
Constructs a standardised, high-fidelity HTML table for leader run candidates.
Includes robust key guards and fallback aliases for asynchronous safety.
"""
function LENS_BuildLeadersHTML_DDEF(ldf::DataFrame, res::AbstractDict)
    (isempty(ldf) || size(ldf, 1) == 0) && return ""
    
    C = Main.Sys_Fast.FAST_Data_DDEC
    lcols = names(ldf)
    
    # Robust Column Identification
    id_col      = findfirst(c -> c == C.COL_EXP_ID || c == C.COL_ID || string(c) == "ID", lcols)
    in_cols_l   = filter(c -> startswith(string(c), C.PRE_INPUT), lcols)
    pred_cols_l = filter(c -> startswith(string(c), C.PRE_PRED),  lcols)
    score_col   = findfirst(c -> c == C.COL_SCORE || string(c) == "Score" || string(c) == "SCORE", lcols)
    
    display_cols  = String[]
    display_names = String[]
    
    # ID Column Mapping
    if !isnothing(id_col)
        push!(display_cols,  string(lcols[id_col]))
        push!(display_names, "ID")
    end
    
    # Inputs Mapping (with DisplayInNames fallback)
    in_names_list = get(res, "InNames", String[])
    disp_in_names = get(res, "DisplayInNames", in_names_list)
    for c in in_cols_l
        c_str = string(c)
        push!(display_cols, c_str)
        raw_n = replace(c_str, C.PRE_INPUT => "")
        idx = findfirst(==(raw_n), in_names_list)
        if !isnothing(idx) && idx <= length(disp_in_names)
            push!(display_names, string(disp_in_names[idx]))
        else
            push!(display_names, raw_n)
        end
    end
    
    # Outputs Mapping (with DisplayOutNames fallback)
    out_names_list = get(res, "OutNames", String[])
    disp_out_names = get(res, "DisplayOutNames", out_names_list)
    for c in pred_cols_l
        c_str = string(c)
        push!(display_cols, c_str)
        raw_n = replace(c_str, C.PRE_PRED => "")
        idx = findfirst(==(raw_n), out_names_list)
        if !isnothing(idx) && idx <= length(disp_out_names)
            push!(display_names, string(disp_out_names[idx]))
        else
            push!(display_names, raw_n)
        end
    end
    
    # Score Column Mapping
    if !isnothing(score_col)
        push!(display_cols,  string(lcols[score_col]))
        push!(display_names, "Score")
    end
    
    # HTML Rendering styling configuration
    th_style = Dict("textAlign" => "center", "borderBottom" => "2px solid var(--colour-val2-liglow)", "padding" => "4px 6px", "fontSize" => "10px", "whiteSpace" => "nowrap")
    td_style = Dict("textAlign" => "center", "padding" => "3px 6px", "fontSize" => "10px")
    
    header_row = html_tr([html_th(n, style=th_style) for n in display_names])
    body_rows  = [html_tr([
        html_td(
            let v = ldf[r, Symbol(c)]
                ismissing(v) ? "-" : (v isa Number ? Printf.@sprintf("%.3f", v) : string(v))
            end,
            className = c == C.COL_SCORE ? "colourtx-c1sm" : "",
            style=merge(td_style, c == C.COL_SCORE ? Dict("fontWeight" => "bold") : Dict())
        ) for c in display_cols
    ], style=Dict("borderBottom" => "1px solid var(--colour-val1-lighig)")) for r in 1:nrow(ldf)]
    
    return html_table([
        html_thead(header_row),
        html_tbody(body_rows),
    ], className="table table-sm table-borderless mb-0 mx-auto", style=Dict("width" => "100%", "marginTop" => "5px"))
end

function LENS_BuildSlotCard_DDEF(i::Int)
    return html_div([
        html_div([
            html_span("Slot $i", id="lens-slot-name-$i", className="small fw-bold colourtx-v5pb"),
            html_span("", id="lens-slot-leader-$i", className="x-small colourtx-v3dl ms-2"),
        ], className="d-flex align-items-center mb-1"),

        dbc_radioitems(
            id="lens-slot-mode-$i",
            options=[
                Dict("label" => " Keep", "value" => "KEEP"),
                Dict("label" => " Scale", "value" => "SCALE"),
                Dict("label" => " Replace", "value" => "REPLACE"),
            ],
            value="KEEP",
            inline=true,
            className="small mb-2",
            inputClassName="me-1",
            labelClassName="me-3 small",
        ),

        html_div(id="lens-slot-scale-div-$i", [
            dbc_input(id="lens-slot-scale-name-$i", type="text", placeholder="New Variable Name (Optional)", size="sm", className="form-control-sm mb-1"),
            dbc_row([
                dbc_col([
                    dbc_label(["Alpha ", html_span("(α)", className="ms-1"), " Multiplier"], className="x-small mb-0 colourtx-v3dl"),
                    dbc_input(id="lens-slot-alpha-$i", type="number", value=1.0, step="any", size="sm", className="form-control-sm"),
                ], width=4),
                dbc_col([
                    dbc_label(["Beta ", html_span("(β)", className="ms-1"), " Offset"], className="x-small mb-0 colourtx-v3dl"),
                    dbc_input(id="lens-slot-beta-$i", type="number", value=0.0, step="any", size="sm", className="form-control-sm"),
                ], width=4),
                dbc_col([
                    dbc_label("Transformed", className="x-small mb-0 colourtx-v3dl"),
                    html_div("-", id="lens-slot-transformed-$i", className="small fw-bold colourtx-c1sm mt-1"),
                ], width=4),
            ], className="g-1 mb-1"),
            dbc_row([
                dbc_col(dbc_input(id="lens-slot-scale-min-$i", type="number", placeholder="Min Limit", step="any", size="sm", className="form-control-sm"), width=6),
                dbc_col(dbc_input(id="lens-slot-scale-max-$i", type="number", placeholder="Max Limit", step="any", size="sm", className="form-control-sm"), width=6),
            ], className="g-1"),
        ], style=Dict("display" => "none")),

        html_div(id="lens-slot-replace-div-$i", [
            dbc_row([
                dbc_col(dbc_input(id="lens-slot-replace-name-$i", type="text", placeholder="New Variable Name", size="sm", className="form-control-sm mb-1"), width=6),
                dbc_col(dbc_input(id="lens-slot-replace-unit-$i", type="text", placeholder="New Unit", size="sm", className="form-control-sm mb-1"), width=6),
            ], className="g-1"),
            dbc_row([
                dbc_col(dbc_input(id="lens-slot-replace-l1-$i", type="number", placeholder="Lower", step="any", size="sm", className="form-control-sm mb-1"), width=4),
                dbc_col(dbc_input(id="lens-slot-replace-l2-$i", type="number", placeholder="Centre", step="any", size="sm", className="form-control-sm mb-1"), width=4),
                dbc_col(dbc_input(id="lens-slot-replace-l3-$i", type="number", placeholder="Upper", step="any", size="sm", className="form-control-sm mb-1"), width=4),
            ], className="g-1"),
            dbc_row([
                dbc_col(dbc_input(id="lens-slot-replace-min-$i", type="number", placeholder="Min Limit", step="any", size="sm", className="form-control-sm"), width=6),
                dbc_col(dbc_input(id="lens-slot-replace-max-$i", type="number", placeholder="Max Limit", step="any", size="sm", className="form-control-sm"), width=6),
            ], className="g-1"),
        ], style=Dict("display" => "none")),
    ], className="border rounded p-2 mb-2", style=Dict("backgroundColor" => "var(--colour-val1-lighig)"), id="lens-slot-card-$i")
end

"""
    LENS_ApplySlotCustomisation_DDEF!(conf::AbstractVector, slots::AbstractVector, leader_vals::AbstractVector)
Applies scale or replacement transformations and boundary overrides to factor configurations.
Deduplicates transition configuration across wizard preview and evolution execution.
"""
function LENS_ApplySlotCustomisation_DDEF!(conf::AbstractVector, slots::AbstractVector, leader_vals::AbstractVector)
    fd = Main.Sys_Fast.FAST_Data_DDEC
    vi = 0
    for c in conf
        get(c, "Role", "") != fd.ROLE_VAR && continue
        vi += 1
        vi > length(slots) && continue
        sl = slots[vi]
        mode = get(sl, "Mode", "KEEP")

        if mode in ("SCALE", "REPLACE")
            !isempty(get(sl, "NewName", "")) && (c["Name"] = string(sl["NewName"]))
            !isempty(get(sl, "NewUnit", "")) && (c["Unit"] = string(sl["NewUnit"]))
        end

        if mode == "SCALE" && vi <= length(leader_vals)
            α  = Float64(get(sl, "Alpha", 1.0))
            β  = Float64(get(sl, "Beta",  0.0))
            tv = Main.Sys_Flow.FLOW_BridgeTransform_DDEF(Float64(leader_vals[vi]), α, β)
            lvls = get(c, "Levels", [0.0, 0.0, 0.0])
            hr = abs(Float64(lvls[3]) - Float64(lvls[1])) * 0.5 * abs(α)
            c["Levels"] = [round(tv - hr; digits=4), round(tv; digits=4), round(tv + hr; digits=4)]
        elseif mode == "REPLACE"
            c["Levels"] = [Float64(get(sl, "NewL1", 0.0)), Float64(get(sl, "NewL2", 0.0)), Float64(get(sl, "NewL3", 0.0))]
        end

        haskey(sl, "NewMin") && (c["Min"] = Float64(sl["NewMin"]))
        haskey(sl, "NewMax") && (c["Max"] = Float64(sl["NewMax"]))
    end
end

# ------------------------------------------------------------------------------
# SECTION 1B: DIAGNOSTIC STYLING & FORMATTING DISPATCHERS
# ------------------------------------------------------------------------------

"""
    _LENS_SafeFloat(v) -> Union{Float64, Nothing}
Internal helper ensuring zero runtime MethodErrors when validating metric values.
Safely handles `nothing`, `missing`, non-numeric types, and `NaN`.
"""
function _LENS_SafeFloat(v)::Union{Float64, Nothing}
    (isnothing(v) || ismissing(v) || !(v isa Number) || isnan(v)) && return nothing
    return Float64(v)
end

"""
    LENS_EvalClass_DDEF(::Val{Symbol}, args...) -> String
Centralised, idiomatic dispatch system for metric classification styling.
Eliminates repetitive branching within UI table construction.
"""
LENS_EvalClass_DDEF(::Val{:d_eff}, v) = let f = _LENS_SafeFloat(v)
    (isnothing(f) || f <= 0.0) ? "fw-bold colourtx-v5pb" : (f >= 0.35 ? "fw-bold colourtx-c4tg" : "fw-bold colourtx-c0hr")
end

LENS_EvalClass_DDEF(::Val{:vif}, v) = let f = _LENS_SafeFloat(v)
    isnothing(f) ? "fw-bold colourtx-v5pb" : (f <= 5.0 ? "fw-bold colourtx-c4tg" : (f <= 10.0 ? "fw-bold colourtx-c5hy" : "fw-bold colourtx-c0hr"))
end

LENS_EvalClass_DDEF(::Val{:lof}, v) = let f = _LENS_SafeFloat(v)
    isnothing(f) ? "fw-bold colourtx-v5pb" : (f >= 0.05 ? "fw-bold colourtx-c4tg" : "fw-bold colourtx-c0hr")
end

LENS_EvalClass_DDEF(::Val{:q2}, v) = let f = _LENS_SafeFloat(v)
    isnothing(f) ? "" : (f < 0.0 ? "fw-bold colourtx-c0hr" : (f >= 0.50 ? "fw-bold colourtx-c4tg" : ""))
end

LENS_EvalClass_DDEF(::Val{:pval}, v) = let f = _LENS_SafeFloat(v)
    isnothing(f) ? "" : (f < 0.05 ? "fw-bold colourtx-c4tg" : "fw-bold colourtx-c0hr")
end

LENS_EvalClass_DDEF(::Val{:coef_pval}, pv) = let f = _LENS_SafeFloat(pv)
    (!isnothing(f) && f < 0.05) ? "fw-bold colourtx-c4tg" : ""
end

LENS_EvalClass_DDEF(::Val{:coef_vif}, j, vf) = let f = _LENS_SafeFloat(vf)
    (j > 1 && !isnothing(f) && f > 5.0) ? "fw-bold colourtx-c0hr" : ""
end

LENS_EvalClass_DDEF(::Val{:sensitivity}, s) = let f = _LENS_SafeFloat(s)
    (!isnothing(f) && f > 0.5) ? "fw-bold colourtx-v5pb" : "colourtx-v5pb"
end

function LENS_EvalClass_DDEF(::Val{:anova}, src::AbstractString, p)
    f = _LENS_SafeFloat(p)
    isnothing(f) && return ""
    src == "Model" && return f < 0.05 ? "fw-bold colourtx-c4tg" : "fw-bold colourtx-c0hr"
    src == "Lack of Fit" && return f < 0.05 ? "fw-bold colourtx-c0hr" : "fw-bold colourtx-c4tg"
    return f < 0.05 ? "fw-bold" : ""
end

LENS_EvalClass_DDEF(sym::Symbol, args...) = LENS_EvalClass_DDEF(Val(sym), args...)

"""
    LENS_FormatMetric_DDEF(::Val{Symbol}, v) -> String
Compact scientific number formatting dispatcher for table cells.
"""
LENS_FormatMetric_DDEF(::Val{:d_eff}, v) = let f = _LENS_SafeFloat(v)
    (!isnothing(f) && f > 0.0) ? @sprintf("%.3f", f) : "-"
end

LENS_FormatMetric_DDEF(::Val{:eff}, v) = let f = _LENS_SafeFloat(v)
    (!isnothing(f) && f > 0.0) ? @sprintf("%.2f", f) : "-"
end

LENS_FormatMetric_DDEF(::Val{:vif}, v) = let f = _LENS_SafeFloat(v)
    !isnothing(f) ? @sprintf("%.2f", f) : "-"
end

LENS_FormatMetric_DDEF(::Val{:lof}, v) = let f = _LENS_SafeFloat(v)
    !isnothing(f) ? @sprintf("%.3f", f) : "N/A"
end

LENS_FormatMetric_DDEF(sym::Symbol, v) = LENS_FormatMetric_DDEF(Val(sym), v)

# ------------------------------------------------------------------------------
# SECTION 2: INTERFACE LAYOUT
# ------------------------------------------------------------------------------

"""
    LENS_Layout_DDEF() -> Container
Constructs the primary statistical analysis and visualisation interface layout.
"""
function LENS_Layout_DDEF()
    return dbc_container([
        BASE_PageHeader_DDEF("Statistical Modelling and Data Optimisation", "Fit response surface models, visualise 2D and 3D interactions, and determine optimal formulation conditions."),

        dbc_row([
            # Initialisation of the Left Interface Column for analysis configuration.
            dbc_col([
                dbc_row(dbc_col(BASE_GlassPanel_DDEF([html_i(className="fas fa-cogs me-2"), "ANALYSIS CONFIGURATION"], [
                    BASE_SidebarHeader_DDEF("DATA ACQUISITION", icon="fas fa-database"),
                    BASE_Upload_DDEF("lens-upload-data", "Import Dataset (Xlsx)", "fas fa-file-import", class="w-100 mb-2 fw-bold pulse-green"),
                    BASE_Loading_DDEF("lens-upload-status", "No Data Source"; class="glass-loading-status mb-2"),
                    BASE_Separator_DDEF(),

                    BASE_SidebarHeader_DDEF("EXPORT", icon="fas fa-file-export"),
                    BASE_ActionButton_DDEF("lens-btn-export-plots",    "Plots",    "fas fa-camera-retro"),
                    BASE_ActionButton_DDEF("lens-btn-download-report", "Report",   "fas fa-file-export"),
                    BASE_ActionButton_DDEF("lens-btn-export-excel",    "(XLSX)",   "fas fa-file-excel",   class="w-100 fw-bold mb-3"),
                    BASE_Separator_DDEF(),

                    BASE_ControlGroup_DDEF("Project Name",
                        dbc_input(id="lens-input-project", type="text", value="",
                            placeholder="Enter project name...", className="mb-2 form-control-sm")),
                    BASE_ControlGroup_DDEF("Phase",
                        dcc_dropdown(id="lens-dd-phase",
                            options=[Dict("label" => "Phase 1", "value" => "Phase1")],
                            clearable=false, className="mb-3")),
                    BASE_ControlGroup_DDEF("Model",
                        dcc_dropdown(id="lens-dd-model", options=[
                            Dict("label" => "Automatic", "value" => "Auto"),
                            Dict("label" => "Linear",    "value" => "Linear"),
                            Dict("label" => "Quadratic", "value" => "Quadratic"),
                        ], value="Auto", clearable=false, className="mb-3")),
                    BASE_Separator_DDEF(),

                    html_div(id="lens-panel-radio", className="d-none", children=[
                        BASE_SidebarHeader_DDEF("RADIOACTIVITY", icon="fas fa-radiation-alt"),
                        dbc_row(dbc_col([
                            dbc_button([html_i(id="lens-icon-radio-correct", className="fas fa-radiation-alt me-2"), "Radioactive Correction"],
                                id="lens-btn-radio-correct", className="w-100 fw-bold lens-radio-inactive", outline=false, size="sm")
                        ], xs=12)),
                        BASE_Separator_DDEF(),
                    ]),
                    BASE_ActionButton_DDEF("lens-btn-view-report",    "Summary",    "fas fa-file-alt", disabled=true),
                    BASE_ActionButton_DDEF("lens-btn-next-phase",    "Next Phase", "fas fa-forward"),
                    html_div(id="lens-phase-guard-msg", className="small text-center mb-1"),
                    BASE_NextButton_DDEF("lens-btn-run",            "Run Analysis", disabled=true),

                    dcc_download(id="lens-download-phase"),
                    dcc_download(id="lens-download-analysis"),
                    dcc_download(id="lens-download-plots"),
                    dcc_download(id="lens-download-report-file"),

                    BASE_Loading_DDEF("lens-run-output",           ""),
                    BASE_Loading_DDEF("lens-export-plots-status", ""),
                    BASE_Loading_DDEF("lens-export-excel-status", ""),
                ]; panel_class="mb-3 h-auto", content_class="p-2"), xs=12)),
            ]; xs=12, md=3, className="mb-3 mb-md-0"),

            # Initialisation of the Right Interface Column for results display and visualisation.
            dbc_col([
                BASE_GlassPanel_DDEF(["OPTIMISATION OBJECTIVES", html_span("", className="ms-2 fw-normal colourtx-v3dl")], [
                    dbc_row(dbc_col([
                        html_div(html_table([
                            html_thead(html_tr([
                                BASE_TableHeader_DDEF("RESPONSE",  width="16%"),
                                BASE_TableHeader_DDEF("LOWER",     width="15%"),
                                BASE_TableHeader_DDEF("TARGET",    width="15%"),
                                BASE_TableHeader_DDEF("UPPER",     width="15%"),
                                BASE_TableHeader_DDEF("OBJECTIVE", width="20%"),
                                BASE_TableHeader_DDEF("VALUE",     width="19%"), 
                            ])),
                            html_tbody([BASE_BuildGoalRow_DDEF(i) for i in 1:3])
                        ], className="colourtx-v5pb", style=Dict("width" => "100%", "borderCollapse" => "collapse", "fontSize" => "10px", "tableLayout" => "fixed")), className="table-responsive m-0")
                    ], xs=12)),
                ]; panel_class="mb-3", content_class="glass-content p-2"),
                # Orchestration of the Model Performance Display Panel.
                BASE_GlassPanel_DDEF(["MODEL PERFORMANCE", html_span(id="lens-radio-badge", className="ms-2")], [
                    dbc_row(dbc_col(html_div(id="lens-results-text", className="small px-2 table-responsive"), xs=12)),
                ]; panel_class="mb-3", content_class="glass-content p-2"),
                # Orchestration of the Leader Candidates Selection Panel.
                BASE_GlassPanel_DDEF(["LEADER CANDIDATES", html_span("", className="ms-2 fw-normal colourtx-v3dl")], [
                    dbc_row(dbc_col(html_div(id="lens-leaders-text", className="small px-2 table-responsive"), xs=12)),
                ]; panel_class="mb-3", content_class="glass-content p-2"),
                # Orchestration of the Graph Descriptive Index Panel.
                BASE_GlassPanel_DDEF("GRAPH INDEX", [
                    html_div(id="lens-graph-info", className="p-1"),
                ]; panel_class="mb-3", content_class="glass-content p-2"),
                # Orchestration of the Primary Chart Viewer and Plotting Engine.
                BASE_GlassPanel_DDEF("PLOTS", [
                    html_div(id="lens-graph-title", className="text-center small mb-1 fw-bold colourtx-v4dh"),
                    BASE_Loading_DDEF("lens-graph-loading",
                        dcc_graph(
                            id     = "lens-graph-main",
                            style  = Dict("width" => "100%", "maxWidth" => "320px", "height" => "400px", "margin" => "0 auto"),
                            config = Dict("displayModeBar" => "hover", "displaylogo" => false, "responsive" => true),
                            figure = BASE_EmptyFigure_DDEC,
                        )),
                ]; panel_class="mb-2", content_class="glass-content p-2"),

                dbc_row(dbc_col(html_div([
                    dbc_button(html_i(className="fas fa-chevron-left"),
                        id="lens-btn-prev", outline=false, size="sm", className="me-1 px-2 py-1 btn-white-bg"),
                    dcc_input(id="lens-graph-input", type="number", min=1, step=1, value=1, debounce=true, className="form-control form-control-sm mx-1 text-center colourtx-v5pb", style=Dict("backgroundColor" => "transparent", "borderColor" => "var(--colour-val3-darlow)", "width" => "60px", "height" => "28px", "fontSize" => "12px")),
                    html_span(id="lens-graph-counter", className="small mx-1 colourtx-v4dh"),
                    dbc_button(html_i(className="fas fa-chevron-right"),
                        id="lens-btn-next", outline=false, size="sm", className="ms-1 px-2 py-1 btn-white-bg"),
                ], className="d-flex align-items-center justify-content-center py-2"), xs=12)),

                dcc_store(id="lens-store-graph-meta",    data=Dict("count" => 0, "ts" => 0)),
                dcc_store(id="lens-store-index",         data=0),
                dcc_store(id="lens-store-report",        data=""),
                dcc_store(id="lens-store-results",       data=Dict()),
                dcc_store(id="lens-store-radio-correct", data=true),
                # Synchronisation flag for multi-platform session orchestration.
                dcc_store(id="lens-store-sync-flag",     data=Dict("status" => 0, "dataid" => "")), 
                dcc_store(id="lens-signal-process",      data=Dict("ts" => 0, "success" => false)),
                dcc_store(id="lens-store-diag-force",    data=0),
                dcc_store(id="lens-store-slot-config",   data=Dict()),
                dcc_store(id="lens-store-excluded-constants", data=String[]),
                dcc_store(id="lens-store-graphs-blob",   data=""),
                dcc_store(id="lens-store-batch-status",  data=Dict("next_pkg" => 0, "handle" => "", "expected" => 0)),
                dcc_interval(id="lens-interval-batch", interval=2000, n_intervals=0, disabled=true),
            ]; xs=12, md=9),
        ], className="g-3"),

# ------------------------------------------------------------------------------
# SECTION 3: SYSTEM MODALS & DIALOGUES
# ------------------------------------------------------------------------------

        # Interface orchestration for system modal dialogues and user interactions.
        BASE_Modal_DDEF("lens-modal-report", "DoECISORY Scientific Analysis Report",
            html_div(id="lens-report-content", children="", className="p-4 rounded academic-dossier", style=Dict("maxHeight" => "650px", "overflowY" => "auto")),
            dbc_button(["Download Report (TXT)"], id="lens-btn-download-txt", className="w-100 colourgl-c4tg"); size="xl"),
        BASE_Modal_DDEF("lens-modal-wizard", [html_i(className="fas fa-layer-group me-2 colourtx-c1sm"), "Phase Evolution - Step 1/3"],
            [
                html_div([
                    html_p("Define the experimental horizon for the next phase sequence.", className="small mb-4 colourtx-v3dl"),
                    dbc_row([
                        dbc_col([
                            dbc_label("Source Phase", className="x-small fw-bold text-uppercase mb-2 colourtx-v3dl"),
                            dcc_dropdown(id="lens-wiz-dd-source", options=[], clearable=false, className="mb-3"),
                        ], xs=12, md=6),
                        dbc_col([
                            dbc_label("Target Designation", className="x-small fw-bold text-uppercase mb-2 colourtx-v3dl"),
                            dbc_input(id="lens-wiz-input-target", disabled=true, className="mb-3 fw-bold colourbg-v0pw colourtx-c1sm"),
                        ], xs=12, md=6),
                    ]),
                ], className="p-2")
            ],
            html_div([
                dbc_button("Cancel", id="lens-wiz-btn-cancel", outline=false, className="me-2 colourgl-c0hr"),
                dbc_button(["Next: Select Leader ", html_i(className="fas fa-chevron-right ms-2")], id="lens-wiz-btn-next", className="colourgl-c4tg"),
            ], className="d-flex justify-content-end"); size="lg", close_button=false, backdrop="static", keyboard=false),

        BASE_Modal_DDEF("lens-modal-leader", [html_i(className="fas fa-magic me-2 colourtx-c1sm"), "Phase Evolution - Step 2/3"],
            dbc_row(dbc_col([
                dbc_alert([
                    html_i(className="fas fa-info-circle me-2"),
                    "Select the most promising leader run to serve as the reference centre for the next phase."
                ], className="small py-2 mb-3 border-0 shadow-sm colourgl-c1sm colourtx-v0pw"),
                html_div(BASE_DataTable_DDEF("lens-table-candidates", [
                    Dict("name" => "ID",    "id" => "ID"),
                    Dict("name" => "Score", "id" => "Score")
                ], []; row_selectable="single", selected_rows=[]), id="lens-container-candidates", className="table-responsive"),
            ], xs=12)),
            dbc_row([
                dbc_col(dbc_button([html_i(className="fas fa-chevron-left me-2"), "Back"], id="lens-lead-btn-back", outline=false, size="sm", className="w-100 colourgl-neut"), xs=12, md=3),
                dbc_col(dbc_button([html_i(className="fas fa-times me-2"),        "Cancel"], id="lens-lead-btn-cancel", outline=false, size="sm", className="w-100 colourgl-c0hr"), xs=12, md=3),
                dbc_col(dbc_button(["Next: Adjust Design ", html_i(className="fas fa-chevron-right ms-2")], id="lens-lead-btn-confirm", className="w-100 colourgl-c1sm pulse-purple", disabled=true, size="sm"), xs=12, md=6),
            ], className="w-100 g-2"); size="xl", close_button=false, backdrop="static", keyboard=false),

        BASE_Modal_DDEF("lens-modal-preview", [html_i(className="fas fa-microscope me-2 colourtx-c4tg"), "Phase Evolution - Step 3/3"],
            [
                dbc_alert([
                    html_i(className="fas fa-lightbulb me-2 colourtx-c1sm"),
                    html_span("Design Protocol Guidance: ", className="fw-bold colourtx-v5pb"),
                    "This wizard configures the active experimental search space. For comprehensive structural modifications (such as introducing new fixed constants, re-specifying stoichiometry, or adjusting global physical constants), you may load the exported Vault Excel file directly into the ",
                    html_strong("Design"),
                    " page to use it as a custom project template."
                ], className="small py-2 mb-3 border-0 shadow-sm colourbg-v1lw colourtx-v5pb", style=Dict("borderLeft" => "4px solid #21918C")),
                dbc_row([
                    dbc_col([
                        html_div([
                            dbc_label("Design Control", className="x-small fw-bold text-uppercase mb-2 d-block colourtx-v3dl"),
                            dbc_label("Matrix Protocol", className="small mb-1"),
                            dcc_dropdown(id="lens-prev-dd-method", options=[
                                Dict("label" => "Taguchi (L9, Linear)",                     "value" => "TL09"),
                                Dict("label" => "Box-Behnken (BBD15, Quadratic)",           "value" => "BB15"),
                                Dict("label" => "Central Composite (CCD17, Quadratic)",     "value" => "CD17"),
                                Dict("label" => "D-Optimal (D-FFCCD14, Quadratic)",         "value" => "DF14"),
                            ], value="TL09", clearable=false, className="mb-2 dd-method-compact"),
                            html_div(id="lens-prev-direction-container", style=Dict("display" => "none"), children=[
                                dbc_label("Target Factor Directions (DF14)", className="x-small fw-bold text-uppercase mb-2 d-block colourtx-v3dl"),
                                html_div([
                                    dbc_row([
                                        dbc_col([
                                            dbc_label("X₁ Direction", id="lens-prev-dir-lbl-1", className="x-small mb-1 d-block fw-semibold"),
                                            dcc_dropdown(
                                                id="lens-prev-dir-x1",
                                                options=[
                                                    Dict("label" => "−1 (Lower)", "value" => -1),
                                                    Dict("label" => "+1 (Upper)", "value" => 1),
                                                ],
                                                value=-1,
                                                clearable=false,
                                                className="small",
                                            ),
                                        ], xs=12, md=4, className="mb-2"),
                                        dbc_col([
                                            dbc_label("X₂ Direction", id="lens-prev-dir-lbl-2", className="x-small mb-1 d-block fw-semibold"),
                                            dcc_dropdown(
                                                id="lens-prev-dir-x2",
                                                options=[
                                                    Dict("label" => "−1 (Lower)", "value" => -1),
                                                    Dict("label" => "+1 (Upper)", "value" => 1),
                                                ],
                                                value=-1,
                                                clearable=false,
                                                className="small",
                                            ),
                                        ], xs=12, md=4, className="mb-2"),
                                        dbc_col([
                                            dbc_label("X₃ Direction", id="lens-prev-dir-lbl-3", className="x-small mb-1 d-block fw-semibold"),
                                            dcc_dropdown(
                                                id="lens-prev-dir-x3",
                                                options=[
                                                    Dict("label" => "−1 (Lower)", "value" => -1),
                                                    Dict("label" => "+1 (Upper)", "value" => 1),
                                                ],
                                                value=-1,
                                                clearable=false,
                                                className="small",
                                            ),
                                        ], xs=12, md=4, className="mb-2"),
                                    ], className="g-2"),
                                    dbc_formtext("DF14 allocates one face-centered star run per factor. Select whether each factor focuses on its Lower (−1) or Upper (+1) boundary.", className="x-small colourtx-v3dl mt-1"),
                                ], className="p-2 border rounded colourbg-v0pw mb-2", style=Dict("borderColor" => "var(--colour-val1-lighig)"))
                            ]),
                            html_hr(className="my-3"),
                            dbc_label("Global Zoom", className="small mb-1 d-flex justify-content-between", children=[
                                html_span("Wide (1.0)", className="colourtx-v5pb"),
                                html_span("Fine (0.1)", className="colourtx-v5pb")
                            ]),
                            html_div(dcc_slider(id="lens-prev-slider-zoom",
                                min=1, max=5, step=nothing, value=3,
                                updatemode="drag",
                                marks=Dict(
                                    1 => Dict("label" => "1.0",  "style" => Dict("fontWeight" => "bold", "fontSize" => "10px"), "className" => "colourtx-v5pb"),
                                    2 => Dict("label" => "0.75", "style" => Dict("fontSize" => "10px")),
                                    3 => Dict("label" => "0.5",  "style" => Dict("fontSize" => "10px")),
                                    4 => Dict("label" => "0.25", "style" => Dict("fontSize" => "10px")),
                                    5 => Dict("label" => "0.1",  "style" => Dict("fontSize" => "10px"))
                                )),
                                className="px-2 mb-2"),
                            html_div(id="lens-prev-slider-shift", style=Dict("display" => "none")),
                        ], className="p-3 border-0 rounded shadow-sm colourbg-v0pw mb-3"),

                        html_div([
                            dbc_label("Variable Configuration", className="x-small fw-bold text-uppercase mb-2 d-block colourtx-v3dl"),
                            LENS_BuildSlotCard_DDEF(1),
                            LENS_BuildSlotCard_DDEF(2),
                            LENS_BuildSlotCard_DDEF(3),
                        ], className="p-3 border-0 rounded shadow-sm colourbg-v0pw"),
                    ], xs=12, md=5),

                    dbc_col([
                        html_div([
                            html_h6("Transition Visualisation", className="x-small fw-bold text-uppercase mb-2 colourtx-v3dl"),
                            dcc_graph(id="lens-graph-transition", config=Dict("displayModeBar" => false), style=Dict("height" => "250px"))
                        ], className="border-0 rounded p-3 mb-3 shadow-sm colourbg-v0pw"),
                        dbc_card([
                            dbc_cardheader([
                                html_div([
                                    html_div([html_i(className="fas fa-th-list me-2"), "Calculated Boundaries"], className="small fw-bold"),
                                    html_span("Phase Target Bounds", className="x-small text-muted")
                                ], className="d-flex align-items-center justify-content-between w-100")
                            ], className="small fw-bold border-0 py-2", style=Dict("backgroundColor" => "transparent")),
                            html_div(id="lens-container-preview-table", className="table-responsive p-2", style=Dict("maxHeight" => "240px", "overflowY" => "auto")),
                        ], className="shadow-sm border-0"),
                    ], xs=12, md=7)
                ]),
                html_div(id="lens-container-preview-audit", className="mt-3")
            ],
            dbc_row([
                dbc_col(dbc_button([html_i(className="fas fa-chevron-left me-2"), "Back"], id="lens-prev-btn-back", outline=false, size="sm", className="w-100 colourgl-neut"), xs=12, md=3),
                dbc_col(dbc_button([html_i(className="fas fa-times me-2"),        "Cancel"], id="lens-prev-btn-cancel", outline=false, size="sm", className="w-100 colourgl-c0hr"), xs=12, md=3),
                dbc_col(dbc_button([html_i(className="fas fa-check-circle me-2"), "Commit to Project Vault"], id="lens-prev-btn-commit", className="w-100 colourgl-c4tg", size="sm"), xs=12, md=6),
            ], className="w-100 g-2"); size="xl", close_button=false, backdrop="static", keyboard=false),

        BASE_Modal_DDEF("lens-modal-radio-config", [html_i(className="fas fa-radiation-alt me-2 colourtx-c1sm"), "Radioactivity Decay Correction"],
            [
                dbc_alert([
                    html_strong("NOTICE: "),
                    "Radioactive correction supports both absolute activity measurements (units such as mCi, MBq, Ci, GBq, CPM, CPS) and relative yield metrics. Mapping an output to a specific input triggers a yield calculation, which determines the decay-compensated ratio between the final and initial states. In these cases, percentage-based units are standard and ensure mathematical consistency within the analytical model."
                ], color="danger", className="small py-2 mb-3 fw-bold"),
                dbc_row([
                    dbc_col([
                        html_h6("1. Forward Decay (Inputs)", className="small fw-bold colourtx-v4dh border-bottom pb-1"),
                        html_p("Target radioactive inputs for correction:", className="x-small colourtx-v3dl mb-2"),
                        dcc_dropdown(id="lens-radio-dd-inputs", options=[], multi=true, placeholder="Select...", className="small mb-3"),
                        
                        html_div(children=[
                            html_div(id="lens-radio-in-div-$i", className="mb-2 d-none", children=[
                                html_span(id="lens-radio-in-lbl-$i", className="small fw-bold d-block colourtx-v5pb"),
                                dbc_row([
                                    dbc_col(dbc_input(id="lens-radio-in-name-$i", placeholder="Corrected Display Alias", type="text", size="sm", className="form-control-sm"), width=8),
                                    dbc_col(dbc_input(id="lens-radio-in-unit-$i", placeholder="Measurement Unit", type="text", size="sm", className="form-control-sm"), width=4)
                                ], className="g-1")
                            ]) for i in 1:6
                        ])
                    ], md=6),
                    dbc_col([
                        html_h6("2. Reverse Decay & Yield (Outputs)", className="small fw-bold colourtx-v4dh border-bottom pb-1"),
                        html_p("Map response variables to source inputs for yield calculation:", className="x-small colourtx-v3dl mb-2"),
                        
                        html_div(children=[
                            html_div(id="lens-radio-out-div-$i", className="mb-3 d-none", children=[
                                html_span(id="lens-radio-out-lbl-$i", className="small fw-bold d-block colourtx-v5pb"),
                                dcc_dropdown(id="lens-radio-out-dd-$i", options=[Dict("label" => "None", "value" => "None")], value="None", clearable=false, className="small mb-1"),
                                dbc_row([
                                    dbc_col(dbc_input(id="lens-radio-out-name-$i", placeholder="Corrected Result Display Alias", type="text", size="sm", className="form-control-sm"), width=8),
                                    dbc_col(dbc_input(id="lens-radio-out-unit-$i", placeholder="Measurement Unit", type="text", size="sm", className="form-control-sm"), width=4)
                                ], id="lens-radio-out-alias-div-$i", className="g-1 d-none")
                            ]) for i in 1:6
                        ])
                    ], md=6)
                ])
            ],
            html_div([
                dbc_button("Cancel", id="lens-radio-btn-cancel", outline=false, className="me-2 colourgl-c0hr", size="sm"),
                dbc_button(["Apply and Save ", html_i(className="fas fa-check ms-2")], id="lens-radio-btn-apply", className="colourgl-c4tg", size="sm"),
            ], className="d-flex justify-content-end"); size="lg", close_button=false, backdrop="static", keyboard=false),

        dcc_store(id="lens-store-next-phase-proposal", data=Dict()),
    ], fluid=true, className="px-4 py-3")
end

# ==============================================================================
# PART B: CALLBACKS & ANALYSIS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 4: CALLBACK REGISTRY GATEWAY
# ------------------------------------------------------------------------------

"""
    LENS_RegisterCallbacks_DDEF(app) -> Nothing
Initialises the reactive architecture and callback registry for the LENS module.
"""
function LENS_RegisterCallbacks_DDEF(app)
    C = Sys_Fast.FAST_Data_DDEC

# ------------------------------------------------------------------------------
# SECTION 5: UPLOAD & SYNC PIPELINES
# ------------------------------------------------------------------------------

    # Visibility Orchestration of Phase Transition DF14 Direction Selection Panel
    callback!(app,
        Output("lens-prev-direction-container", "style"),
        Input("lens-prev-dd-method", "value"),
        prevent_initial_call=false
    ) do method
        if method == "DF14"
            return Dict("display" => "block")
        else
            return Dict("display" => "none")
        end
    end

    # Pipeline Orchestration Stage 1B: Global session synchronisation and objective initialisation.
    callback!(app,
        Output("lens-dd-phase",       "options"),
        Output("lens-upload-status",  "children"),
        Output("lens-upload-data-btn", "className"),
        Output("lens-dd-phase",       "value"),
        [Output("lens-goal-name-$i",   "value") for i in 1:3]...,
        [Output("lens-goal-min-$i",    "value") for i in 1:3]...,
        [Output("lens-goal-target-$i", "value") for i in 1:3]...,
        [Output("lens-goal-max-$i",    "value") for i in 1:3]...,
        [Output("lens-goal-type-$i",   "value") for i in 1:3]...,
        [Output("lens-goal-weight-$i", "value") for i in 1:3]...,
        Output("lens-dd-model",       "options"),
        Output("lens-dd-model",       "value"),
        Output("lens-store-sync-flag", "data"),
        Output("lens-panel-radio", "className"),
        Output("lens-input-project",  "value"),
        Input("store-master-vault",   "data"),
        State("lens-input-project",   "value"),
        State("lens-store-batch-status", "data"),
        prevent_initial_call=true
    ) do active_data, current_proj, batch_status
        # Unified Initialisation of Session Metadata
        is_loading = get(batch_status, "next_pkg", get(batch_status, :next_pkg, 0)) > 0
        proj_v = isnothing(current_proj) || isempty(strip(string(current_proj))) || lowercase(strip(string(current_proj))) == "doecisory" ? "" : string(current_proj)
        
        path = ""
        try
            active_cont = Sys_Fast.FAST_ExtractDataID_DDEF(active_data)

            # Sync-Lock Guard: Prevent vault sync from overriding the UI during background rendering phases.
            # However, we MUST allow the sync-flag to update to the current DataID even if loading.
            if is_loading
                # Selective Update: We return no_updates for everything EXCEPT the sync-flag and project name.
                out = ntuple(_ -> Dash.no_update(), 27)
                mutable_out = collect(Any, out)
                
                # Fetch minimal metadata for the flag
                if !isempty(active_cont) && active_cont != "none"
                    mutable_out[25] = Dict("status" => 1, "dataid" => active_cont)
                    mutable_out[27] = proj_v
                end
                return Tuple(mutable_out)
            end
            
            # If nothing in vault, return no updates
            (isempty(active_cont) || active_cont == "none") && return ntuple(_ -> Dash.no_update(), 27)

            path = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)
            !isfile(path) && return ntuple(_ -> Dash.no_update(), 27)

            df = Main.Sys_Fast.FAST_ReadExcel_DDEF(path, Main.Sys_Fast.FAST_Data_DDEC.SHEET_CONFIG)
            config = Main.Sys_Fast.FAST_ReadConfig_DDEF(path)

            col_phase = Symbol(Main.Sys_Fast.FAST_Data_DDEC.COL_PHASE)
            phases = []
            if hasproperty(df, col_phase)
                phases = unique(filter(!ismissing, df[!, col_phase]))
            end
   
            active_fname = ""
            if active_data isa String
                active_cont = active_data
            elseif active_data isa AbstractDict || active_data isa Dict
                active_cont = get(active_data, "content", active_data)
                active_fname = get(active_data, "filename", "")
                # Sync Guard: If this is a science pulse from an active analysis, skip redundant I/O read.
                if get(active_data, "type", "") == "SCIENCE_PULSE"
                    return ntuple(_ -> Dash.no_update(), 27)
                end
            end

            afname = (active_data isa AbstractDict && haskey(active_data, "filename")) ? string(active_data["filename"]) : ""
            extracted_proj = Main.Sys_Fast.FAST_ExtractProjectFromFilename_DDEF(afname)
            (extracted_proj != "") && (proj_v = extracted_proj)
            (proj_v == "") && (proj_v = "DoECISORY")

            if isnothing(active_cont) || active_cont == ""
                return tuple([], "No Data Source", "w-100 mb-2 fw-bold pulse-green", nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., [], nothing, Dict("status" => 0, "dataid" => ""), "d-none", proj_v)
            end

            Sys_Fast.FAST_Log_DDEF("LENS", "Sync", "Synchronising from Smart Vault (Handle: $(first(active_cont, 64))...)...", "INFO")
            path = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)
            if !isfile(path)
                 return tuple([], html_span([html_i(className="fas fa-times-circle me-2"), "Data handle expired or missing. Please re-upload."], className="small colourtx-c0hr"), "w-100 mb-2 fw-bold pulse-green", nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., [], nothing, Dict("status" => 2, "dataid" => ""), "d-none", proj_v)
            end

            ext = lowercase(splitext(path)[2])
            if ext != ".xlsx"
                Sys_Fast.FAST_CleanTransient_DDEF(path)
                return tuple([], html_span([html_i(className="fas fa-times-circle me-2"), "This is not a valid Excel file! (Please upload .xlsx)"], className="small colourtx-c0hr"), "w-100 mb-2 fw-bold pulse-green", nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., [], nothing, Dict("status" => 2, "dataid" => ""), "d-none", proj_v)
            end

            df = Sys_Fast.FAST_ReadExcel_DDEF(path, C.SHEET_DATA)
            isempty(df) && (df = Sys_Fast.FAST_ReadExcel_DDEF(path, "DATA_RECORDS"))

            if isempty(df)
                return tuple([], html_span([html_i(className="fas fa-times-circle me-2"), "No Valid Data Sheet found in spreadsheet."], className="small colourtx-c0hr"), "w-100 mb-2 fw-bold pulse-green", nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., [], nothing, Dict("status" => 2, "dataid" => ""), "d-none", proj_v)
            end

            col_phase = Symbol(C.COL_PHASE)
            phases = []
            if hasproperty(df, col_phase)
                phases = map(unique(skipmissing(df[:, col_phase]))) do p
                    Dict("label" => string(p), "value" => string(p))
                end
            else
                # Operational fallback: designated as single-phase system if phase attribute is absent.
                phases = [Dict("label" => "Default", "value" => "Default")]
            end

            out_cols = filter(c -> startswith(c, C.PRE_RESULT), names(df))
            goals_name   = fill("", 3)
            goals_min    = fill(0.0, 3)
            goals_target = fill(0.0, 3)
            goals_max    = fill(0.0, 3)
            goals_type   = fill("Nominal", 3)
            goals_weight = fill("1.00", 3)

            for (i, c) in enumerate(out_cols[1:min(length(out_cols), 3)])
                raw_vals = skipmissing(df[!, c])
                vals = Float64[]
                for v in raw_vals
                    if v isa Number && !isnan(v)
                        push!(vals, Float64(v))
                    end
                end
                mn, mx = isempty(vals) ? (0.0, 0.0) : extrema(vals)
                goals_name[i]   = replace(c, C.PRE_RESULT => "")
                goals_type[i]   = "Nominal"
                goals_min[i]    = round(mn; digits=2)
                goals_max[i]    = round(mx; digits=2)
                goals_target[i] = round((mn + mx) / 2; digits=2)
            end

            config = Sys_Fast.FAST_ReadConfig_DDEF(path)
            method = get(get(config, "Global", Dict()), "Method", "")

            model_opts = []
            model_val  = "Auto"
            if method == "TL09"
                model_opts = [Dict("label" => "Linear", "value" => "Linear")]
                model_val  = "Linear"
            elseif method in ["BB15", "CD17", "DF14"]
                model_opts = [
                    Dict("label" => "Quadratic", "value" => "Quadratic"),
                    Dict("label" => "Linear",    "value" => "Linear"),
                    Dict("label" => "Automatic", "value" => "Auto"),
                ]
                model_val  = "Quadratic"
            else
                model_opts = [
                    Dict("label" => "Automatic", "value" => "Auto"),
                    Dict("label" => "Linear",    "value" => "Linear"),
                    Dict("label" => "Quadratic", "value" => "Quadratic"),
                ]
                model_val  = "Auto"
            end

            # Apply Radio Correction Overrides to UI Goals
            orig_goals_name = copy(goals_name)
            radio_opts = get(config, "RadioOpts", Dict{String,Any}())
            rev_dict = get(radio_opts, "ReverseMap", Dict{String,Any}())
            for (i, name) in enumerate(orig_goals_name)
                if haskey(rev_dict, name)
                    mapping = rev_dict[name]
                    alias = get(mapping, "Name", "")
                    unit = get(mapping, "Unit", "")
                    if !isempty(alias)
                        goals_name[i] = alias * (isempty(unit) ? "" : " ($unit)")
                    end
                end
            end

            saved_goals = get(config, "LensGoals", [])
            for (i, name) in enumerate(goals_name)
                # Primary match via corrected alias, fallback to raw output name
                g_idx = findfirst(g -> get(g, "Name", "") == name, saved_goals)
                if isnothing(g_idx)
                    g_idx = findfirst(g -> get(g, "Name", "") == orig_goals_name[i], saved_goals)
                end
                
                if !isnothing(g_idx)
                    saved_g = saved_goals[g_idx]
                    goals_type[i]   = string(get(saved_g, "Type", "Nominal"))
                    goals_weight[i] = Printf.@sprintf("%.2f", Main.Sys_Fast.FAST_SafeNum_DDEF(get(saved_g, "Weight", 1.0)))
                    goals_target[i] = Float64(get(saved_g, "Target", goals_target[i]))
                    goals_min[i]    = Float64(get(saved_g, "Min",    goals_min[i]))
                    goals_max[i]    = Float64(get(saved_g, "Max",    goals_max[i]))
                end
            end
            has_radio_headers = any(c -> occursin("TIME_EXP_", string(c)) || occursin("TIME_MEAS_", string(c)), names(df))
            has_radio_config = false
            if haskey(config, "Ingredients")
                has_radio_config = has_radio_config || any(get(f, "IsRadioactive", false) == true for f in config["Ingredients"])
            end
            if haskey(config, "Outputs")
                has_radio_config = has_radio_config || any(get(o, "IsRadioactive", false) == true for o in config["Outputs"])
            end
            
            has_radio = has_radio_headers || has_radio_config
            panel_class = has_radio ? "d-block mt-3" : "d-none"

            return tuple(
                phases,
                html_span("✅ System Synced", className="small fw-bold", style=Dict("color" => "var(--colour-chr4-tongre)")),
                "w-100 mb-2 fw-bold",
                isempty(phases) ? nothing : phases[end]["value"],
                goals_name...,
                goals_min...,
                goals_target...,
                goals_max...,
                goals_type...,
                goals_weight...,
                model_opts,
                model_val,
                Dict("status" => 1, "dataid" => active_cont),
                panel_class,
                proj_v
            )

        catch e
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "SYNC_FAIL", bt, "FAIL")
            return tuple([], html_span([html_i(className="fas fa-times-circle me-2"), "Sync Error: $(first(string(e), 120))"], className="small colourtx-c0hr"), "w-100 mb-2 fw-bold pulse-green",
                nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., [], nothing, Dict("status" => 2, "dataid" => ""), "d-none", proj_v)
        finally
            !isempty(path) && try
                rm(path; force=true)
            catch
            end
        end
    end

# ==============================================================================
# PART C: ANALYSIS ENGINE & RESULTS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 6: STATISTICAL ANALYSIS ENGINE
# ------------------------------------------------------------------------------

    callback!(app,
        Output("lens-store-graph-meta", "data"),
        Output("lens-results-text",    "children"),
        Output("lens-run-output",      "children"),
        Output("lens-store-report",    "data"),
        Output("lens-store-results",   "data"),
        Output("sync-lens-analysis",   "data"),
        Output("lens-leaders-text",    "children"),
        Output("lens-radio-badge",     "children"),
        Output("lens-store-batch-status", "data"),
        Output("lens-interval-batch",     "disabled"),
        Output("lens-store-graphs-blob",   "data"),
        Input("lens-btn-run",          "n_clicks"),
        Input("lens-interval-batch",   "n_intervals"),
        State("lens-dd-phase",         "value"),
        State("lens-dd-model",         "value"),
        [State("lens-goal-name-$i",   "value") for i in 1:3]...,
        [State("lens-goal-min-$i",    "value") for i in 1:3]...,
        [State("lens-goal-target-$i", "value") for i in 1:3]...,
        [State("lens-goal-max-$i",    "value") for i in 1:3]...,
        [State("lens-goal-type-$i",   "value") for i in 1:3]...,
        [State("lens-goal-weight-$i", "value") for i in 1:3]...,
        State("lens-store-radio-correct", "data"),
        State("store-master-vault",       "data"),
        State("lens-store-graph-meta",    "data"),
        State("lens-store-batch-status",  "data"),
        prevent_initial_call=true
    ) do args...
        trig = Main.Gui_Base.BASE_GetTrigger_DDEF(callback_context())
        nu   = Dash.no_update()
        if trig == "lens-interval-batch"
            status  = args[26]
            st_next = get(status, "next_pkg", get(status, :next_pkg, 0))
            lpt     = LENS_LastPayloadTime_DDEC[]
            
            # Scenario A: Delivery confirmed by UI (Terminal State).
            if st_next == 0 && lpt > 0.0
                Sys_Fast.FAST_Log_DDEF("LENS", "Batch_Flow", "Termination confirmed by UI. Pipeline reset.", "OK")
                LENS_BatchPayload_DDEC[] = nothing
                LENS_LastPayloadTime_DDEC[] = 0.0
                return (ntuple(_ -> nu, 9)..., true, nu)
            end
            
            # Robust Return: If we are already finished, force-disable the interval to prevent zombies.
            (isnothing(status) || st_next == 0) && return (ntuple(_ -> nu, 9)..., true, nu)
            
            payload = LENS_BatchPayload_DDEC[]
            
            # Scenario B: Payload exists - Delivery/Redelivery phase.
            if !isnothing(payload)
                # First Delivery Catch: Record the timestamp.
                if LENS_LastPayloadTime_DDEC[] < 1.0
                    LENS_LastPayloadTime_DDEC[] = time()
                    Sys_Fast.FAST_Log_DDEF("LENS", "Batch_Poll", "Staging Pulse #$(st_next) - Initiating Delivery...", "WAIT")
                else
                    Sys_Fast.FAST_Log_DDEF("LENS", "Batch_Poll", "Staging Pulse #$(st_next) - Redelivering (Window: $(round(time() - LENS_LastPayloadTime_DDEC[]; digits=1))s)...", "WAIT")
                end
                
                opt_data    = get(payload, "opt_results", nothing)
                res_report  = isnothing(opt_data) ? nu : get(opt_data, "Report",  nu)
                res_bundle  = isnothing(opt_data) ? nu : get(opt_data, "Bundle",  nu)
                res_leaders = isnothing(opt_data) ? nu : get(opt_data, "Leaders", nu)
                res_badge   = isnothing(opt_data) ? nu : get(opt_data, "Badge",   nu)
                
                vault_b64   = get(payload, "vault_b64",   nu)
                g_count     = get(payload, "graph_count",  0)
                graph_meta  = g_count > 0 ? Dict("count" => g_count, "ts" => time()) : nu
                graph_blob  = get(payload, "graph_blob",   nu)
                
                # Deliver: We keep the interval enabled to allow retries until st_next == 0 is received.
                return (graph_meta, nu, nu, res_report, res_bundle, vault_b64, res_leaders, res_badge, Dict("next_pkg" => 0, "handle" => "", "working" => false), false, graph_blob)
            end
            
            # Scenario C: No Payload - Polling or Timeout phase.
            if LENS_LastPayloadTime_DDEC[] > 1.0
                elapsed = time() - LENS_LastPayloadTime_DDEC[]
                if elapsed >= 60.0
                    Sys_Fast.FAST_Log_DDEF("LENS", "Security_Clear", "60s Grace Period expired. Emptying payload RAM.", "INFO")
                    LENS_BatchPayload_DDEC[] = nothing
                    LENS_LastPayloadTime_DDEC[] = 0.0
                    return (ntuple(_ -> nu, 8)..., Dict("next_pkg" => 0, "handle" => "", "working" => false), true, nu)
                end
            end
            
            # Scenario D: True Waiting.
            (st_next > 0) && Sys_Fast.FAST_Log_DDEF("LENS", "Batch_Poll", "Staging Pulse #$(st_next)...", "WAIT")
            return ntuple(_ -> nu, 11)
        end

        t_start = time()
        n, _, phase, model = args[1:4]

        # Guards to prevent re-entry during pre-operation phase.
        (n === nothing || n == 0) && return ntuple(_ -> nu, 11)

        is_rad_apply = args[23] === true
        base64_file  = args[24]

        active_cont = ""
        if base64_file isa String
            active_cont = base64_file
        elseif base64_file isa AbstractDict || base64_file isa Dict
            active_cont = get(base64_file, "content", "")
        end

        if isnothing(active_cont) || isempty(active_cont)
            return ntuple(_ -> nu, 11)
        end

        # Scientific objective extraction and sanitisation.
        goals    = Dict{String,Any}[]
        gnames   = collect(args[5:7])
        gmins    = collect(args[8:10])
        gtargets = collect(args[11:13])
        gmaxes   = collect(args[14:16])
        gtypes   = collect(args[17:19])
        gweights = collect(args[20:22])

        for i in 1:3
            if !isnothing(gnames[i]) && strip(string(gnames[i])) != ""
                push!(goals, Dict(
                    "Name"   => string(gnames[i]),
                    "Min"    => isnothing(gmins[i])    ? 0.0 : Float64(gmins[i]),
                    "Target" => isnothing(gtargets[i]) ? 0.0 : Float64(gtargets[i]),
                    "Max"    => isnothing(gmaxes[i])   ? 0.0 : Float64(gmaxes[i]),
                    "Type"   => isnothing(gtypes[i])   ? "Nominal" : string(gtypes[i]),
                    "Weight" => isnothing(gweights[i]) ? 1.0 : parse(Float64, string(gweights[i]))
                ))
            end
        end

        # Implementation of a race-condition lock to preserve system state integrity.
        if !Sys_Fast.FAST_AcquireLock_DDEF("VISE_ANALYSIS", "User triggered Analysis via lens-btn-run")
            Sys_Fast.FAST_Log_DDEF("LENS", "LOCK_REJECT", "Analysis Busy. Request Debounced.", "WARN")
            return nu, nu, html_span("⚠ Analysis in progress. Please wait.", className="fw-bold colourtx-c1sm"), nu, nu, nu, nu, nu, nu, true, nu
        end

        path = ""
        try
            path = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)
            if !isfile(path)
                return nu, nu, html_span("❌ Session Stale. Re-upload dataset.", className="fw-bold colourtx-c0hr"), nu, nu, nu, nu, nu, nu, true, nu
            end
            
            # Start of Scientific Cycle: Reset Timers and Lock Pipeline.
            LENS_LastPayloadTime_DDEC[] = 0.1
            
            Sys_Fast.FAST_Log_DDEF("LENS", "Process", "Starting OLS Analysis (Phase: $phase)...", "WAIT")

            config_full      = Sys_Fast.FAST_ReadConfig_DDEF(path)
            full_radio_opts  = get(config_full, "RadioOpts", Dict("Apply" => false))
            full_radio_opts["Apply"] = is_rad_apply
            opts = Dict{String,Any}("RadioOpts" => full_radio_opts)
            
            phase_str   = isnothing(phase) ? "Phase1" : string(phase)
            model_str   = isnothing(model) ? "Auto" : string(model)
            cfg_updates = Dict{String,Any}("LensGoals" => goals, "RadioOpts" => opts["RadioOpts"])

            res = Lib_Vise.VISE_Execute_DDEF(path, phase_str, goals, model_str; 
                Opts=opts, ConfigUpdates=cfg_updates, t_start=t_start, RenderMode=:Priority, Optim=false)

            if res["Status"] != "OK"
                return (Dict("count" => 0, "ts" => 0), "", html_span("❌ Analysis Failed: $(res["Message"])", className="colourtx-c0hr"), "", nu, nu, "", "", nu, true, nu)
            end

            sci_report = Lib_Vise.VISE_GenerateScientificReport_DDEF(res)
            
            pkg1_graphs = [
                Dict{String,Any}(
                    "figure" => Dict{String,Any}("data" => g["Plot"].data, "layout" => g["Plot"].layout, "config" => g["Plot"].config),
                    "title"  => string(g["Title"])
                ) for g in res["Graphs"] 
            ]

            # Priority payload: Send the first 6 graphs as a JSON package to the browser immediately.
            pkg1_blob = JSON3.write(pkg1_graphs)
            LENS_BatchPayload_DDEC[] = nothing
            LENS_LastPayloadTime_DDEC[] = 0.0
            local pkg1_copy = deepcopy(pkg1_graphs)

            Sys_Fast.FAST_Log_DDEF("LENS", "Render", "(Pkg 1) Prepared $(length(pkg1_graphs)) units for Priority delivery.", "OK")

            Threads.@spawn begin
                try
                    C, Log = Sys_Fast.FAST_Data_DDEC, Sys_Fast.FAST_Log_DDEF
                    
                    config_b = Sys_Fast.FAST_ReadConfig_DDEF(path)
                    in_n = collect(String, res["InNames"])
                    out_n = collect(String, res["OutNames"])
                    
                    bp, bs, ldf, sc, warns = Lib_Vise.VISE_RunOptimisation_DDEF(
                        res["X_Clean"], res["Models"], goals, config_b, phase_str, in_n, out_n, opts, C, Log
                    )
                    
                    # 1. Unify pre-BBO sheets and Leaders sheet into a single atomic write transaction
                    commit_sheets = Dict{String,DataFrame}()
                    raw_hidden = get(res, "_Hidden_Sheets", Dict())
                    if raw_hidden isa AbstractDict
                        for (k, v) in raw_hidden
                            commit_sheets[string(k)] = v
                        end
                    end
                    if !isempty(ldf)
                        commit_sheets[C.PREFIX_LEADERS * phase_str] = ldf
                    end
                    if !isempty(commit_sheets)
                        Sys_Fast.FAST_SafeExcelWrite_DDEF(path, commit_sheets)
                    end
                    
                    # 3. Build full result for report generation
                    res_b = copy(res)
                    res_b["BestPoint"] = bp
                    res_b["BestScore"] = bs
                    res_b["Leaders"]   = ldf
                    res_b["BoundaryWarnings"] = warns
                    
                    rep_b = Lib_Vise.VISE_GenerateScientificReport_DDEF(res_b)
                    
                    # 4. Build Leaders HTML
                    ld_html = LENS_BuildLeadersHTML_DDEF(ldf, res_b)

                    rad_b = (haskey(res_b, "RadioCorrection") && !isempty(res_b["RadioCorrection"])) ?
                            dbc_badge([html_i(className="fas fa-radiation me-1 colourtx-v5pb"), "Radio-Corrected"], className="ms-2 fw-bold colourgl-c4tg colourtx-v5pb") : ""

                    # 5. Render deferred graphs (64 units)
                    def_opts = copy(opts)
                    def_opts["Mode"] = :Deferred
                    def_raw = Main.Lib_Arts.ARTS_Render_DDEF(
                        res["Models"], res["X_Clean"], res["Y_Clean"], get(res, "DisplayInNames", res["InNames"]), get(res, "DisplayOutNames", res["OutNames"]), 
                        goals, res["R2_Adj"], res["Q2"], def_opts, ldf, res["Sensitivities"], res["Residuals"]
                    )
                    pkg_graphs = [Dict{String,Any}("figure" => Dict{String,Any}("data" => g["Plot"].data, "layout" => g["Plot"].layout, "config" => g["Plot"].config), "title" => string(g["Title"])) for g in def_raw]
                    
                    # 6. Build Collective Portfolio: Priority + Deferred
                    full_graphs = vcat(pkg1_copy, pkg_graphs)
                    full_blob   = JSON3.write(full_graphs)
                    
                    # 7. Re-read Excel as base64 for vault update (Leaders included!)
                    updated_vault_b64 = Sys_Fast.FAST_ReadToStore_DDEF(path)
                    
                    # 8. Sanitise result bundle for store (remove heavy objects first)
                    delete!(res_b, "Graphs")
                    delete!(res_b, "_Hidden_Sheets")
                    final_bundle = Sys_Fast.FAST_SanitiseJson_DDEF(res_b)
                    final_bundle["dataid"] = updated_vault_b64
                    final_bundle["type"] = "SCIENCE_PULSE"
                    
                    # 9. Store payload for interval pickup (NO graphs, small payload)
                    LENS_BatchPayload_DDEC[] = Dict{String,Any}(
                        "opt_results" => Dict{String,Any}("Report" => rep_b, "Bundle" => final_bundle, "Leaders" => ld_html, "Badge" => rad_b),
                        "vault_b64"   => updated_vault_b64,
                        "graph_count" => length(full_graphs),
                        "graph_blob"  => full_blob
                    )
                    Log("LENS", "Batch_Async", "Background Portfolio Compiled [Total: $(length(full_graphs))]. Blob Packed.", "OK")
                catch e
                    Sys_Fast.FAST_Log_DDEF("LENS", "Batch_Crash", "Background Task failed: $e", "FAIL")
                finally
                    !isempty(path) && try rm(path; force=true) catch end
                end
            end

            summary_rows = [
                html_tr([
                    html_td(n, style=Dict("padding" => "2px"), className="fw-bold"),
                    html_td((i <= length(res["R2_Adj"]) && !ismissing(res["R2_Adj"][i]) && !isnan(res["R2_Adj"][i])) ? @sprintf("%.3f", Float64(res["R2_Adj"][i])) : "-", style=Dict("padding" => "2px")),
                    html_td(
                        (i <= length(res["Q2"]) && !ismissing(res["Q2"][i]) && !isnan(res["Q2"][i])) ? @sprintf("%.3f", Float64(res["Q2"][i])) : "-",
                        className = LENS_EvalClass_DDEF(:q2, (i <= length(res["Q2"])) ? res["Q2"][i] : NaN),
                        style=Dict("padding" => "2px")
                    ),
                    html_td(
                        (i <= length(res["Models"]) && haskey(res["Models"][i], "P_Value") && !ismissing(res["Models"][i]["P_Value"]) && !isnan(res["Models"][i]["P_Value"])) ?
                            @sprintf("%.5f", Float64(res["Models"][i]["P_Value"])) : "N/A",
                        className = LENS_EvalClass_DDEF(:pval, (i <= length(res["Models"]) && haskey(res["Models"][i], "P_Value")) ? res["Models"][i]["P_Value"] : NaN),
                        style=Dict("padding" => "2px")
                    ),
                ]) for (i, n) in enumerate(get(res, "DisplayOutNames", res["OutNames"]))
            ]

            summary = html_div([
# ------------------------------------------------------------------------------
# SECTION 7: EXPERIMENTAL DESIGN VITALS & MODEL PERFORMANCE
# ------------------------------------------------------------------------------
                (haskey(res, "Vitals") && !isnothing(res["Vitals"]) ? html_div([
                    html_h6("EXPERIMENTAL DESIGN VITALS", className="fw-bold text-center mb-2 colourtx-c1sm", style=Dict("letterSpacing" => "1px")),
                    html_div([
                        # Row 1: Design Optimality Efficiencies
                        html_div([
                            html_span([
                                html_span("D-Efficiency: ", className="colourtx-v4dh"),
                                html_span(
                                    LENS_FormatMetric_DDEF(:d_eff, get(res["Vitals"], "D", NaN)),
                                    className = LENS_EvalClass_DDEF(:d_eff, get(res["Vitals"], "D", NaN))
                                )
                            ], className="mx-2"),
                            html_span("•", className="colourtx-v2mw"),
                            html_span([
                                html_span("A-Efficiency: ", className="colourtx-v4dh"),
                                html_span(LENS_FormatMetric_DDEF(:eff, get(res["Vitals"], "A", NaN)), className="fw-bold colourtx-v5pb")
                            ], className="mx-2"),
                            html_span("•", className="colourtx-v2mw"),
                            html_span([
                                html_span("G-Efficiency: ", className="colourtx-v4dh"),
                                html_span(LENS_FormatMetric_DDEF(:eff, get(res["Vitals"], "G", NaN)), className="fw-bold colourtx-v5pb")
                            ], className="mx-2"),
                            html_span("•", className="colourtx-v2mw"),
                            html_span([
                                html_span("I-Efficiency: ", className="colourtx-v4dh"),
                                html_span(LENS_FormatMetric_DDEF(:eff, get(res["Vitals"], "I", NaN)), className="fw-bold colourtx-v5pb")
                            ], className="mx-2"),
                        ], className="d-flex justify-content-center align-items-center flex-wrap py-1"),
                        # Row 2: Collinearity Diagnostics & LOF P-Value on Far Right
                        let c_raw   = get(res["Vitals"], "Condition", NaN),
                            (c_val, _, c_col) = Sys_Fast.FAST_FormatConditionNumber_DDEF(c_raw),
                            max_vif = get(res["Vitals"], "MaxVIF", NaN),
                            lof_val = get(res["Vitals"], "LOF", NaN)
                            html_div([
                                html_span([
                                    html_span("Max VIF: ", className="colourtx-v4dh"),
                                    html_span(
                                        LENS_FormatMetric_DDEF(:vif, max_vif),
                                        className = LENS_EvalClass_DDEF(:vif, max_vif)
                                    )
                                ], className="mx-3"),
                                html_span("•", className="colourtx-v2mw"),
                                html_span([
                                    html_span("Matrix Condition (κ): ", className="colourtx-v4dh"),
                                    html_span(c_val, className="fw-bold", style=Dict("color" => c_col))
                                ], className="mx-3"),
                                html_span("•", className="colourtx-v2mw"),
                                html_span([
                                    html_span("Lack-of-Fit P: ", className="colourtx-v4dh"),
                                    html_span(
                                        LENS_FormatMetric_DDEF(:lof, lof_val),
                                        className = LENS_EvalClass_DDEF(:lof, lof_val)
                                    )
                                ], className="mx-3"),
                            ], className="d-flex justify-content-center align-items-center flex-wrap py-1 border-top", style=Dict("borderColor" => "var(--colour-val1-lighig)"))
                        end
                    ], className="border rounded py-1 px-2 mb-3 colourbg-v0pw small"),
                    html_hr(style=Dict("height" => "1px", "border" => "none", "borderTop" => "1px solid var(--colour-val1-lighig)", "margin" => "15px 0"))
                ]) : html_div()),

                html_h6("MODEL PERFORMANCE SUMMARY", className="fw-bold text-center mb-3 colourtx-c1sm", style=Dict("letterSpacing" => "1px")),
                html_table([
                    html_thead(html_tr([
                        html_th("Output",   style=Dict("width" => "40%", "padding" => "2px")),
                        html_th("R² (Adj)", style=Dict("width" => "20%", "padding" => "2px")),
                        html_th("Q² (Pred)", style=Dict("width" => "20%", "padding" => "2px")),
                        html_th("P-Value",  style=Dict("width" => "20%", "padding" => "2px"))
                    ])),
                    html_tbody(summary_rows)
                ], className="table table-sm table-hover small mb-3 border", style=Dict("tableLayout" => "fixed", "width" => "100%")),

                (haskey(res, "Sensitivities") && !isempty(res["Sensitivities"]) ? html_div([
                    html_hr(style=Dict("height" => "1px", "border" => "none", "borderTop" => "1px solid var(--colour-val1-lighig)", "margin" => "15px 0")),
                    html_h6("FACTOR SENSITIVITY", className="fw-bold text-center mb-3 colourtx-c1sm", style=Dict("letterSpacing" => "1px")),
                    let out_names = get(res, "DisplayOutNames", res["OutNames"]),
                        n_out = max(1, length(out_names)),
                        w_col = @sprintf("%.2f%%", 60.0 / n_out)
                        html_table([
                            html_thead(html_tr([
                                html_th("Factor", style=Dict("width" => "40%", "padding" => "2px")),
                                [html_th(out, style=Dict("width" => w_col, "padding" => "2px")) for out in out_names]...
                            ])),
                            html_tbody([
                                html_tr([
                                    html_td(get(res, "DisplayInNames", res["InNames"])[fi], className="fw-bold", style=Dict("padding" => "2px")),
                                    [html_td(
                                        let s = (mi <= length(res["Sensitivities"]) && fi <= length(res["Sensitivities"][mi])) ? res["Sensitivities"][mi][fi] : NaN
                                            (!ismissing(s) && !isnan(s)) ? @sprintf("%.1f%%", Float64(s) * 100) : "-"
                                        end, 
                                        className = LENS_EvalClass_DDEF(:sensitivity, (mi <= length(res["Sensitivities"]) && fi <= length(res["Sensitivities"][mi])) ? res["Sensitivities"][mi][fi] : NaN), 
                                        style=Dict("padding" => "2px"))
                                     for mi in 1:length(out_names)]...
                                ]) for fi in 1:length(get(res, "DisplayInNames", res["InNames"]))
                            ])
                        ], className="table table-sm table-hover small mb-3 border", style=Dict("tableLayout" => "fixed", "width" => "100%"))
                    end
                ]) : html_div()),

                html_div([
                    html_hr(style=Dict("height" => "2px", "border" => "none", "borderTop" => "2px solid var(--colour-chr3-toncya)", "margin" => "15px 0")),
                    html_h6("MODEL DIAGNOSTICS", className="fw-bold text-center mb-3 colourtx-c1sm", style=Dict("letterSpacing" => "1px")),
                    [html_div([
                        html_div("Analysis of Variance (ANOVA): $out_name", className="small fw-bold mb-1 colourtx-v4dh"),
                        # ANOVA Table
                        let df_ano = (haskey(res, "ANOVA") && i <= length(res["ANOVA"])) ? res["ANOVA"][i] : DataFrame()
                            if isempty(df_ano)
                                html_div("ANOVA diagnostics not available.", className="small text-muted py-1")
                            else
                                html_table([
                                    html_thead(html_tr([
                                        html_th("Source",  style=Dict("width" => "30%", "padding" => "2px")),
                                        html_th("df",      style=Dict("width" => "10%", "padding" => "2px")),
                                        html_th("MS",      style=Dict("width" => "20%", "padding" => "2px")),
                                        html_th("F-Value", style=Dict("width" => "20%", "padding" => "2px")),
                                        html_th("P-Value", style=Dict("width" => "20%", "padding" => "2px"))
                                    ])),
                                    html_tbody([
                                        html_tr([
                                            html_td(string(r.Source), style=Dict("padding" => "2px")), 
                                            html_td(string(r.df),     style=Dict("padding" => "2px")), 
                                            html_td((ismissing(r.MS) || isnan(r.MS)) ? "-" : @sprintf("%.4f", Float64(r.MS)), style=Dict("padding" => "2px")), 
                                            html_td((ismissing(r.F)  || isnan(r.F))  ? "-" : @sprintf("%.2f", Float64(r.F)),  style=Dict("padding" => "2px")), 
                                            html_td((ismissing(r.P)  || isnan(r.P))  ? "-" : @sprintf("%.4f", Float64(r.P)),
                                                className = LENS_EvalClass_DDEF(:anova, string(r.Source), r.P),
                                                style=Dict("padding" => "2px"))
                                        ]) for r in eachrow(df_ano)
                                    ])
                                ], className="table table-sm table-hover small mb-3 border", style=Dict("tableLayout" => "fixed", "width" => "100%"))
                            end
                        end,

                        html_div("Term Significance (Coefficients): $out_name", className="small fw-bold mb-1 colourtx-v4dh"),
                        # Coefficients Table
                        let m = (haskey(res, "Models") && i <= length(res["Models"])) ? res["Models"][i] : Dict{String,Any}()
                            if get(m, "Status", "") != "OK" || !haskey(m, "TermNames")
                                html_div("Coefficients not available: $(get(m, "Error", "Model error"))", className="small text-muted py-1 mb-3")
                            else
                                t_names = get(m, "TermNames", String[])
                                coefs   = get(m, "Coefs", Float64[])
                                p_coefs = get(m, "P_Coefs", Float64[])
                                vifs    = get(m, "VIFs", Float64[])
                                html_table([
                                    html_thead(html_tr([
                                        html_th("Term",    style=Dict("width" => "40%", "padding" => "2px")), 
                                        html_th("Beta",    style=Dict("width" => "20%", "padding" => "2px")), 
                                        html_th("VIF",     style=Dict("width" => "20%", "padding" => "2px")), 
                                        html_th("P-Value", style=Dict("width" => "20%", "padding" => "2px"))
                                    ])),
                                    html_tbody([
                                        html_tr([
                                            html_td(string(t_names[j]), style=Dict("padding" => "2px")), 
                                            html_td((j <= length(coefs) && !ismissing(coefs[j]) && !isnan(coefs[j])) ? @sprintf("%.4f", Float64(coefs[j])) : "-", style=Dict("padding" => "2px")), 
                                            html_td(
                                                let vf = (j <= length(vifs)) ? vifs[j] : NaN
                                                    (j == 1 || ismissing(vf) || isnan(vf)) ? "-" : @sprintf("%.2f", Float64(vf))
                                                end,
                                                className = LENS_EvalClass_DDEF(:coef_vif, j, (j <= length(vifs)) ? vifs[j] : NaN),
                                                style=Dict("padding" => "2px")),
                                            html_td(
                                                let pv = (j <= length(p_coefs)) ? p_coefs[j] : NaN
                                                    (ismissing(pv) || isnan(pv)) ? "N/A" : @sprintf("%.4f", Float64(pv))
                                                end,
                                                className = LENS_EvalClass_DDEF(:coef_pval, (j <= length(p_coefs)) ? p_coefs[j] : NaN),
                                                style=Dict("padding" => "2px"))
                                        ]) for j in 1:length(t_names)
                                    ])
                                ], className="table table-sm table-hover small mb-4 border", style=Dict("tableLayout" => "fixed", "width" => "100%"))
                            end
                        end
                    ]) for (i, out_name) in enumerate(get(res, "DisplayOutNames", res["OutNames"]))]...
                ], className="mt-3"),

                # Orchestration of architectural boundary warnings and spatial limit detections (AskLeader Integration).
                let warnings = get(res, "BoundaryWarnings", String[])
                    !isempty(warnings) ? dbc_alert([
                        html_div([
                            html_i(className="fas fa-exclamation-triangle me-2"), 
                            html_strong("Boundary Warning (Search Space Limit)"),
                        ], className="mb-1"),
                        html_ul([html_li(w, className="mb-0") for w in warnings], className="ps-3 mb-0 small")
                    ], className="mt-2 py-2 border-0 shadow-sm colourgl-c5hy colourtx-v5pb", style=Dict("borderColor" => "var(--colour-chr5-hueyel)")) : html_div()
                end
            ])

            updated_base64 = Sys_Fast.FAST_ReadToStore_DDEF(path)

            leaders_html = ""
            if haskey(res, "Leaders") && !isempty(res["Leaders"])
                leaders_html = LENS_BuildLeadersHTML_DDEF(res["Leaders"], res)
            end
            rad_badge = (haskey(res, "RadioCorrection") && !isempty(res["RadioCorrection"])) ?
                        dbc_badge([html_i(className="fas fa-radiation me-1 colourtx-v5pb"), "Radio-Corrected"], className="ms-2 fw-bold colourgl-c4tg colourtx-v5pb") : ""

            # Architectural Optimisation: Remove bulky objects before sanitisation to prevent lag.
            delete!(res, "Graphs") 
            delete!(res, "_Hidden_Sheets")
            final_res = Sys_Fast.FAST_SanitiseJson_DDEF(res)

            final_res["dataid"]  = updated_base64
            final_res["type"] = "SCIENCE_PULSE"
            # Final Architectural Sync: Capture total duration AFTER all post-processing.
            t_total       = round(time() - t_start; digits=1)
            elapsed_badge = html_span(" ($(t_total)s)", className="colourtx-v3dl")

            is_staged = true
            
            return (
                Dict("count" => length(pkg1_graphs), "ts" => time()), 
                summary, 
                html_span(["✅ Analysis Complete", elapsed_badge], className="fw-bold small colourtx-c4tg"), 
                sci_report, 
                final_res, 
                updated_base64, 
                leaders_html, 
                rad_badge,
                Dict("next_pkg" => 2, "handle" => "", "working" => false),
                false,
                pkg1_blob
            )

        # ------------------------------------------------------------------------------
        # SECTION 8: ANALYSIS ERROR GUARD & CLEANUP

        catch e
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "ANALYSIS_CRASH", bt, "FAIL")
            !isempty(path) && try rm(path; force=true) catch end
            LENS_LastPayloadTime_DDEC[] = 0.0
            LENS_BatchPayload_DDEC[] = nothing
            err_msg = html_span(["❌ Analysis Error: ", first(string(e), 120)], className="fw-bold small colourtx-c0hr")
            return (nu, nu, err_msg, nu, nu, nu, nu, nu, Dict("next_pkg" => 0, "handle" => "", "working" => false), true, nu)
        finally
            # Mandatory release of the architectural lock to restore system concurrency.
            Sys_Fast.FAST_ReleaseLock_DDEF("VISE_ANALYSIS")
        end
    end

# ------------------------------------------------------------------------------
# SECTION 9: UI ORCHESTRATED ACTION CONTROLLER
# ------------------------------------------------------------------------------

    callback!(app,
        [Output("lens-btn-$id", "disabled") for id in ["run", "view-report", "export-plots", "download-report", "export-excel"]]...,
        Input("store-master-vault",   "data"),
        Input("lens-store-sync-flag",  "data"),
        Input("lens-store-results",    "data"),
        Input("lens-store-diag-force", "data"),
        Input("lens-interval-batch",   "n_intervals")
    ) do vault, sync_flag, results, diag_force, _n_int
        trig = BASE_GetTrigger_DDEF(callback_context())

        if trig == "lens-store-diag-force" && diag_force > 0
            Sys_Fast.FAST_Log_DDEF("LENS", "Guard", "Emergency Unlock triggered via Diagnostics.", "OK")
            if !isnothing(results) && haskey(results, "dataid")
                return ntuple(_ -> false, 5)
            end
            return false, true, true, true, true
        end

        # Deliver-to-Unlock Security Lock: Prevent re-entry while analysis or delivery is active.
        lpt = LENS_LastPayloadTime_DDEC[]
        if lpt > 0.0
            # If lpt < 1.0, it's analysis phase. If lpt > 1.0, it's delivery phase.
            # Safety Check: If timeout hasn't reached, keep it locked.
            if lpt < 1.0 || (time() - lpt < 60.0)
                has_res = !isnothing(results) && Sys_Fast.FAST_ExtractDataID_DDEF(results) == Sys_Fast.FAST_ExtractDataID_DDEF(vault)
                return true, !has_res, !has_res, !has_res, !has_res
            end
        end

        if isnothing(vault) || isempty(vault)
            return ntuple(_ -> true, 5)
        end

        curr_dataid = Sys_Fast.FAST_ExtractDataID_DDEF(vault)

        if isnothing(curr_dataid) || isempty(curr_dataid)
            return ntuple(_ -> true, 5)
        end

        # 1. Direct Analysis Match: Results are already calculated for this specific data.
        if !isnothing(results) && Sys_Fast.FAST_ExtractDataID_DDEF(results) == curr_dataid
            Sys_Fast.FAST_Log_DDEF("LENS", "Guard", "Analysis valid for current data. Unlocked all.", "OK")
            return ntuple(_ -> false, 5)
        end

        # 2. Sync State Match: Data is loaded but analysis is not yet run.
        if !isnothing(sync_flag) && Sys_Fast.FAST_ExtractDataID_DDEF(sync_flag) == curr_dataid && get(sync_flag, "status", 0) == 1
            Sys_Fast.FAST_Log_DDEF("LENS", "Guard", "Sync validated. Unlocked Analysis Engine.", "OK")
            return false, true, true, true, true
        end

        # Exception: Diagnostics override for power users.
        if !isnothing(diag_force) && diag_force > 0
             return ntuple(_ -> false, 5)
        end

        Sys_Fast.FAST_Log_DDEF("LENS", "Guard", "Data in transition or sync pending [DataID: $(first(curr_dataid, 8))].", "WAIT")
        return ntuple(_ -> true, 5)
    end



# ------------------------------------------------------------------------------
# SECTION 10: GRAPH RENDERING & METADATA
# ------------------------------------------------------------------------------

    callback!(ClientsideFunction("clientside", "update_index"), app,
        Output("lens-store-index", "data"),
        Output("lens-graph-input", "value"),
        Output("lens-graph-input", "max"),
        Input("lens-store-graph-meta", "data"),
        Input("lens-btn-next",         "n_clicks"),
        Input("lens-btn-prev",         "n_clicks"),
        Input("lens-graph-input",      "value"),
        State("lens-store-index",      "data"),
        prevent_initial_call=true
    )

    callback!(ClientsideFunction("clientside", "render_graph"), app,
        Output("lens-graph-main",    "figure"),
        Output("lens-graph-title",   "children"),
        Output("lens-graph-counter", "children"),
        Input("lens-store-graphs-blob", "data"),
        Input("lens-store-index",       "data"),
        prevent_initial_call=true
    )


    # Metadata synchronisation for graph descriptive index panel.
    callback!(ClientsideFunction("clientside", "update_info"), app,
        Output("lens-graph-info", "children"),
        Input("lens-store-graphs-blob", "data"),
        prevent_initial_call=true
    )


# ------------------------------------------------------------------------------
# SECTION 11: PHASE EVOLUTION WIZARD (MODAL)
# ------------------------------------------------------------------------------

    callback!(app,
        Output("lens-modal-wizard",  "is_open"),
        Output("lens-modal-leader",  "is_open"),
        Output("lens-modal-preview", "is_open"),
        Output("lens-phase-guard-msg", "children"),
        Input("lens-btn-next-phase", "n_clicks"),
        Input("lens-wiz-btn-next",   "n_clicks"),
        Input("lens-wiz-btn-cancel", "n_clicks"),
        Input("lens-lead-btn-back",    "n_clicks"),
        Input("lens-lead-btn-confirm", "n_clicks"),
        Input("lens-lead-btn-cancel",  "n_clicks"),
        Input("lens-prev-btn-back",    "n_clicks"),
        Input("lens-prev-btn-cancel",  "n_clicks"),
        Input("lens-signal-process",   "data"),
        State("lens-modal-wizard",  "is_open"),
        State("lens-modal-leader",  "is_open"),
        State("lens-modal-preview", "is_open"),
        State("lens-store-results", "data"),
        prevent_initial_call=true
    ) do n_open, n_w2L, n_w_can, n_L2w, n_L2p, n_L_can, n_p2L, n_p_can, sig, w_open, L_open, p_open, results
        trig = BASE_GetTrigger_DDEF(callback_context())
        no_msg = Dash.no_update()

        (trig in ("lens-wiz-btn-cancel", "lens-lead-btn-cancel", "lens-prev-btn-cancel") || (trig == "lens-signal-process" && get(sig, "success", false))) && return false, false, false, ""

        if trig == "lens-btn-next-phase"
            has_analysis = !isnothing(results) && (results isa AbstractDict || results isa Dict) && get(results, "Status", "") == "OK"
            !has_analysis && return false, false, false, html_span([html_i(className="fas fa-info-circle me-1"), "Run the analysis first to identify leader candidates."], className="colourtx-c1sm fw-bold")
            return true, false, false, ""
        end

        trig == "lens-wiz-btn-next"    && return false, true, false, no_msg
        trig == "lens-lead-btn-back"    && return true, false, false, no_msg
        trig == "lens-lead-btn-confirm" && return false, false, true, no_msg
        trig == "lens-prev-btn-back"    && return false, true, false, no_msg

        return Dash.no_update(), Dash.no_update(), Dash.no_update(), no_msg
    end

# ------------------------------------------------------------------------------
# SECTION 12: SCIENTIFIC REPORT & DOWNLOAD
# ------------------------------------------------------------------------------

"""
    LENS_ParseInlineContent_DDEF(text::AbstractString; is_cell::Bool=false) -> Vector{Any}
Parses inline scientific text, highlighting positive metrics in system green and negative metrics in system red.
Cell-specific evaluations are strictly isolated to avoid polluting running academic prose.
"""
function LENS_ParseInlineContent_DDEF(text::AbstractString; is_cell::Bool=false)
    clean = replace(text, "&lt;" => "<", "&gt;" => ">")
    
    # 1. Tag-based matching: <ins> or report-pos / colourtx-c4tg
    m_pos = match(r"<(?:ins|span)[^>]*class=[\"'][^\"']*(?:report-pos|colourtx-c4tg)[^\"']*[\"'][^>]*>(.*?)</(?:ins|span)>", clean)
    if isnothing(m_pos)
        m_pos = match(r"<ins[^>]*>(.*?)</ins>", clean)
    end
    if !isnothing(m_pos)
        inner = replace(m_pos.captures[1], r"<[^>]*>" => "")
        pfx = clean[1:m_pos.offset-1]
        sfx = clean[m_pos.offset + length(m_pos.match):end]
        return Any[
            LENS_ParseInlineContent_DDEF(pfx; is_cell=is_cell)...,
            html_span(inner, className="colourtx-c4tg fw-bold", style=Dict("color" => "var(--colour-chr4-tongre)", "fontWeight" => "700")),
            LENS_ParseInlineContent_DDEF(sfx; is_cell=is_cell)...
        ]
    end

    # 2. Tag-based matching: <del> or report-neg / colourtx-c0hr
    m_neg = match(r"<(?:del|span)[^>]*class=[\"'][^\"']*(?:report-neg|colourtx-c0hr)[^\"']*[\"'][^>]*>(.*?)</(?:del|span)>", clean)
    if isnothing(m_neg)
        m_neg = match(r"<del[^>]*>(.*?)</del>", clean)
    end
    if !isnothing(m_neg)
        inner = replace(m_neg.captures[1], r"<[^>]*>" => "")
        pfx = clean[1:m_neg.offset-1]
        sfx = clean[m_neg.offset + length(m_neg.match):end]
        return Any[
            LENS_ParseInlineContent_DDEF(pfx; is_cell=is_cell)...,
            html_span(inner, className="colourtx-c0hr fw-bold", style=Dict("color" => "var(--colour-chr0-huered)", "fontWeight" => "700")),
            LENS_ParseInlineContent_DDEF(sfx; is_cell=is_cell)...
        ]
    end

    # 3. Tag-based matching: generic <span>
    m_span = match(r"<span[^>]*>(.*?)</span>", clean)
    if !isnothing(m_span)
        inner = replace(m_span.captures[1], r"<[^>]*>" => "")
        pfx = clean[1:m_span.offset-1]
        sfx = clean[m_span.offset + length(m_span.match):end]
        return Any[
            LENS_ParseInlineContent_DDEF(pfx; is_cell=is_cell)...,
            inner,
            LENS_ParseInlineContent_DDEF(sfx; is_cell=is_cell)...
        ]
    end

    # 4. Markdown Bold: **...**
    m_b = match(r"\*\*(.*?)\*\*", clean)
    if !isnothing(m_b)
        pfx = clean[1:m_b.offset-1]
        inner = m_b.captures[1]
        sfx = clean[m_b.offset + length(m_b.match):end]
        return Any[
            LENS_ParseInlineContent_DDEF(pfx; is_cell=is_cell)...,
            html_strong(inner),
            LENS_ParseInlineContent_DDEF(sfx; is_cell=is_cell)...
        ]
    end

    # 5. Markdown Inline Code: `...`
    m_c = match(r"`(.*?)`", clean)
    if !isnothing(m_c)
        pfx = clean[1:m_c.offset-1]
        inner = m_c.captures[1]
        sfx = clean[m_c.offset + length(m_c.match):end]
        return Any[
            LENS_ParseInlineContent_DDEF(pfx; is_cell=is_cell)...,
            html_code(inner),
            LENS_ParseInlineContent_DDEF(sfx; is_cell=is_cell)...
        ]
    end

    # 6. Fallback Exact Matching for Diagnostic Table Cells ONLY
    if is_cell
        trim_c = strip(clean)
        trim_c in LENS_PosCells_DDEC && return Any[html_span(trim_c, className="colourtx-c4tg fw-bold", style=Dict("color" => "var(--colour-chr4-tongre)", "fontWeight" => "700"))]
        trim_c in LENS_NegCells_DDEC && return Any[html_span(trim_c, className="colourtx-c0hr fw-bold", style=Dict("color" => "var(--colour-chr0-huered)", "fontWeight" => "700"))]
    end

    return isempty(clean) ? Any[] : Any[clean]
end

"""
    LENS_RenderAcademicReport_DDEF(report_raw::AbstractString) -> html_div
Transforms a raw markdown statistical analysis report into styled Dash HTML components with visual evaluation accents.
"""
function LENS_RenderAcademicReport_DDEF(report_raw::AbstractString)
    lines = split(report_raw, "\n")
    components = Any[]
    
    i = 1
    n_lines = length(lines)
    while i <= n_lines
        line = strip(lines[i])
        
        if isempty(line)
            i += 1
            continue
        end
        
        # Table Processing
        if startswith(line, "|") && endswith(line, "|")
            table_lines = String[]
            while i <= n_lines && startswith(strip(lines[i]), "|") && endswith(strip(lines[i]), "|")
                push!(table_lines, strip(lines[i]))
                i += 1
            end
            
            if length(table_lines) >= 2
                raw_headers = [strip(c) for c in split(table_lines[1], "|")[2:end-1]]
                raw_divs = [strip(c) for c in split(table_lines[2], "|")[2:end-1]]
                aligns = String[]
                for d in raw_divs
                    if startswith(d, ":") && endswith(d, ":")
                        push!(aligns, "center")
                    elseif endswith(d, ":")
                        push!(aligns, "right")
                    else
                        push!(aligns, "left")
                    end
                end
                
                rows_comp = Any[]
                for r_idx in 3:length(table_lines)
                    raw_cells = [strip(c) for c in split(table_lines[r_idx], "|")[2:end-1]]
                    tds = Any[]
                    for (c_idx, cell) in enumerate(raw_cells)
                        al = (c_idx <= length(aligns)) ? aligns[c_idx] : "left"
                        push!(tds, html_td(LENS_ParseInlineContent_DDEF(cell; is_cell=true), style=Dict("textAlign" => al)))
                    end
                    push!(rows_comp, html_tr(tds))
                end
                
                ths = [html_th(h, style=Dict("textAlign" => (j <= length(aligns) ? aligns[j] : "left"))) for (j, h) in enumerate(raw_headers)]
                tbl = html_table([
                    html_thead(html_tr(ths)),
                    html_tbody(rows_comp)
                ], className="table table-sm mb-3")
                push!(components, tbl)
            end
            continue
        end
        
        # Structural Headings
        if startswith(line, "# ")
            push!(components, html_h1(strip(line[3:end])))
        elseif startswith(line, "### ")
            push!(components, html_h3(strip(line[5:end])))
        elseif startswith(line, "#### ")
            push!(components, html_h4(strip(line[6:end])))
        elseif line == "---"
            push!(components, html_hr())
        elseif startswith(line, "*") && endswith(line, "*") && length(line) >= 2
            inner = strip(line[2:end-1])
            push!(components, html_p(html_em(LENS_ParseInlineContent_DDEF(inner; is_cell=false)), className="mb-2"))
        elseif startswith(line, "- ")
            inner = strip(line[3:end])
            push!(components, html_p([html_span("• ", className="fw-bold me-2"), LENS_ParseInlineContent_DDEF(inner; is_cell=false)...], className="mb-1 ps-3"))
        else
            push!(components, html_p(LENS_ParseInlineContent_DDEF(line; is_cell=false), className="mb-2"))
        end
        
        i += 1
    end
    
    return html_div(components, className="academic-dossier")
end

    callback!(app,
        Output("lens-modal-report",   "is_open"),
        Output("lens-report-content", "children"),
        Input("lens-btn-view-report", "n_clicks"),
        State("lens-store-report",    "data"),
        prevent_initial_call=true
    ) do n, report
        if n > 0 && !isnothing(report) && !isempty(report)
            return true, LENS_RenderAcademicReport_DDEF(report)
        end
        return false, html_div()
    end

    # Scientific report download in TXT format.
    callback!(app,
        Output("lens-download-report-file", "data"),
        Input("lens-btn-download-txt", "n_clicks"),
        Input("lens-btn-download-report", "n_clicks"),
        State("lens-store-report",     "data"),
        State("lens-input-project",    "value"),
        State("lens-dd-phase",         "value"),
        prevent_initial_call=true
    ) do n1, n2, report, project, phase
        if (isnothing(n1) || n1 == 0) && (isnothing(n2) || n2 == 0)
            return Dash.no_update()
        end
        
        (isnothing(report) || isempty(report)) && return Dash.no_update()

        proj  = isnothing(project) ? "DoECISORY" : project
        ph    = isnothing(phase)   ? "Phase1" : phase
        fname = "DoECISORY_$(proj)_$(ph)_Scientific_Report.txt"
        clean_txt = replace(report, r"<[^>]*>" => "")
        clean_txt = replace(clean_txt, "&lt;" => "<", "&gt;" => ">")

        return Dict("filename" => fname, "content" => clean_txt)
    end

# ------------------------------------------------------------------------------
# SECTION 13: PHASE EVOLUTION WIZARD (LOGIC)
# ------------------------------------------------------------------------------

    callback!(app,
        Output("lens-lead-btn-confirm", "disabled"),
        Output("lens-lead-btn-confirm", "className"),
        Input("lens-table-candidates", "selected_rows")
    ) do s
        is_disabled = isnothing(s) || isempty(s)
        btn_class   = is_disabled ? "w-100 colourgl-c1sm pulse-purple" : "w-100 colourgl-c4tg"
        return is_disabled, btn_class
    end

    # Phase wizard data initialisation.
    callback!(app,
        Output("lens-wiz-dd-source",    "options"),
        Output("lens-wiz-dd-source",    "value"),
        Output("lens-wiz-input-target", "value"),
        Input("lens-btn-next-phase", "n_clicks"),
        State("lens-dd-phase",       "value"),
        prevent_initial_call=true
    ) do n, ph
        src_phase = isnothing(ph) ? "Phase1" : ph
        digit_match = match(r"\d+", src_phase)
        next_val = isnothing(digit_match) ? 2 : parse(Int, digit_match.match) + 1

        Sys_Fast.FAST_Log_DDEF("LENS", "Wizard", "Targeting: $src_phase -> Phase$next_val", "INFO")

        return [Dict("label" => src_phase, "value" => src_phase)], src_phase, "Phase$next_val"
    end

    # Candidate data loader.
    callback!(app,
        Output("lens-table-candidates", "data"),
        Output("lens-table-candidates", "columns"),
        Input("lens-modal-leader",   "is_open"),
        State("lens-wiz-dd-source",  "value"),
        State("store-master-vault",  "data"),
        prevent_initial_call=true
    ) do is_open, src, base64_file
        !is_open && return Dash.no_update(), Dash.no_update()
        isnothing(base64_file) && return [], []

        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)
        C = Sys_Fast.FAST_Data_DDEC
        config_full = Sys_Fast.FAST_ReadConfig_DDEF(path)
        data = Sys_Flow.FLOW_GetCandidates_DDEF(path, src)
        Sys_Fast.FAST_CleanTransient_DDEF(path)

        isempty(data) && return [], []

        cols_to_show = String[]

        all_keys = collect(keys(data[1]))
        h_id_idx = findfirst(k -> occursin("ID", uppercase(string(k))), all_keys)
        !isnothing(h_id_idx) && push!(cols_to_show, string(all_keys[h_id_idx]))
 
        ingredients = get(config_full, "Ingredients", [])
        for c in ingredients
            name = get(c, "Name", "")
            if get(c, "Role", "") == C.ROLE_VAR
                v_key = "$(C.PRE_INPUT)$name"
                if any(k -> string(k) == v_key, all_keys)
                    push!(cols_to_show, v_key)
                elseif any(k -> string(k) == name, all_keys)
                    push!(cols_to_show, name)
                end
            end
        end
 
        # Integration of Prediction parameters in strict Configuration sequence.
        outputs = get(config_full, "Outputs", [])
        for o in outputs
            name = get(o, "Name", "")
            p_key = "$(C.PRE_PRED)$name"
            if any(k -> string(k) == p_key, all_keys)
                push!(cols_to_show, p_key)
            elseif any(k -> string(k) == name, all_keys)
                push!(cols_to_show, name)
            end
        end

        h_score_idx = findfirst(k -> uppercase(string(k)) == "SCORE", all_keys)
        !isnothing(h_score_idx) && push!(cols_to_show, string(all_keys[h_score_idx]))

        columns = [Dict{String,Any}("name" => replace(c, r"^(VARIA_|PRED_)" => ""), "id" => c) for c in cols_to_show]
        for col in columns
            if col["id"] == "Score" || col["id"] == "SCORE"
                col["type"]   = "numeric"
                col["format"] = Dict("specifier" => ".4f")
            end
        end

        return data, columns
    end

    callback!(app,
        Output("lens-store-next-phase-proposal", "data"),
        Output("lens-prev-slider-zoom",  "value"),
        Output("lens-prev-slider-shift", "value"),
        Output("lens-prev-dd-method",    "value"),
        [Output("lens-slot-name-$i",   "children") for i in 1:3]...,
        [Output("lens-slot-leader-$i", "children") for i in 1:3]...,
        [Output("lens-slot-mode-$i",   "value") for i in 1:3]...,
        Output("lens-prev-dir-x1",     "value"),
        Output("lens-prev-dir-x2",     "value"),
        Output("lens-prev-dir-x3",     "value"),
        Input("lens-lead-btn-confirm",  "n_clicks"),
        Input("lens-prev-slider-zoom",  "value"),
        Input("lens-prev-slider-shift", "value"),
        Input("lens-prev-dd-method",    "value"),
        State("lens-wiz-dd-source",     "value"),
        State("lens-table-candidates",  "selected_rows"),
        State("lens-table-candidates",  "data"),
        State("store-master-vault",     "data"),
        State("lens-store-results",     "data"),
        prevent_initial_call=true
    ) do n_prev, zoom_p, shift_p, meth_p, src, sel_rows, cand_data, base64_file, results
        trig = BASE_GetTrigger_DDEF(callback_context())

        zoom_map = Float64[1.0, 0.75, 0.5, 0.25, 0.1]
        z_idx = isnothing(zoom_p) ? 3 : clamp(round(Int, zoom_p), 1, 5)

        is_reset = (trig == "lens-lead-btn-confirm")
        
        z = is_reset ? 0.5 : zoom_map[z_idx]
        s = is_reset ? 0.0 : Float64(isnothing(shift_p) ? 0.0 : shift_p)
        m = is_reset ? "TL09" : meth_p
        
        ret_z = is_reset ? 3 : Dash.no_update()
        ret_s = is_reset ? 0.0 : Dash.no_update()
        ret_m = is_reset ? "TL09" : Dash.no_update()

        nu = Dash.no_update()
        slot_names   = Any[nu, nu, nu]
        slot_leaders = Any[nu, nu, nu]
        slot_modes   = Any[nu, nu, nu]

        (isnothing(base64_file) || isnothing(sel_rows) || isempty(sel_rows)) && return Dict(), ret_z, ret_s, ret_m, slot_names..., slot_leaders..., slot_modes..., nu, nu, nu

        row_sel = cand_data[sel_rows[1]+1]
        sel_id = haskey(row_sel, "EXP_ID") ? string(row_sel["EXP_ID"]) :
                 haskey(row_sel, "ID")     ? string(row_sel["ID"]) :
                 haskey(row_sel, :EXP_ID)  ? string(row_sel[:EXP_ID]) :
                 haskey(row_sel, :ID)      ? string(row_sel[:ID]) : ""

        C = Sys_Fast.FAST_Data_DDEC
        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)
        config_full = Sys_Fast.FAST_ReadConfig_DDEF(path)

        ingredients_raw = get(config_full, "Ingredients", [])
        ingredients = if ingredients_raw isa AbstractDict || ingredients_raw isa Dict
            [Dict{String,Any}(string(k) => v for (k, v) in pairs(val)) for val in values(ingredients_raw)]
        else
            [Dict{String,Any}(string(k) => v for (k, v) in pairs(val)) for val in ingredients_raw]
        end
        vars_config = filter(c -> Sys_Fast.FAST_GetSafe_DDEF(c, "Role", "") == C.ROLE_VAR, ingredients)

        res = Sys_Flow.FLOW_NextPhase_DDEF(path, src, sel_id, Float64(z), Float64(s))
        Sys_Fast.FAST_CleanTransient_DDEF(path)

        res["SelectedZoom"]   = z
        res["SelectedShift"]  = s
        res["SelectedMethod"] = m
        res["IsRadioCorrected"] = !isnothing(results) && haskey(results, "RadioCorrection") && !isempty(results["RadioCorrection"])
        res["RadioOpts"]        = get(config_full, "RadioOpts", Dict{String,Any}())

        ret_dir1 = nu
        ret_dir2 = nu
        ret_dir3 = nu
        if is_reset
            g_curr = get(config_full, "Global", Dict())
            ret_dir1, ret_dir2, ret_dir3 = LENS_ExtractDirections_DDEF(g_curr, vars_config)

            leader_vals = get(res, "LeaderValues", Float64[])
            for j in 1:min(3, length(vars_config))
                vname = get(vars_config[j], "Name", "Var $j")
                vunit = get(vars_config[j], "Unit", "")
                lv    = j <= length(leader_vals) ? round(leader_vals[j]; digits=3) : 0.0
                slot_names[j]   = vname
                slot_leaders[j] = "Leader: $lv $vunit"
                slot_modes[j]   = "KEEP"
            end
        end
        
        return res, ret_z, ret_s, ret_m, slot_names..., slot_leaders..., slot_modes..., ret_dir1, ret_dir2, ret_dir3
    end

    callback!(app,
        Output("lens-container-preview-table", "children"),
        Output("lens-container-preview-audit", "children"),
        Output("lens-graph-transition", "figure"),
        Output("lens-prev-dir-lbl-1", "children"),
        Output("lens-prev-dir-lbl-2", "children"),
        Output("lens-prev-dir-lbl-3", "children"),
        Input("lens-store-next-phase-proposal", "data"),
        Input("lens-store-slot-config", "data"),
        Input("lens-store-excluded-constants", "data"),
        Input("lens-prev-dir-x1", "value"),
        Input("lens-prev-dir-x2", "value"),
        Input("lens-prev-dir-x3", "value"),
        Input("lens-prev-dd-method", "value"),
        prevent_initial_call=true
    ) do res, slot_cfg, excluded_raw, dir_x1, dir_x2, dir_x3, meth_val
        (isnothing(res) || isempty(res) || get(res, "Status", "") != "OK") && return html_div("No proposal available."), "", Dict(), "X₁ Direction", "X₂ Direction", "X₃ Direction"

        excluded = (isnothing(excluded_raw) || !(excluded_raw isa AbstractVector)) ? String[] : String[string(x) for x in excluded_raw]

        conf = res["NewConfig"]

        old_conf    = get(res, "OldConfig", conf)
        new_conf    = get(res, "NewConfig", conf)
        leader_vals = get(res, "LeaderValues", Float64[])
        header_info = get(res, "Global", Dict())
        vol         = Float64(get(header_info, "Volume", 5.0))
        conc        = Float64(get(header_info, "Concentration", 10.0))
        zoom_f      = get(res, "SelectedZoom", 0.5)

        fd = Sys_Fast.FAST_Data_DDEC

        display_conf = map(new_conf) do c
            Dict{String,Any}(string(k) => v for (k,v) in pairs(c))
        end

        slots = Dict{String,Any}[]
        if !isnothing(slot_cfg) && (slot_cfg isa AbstractDict || slot_cfg isa Dict) && haskey(slot_cfg, "Slots")
            raw_slots = slot_cfg["Slots"]
            if raw_slots isa AbstractVector
                slots = [(s isa AbstractDict || s isa Dict) ? Dict{String,Any}(string(k) => v for (k,v) in pairs(s)) : Dict{String,Any}() for s in raw_slots]
            end
        end

        LENS_ApplySlotCustomisation_DDEF!(display_conf, slots, leader_vals)

        # Separate active components (excluding deleted constants) for stoichiometry audit & graph
        active_conf = filter(c -> !(lowercase(strip(string(LENS_GetSafe_DDEF(c, "Role", "")))) in ("fixed", "fix") && string(LENS_GetSafe_DDEF(c, "Name", "")) in excluded), display_conf)

        # Dynamic Direction Labels for X1, X2, X3
        active_vars = filter(c -> get(c, "Role", "") == fd.ROLE_VAR, active_conf)
        subscripts  = ("₁", "₂", "₃")
        lbls = [k <= length(active_vars) ? "$(get(active_vars[k], "Name", "Var $k")) (X$(subscripts[k])) Direction" : "X$(subscripts[k]) Direction" for k in 1:3]

        d_vec = [dx isa Number ? Int(dx) : something(tryparse(Int, string(something(dx, -1))), -1) for dx in (dir_x1, dir_x2, dir_x3)]
        m_str = string(something(meth_val, "TL09"))

        audit_rows = [Dict(
            "Name" => string(get(c, "Name", "Unknown")),
            "Role" => string(get(c, "Role", "Fixed")),
            "L1"   => Float64(get(c, "Levels", [0.0, 0.0, 0.0])[1]),
            "L2"   => Float64(get(c, "Levels", [0.0, 0.0, 0.0])[2]),
            "L3"   => Float64(get(c, "Levels", [0.0, 0.0, 0.0])[3]),
            "MW"   => Float64(get(c, "MW", 0.0)),
            "Unit" => string(get(c, "Unit", "-"))
        ) for c in active_conf]

        audit_ok, audit_report, audit_results, _, _ = Main.Lib_Mole.MOLE_QuickAudit_DDEF(audit_rows, vol, conc)

        if !isempty(audit_results)
            for c in active_conf
                get(c, "Role", "") != fd.ROLE_FILL && continue
                m_idx = findfirst(==(get(c, "Name", "")), audit_results.Component)
                !isnothing(m_idx) && (c["Levels"] = [0.0, audit_results[m_idx, :TARGET_MASS_mg], 0.0])
            end
        end

        fig = Sys_Flow.FLOW_RenderPhaseTransition_DDEF(old_conf, active_conf, leader_vals; Method=m_str, Direction=d_vec)

        var_slot_idx = 0
        fix_idx = 0
        rows = []
        for c in display_conf
            role = get(c, "Role", "Variable")
            lvls = get(c, "Levels", [0.0, 0.0, 0.0])
            c_name = string(LENS_GetSafe_DDEF(c, "Name", "???"))
            is_fixed = lowercase(strip(string(role))) in ("fixed", "fix")
            is_excluded = is_fixed && (c_name in excluded)

            slot_mode = role == fd.ROLE_VAR ? (var_slot_idx += 1; var_slot_idx <= length(slots) ? get(slots[var_slot_idx], "Mode", "KEEP") : "KEEP") : ""
            mode_badge = slot_mode in ("SCALE", "REPLACE") ? html_span(slot_mode == "SCALE" ? " S" : " R", className="badge ms-1 colourbg-c3tc colourtx-v5pb", style=Dict("fontSize" => "8px")) : ""

            disp_name = c_name
            r_opts = get(res, "RadioOpts", Dict{String,Any}())
            if get(r_opts, "Apply", false)
                alias = get(get(r_opts, "Forward", Dict{String,Any}()), disp_name, Dict{String,Any}())
                !isempty(get(alias, "Name", "")) && (disp_name = alias["Name"])
            end

            disp_unit = get(c, "Unit", "")
            final_name = (isempty(disp_unit) || disp_unit == "-") ? disp_name : "$disp_name $disp_unit"

            l1_s = string(round(lvls[1]; digits=3))
            l2_s = string(round(lvls[2]; digits=3))
            l3_s = string(round(lvls[3]; digits=3))

            btn_cell = ""
            if is_fixed
                fix_idx += 1
                btn_id = "lens-const-del-$fix_idx"
                btn_icon = is_excluded ? "fas fa-undo colourtx-c1sm" : "fas fa-trash-alt colourtx-c0hr"
                btn_title = is_excluded ? "Restore $c_name to phase" : "Exclude $c_name from Phase"
                btn_cell = dbc_button(
                    html_i(className=btn_icon, style=Dict("fontSize" => "11px")),
                    id=btn_id, color="link", size="sm", className="p-0 border-0 text-decoration-none shadow-none",
                    style=Dict("width" => "22px", "height" => "22px", "display" => "inline-flex", "alignItems" => "center", "justifyContent" => "center", "cursor" => "pointer"),
                    title=btn_title
                )
            end

            if is_excluded
                push!(rows, html_tr([
                    html_td([html_s(final_name), html_span(" (Excluded)", className="badge bg-secondary ms-1", style=Dict("fontSize" => "8px"))], className="text-muted opacity-75"),
                    html_td(html_s(role), className="text-muted opacity-75"),
                    html_td(html_s(l1_s), className="text-muted opacity-75"),
                    html_td(html_s(l2_s), className="colourbg-v0pw text-muted opacity-75"),
                    html_td(html_s(l3_s), className="text-muted opacity-75"),
                    html_td(btn_cell, className="text-center")
                ], className="table-light"))
            else
                role_cls = role == fd.ROLE_VAR ? "colourtx-c1sm fw-bold" : "colourtx-v5pb"
                push!(rows, html_tr([
                    html_td([final_name, mode_badge]),
                    html_td(role, className=role_cls),
                    html_td(l1_s),
                    html_td(html_b(l2_s), className="colourbg-v0pw"),
                    html_td(l3_s),
                    html_td(btn_cell, className="text-center")
                ]))
            end
        end

        tbl = html_table([
            html_thead(html_tr([
                html_th("Ingredient"), html_th("Role"), html_th("Min"), html_th("Centre"), html_th("Max"),
                html_th("Action", className="text-center", style=Dict("width" => "55px"))
            ])),
            html_tbody(rows)
        ], className="table table-sm table-hover align-middle small")

        # Dummy hidden buttons for any unused indices up to 5, ensuring Dash never lacks Input targets
        dummy_buttons = html_div([
            dbc_button(id="lens-const-del-$k", style=Dict("display" => "none")) for k in (fix_idx+1):5
        ], style=Dict("display" => "none"))

        tbl_component = html_div([tbl, dummy_buttons])

        audit_html = if audit_ok
            dbc_alert([
                html_h5([html_i(className="fas fa-check-circle me-2"), "Stoichiometry Audit (Proposed Phase): PASS"], className="alert-heading small fw-bold"),
                html_hr(),
                html_pre(audit_report, className="mb-0 x-small", style=Dict("fontFamily" => "monospace"))
            ], className="shadow-sm border-0 py-3 colourgl-c4tg colourtx-v5pb", style=Dict("borderColor" => "var(--colour-chr4-tongre)"))
        else
            dbc_alert([
                html_h6([html_i(className="fas fa-exclamation-triangle me-2"), "Stoichiometric limits exceeded or configuration missing for this phase."], className="mb-0 small fw-bold")
            ], className="shadow-sm border-0 py-3 colourgl-neut colourtx-v5pb", style=Dict("borderColor" => "var(--colour-val3-darlow)"))
        end

        radio_warn = get(res, "IsRadioCorrected", false) ? dbc_alert([
            html_div([
                html_i(className="fas fa-radiation-alt fa-2x me-3"),
                html_div([
                    html_h6("DECAY-CORRECTION DETECTED", className="fw-bold mb-1"),
                    html_p("Values are decay-corrected. Calculate required radioactivity and masses for your next experiment.", className="mb-0 small")
                ])
            ], className="d-flex align-items-center")
        ], className="mt-3 border-0 shadow colourgl-c5hy colourtx-v5pb") : html_div()

        return tbl_component, [audit_html, radio_warn], fig, lbls[1], lbls[2], lbls[3]
    end

    callback!(app,
        Output("lens-store-excluded-constants", "data"),
        Input("lens-store-next-phase-proposal", "data"),
        [Input("lens-const-del-$i", "n_clicks") for i in 1:5]...,
        State("lens-store-excluded-constants", "data"),
        State("lens-store-next-phase-proposal", "data"),
        prevent_initial_call=true
    ) do prop_data, c1, c2, c3, c4, c5, cur_excluded, prop_state
        trig = BASE_GetTrigger_DDEF(callback_context())
        prop = (!isnothing(prop_state) && (haskey(prop_state, "NewConfig") || haskey(prop_state, :NewConfig))) ? prop_state : 
               (!isnothing(prop_data) && (haskey(prop_data, "NewConfig") || haskey(prop_data, :NewConfig)) ? prop_data : Dict{String,Any}())
        if trig == "lens-store-next-phase-proposal" || isempty(prop)
            return String[]
        end

        excluded = (isnothing(cur_excluded) || !(cur_excluded isa AbstractVector)) ? String[] : String[string(x) for x in cur_excluded]

        for i in 1:5
            if trig == "lens-const-del-$i"
                conf = LENS_GetSafe_DDEF(prop, "NewConfig", [])
                fixed_items = [c for c in conf if lowercase(strip(string(LENS_GetSafe_DDEF(c, "Role", "")))) in ("fixed", "fix")]
                if i <= length(fixed_items)
                    c_name = string(LENS_GetSafe_DDEF(fixed_items[i], "Name", ""))
                    if c_name in excluded
                        filter!(x -> x != c_name, excluded)
                    else
                        push!(excluded, c_name)
                    end
                end
                break
            end
        end
        return unique(excluded)
    end

    callback!(app,
        Output("lens-download-phase", "data"),
        Output("lens-signal-process", "data"),
        Input("lens-prev-btn-commit", "n_clicks"),
        State("lens-store-next-phase-proposal", "data"),
        State("lens-table-candidates", "selected_rows"),
        State("lens-table-candidates", "data"),
        State("lens-wiz-dd-source",    "value"),
        State("store-master-vault",    "data"),
        State("lens-input-project",    "value"),
        State("lens-store-slot-config", "data"),
        State("lens-prev-dir-x1",      "value"),
        State("lens-prev-dir-x2",      "value"),
        State("lens-prev-dir-x3",      "value"),
        State("lens-store-excluded-constants", "data"),
        prevent_initial_call=true
    ) do n_commit, proposal, sel_rows, cand_data, src, base64_file, proj_v, slot_cfg, dir_x1, dir_x2, dir_x3, excluded_raw
        (isnothing(n_commit) || n_commit == 0 || isnothing(proposal) || get(proposal, "Status", "") != "OK") && return Dash.no_update()
        (isnothing(sel_rows) || isempty(sel_rows)) && return Dash.no_update()

        row_sel = cand_data[sel_rows[1]+1]
        sel_id = haskey(row_sel, "EXP_ID") ? string(row_sel["EXP_ID"]) :
                 haskey(row_sel, "ID")     ? string(row_sel["ID"]) :
                 haskey(row_sel, :EXP_ID)  ? string(row_sel[:EXP_ID]) :
                 haskey(row_sel, :ID)      ? string(row_sel[:ID]) : ""

        zoom  = get(proposal, "SelectedZoom", 0.5)
        shift = get(proposal, "SelectedShift", 0.0)
        meth  = get(proposal, "SelectedMethod", "TL09")

        safe_dir(x) = x isa Number ? Int(x) : something(tryparse(Int, string(something(x, -1))), -1)
        direction_vec = [safe_dir(dir_x1), safe_dir(dir_x2), safe_dir(dir_x3)]

        excluded = (isnothing(excluded_raw) || !(excluded_raw isa AbstractVector)) ? String[] : String[string(x) for x in excluded_raw]

        slots = Dict{String,Any}[]
        if !isnothing(slot_cfg) && (slot_cfg isa AbstractDict || slot_cfg isa Dict) && haskey(slot_cfg, "Slots")
            raw = slot_cfg["Slots"]
            if raw isa AbstractVector
                slots = [(s isa AbstractDict || s isa Dict) ? Dict{String,Any}(string(k) => v for (k,v) in pairs(s)) : Dict{String,Any}() for s in raw]
            end
        end

        has_custom = any(get(s, "Mode", "KEEP") != "KEEP" || haskey(s, "NewMin") || haskey(s, "NewMax") for s in slots) || !isempty(excluded)

        custom_conf = nothing
        if haskey(proposal, "NewConfig")
            base_new_conf = proposal["NewConfig"]
            custom_conf = [Dict{String,Any}(string(k) => (v isa AbstractVector ? copy(v) : v) for (k,v) in pairs(c)) for c in base_new_conf]
            leader_vals = get(proposal, "LeaderValues", Float64[])
            LENS_ApplySlotCustomisation_DDEF!(custom_conf, slots, leader_vals)
            filter!(c -> !(lowercase(strip(string(LENS_GetSafe_DDEF(c, "Role", "")))) in ("fixed", "fix") && string(LENS_GetSafe_DDEF(c, "Name", "")) in excluded), custom_conf)
        end

        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)
        res  = Sys_Flow.FLOW_BuildNextPhase_DDEF(
            path, src, sel_id, Float64(zoom), meth, Float64(shift);
            Direction=direction_vec,
            CustomConfig=has_custom ? custom_conf : nothing
        )

        if res["Status"] == "OK"

            new_vault = Sys_Fast.FAST_ReadToStore_DDEF(path)
            _, bytes = Sys_Fast.FAST_PrepareDownload_DDEF(path)
            Sys_Fast.FAST_CleanTransient_DDEF(path)

            proj_n = (isnothing(proj_v) || isempty(strip(string(proj_v)))) ? "DoECISORY" : string(proj_v)
            fname = Sys_Fast.FAST_GenerateSmartName_DDEF(proj_n, res["TargetPhase"], "EVO", "xlsx")

            return (
                Dict("filename" => fname, "content" => base64encode(bytes), "base64" => true),
                Dict("success"  => true, "msg" => "Phase Created Successfully", "base64" => new_vault)
            )
        else
            Sys_Fast.FAST_CleanTransient_DDEF(path)
            return Dash.no_update(), Dict("success" => false, "msg" => res["Message"])
        end
    end

# ------------------------------------------------------------------------------
# SECTION 14: DATA & PLOT EXPORT
# ------------------------------------------------------------------------------

    callback!(app,
        Output("lens-download-plots",        "data"),
        Output("lens-export-plots-status", "children"),
        Input("lens-btn-export-plots", "n_clicks"),
        State("lens-input-project",    "value"),
        State("lens-dd-phase",         "value"),
        State("lens-store-graphs-blob", "data"),
        prevent_initial_call=true
    ) do n, proj_v, phase_v, blob_st
        (isnothing(n) || n == 0 || isnothing(blob_st) || isempty(blob_st)) &&
            return Dash.no_update(), Dash.no_update()

        graphs = JSON3.read(blob_st, Vector{Dict{String, Any}})
        isempty(graphs) && return Dash.no_update(), Dash.no_update()

        try
            # Standardised Naming: Project, Phase, Tag (ARTS), Extension (zip)
            proj_n = (isnothing(proj_v) || isempty(strip(string(proj_v)))) ? "DoECISORY" : string(proj_v)
            ph_n   = (isnothing(phase_v) || isempty(strip(string(phase_v)))) ? "Phase1" : string(phase_v)
            fname  = Sys_Fast.FAST_GenerateSmartName_DDEF(proj_n, ph_n, "ARTS", "zip")

            temp_uuid  = replace(string(Base.UUID(rand(UInt128))), "-" => "")
            export_dir = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DoECISORYRender_$temp_uuid")
            mkpath(export_dir)

            count = 0
            for (i, g) in enumerate(graphs)
                title      = get(g, "title", "Plot_$i")
                safe_title = Sys_Fast.FAST_SanitiseFilename_DDEF(title)
                filepath   = joinpath(export_dir, "$(safe_title).png")

                fig_dict = g["figure"]
                layout_dict = deepcopy(fig_dict["layout"])
                layout_dict["width"]  = 640
                layout_dict["height"] = 800
                if !haskey(layout_dict, "margin") layout_dict["margin"] = Dict() end
                layout_dict["margin"]["t"] = 130

                p = Plot([GenericTrace(d) for d in fig_dict["data"]], Layout(layout_dict))
                savefig(p, filepath; width=640, height=800, scale=1.0)
                count += 1
            end

            zip_path = joinpath(Sys_Fast.FAST_TempRoot_DDEC, fname)
            let zdir = ZipFile.Writer(zip_path)
                for file in readdir(export_dir)
                    fpath = joinpath(export_dir, file)
                    f     = ZipFile.addfile(zdir, file; method=ZipFile.Deflate)
                    write(f, read(fpath))
                end
                close(zdir)
            end

            bytes = read(zip_path)
            rm(export_dir; recursive=true, force=true)
            rm(zip_path; force=true)

            Sys_Fast.FAST_Log_DDEF("LENS", "Export", "Zipped $count high-res plots.", "OK")
            return (
                Dict("filename" => fname, "content" => base64encode(bytes), "base64" => true),
                html_span([html_i(className="fas fa-check-circle me-2"), "Successfully downloaded $count High-Res plots."], className="fw-bold colourtx-c4tg"),
            )
        catch e
            Sys_Fast.FAST_Log_DDEF("LENS", "Export_Error", string(e), "FAIL")
            return Dash.no_update(), html_span([html_i(className="fas fa-times-circle me-2"), "Error during plot export (Kaleido missing?): $e"], className="fw-bold colourtx-c0hr")
        end
    end

    callback!(app,
        Output("lens-download-analysis",     "data"),
        Output("lens-export-excel-status", "children"),
        Input("lens-btn-export-excel", "n_clicks"),
        State("lens-store-results",    "data"),
        State("lens-input-project",    "value"),
        State("lens-dd-phase",         "value"),
        State("store-master-vault",    "data"),
        prevent_initial_call=true
    ) do n, res, proj, phase, mv
        (isnothing(n) || n == 0 || isnothing(res) || isempty(res)) && return Dash.no_update(), Dash.no_update()
        isnothing(mv) && return Dash.no_update(), html_span("❌ No data source found.", className="colourtx-c0hr")

        path = ""
        try
            path = Sys_Fast.FAST_GetTransientPath_DDEF(mv)
 
            success = Lib_Vise.VISE_ExportToExcel_DDEF(res, path)

            if success
                bytes = read(path)
                
                # Standardised Naming: Project, Phase, Tag (SCI), Extension (xlsx)
                proj_n = (isnothing(proj) || isempty(strip(string(proj)))) ? "DoECISORY" : string(proj)
                ph_n   = (isnothing(phase) || isempty(strip(string(phase)))) ? "Phase1" : string(phase)
                fname  = Sys_Fast.FAST_GenerateSmartName_DDEF(proj_n, ph_n, "SCI", "xlsx")

                return (
                    Dict("filename" => fname, "content" => base64encode(bytes), "base64" => true),
                    html_span([html_i(className="fas fa-check-circle me-1"), "Scientific XLSX downloaded."], className="fw-bold small colourtx-c4tg")
                )
            else
                return Dash.no_update(), html_span([html_i(className="fas fa-times-circle me-1"), "Excel export failed."], className="small colourtx-c0hr")
            end
        catch e
            Sys_Fast.FAST_Log_DDEF("LENS", "EXCEL_EXPORT_FAIL", string(e), "FAIL")
            return Dash.no_update(), html_span([html_i(className="fas fa-times-circle me-1"), "Export Error: $e"], className="small colourtx-c0hr")
        finally
            Sys_Fast.FAST_CleanTransient_DDEF(path)
        end
    end

# ------------------------------------------------------------------------------
# SECTION 15: RADIOACTIVITY CORRECTION
# ------------------------------------------------------------------------------

    # 1. Open/Close Modal
    callback!(app,
        Output("lens-modal-radio-config", "is_open"),
        Input("lens-btn-radio-correct", "n_clicks"),
        Input("lens-radio-btn-cancel", "n_clicks"),
        Input("lens-radio-btn-apply", "n_clicks"),
        State("lens-modal-radio-config", "is_open"),
        prevent_initial_call=true
    ) do n1, n2, n3, is_open
        trig = BASE_GetTrigger_DDEF(callback_context())
        
        # Explicit type conversion to handle Dash.jl integers parsing booleans as 0 or 1.
        current_state = (is_open == true || is_open == 1)
        
        if trig == "lens-radio-btn-cancel" || trig == "lens-radio-btn-apply"
            return false
        elseif trig == "lens-btn-radio-correct"
            return !current_state
        end
        return Dash.no_update()
    end

    # 2. Populate Modal Options from Smart Vault Data
    # Unit 1: Radioactivity - Forward Configuration (Inputs)
    callback!(app,
        Output("lens-radio-dd-inputs", "options"),
        Output("lens-radio-dd-inputs", "value"),
        [Output("lens-radio-in-name-$i", "value") for i in 1:6]...,
        [Output("lens-radio-in-unit-$i", "value") for i in 1:6]...,
        Input("lens-modal-radio-config", "is_open"),
        State("store-master-vault", "data"),
        prevent_initial_call=true
    ) do is_open, active_data
        (!is_open || isnothing(active_data) || active_data == "") && return [], [], fill("", 6)..., fill("", 6)...
        
        active_cont = active_data isa String ? active_data : get(active_data, "content", "")
        (isnothing(active_cont) || active_cont == "") && return [], [], fill("", 6)..., fill("", 6)...

        path   = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)
        config = Sys_Fast.FAST_ReadConfig_DDEF(path)
        Sys_Fast.FAST_CleanTransient_DDEF(path)

        ingreds = get(config, "Ingredients", [])
        rad_inputs = filter(i -> get(i, "IsRadioactive", false) == true || Sys_Fast.FAST_SafeNum_DDEF(get(i, "HalfLife", 0.0)) > 0, ingreds)
        in_options = [Dict("label" => get(i, "Name", ""), "value" => get(i, "Name", "")) for i in rad_inputs]
        
        radio_opts = get(config, "RadioOpts", Dict{String,Any}())
        fwd_dict = get(radio_opts, "Forward", Dict{String,Any}())
        fwd_keys = collect(keys(fwd_dict))

        in_names = fill("", 6); in_units = fill("", 6)
        for (idx, k) in enumerate(fwd_keys[1:min(length(fwd_keys), 6)])
            in_names[idx] = get(fwd_dict[k], "Name", "")
            in_units[idx] = get(fwd_dict[k], "Unit", "")
        end
        return in_options, fwd_keys, in_names..., in_units...
    end

    function LENS_IsRadioactiveTarget_DDEF(name::String, unit::String)
        u = lowercase(strip(unit))
        n = lowercase(strip(name))
        
        # Selection of outputs explicitly bearing absolute radiochemical measurement units.
        if occursin(r"\b(mci|mbq|ci|gbq|kbq|bq|cpm|cps|dpm|dps)\b|radioactivity|radio-activity", u)
            return true
        end
        
        # Fallback extrapolation for percentage-based yields mapping directly to isotope conversion efficiency.
        if occursin(r"\b(mci|mbq|ci|gbq|kbq|bq|cpm|cps|dpm|dps)\b|radioactivity|radio-activity|yield|rcy|rad\b|decay", n)
            return true
        end
        
        return false
    end

    # Unit 2: Radioactivity - Reverse Mapping (Outputs)
    callback!(app,
        [Output("lens-radio-out-dd-$i", "options") for i in 1:6]...,
        [Output("lens-radio-out-div-$i", "className") for i in 1:6]...,
        [Output("lens-radio-out-lbl-$i", "children") for i in 1:6]...,
        [Output("lens-radio-out-dd-$i", "value") for i in 1:6]...,
        [Output("lens-radio-out-name-$i", "value") for i in 1:6]...,
        [Output("lens-radio-out-unit-$i", "value") for i in 1:6]...,
        Input("lens-modal-radio-config", "is_open"),
        State("store-master-vault", "data"),
        prevent_initial_call=true
    ) do is_open, active_data
        (!is_open || isnothing(active_data) || active_data == "") && return fill([Dict("label"=>"None", "value"=>"None")], 6)..., fill("d-none", 6)..., fill("", 6)..., fill("None", 6)..., fill("", 6)..., fill("", 6)...
        
        active_cont = active_data isa String ? active_data : get(active_data, "content", "")
        (isnothing(active_cont) || active_cont == "") && return fill([Dict("label"=>"None", "value"=>"None")], 6)..., fill("d-none", 6)..., fill("", 6)..., fill("None", 6)..., fill("", 6)..., fill("", 6)...

        path   = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)
        config = Sys_Fast.FAST_ReadConfig_DDEF(path)
        Sys_Fast.FAST_CleanTransient_DDEF(path)

        ingreds = get(config, "Ingredients", [])
        outputs = get(config, "Outputs", [])
        
        rad_inputs = filter(i -> get(i, "IsRadioactive", false) == true || Sys_Fast.FAST_SafeNum_DDEF(get(i, "HalfLife", 0.0)) > 0, ingreds)
        in_options = [Dict("label" => get(i, "Name", ""), "value" => get(i, "Name", "")) for i in rad_inputs]
        
        out_options = [Dict("label" => "None", "value" => "None")]
        append!(out_options, in_options)

        radio_opts = get(config, "RadioOpts", Dict{String,Any}())
        rev_dict = get(radio_opts, "ReverseMap", Dict{String,Any}())
        
        out_div_classes = fill("d-none", 6); out_lbls = fill("", 6)
        out_src_vals = fill("None", 6); out_names = fill("", 6); out_units = fill("", 6)

        rad_outputs = filter(o -> get(o, "IsRadioactive", false) == true || LENS_IsRadioactiveTarget_DDEF(get(o, "Name", ""), get(o, "Unit", "")), outputs)

        for (idx, o) in enumerate(rad_outputs[1:min(length(rad_outputs), 6)])
            out_name = get(o, "Name", "")
            out_div_classes[idx] = "mb-3 d-block"; out_lbls[idx] = out_name
            if haskey(rev_dict, out_name)
                mapping = rev_dict[out_name]
                out_src_vals[idx] = get(mapping, "Source", "None")
                out_names[idx]    = get(mapping, "Name", "")
                out_units[idx]    = get(mapping, "Unit", "")
            end
        end
        return fill(out_options, 6)..., out_div_classes..., out_lbls..., out_src_vals..., out_names..., out_units...
    end

    # 2.5 Dynamic Input Row Visibility Toggle & Intelligent Suggestions
    callback!(app,
        [Output("lens-radio-in-div-$i", "className") for i in 1:6]...,
        [Output("lens-radio-in-lbl-$i", "children") for i in 1:6]...,
        [Output("lens-radio-in-name-$i", "placeholder") for i in 1:6]...,
        [Output("lens-radio-in-unit-$i", "placeholder") for i in 1:6]...,
        Input("lens-radio-dd-inputs", "value"),
        prevent_initial_call=true
    ) do sel_vals
        vals = isnothing(sel_vals) ? String[] : (sel_vals isa String ? [sel_vals] : convert(Vector{String}, sel_vals))
        cls = fill("d-none", 6)
        lbl = fill("", 6)
        ph_names = fill("Corrected Display Alias", 6)
        ph_units = fill("Measurement Unit", 6)
        
        for (i, v) in enumerate(vals[1:min(length(vals), 6)])
            cls[i] = "mb-2 d-block"
            lbl[i] = v
            
            # Active Contextual Placeholder Generation for Inputs (Forward Decay)
            if !isnothing(v) && v != ""
                ph_names[i] = "e.g. Decayed $v"
                ph_units[i] = "e.g. MBq"
            end
        end
        return tuple(cls..., lbl..., ph_names..., ph_units...)
    end

    # 2.8 Dynamic Output Row Visibility Toggle & Intelligent Suggestions
    callback!(app,
        [Output("lens-radio-out-alias-div-$i", "className") for i in 1:6]...,
        [Output("lens-radio-out-name-$i", "placeholder") for i in 1:6]...,
        [Output("lens-radio-out-unit-$i", "placeholder") for i in 1:6]...,
        [Input("lens-radio-out-dd-$i", "value") for i in 1:6]...,
        [State("lens-radio-out-lbl-$i", "children") for i in 1:6]...,
        prevent_initial_call=true
    ) do sel_args...
        sel_vals = sel_args[1:6]
        lbl_vals = sel_args[7:12]
        
        cls = fill("g-1 d-none", 6)
        ph_names = fill("Corrected Result Display Alias", 6)
        ph_units = fill("Measurement Unit", 6)
        
        for i in 1:6
            v = sel_vals[i]
            if !isnothing(v) && v != "None" && v != ""
                cls[i] = "g-1 mt-1 d-flex"
                
                # Active Contextual Placeholder Generation
                cur_lbl = lbl_vals[i]
                if !isnothing(cur_lbl) && cur_lbl != ""
                    clean_lbl = strip(replace(cur_lbl, r"(?i)yield|rcy|\(mbq\)|\(mci\)|\(ci\)|\(gbq\)|\(kbq\)|\(bq\)|\(cpm\)|\(cps\)|\(%|%\)|%" => ""))
                    if isempty(clean_lbl)
                        clean_lbl = "Activity"
                    end
                    ph_names[i] = "e.g. $clean_lbl Yield"
                    ph_units[i] = "e.g. %"
                end
            end
        end
        return tuple(cls..., ph_names..., ph_units...)
    end

    # 3. Apply Configuration & Master Vault Sync
    callback!(app,
        Output("sync-lens-content",        "data"),
        Input("lens-radio-btn-apply", "n_clicks"),
        Input("lens-upload-data",     "contents"),
        State("lens-upload-data",     "filename"),
        State("store-master-vault",   "data"),
        State("lens-radio-dd-inputs", "value"),
        [State("lens-radio-in-lbl-$i", "children") for i in 1:6]...,
        [State("lens-radio-in-name-$i", "value") for i in 1:6]...,
        [State("lens-radio-in-unit-$i", "value") for i in 1:6]...,
        [State("lens-radio-out-lbl-$i", "children") for i in 1:6]...,
        [State("lens-radio-out-dd-$i", "value") for i in 1:6]...,
        [State("lens-radio-out-name-$i", "value") for i in 1:6]...,
        [State("lens-radio-out-unit-$i", "value") for i in 1:6]...,
        prevent_initial_call=true
    ) do apply_clicks, upload_cont, upload_fname, active_cont, fwd_inputs, 
         il1, il2, il3, il4, il5, il6,
         in1, in2, in3, in4, in5, in6,
         iu1, iu2, iu3, iu4, iu5, iu6,
         ol1, ol2, ol3, ol4, ol5, ol6,
         od1, od2, od3, od4, od5, od6,
         on1, on2, on3, on4, on5, on6,
         ou1, ou2, ou3, ou4, ou5, ou6

        trig = BASE_GetTrigger_DDEF(callback_context())
        
        if trig == "lens-upload-data"
            (isnothing(upload_cont) || upload_cont == "") && return Dash.no_update()
            return Dict("content" => upload_cont, "filename" => upload_fname)
        end

        if trig == "lens-radio-btn-apply"
            (isnothing(apply_clicks) || apply_clicks == 0) && return Dash.no_update()
            (isnothing(active_cont) || active_cont == "") && return Dash.no_update()

            # Robust handle extraction for scientific configuration updates.
            handle = active_cont isa String ? active_cont : get(active_cont, "content", "")
            (isnothing(handle) || handle == "") && return Dash.no_update()

            in_lbls  = [il1, il2, il3, il4, il5, il6]
            in_names = [in1, in2, in3, in4, in5, in6]
            in_units = [iu1, iu2, iu3, iu4, iu5, iu6]
            
            out_lbls  = [ol1, ol2, ol3, ol4, ol5, ol6]
            out_srcs  = [od1, od2, od3, od4, od5, od6]
            out_names = [on1, on2, on3, on4, on5, on6]
            out_units = [ou1, ou2, ou3, ou4, ou5, ou6]

            fwd_arr = isnothing(fwd_inputs) ? String[] : (fwd_inputs isa String ? [fwd_inputs] : convert(Vector{String}, fwd_inputs))
            fwd_dict = Dict{String, Any}()
            
            for fwd in fwd_arr
                idx = findfirst(==(fwd), in_lbls)
                if !isnothing(idx)
                    fwd_dict[fwd] = Dict(
                        "Name" => isnothing(in_names[idx]) ? "" : in_names[idx], 
                        "Unit" => isnothing(in_units[idx]) ? "" : in_units[idx]
                    )
                end
            end

            rev_dict = Dict{String, Any}()
            for i in 1:6
                lbl = out_lbls[i]
                src = out_srcs[i]
                if !isnothing(lbl) && lbl != "" && !isnothing(src) && src != "None"
                    rev_dict[lbl] = Dict(
                        "Source" => src, 
                        "Name"   => isnothing(out_names[i]) ? "" : out_names[i], 
                        "Unit"   => isnothing(out_units[i]) ? "" : out_units[i]
                    )
                end
            end

            apply_flag = !isempty(fwd_dict) || !isempty(rev_dict)
            new_radio_opts = Dict(
                "Apply" => apply_flag,
                "Forward" => fwd_dict,
                "ReverseMap" => rev_dict
            )

            path   = Sys_Fast.FAST_GetTransientPath_DDEF(handle)
            Sys_Fast.FAST_UpdateConfig_DDEF(path, Dict("RadioOpts" => new_radio_opts))
            new_vault = Sys_Fast.FAST_ReadToStore_DDEF(path)
            Sys_Fast.FAST_CleanTransient_DDEF(path)

            return new_vault
        end

        return Dash.no_update()
    end

    callback!(app,
        Output("lens-store-radio-correct", "data"),
        Output("lens-btn-radio-correct",   "className"),
        Output("lens-icon-radio-correct",  "className"),
        Input("store-master-vault", "data"),
        prevent_initial_call=true
    ) do active_data
        (isnothing(active_data) || active_data == "") && return false, "w-100 fw-bold lens-radio-inactive", "fas fa-radiation-alt me-2"
        
        active_cont = active_data isa String ? active_data : get(active_data, "content", "")
        (isnothing(active_cont) || active_cont == "") && return false, "w-100 fw-bold lens-radio-inactive", "fas fa-radiation-alt me-2"

        path   = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)
        config = Sys_Fast.FAST_ReadConfig_DDEF(path)
        Sys_Fast.FAST_CleanTransient_DDEF(path)
        
        radio_opts = get(config, "RadioOpts", Dict("Apply" => false))
        apply_flag = get(radio_opts, "Apply", false)

        btn_class = apply_flag ? "w-100 fw-bold lens-radio-active" : "w-100 fw-bold lens-radio-inactive"
        icon = apply_flag ? "fas fa-check-circle me-2" : "fas fa-times-circle me-2"

        return apply_flag, btn_class, icon
    end

# ------------------------------------------------------------------------------
# SECTION 16: PHASE EVOLUTION SLOT CONFIGURATION
# ------------------------------------------------------------------------------

    callback!(app,
        [Output("lens-slot-scale-div-$i",   "style") for i in 1:3]...,
        [Output("lens-slot-replace-div-$i", "style") for i in 1:3]...,
        [Input("lens-slot-mode-$i", "value") for i in 1:3]...,
        prevent_initial_call=true
    ) do m1, m2, m3
        modes = [m1, m2, m3]
        show   = Dict("display" => "block")
        hide   = Dict("display" => "none")
        scale  = [m == "SCALE"   ? show : hide for m in modes]
        repl   = [m == "REPLACE" ? show : hide for m in modes]
        return (scale..., repl...)
    end

    callback!(app,
        Output("lens-store-slot-config", "data"),
        [Output("lens-slot-transformed-$i", "children") for i in 1:3]...,
        [Input("lens-slot-mode-$i",  "value") for i in 1:3]...,
        [Input("lens-slot-alpha-$i", "value") for i in 1:3]...,
        [Input("lens-slot-beta-$i",  "value") for i in 1:3]...,
        [Input("lens-slot-scale-name-$i", "value") for i in 1:3]...,
        [Input("lens-slot-scale-min-$i",  "value") for i in 1:3]...,
        [Input("lens-slot-scale-max-$i",  "value") for i in 1:3]...,
        [Input("lens-slot-replace-name-$i", "value") for i in 1:3]...,
        [Input("lens-slot-replace-unit-$i", "value") for i in 1:3]...,
        [Input("lens-slot-replace-l1-$i",   "value") for i in 1:3]...,
        [Input("lens-slot-replace-l2-$i",   "value") for i in 1:3]...,
        [Input("lens-slot-replace-l3-$i",   "value") for i in 1:3]...,
        [Input("lens-slot-replace-min-$i",  "value") for i in 1:3]...,
        [Input("lens-slot-replace-max-$i",  "value") for i in 1:3]...,
        State("lens-store-next-phase-proposal", "data"),
        prevent_initial_call=true
    ) do m1, m2, m3, a1, a2, a3, b1, b2, b3,
         sn1, sn2, sn3, smin1, smin2, smin3, smax1, smax2, smax3,
         rn1, rn2, rn3, ru1, ru2, ru3, rl1a, rl1b, rl1c, rl2a, rl2b, rl2c, rl3a, rl3b, rl3c, rmin1, rmin2, rmin3, rmax1, rmax2, rmax3, proposal

        modes  = [m1, m2, m3]
        alphas = [a1, a2, a3]
        betas  = [b1, b2, b3]
        
        snames = [sn1, sn2, sn3]
        smins  = [smin1, smin2, smin3]
        smaxs  = [smax1, smax2, smax3]
        
        rnames = [rn1, rn2, rn3]
        runits = [ru1, ru2, ru3]
        rl1s   = [rl1a, rl1b, rl1c]
        rl2s   = [rl2a, rl2b, rl2c]
        rl3s   = [rl3a, rl3b, rl3c]
        rmins  = [rmin1, rmin2, rmin3]
        rmaxs  = [rmax1, rmax2, rmax3]

        leader_vals = Float64[]
        if !isnothing(proposal) && (proposal isa AbstractDict || proposal isa Dict) && haskey(proposal, "LeaderValues")
            leader_vals = Float64.(get(proposal, "LeaderValues", Float64[]))
        end

        transformed_displays = fill("—", 3)
        slots = Dict{String,Any}[]
        for i in 1:3
            mode = isnothing(modes[i]) ? "KEEP" : string(modes[i])
            α  = Sys_Fast.FAST_SafeNum_DDEF(isnothing(alphas[i]) ? 1.0 : alphas[i])
            β  = Sys_Fast.FAST_SafeNum_DDEF(isnothing(betas[i])  ? 0.0 : betas[i])

            slot = Dict{String,Any}("Mode" => mode, "Alpha" => α, "Beta" => β)

            # Utilisation of global input validation helpers from Sys_Fast
            has_str(v) = Sys_Fast.FAST_IsPopulatedInput_DDEF(v)
            has_num(v) = Sys_Fast.FAST_IsNumericInput_DDEF(v)

            # Explicit extraction vectors to ensure index-safety
            r_l1s = [rl1a, rl1b, rl1c]
            r_l2s = [rl2a, rl2b, rl2c]
            r_l3s = [rl3a, rl3b, rl3c]

            if mode == "SCALE"
                slot["NewName"] = isnothing(snames[i]) ? "" : string(snames[i])
                has_num(smins[i]) && (slot["NewMin"] = Sys_Fast.FAST_SafeNum_DDEF(smins[i]))
                has_num(smaxs[i]) && (slot["NewMax"] = Sys_Fast.FAST_SafeNum_DDEF(smaxs[i]))
                if i <= length(leader_vals)
                    tv = Sys_Flow.FLOW_BridgeTransform_DDEF(leader_vals[i], α, β)
                    slot["TransformedVal"] = tv
                    transformed_displays[i] = string(round(tv; digits=3))
                end
            elseif mode == "REPLACE"
                slot["NewName"] = isnothing(rnames[i]) ? "" : string(rnames[i])
                slot["NewUnit"] = isnothing(runits[i]) ? "" : string(runits[i])
                v1 = Sys_Fast.FAST_SafeNum_DDEF(r_l1s[i])
                v2 = Sys_Fast.FAST_SafeNum_DDEF(r_l2s[i])
                v3 = Sys_Fast.FAST_SafeNum_DDEF(r_l3s[i])
                slot["NewL1"] = isnan(v1) ? 0.0 : v1
                slot["NewL2"] = isnan(v2) ? 0.0 : v2
                slot["NewL3"] = isnan(v3) ? 0.0 : v3
                has_num(rmins[i]) && (slot["NewMin"] = Sys_Fast.FAST_SafeNum_DDEF(rmins[i]))
                has_num(rmaxs[i]) && (slot["NewMax"] = Sys_Fast.FAST_SafeNum_DDEF(rmaxs[i]))
                transformed_displays[i] = string(round(Float64(slot["NewL2"]); digits=3))
            end

            push!(slots, slot)
        end

        config = Dict{String,Any}("Slots" => slots)
        return config, transformed_displays...
    end
end

end