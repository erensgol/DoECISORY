module Gui_Lens

# ======================================================================================
# DAISHODOE - GUI LENS (STATISTICAL ANALYSIS ENGINE)
# ======================================================================================
# Purpose: Data analysis, model fitting (GLM), and high-fidelity visualisation.
# Module Tag: LENS
# ======================================================================================

using Dash
using DashBootstrapComponents
using Main.Sys_Fast
using Main.Sys_Flow
using Main.Lib_Vise
using Main.Lib_Arts
using Main.Gui_Base
using DataFrames
using Printf
using PlotlyJS: JSON, savefig, Plot, GenericTrace, Layout
using ZipFile
using Base64
using XLSX

export LENS_Layout_DDEF, LENS_RegisterCallbacks_DDEF

# --------------------------------------------------------------------------------------
# SECTION 1: INTERFACE LAYOUT
# --------------------------------------------------------------------------------------

# --- RESTRUCTURING: LENS_BuildGoalRow_DDEF IS NOW MOVED TO Gui_Base.jl AS BASE_BuildGoalRow_DDEF

"""
    LENS_Layout_DDEF()
Constructs the statistical analysis and visualisation interface layout.
"""
function LENS_Layout_DDEF()
    return dbc_container([
        # Page Header
        BASE_PageHeader_DDEF("Statistical Modelling and Data Optimisation", "Analyse experimental outcomes, evaluate complex factor interactions via robust mathematical models, and ascertain optimal solution matrices."),

        # Main Workspace
        dbc_row([
            # --- LEFT COLUMN ---
            dbc_col([
                dbc_row(dbc_col(BASE_GlassPanel_DDEF([html_i(className="fas fa-cogs me-2"), "ANALYSIS CONFIGURATION"], [
                    # Data Ingestion
                    BASE_SidebarHeader_DDEF("DATA ACQUISITION", icon="fas fa-database"),
                    BASE_Upload_DDEF("lens-upload-data", "Import Dataset", "fas fa-file-import"),
                    BASE_Loading_DDEF("lens-upload-status", "No Data Source"; class="glass-loading-status mb-2"),
                    BASE_Separator_DDEF(),

                    # Exports Section
                    BASE_SidebarHeader_DDEF("EXPORT", icon="fas fa-file-export"),
                    BASE_ActionButton_DDEF("lens-btn-export-plots",    "Plots",    "fas fa-camera-retro", disabled=true),
                    BASE_ActionButton_DDEF("lens-btn-download-report", "Report",   "fas fa-file-export",  disabled=true),
                    BASE_ActionButton_DDEF("lens-btn-export-excel",    "(XLSX)",   "fas fa-file-excel",   class="w-100 fw-bold mb-3", disabled=true),
                    BASE_Separator_DDEF(),

                    # Control Settings
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

                    # Radioactivity Panel
                    html_div(id="lens-panel-radio", className="d-none", children=[
                        BASE_SidebarHeader_DDEF("RADIOACTIVITY", icon="fas fa-radiation-alt"),
                        BASE_ControlGroup_DDEF("Calibration Time",
                            dbc_input(id="lens-date-cal", type="datetime-local", className="mb-2 form-control-sm", style=Dict("fontSize" => "11px")), class="mb-2"),
                        BASE_ControlGroup_DDEF("Experimental Time",
                            dbc_input(id="lens-date-exp", type="datetime-local", className="mb-2 form-control-sm", style=Dict("fontSize" => "11px")), class="mb-2"),
                        dbc_row(dbc_col([
                            dbc_button([html_i(id="lens-icon-radio-correct", className="fas fa-times me-2"), "Decay Correction"],
                                id="lens-btn-radio-correct", className="w-100 fw-bold lens-radio-inactive", outline=false, size="sm")
                        ], xs=12)),
                        BASE_Separator_DDEF(),
                    ]),

                    # Main Operations
                    BASE_ActionButton_DDEF("lens-btn-view-report",    "Summary",    "fas fa-file-alt"),
                    BASE_ActionButton_DDEF("lens-btn-next-phase",    "Next Phase", "fas fa-forward"),
                    BASE_NextButton_DDEF("lens-btn-run",            "Run Analysis"),

                    dcc_download(id="lens-download-phase"),
                    dcc_download(id="lens-download-analysis"),
                    dcc_download(id="lens-download-plots"),
                    dcc_download(id="lens-download-report-file"),

                    BASE_Loading_DDEF("lens-run-output",           ""),
                    BASE_Loading_DDEF("lens-export-plots-status", ""),
                    BASE_Loading_DDEF("lens-export-excel-status", ""),
                ]; panel_class="mb-3 h-auto", content_class="p-2"), xs=12)),
            ]; xs=12, md=3, className="mb-3 mb-md-0"),

            # --- RIGHT COLUMN ---
            dbc_col([
                # Optimisation Objectives Panel
                BASE_GlassPanel_DDEF(["OPTIMISATION OBJECTIVES", html_span("", className="ms-2 fw-normal colourtx-v3dl")], [
                    dbc_row(dbc_col([
                        html_div(html_table([
                            html_thead(html_tr([
                                BASE_TableHeader_DDEF("RESPONSE",  width="20%"),
                                BASE_TableHeader_DDEF("LOWER",     width="15%"),
                                BASE_TableHeader_DDEF("TARGET",    width="15%"),
                                BASE_TableHeader_DDEF("UPPER",     width="15%"),
                                BASE_TableHeader_DDEF("OBJECTIVE", width="20%"),
                                BASE_TableHeader_DDEF("VALUE",     width="15%"),
                            ])),
                            html_tbody([BASE_BuildGoalRow_DDEF(i) for i in 1:3])
                        ], className="colourtx-v5pb", style=Dict("width" => "100%", "borderCollapse" => "collapse", "fontSize" => "10px", "tableLayout" => "fixed")), className="table-responsive m-0")
                    ], xs=12)),
                ]; panel_class="mb-3", content_class="glass-content p-2"),

                # Model Performance Panel
                BASE_GlassPanel_DDEF(["MODEL PERFORMANCE", html_span(id="lens-radio-badge", className="ms-2")], [
                    dbc_row(dbc_col(html_div(id="lens-results-text", className="small px-2 table-responsive"), xs=12)),
                ]; panel_class="mb-3", content_class="glass-content p-2"),

                # Leader Candidates Panel
                BASE_GlassPanel_DDEF(["LEADER CANDIDATES", html_span("", className="ms-2 fw-normal colourtx-v3dl")], [
                    dbc_row(dbc_col(html_div(id="lens-leaders-text", className="small px-2 table-responsive"), xs=12)),
                ]; panel_class="mb-3", content_class="glass-content p-2"),

                # Graph Index Panel
                BASE_GlassPanel_DDEF("GRAPH INDEX", [
                    html_div(id="lens-graph-info", className="p-1"),
                ]; panel_class="mb-3", content_class="glass-content p-2"),

                # Chart Viewer Panel
                BASE_GlassPanel_DDEF("PLOTS", [
                    html_div(id="lens-graph-title", className="text-center small mb-1 fw-bold colourtx-v4dh"),
                    BASE_Loading_DDEF("lens-graph-loading",
                        dcc_graph(
                            id     = "lens-graph-main",
                            style  = Dict("minHeight" => "500px"),
                            config = Dict("displayModeBar" => true, "displaylogo" => false, "responsive" => true),
                            figure = BASE_EmptyFigure_DDEC,
                        )),
                ]; panel_class="mb-2", content_class="glass-content p-2"),

                # Graph Navigation Controls
                dbc_row(dbc_col(html_div([
                    dbc_button(html_i(className="fas fa-chevron-left"),
                        id="lens-btn-prev", outline=false, size="sm", className="me-1 px-2 py-1 btn-white-bg"),
                    dcc_input(id="lens-graph-input", type="number", min=1, step=1, value=1, className="form-control form-control-sm mx-1 text-center colourtx-v5pb", style=Dict("backgroundColor" => "transparent", "borderColor" => "var(--colour-val3-darlow)", "width" => "60px", "height" => "28px", "fontSize" => "12px")),
                    html_span(id="lens-graph-counter", className="small mx-1 colourtx-v4dh"),
                    dbc_button(html_i(className="fas fa-chevron-right"),
                        id="lens-btn-next", outline=false, size="sm", className="ms-1 px-2 py-1 btn-white-bg"),
                ], className="d-flex align-items-center justify-content-center py-2"), xs=12)),

                # Persistent Stores
                dcc_store(id="lens-store-graphs",        data=[]),
                dcc_store(id="lens-store-index",         data=0),
                dcc_store(id="lens-store-report",        data=""),
                dcc_store(id="lens-store-results",       data=Dict()),
                dcc_store(id="lens-store-radio-correct", data=true),
                dcc_store(id="lens-signal-process",      data=Dict("ts" => 0, "success" => false)),
            ]; xs=12, md=9),
        ], className="g-3"),

        # Modal Dialogs
        BASE_Modal_DDEF("lens-modal-report", "DaishoDoE Scientific Intelligence Report",
            html_pre(id="lens-report-content", className="p-4 rounded small academic-report", style=Dict("whiteSpace" => "pre-wrap", "fontFamily" => "monospace", "maxHeight" => "600px", "overflowY" => "auto")),
            dbc_button(["Download Report (TXT)"], id="lens-btn-download-txt", className="w-100 colourgl-c4tg"); size="lg"),
        
        # PHASE WIZARD STEP 1: Phase Designation
        BASE_Modal_DDEF("lens-modal-wizard", [html_i(className="fas fa-layer-group me-2 colourtx-c1sm"), "Phase Evolution - Step 1/3"],
            [
                html_div([
                    html_p("Define the experimental horizon for the next phase sequence.", className="small mb-4 colourtx-v3dl"),
                    dbc_row([
                        dbc_col([
                            dbc_label("Source Phase (Where we are)", className="x-small fw-bold text-uppercase mb-2 colourtx-v3dl"),
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

        # PHASE WIZARD STEP 2: Leader Selection
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
                dbc_col(dbc_button(["Next: Adjust Design ", html_i(className="fas fa-chevron-right ms-2")], id="lens-lead-btn-confirm", className="w-100 colourgl-c1sm", disabled=true, size="sm"), xs=12, md=6),
            ], className="w-100 g-2"); size="xl", close_button=false, backdrop="static", keyboard=false),

        # PHASE WIZARD STEP 3: Preview & Adjustment
        BASE_Modal_DDEF("lens-modal-preview", [html_i(className="fas fa-microscope me-2 colourtx-c4tg"), "Phase Evolution - Step 3/3"],
            [
                dbc_row([
                    # Left: Precision Tuning Panel
                    dbc_col([
                        html_div([
                            dbc_label("Design Control", className="x-small fw-bold text-uppercase mb-3 d-block colourtx-v3dl"),
                            dbc_label("Matrix Protocol", className="small mb-1"),
                            dcc_dropdown(id="lens-prev-dd-method", options=[
                                Dict("label" => "Box-Behnken (15 Runs, Quadratic)", "value" => "BB15"),
                                Dict("label" => "D-Optimal (15 Runs, Quadratic)",   "value" => "DOPT15"),
                                Dict("label" => "Taguchi L9 (9 Runs, Linear)",     "value" => "TL09"),
                                Dict("label" => "D-Optimal (9 Runs, Linear)",     "value" => "DOPT09"),
                            ], value="TL09", clearable=false, className="mb-3"),
                            html_hr(className="my-3"),
                            dbc_label("Zoom Factor", className="small mb-1 d-flex justify-content-between", children=[
                                html_span("Wide-Scan (1.0)", className="colourtx-v5pb"),
                                html_span("Fine-Scan (0.1)", className="colourtx-v5pb")
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
                                className="px-2 mb-4"),
                            html_div(id="lens-prev-slider-shift", style=Dict("display" => "none")),
                        ], className="p-4 border-0 rounded h-100 shadow-sm colourbg-v0pw")
                    ], xs=12, md=4),

                    # Right: Analysis & Feedback
                    dbc_col([
                        html_div([
                            html_h6("Matrix Shift Visualisation", className="x-small fw-bold text-uppercase mb-2 colourtx-v3dl"),
                            dcc_graph(id="lens-graph-transition", config=Dict("displayModeBar" => false), style=Dict("height" => "250px"))
                        ], className="border-0 rounded p-3 mb-3 shadow-sm colourbg-v0pw"),
                        dbc_card([
                            dbc_cardheader([html_i(className="fas fa-th-list me-2"), "Calculated Boundaries"], className="small fw-bold border-0", style=Dict("backgroundColor" => "transparent")),
                            html_div(id="lens-container-preview-table", className="table-responsive p-2", style=Dict("maxHeight" => "200px", "overflowY" => "auto")),
                        ], className="shadow-sm border-0"),
                    ], xs=12, md=8)
                ]),
                html_div(id="lens-container-preview-audit", className="mt-3")
            ],
            dbc_row([
                dbc_col(dbc_button([html_i(className="fas fa-chevron-left me-2"), "Back"], id="lens-prev-btn-back", outline=false, size="sm", className="w-100 colourgl-neut"), xs=12, md=3),
                dbc_col(dbc_button([html_i(className="fas fa-times me-2"),        "Cancel"], id="lens-prev-btn-cancel", outline=false, size="sm", className="w-100 colourgl-c0hr"), xs=12, md=3),
                dbc_col(dbc_button([html_i(className="fas fa-check-circle me-2"), "Commit to Project Vault"], id="lens-prev-btn-commit", className="w-100 colourgl-c4tg", size="sm"), xs=12, md=6),
            ], className="w-100 g-2"); size="xl", close_button=false, backdrop="static", keyboard=false),
        dcc_store(id="lens-store-next-phase-proposal", data=Dict()),
    ], fluid=true, className="px-4 py-3")
end

# --------------------------------------------------------------------------------------
# SECTION 2: REACTIVE LOGIC (CALLBACKS)
# --------------------------------------------------------------------------------------

"""
    LENS_RegisterCallbacks_DDEF(app)
Orchestrates all reactive behavior for the LENS module.
"""
function LENS_RegisterCallbacks_DDEF(app)
    C = Sys_Fast.FAST_Data_DDEC

    # --- 1A. PIPELINE: LOCAL UPLOAD -> GLOBAL SYNC BUS ---
    callback!(app,
        Output("sync-lens-content", "data"),
        Input("lens-upload-data",  "contents"),
        prevent_initial_call=true
    ) do cont
        (isnothing(cont) || cont == "") && return Dash.no_update()
        # Return raw base64 content to the sync store (app.jl will push to Master Vault)
        return cont
    end

    # --- 1B. PIPELINE: GLOBAL SYNC -> GOAL INITIALIZATION ---
    callback!(app,
        Output("lens-dd-phase",       "options"),
        Output("lens-upload-status",  "children"),
        Output("lens-dd-phase",       "value"),
        [Output("lens-goal-name-$i",   "value") for i in 1:3]...,
        [Output("lens-goal-min-$i",    "value") for i in 1:3]...,
        [Output("lens-goal-target-$i", "value") for i in 1:3]...,
        [Output("lens-goal-max-$i",    "value") for i in 1:3]...,
        [Output("lens-goal-type-$i",   "value") for i in 1:3]...,
        [Output("lens-goal-weight-$i", "value") for i in 1:3]...,
        Output("lens-dd-model",       "options"),
        Output("lens-dd-model",       "value"),
        Output("lens-panel-radio",    "className"),
        Output("lens-date-cal",       "value"),
        Output("lens-date-exp",       "value"),
        Input("store-master-vault",   "data"),
        prevent_initial_call=true
    ) do active_cont
        # Determine temp path BEFORE try for guaranteed cleanup
        path = ""
        try  # Error guard for sync callback
            (isnothing(active_cont) || active_cont == "") &&
                return [], "No Data Source", nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., Dash.no_update(), Dash.no_update(), "d-none", "", ""

            Sys_Fast.FAST_Log_DDEF("LENS", "Sync", "Synchronising from Master Vault...", "INFO")
            path = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)

            ext = lowercase(splitext(path)[2])
            if ext != ".xlsx" && ext != ".xlsm"
                Sys_Fast.FAST_CleanTransient_DDEF(path)
                return [], html_span("❌ This is not a valid Excel file! (Please upload .xlsx)", className="small colourtx-c0hr"), nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., Dash.no_update(), Dash.no_update(), "d-none", "", ""
            end

            df = Sys_Fast.FAST_ReadExcel_DDEF(path, C.SHEET_DATA)
            isempty(df) && (df = Sys_Fast.FAST_ReadExcel_DDEF(path, "DATA_RECORDS"))

            if isempty(df)
                return [], html_span("❌ No Valid Data Sheet", className="small colourtx-c0hr"), nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., Dash.no_update(), Dash.no_update(), "d-none", "", ""
            end

            col_phase = Symbol(C.COL_PHASE)
            phases = []
            if hasproperty(df, col_phase)
                phases = map(unique(skipmissing(df[:, col_phase]))) do p
                    Dict("label" => string(p), "value" => string(p))
                end
            else
                # Fallback: if no phase column, treat as single phase
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

            if method == "TL09" || method == "DOPT09"
                model_opts = [Dict("label" => "Linear", "value" => "Linear")]
                model_val  = "Linear"
            elseif method == "BB15" || method == "DOPT15"
                model_opts = [
                    Dict("label" => "Quadratic",           "value" => "Quadratic"),
                    Dict("label" => "Kriging (Surrogate)", "value" => "kriging"),
                    Dict("label" => "RBF (Surrogate)",     "value" => "rbf")
                ]
                model_val  = "Quadratic"
            else
                model_opts = [
                    Dict("label" => "Automatic",           "value" => "Auto"),
                    Dict("label" => "Linear",              "value" => "Linear"),
                    Dict("label" => "Quadratic",           "value" => "Quadratic"),
                    Dict("label" => "Kriging (Surrogate)", "value" => "kriging"),
                    Dict("label" => "RBF (Surrogate)",     "value" => "rbf")
                ]
                model_val  = "Auto"
            end

            # --- GOAL OVERRIDES ---
            saved_goals = get(config, "LensGoals", [])
            for (i, name) in enumerate(goals_name)
                g_idx = findfirst(g -> get(g, "Name", "") == name, saved_goals)
                if !isnothing(g_idx)
                    saved_g = saved_goals[g_idx]
                    goals_type[i]   = string(get(saved_g, "Type", "Nominal"))
                    goals_weight[i] = Printf.@sprintf("%.2f", Main.Sys_Fast.FAST_SafeNum_DDEF(get(saved_g, "Weight", 1.0)))
                    goals_target[i] = Float64(get(saved_g, "Target", goals_target[i]))
                    goals_min[i]    = Float64(get(saved_g, "Min",    goals_min[i]))
                    goals_max[i]    = Float64(get(saved_g, "Max",    goals_max[i]))
                end
            end

            has_radio = false
            if haskey(config, "Ingredients")
                has_radio = has_radio || any(get(f, "IsRadioactive", false) == true for f in config["Ingredients"])
            end
            if haskey(config, "Outputs")
                has_radio = has_radio || any(get(o, "IsRadioactive", false) == true for o in config["Outputs"])
            end

            panel_class = has_radio ? "d-block mt-3" : "d-none"

            # --- RADIO OPTS OVERRIDES ---
            saved_radio = get(config, "RadioOpts", Dict())
            rad_apply = get(saved_radio, "Apply", false)
            rad_t_cal = string(get(saved_radio, "CalibrationTime", ""))
            rad_t_exp = string(get(saved_radio, "ExperimentalTime", ""))

            return (
                phases,
                html_span("✅ System Synced", className="small fw-bold", style=Dict("color" => "var(--colour-chr4-tongre)")),
                isempty(phases) ? nothing : phases[end]["value"],
                goals_name...,
                goals_min...,
                goals_target...,
                goals_max...,
                goals_type...,
                goals_weight...,
                model_opts,
                model_val,
                panel_class,
                rad_t_cal,
                rad_t_exp
            )

        catch e  # Surface sync errors to status area
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "SYNC_FAIL", bt, "FAIL")
            return [], html_span("❌ Sync Error: $(first(string(e), 120))", className="small colourtx-c0hr"),
                nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., Dash.no_update(), Dash.no_update(), "d-none", "", ""
        finally
            # Guaranteed temp file cleanup
            !isempty(path) && try
                rm(path; force=true)
            catch
            end
        end
    end

    # --- 2. ENGINE: RUN GLM ANALYSIS & OPTIMISATION ---
    callback!(app,
        Output("lens-store-graphs",    "data"),
        Output("lens-results-text",    "children"),
        Output("lens-run-output",      "children"),
        Output("lens-btn-next-phase",  "disabled"),
        Output("lens-btn-view-report", "disabled"),
        Output("lens-store-report",    "data"),
        Output("lens-store-results",   "data"),
        Output("sync-lens-analysis",   "data"),
        Output("lens-leaders-text",    "children"),
        Output("lens-radio-badge",     "children"),
        Output("lens-btn-export-plots",   "disabled"),
        Output("lens-btn-download-report", "disabled"),
        Output("lens-btn-export-excel",    "disabled"),
        Input("lens-btn-run", "n_clicks"),
        State("lens-dd-phase", "value"),
        State("lens-dd-model", "value"),
        [State("lens-goal-name-$i",   "value") for i in 1:3]...,
        [State("lens-goal-min-$i",    "value") for i in 1:3]...,
        [State("lens-goal-target-$i", "value") for i in 1:3]...,
        [State("lens-goal-max-$i",    "value") for i in 1:3]...,
        [State("lens-goal-type-$i",   "value") for i in 1:3]...,
        [State("lens-goal-weight-$i", "value") for i in 1:3]...,
        State("lens-store-radio-correct", "data"),
        State("lens-date-cal",            "value"),
        State("lens-date-exp",            "value"),
        State("store-master-vault",       "data"),
        prevent_initial_call=true
    ) do args...
        n, phase, model = args[1:3]

        is_rad_apply = args[22] === true
        t_cal = isnothing(args[23]) ? "" : string(args[23])
        t_exp = isnothing(args[24]) ? "" : string(args[24])

        base64_file = args[25]

        goals = Dict{String,Any}[]
        gnames = collect(args[4:6])
        gmins = collect(args[7:9])
        gtargets = collect(args[10:12])
        gmaxes = collect(args[13:15])
        gtypes = collect(args[16:18])
        gweights = collect(args[19:21])

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

        (n === nothing || n == 0) && return Dash.no_update(), Dash.no_update(), "", true, true, "", Dash.no_update(), Dash.no_update(), "", "", true, true, true
        isnothing(base64_file) &&
            return Dash.no_update(), Dash.no_update(), html_span("Please upload data first.", className="colourtx-c5hy"), true, true, "", Dash.no_update(), Dash.no_update(), "", "", true, true, true

        # Race condition lock: reject concurrent analysis requests
        if !Sys_Fast.FAST_AcquireLock_DDEF("VISE_ANALYSIS")
            Sys_Fast.FAST_Log_DDEF("LENS", "LOCK_REJECT", "Analysis already running. New request rejected.", "WARN")
            return Dash.no_update(), Dash.no_update(),
                html_span("⚠ An analysis is already in progress. Please wait.", className="fw-bold colourtx-c5hy"),
                true, true, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), true, true, true
        end

        # Create temp file BEFORE try so finally can always clean it
        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)

        try  # Error guard for analysis engine
            Sys_Fast.FAST_Log_DDEF("LENS", "Process", "Starting GLM Analysis (Phase: $phase)...", "WAIT")

            opts = Dict{String,Any}(
                "RadioOpts" => Dict(
                    "Apply" => is_rad_apply,
                    "CalibrationTime" => t_cal,
                    "ExperimentalTime" => t_exp
                )
            )

            phase_str = isnothing(phase) ? "Phase1" : string(phase)
            model_str = isnothing(model) ? "Auto" : string(model)
            res = Lib_Vise.VISE_Execute_DDEF(path, phase_str, goals, model_str; Opts=opts)

            if res["Status"] != "OK"
                # Updated to match the expected number of return values (13)
                # Output order: graphs, summary, status_msg, btn_next_dis, btn_view_dis, report_store, results_store, sync_store, leaders_html, rad_badge, export_btn_dis, download_btn_dis, excel_btn_dis
                return [], "", html_span("❌ Analysis Failed: $(res["Message"])", className="colourtx-c0hr"), true, true, "", Dash.no_update(), Dash.no_update(), "", "", true, true, true
            end

            # Generate and capture Scientific Report
            sci_report = Lib_Vise.VISE_GenerateScientificReport_DDEF(res)

            # Serialise PlotlyJS objects to JSON for Dash
            graphs = [
                Dict("figure" => JSON.parse(JSON.json(g["Plot"])), "title" => g["Title"])
                for g in res["Graphs"]
            ]

            summary_rows = [
                html_tr([
                        html_td(n, style=Dict("textAlign" => "center", "padding" => "6px"), className="fw-bold"),
                        html_td(@sprintf("%.3f", res["R2_Adj"][i]), style=Dict("textAlign" => "center", "padding" => "6px")),
                        html_td(@sprintf("%.3f", res["R2_Pred"][i]), style=Dict("textAlign" => "center", "padding" => "6px")),
                        html_td(
                            (haskey(res["Models"][i], "P_Value") && !isnan(res["Models"][i]["P_Value"])) ?
                            @sprintf("%.5f", res["Models"][i]["P_Value"]) : "N/A", style=Dict("textAlign" => "center", "padding" => "6px")
                        ),
                    ], style=Dict("borderBottom" => "1px solid var(--colour-val2-liglow)")) for (i, n) in enumerate(res["OutNames"])
            ]

            summary = html_div([
                html_table([
                        html_thead(html_tr([
                            html_th("Output", style=Dict("textAlign" => "center", "borderBottom" => "2px solid var(--colour-val2-liglow)", "padding" => "8px")),
                            html_th("R² (Adj)", style=Dict("textAlign" => "center", "borderBottom" => "2px solid var(--colour-val2-liglow)", "padding" => "8px")),
                            html_th("Q² (Pred)", style=Dict("textAlign" => "center", "borderBottom" => "2px solid var(--colour-val2-liglow)", "padding" => "8px")),
                            html_th("P-Value", style=Dict("textAlign" => "center", "borderBottom" => "2px solid var(--colour-val2-liglow)", "padding" => "8px"))
                        ])),
                        html_tbody(summary_rows, style=Dict("textAlign" => "center", "borderBottom" => "2px solid var(--colour-val2-liglow)")),
                    ], className="table table-sm table-borderless caption-top mb-1 mx-auto", style=Dict("width" => "95%", "marginTop" => "5px")),

                # --- NEW: SCIENTIFIC VITALS TABLE ---
                (haskey(res, "Vitals") ? html_div([
                    html_hr(style=Dict("height" => "1px", "border" => "none", "borderTop" => "1px dashed var(--colour-val1-lighig)", "margin" => "10px 0")),
                    html_div([
                        html_div([
                            html_span("D-Efficiency:", className="colourtx-v4dh"),
                            html_span(@sprintf("%.3f", res["Vitals"]["D"]), className="fw-bold colourtx-v5pb"),
                        ], className="me-4"),
                        html_div([
                            html_span("Max VIF:", className="colourtx-v4dh"),
                            html_span(@sprintf("%.2f", res["Vitals"]["MaxVIF"]), className = res["Vitals"]["MaxVIF"] > 10 ? "fw-bold" : "fw-bold"),
                        ], className="me-4"),
                        html_div([
                            html_span("Lack-of-Fit P:", className="colourtx-v4dh"),
                            html_span(@sprintf("%.3f", res["Vitals"]["LOF"]), className = res["Vitals"]["LOF"] < 0.05 ? "fw-bold" : "fw-bold"),
                        ], className="me-4"),
                        html_div([
                            html_span("Matrix Condition:", className="colourtx-v4dh"),
                            html_span(@sprintf("%.1e", res["Vitals"]["Condition"]), className="fw-bold colourtx-v5pb"),
                        ]),
                    ], className="d-flex justify-content-center small py-1 rounded colourbg-v0pw")
                ]) : html_div()),

                # --- SENSITIVITY ANALYSIS TABLE ---
                (haskey(res, "Sensitivities") && !isempty(res["Sensitivities"]) ? html_div([
                    html_hr(style=Dict("height" => "1px", "border" => "none", "borderTop" => "1px dashed var(--colour-val1-lighig)", "margin" => "10px 0")),
                    html_h6("Factor Sensitivity (at Optimum)", className="fw-bold small text-center mb-2 colourtx-c1sm"),
                    html_table([
                        html_thead(html_tr([
                            html_th("Factor", style=Dict("textAlign" => "left", "padding" => "4px")),
                            [html_th(out, style=Dict("textAlign" => "center", "padding" => "4px")) for out in res["OutNames"]]...
                        ])),
                        html_tbody([
                            html_tr([
                                html_td(res["InNames"][fi], className="fw-bold", style=Dict("padding" => "4px")),
                                [html_td(@sprintf("%.1f%%", res["Sensitivities"][mi][fi] * 100),
                                    className = res["Sensitivities"][mi][fi] > 0.5 ? "colourtx-c0hr" : "colourtx-v5pb",
                                    style=Dict("textAlign" => "center", "padding" => "4px"))
                                 for mi in 1:length(res["OutNames"])]...
                            ]) for fi in 1:length(res["InNames"])
                        ])
                    ], className="table table-sm table-borderless small mx-auto", style=Dict("width" => "90%"))
                ]) : html_div()),

                # --- ACADEMIC ANOVA & COEFFICIENTS TIER ---
                html_div([
                    html_hr(style=Dict("height" => "2px", "border" => "none", "borderTop" => "2px solid var(--colour-chr3-toncya)", "margin" => "15px 0")),
                    html_h6("ACADEMIC DIAGNOSTICS", className="fw-bold text-center mb-3 colourtx-c1sm", style=Dict("letterSpacing" => "1px")),

                    # Loop through each output for detailed ANOVA
                    [html_div([
                        html_div("Analysis of Variance (ANOVA): $out_name", className="small fw-bold mb-1 colourtx-v4dh"),
                        # ANOVA Table
                        let df_ano = res["ANOVA"][i]
                            html_table([
                                html_thead(html_tr([
                                    html_th("Source",  style=Dict("padding" => "2px")),
                                    html_th("df",      style=Dict("padding" => "2px")),
                                    html_th("MS",      style=Dict("padding" => "2px")),
                                    html_th("F-Value", style=Dict("padding" => "2px")),
                                    html_th("P-Value", style=Dict("padding" => "2px"))
                                ])),
                                html_tbody([
                                    html_tr([
                                        html_td(r.Source, style=Dict("padding" => "2px")),
                                        html_td(r.df,     style=Dict("padding" => "2px")),
                                        html_td(isnan(r.MS) ? "-" : @sprintf("%.4f", r.MS), style=Dict("padding" => "2px")),
                                        html_td(isnan(r.F)  ? "-" : @sprintf("%.2f", r.F),  style=Dict("padding" => "2px")),
                                        html_td(isnan(r.P)  ? "-" : @sprintf("%.4f", r.P),
                                            className = (!isnan(r.P) && r.P < 0.05) ? "fw-bold" : "",
                                            style=Dict("padding" => "2px"))
                                    ]) for r in eachrow(df_ano)
                                ])
                            ], className="table table-sm table-hover small mb-3 border")
                        end,

                        html_div("Term Significance (Coefficients): $out_name", className="small fw-bold mb-1 colourtx-v4dh"),
                        # Coefficients Table
                        let m = res["Models"][i]
                            html_table([
                                html_thead(html_tr([
                                    html_th("Term",    style=Dict("padding" => "2px")),
                                    html_th("Beta",    style=Dict("padding" => "2px")),
                                    html_th("P-Value", style=Dict("padding" => "2px")),
                                    html_th("VIF",     style=Dict("padding" => "2px"))
                                ])),
                                html_tbody([
                                    html_tr([
                                        html_td(m["TermNames"][j], style=Dict("padding" => "2px")),
                                        html_td(@sprintf("%.4f", m["Coefs"][j]), style=Dict("padding" => "2px")),
                                        html_td(isnan(m["P_Coefs"][j]) ? "N/A" : @sprintf("%.4f", m["P_Coefs"][j]),
                                            className = (!isnan(m["P_Coefs"][j]) && m["P_Coefs"][j] < 0.05) ? "fw-bold" : "",
                                            style=Dict("padding" => "2px")),
                                        html_td(j == 1 ? "-" : @sprintf("%.2f", m["VIFs"][j]), style=Dict("padding" => "2px"))
                                    ]) for j in 1:length(m["TermNames"])
                                ])
                            ], className="table table-sm table-hover small mb-4 border")
                        end
                    ]) for (i, out_name) in enumerate(res["OutNames"])]...
                ], className="px-2 mt-3"),

                # --- BOUNDARY WARNINGS (AskLeader Integration) ---
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

            # --- Persist Analysis Configuration (Goals & RadioOpts) ---
            Sys_Fast.FAST_UpdateConfig_DDEF(path, Dict("LensGoals" => goals, "RadioOpts" => opts["RadioOpts"]))

            updated_base64 = Sys_Fast.FAST_ReadToStore_DDEF(path)

            # --- Build Leader Candidates Table ---
            leaders_html = ""
            if haskey(res, "Leaders") && !isempty(res["Leaders"])
                ldf = res["Leaders"]
                C = Sys_Fast.FAST_Data_DDEC
                lcols = names(ldf)

                # Column ordering: ID, Input Variables, Predicted Outputs, Score
                id_col      = findfirst(c -> c == C.COL_EXP_ID || c == C.COL_ID, lcols)
                in_cols_l   = filter(c -> startswith(c, C.PRE_INPUT), lcols)
                pred_cols_l = filter(c -> startswith(c, C.PRE_PRED),  lcols)
                score_col   = findfirst(==(C.COL_SCORE), lcols)

                # Build display header names
                display_cols  = String[]
                display_names = String[]
                if !isnothing(id_col)
                    push!(display_cols,  lcols[id_col])
                    push!(display_names, "ID")
                end
                for c in in_cols_l
                    push!(display_cols,  c)
                    push!(display_names, replace(c, C.PRE_INPUT => ""))
                end
                for c in pred_cols_l
                    push!(display_cols,  c)
                    push!(display_names, replace(c, C.PRE_PRED => ""))
                end
                if !isnothing(score_col)
                    push!(display_cols,  lcols[score_col])
                    push!(display_names, "Score")
                end

                th_style = Dict("textAlign" => "center", "borderBottom" => "2px solid var(--colour-val2-liglow)", "padding" => "4px 6px", "fontSize" => "10px", "whiteSpace" => "nowrap")
                td_style = Dict("textAlign" => "center", "padding" => "3px 6px", "fontSize" => "10px")

                header_row = html_tr([html_th(n, style=th_style) for n in display_names])
                body_rows  = [html_tr([
                    html_td(
                        let v = ldf[r, Symbol(c)]
                            ismissing(v) ? "-" : (v isa Number ? @sprintf("%.3f", v) : string(v))
                        end,
                        className = c == C.COL_SCORE ? "colourtx-c1sm" : "",
                        style=merge(td_style, c == C.COL_SCORE ? Dict("fontWeight" => "bold") : Dict())
                    ) for c in display_cols
                ], style=Dict("borderBottom" => "1px solid var(--colour-val1-lighig)")) for r in 1:nrow(ldf)]

                leaders_html = html_table([
                    html_thead(header_row),
                    html_tbody(body_rows),
                ], className="table table-sm table-borderless mb-0 mx-auto", style=Dict("width" => "100%", "marginTop" => "5px"))
            end

            # Radio Badge Logic
            rad_badge = (haskey(res, "RadioCorrection") && !isempty(res["RadioCorrection"])) ?
                        dbc_badge([html_i(className="fas fa-radiation me-1 colourtx-v5pb"), "Radio-Corrected"], className="ms-2 fw-bold colourgl-c5hy colourtx-v5pb", style=Dict("borderColor" => "var(--colour-chr5-hueyel)")) : ""

            # Show elapsed time in analysis success message
            elapsed_str   = get(res, "Elapsed", "")
            elapsed_badge = isempty(elapsed_str) ? "" :
                            html_span(" ($elapsed_str)", className="colourtx-v3dl")

            return (
                graphs, 
                summary, 
                html_span(["✅ Analysis Complete", elapsed_badge], className="fw-bold small colourtx-c4tg"), 
                false, 
                false, 
                sci_report, 
                Sys_Fast.FAST_SanitiseJson_DDEF(res), 
                updated_base64, 
                leaders_html, 
                rad_badge, 
                false, 
                false, 
                false
            )

        catch e  # Surface analysis errors to UI
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "ANALYSIS_CRASH", bt, "FAIL")
            return [], "",
 html_span("❌ Critical Error: $(first(string(e), 150))", className="fw-bold colourtx-c0hr"), true, true,"", Dash.no_update(), Dash.no_update(),"","", true, true, true
        finally
            # Guaranteed temp file cleanup (prevents disk leak)
            Sys_Fast.FAST_CleanTransient_DDEF(path)
            # Always release the lock, even if an error occurred
            Sys_Fast.FAST_ReleaseLock_DDEF("VISE_ANALYSIS")
        end
    end

    # --- 3. UI: GRAPH INDEX TRACKER ---
    callback!(app,
        Output("lens-store-index", "data"),
        Output("lens-graph-input", "value"),
        Output("lens-graph-input", "max"),
        Input("lens-store-graphs",  "data"),
        Input("lens-btn-next",      "n_clicks"),
        Input("lens-btn-prev",      "n_clicks"),
        Input("lens-graph-input",   "value"),
        State("lens-store-index",   "data"),
        prevent_initial_call=true
    ) do g, n_nxt, n_prv, val_inp, i
        trig = BASE_GetTrigger_DDEF(callback_context())

        tot = isnothing(g) ? 0 : length(g)
        if trig == "lens-store-graphs" || tot == 0
            return 0, 1, max(1, tot)
        end

        idx = isnothing(i) ? 0 : i

        if trig == "lens-btn-next"
            idx = (idx + 1) % tot
        elseif trig == "lens-btn-prev"
            idx = (idx - 1 + tot) % tot
        elseif trig == "lens-graph-input"
            if !isnothing(val_inp) && val_inp >= 1 && val_inp <= tot
                idx = val_inp - 1
            end
        end

        return idx, idx + 1, max(1, tot)
    end

    # --- 4. UI: GRAPH RENDER SYNC ---
    callback!(app,
        Output("lens-graph-main",    "figure"),
        Output("lens-graph-title",   "children"),
        Output("lens-graph-counter", "children"),
        Output("lens-graph-info",    "children"),
        Input("lens-store-index",    "data"),
        State("lens-store-graphs",   "data")
    ) do i, g
        (isnothing(g) || isempty(g)) && return Dict(), "No Visualisation Data", "/ 0", ""
        idx = (i % length(g)) + 1

        counts = Dict{String,Int}()
        order = String[]
        for item in g
            t = split(get(item, "title", "Unknown"), ":")[1]
            if !haskey(counts, t)
                push!(order, t)
                counts[t] = 0
            end
            counts[t] += 1
        end

        info_parts = String[]
        curr_start = 1
        for t in order
            c = counts[t]
            push!(info_parts, "$t ($curr_start-$(curr_start + c - 1))")
            curr_start += c
        end

        function LENS_FormatLine_DDEF(items)
            return html_div([
                html_span(item, className="colourtx-v5pb", style=Dict(
                    "width"      => "33.3%",
                    "textAlign"  => "center",
                    "whiteSpace" => "nowrap",
                    "padding"    => "4px 0",
                    "fontSize"   => "11px",
                    "fontWeight" => "600"
                )) for item in items
            ], style=Dict("display" => "flex", "width" => "100%", "justifyContent" => "space-around"))
        end

        info_html = html_div([
            LENS_FormatLine_DDEF(info_parts[1:min(length(info_parts), 3)]),
            length(info_parts) > 3 ? LENS_FormatLine_DDEF(info_parts[4:min(length(info_parts), 6)]) : html_div(),
            length(info_parts) > 6 ? LENS_FormatLine_DDEF(info_parts[7:min(length(info_parts), 9)]) : html_div()
        ], style=Dict("display" => "flex", "flexDirection" => "column", "width" => "100%", "padding" => "2px 0"))

        return g[idx]["figure"], g[idx]["title"], "/ $(length(g))", info_html
    end

    # --- 7. UI: MODAL SEQUENTIAL SWITCHING (3-STEP WIZARD) ---
    callback!(app,
        Output("lens-modal-wizard",  "is_open"),
        Output("lens-modal-leader",  "is_open"),
        Output("lens-modal-preview", "is_open"),
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
        prevent_initial_call=true
    ) do n_open, n_w2L, n_w_can, n_L2w, n_L2p, n_L_can, n_p2L, n_p_can, sig, w_open, L_open, p_open
        trig = BASE_GetTrigger_DDEF(callback_context())

        # Reset states
        if trig == "lens-wiz-btn-cancel" || trig == "lens-lead-btn-cancel" || trig == "lens-prev-btn-cancel" || (trig == "lens-signal-process" && get(sig, "success", false))
            return false, false, false
        end

        # Entry from main page
        if trig == "lens-btn-next-phase"
            return true, false, false
        end

        # Step 1 -> Step 2
        if trig == "lens-wiz-btn-next"
            return false, true, false
        end

        # Step 2 -> Step 1
        if trig == "lens-lead-btn-back"
            return true, false, false
        end

        # Step 2 -> Step 3
        if trig == "lens-lead-btn-confirm"
            return false, false, true
        end

        # Step 3 -> Step 2
        if trig == "lens-prev-btn-back"
            return false, true, false
        end

        return Dash.no_update(), Dash.no_update(), Dash.no_update()
    end

    # --- 8. UI: REPORT MODAL CONTROL ---
    callback!(app,
        Output("lens-modal-report",   "is_open"),
        Output("lens-report-content", "children"),
        Input("lens-btn-view-report", "n_clicks"),
        State("lens-store-report",    "data"),
        prevent_initial_call=true
    ) do n, report
        n > 0 && return true, report
        return false, ""
    end

    # --- 8B. UI: SCIENTIFIC REPORT DOWNLOAD (TXT) ---
    callback!(app,
        Output("lens-download-report-file", "data"),
        Input("lens-btn-download-txt", "n_clicks"),
        State("lens-store-report",     "data"),
        State("lens-input-project",    "value"),
        State("lens-dd-phase",         "value"),
        prevent_initial_call=true
    ) do n, report, project, phase
        (isnothing(n) || n == 0 || isnothing(report) || isempty(report)) && return Dash.no_update()

        proj  = isnothing(project) ? "Daisho" : project
        ph    = isnothing(phase)   ? "Phase1" : phase
        fname = "Daisho_$(proj)_$(ph)_Scientific_Report.txt"

        return Dict("filename" => fname, "content" => report)
    end
    # --- 9. UI: CONDITIONAL ACTION ENABLING ---
    callback!(app,
        Output("lens-lead-btn-confirm", "disabled"),
        Output("lens-lead-btn-confirm", "className"),
        Input("lens-table-candidates", "selected_rows")
    ) do s
        is_disabled = isnothing(s) || isempty(s)
        btn_class   = is_disabled ? "w-100 colourgl-c1sm" : "w-100 colourgl-c4tg"
        return is_disabled, btn_class
    end

    # --- 5. UI: PHASE WIZARD DATA INITIALIZATION ---
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

    # --- 6. UI: CANDIDATE DATA LOADER (FOR STEP 2) ---
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
        # Load Config to ensure strict ordering
        C = Sys_Fast.FAST_Data_DDEC
        config_full = Sys_Fast.FAST_ReadConfig_DDEF(path)
        data = Sys_Flow.FLOW_GetCandidates_DDEF(path, src)
        Sys_Fast.FAST_CleanTransient_DDEF(path)

        isempty(data) && return [], []

        # Identify columns based on Config order
        cols_to_show = String[]

        # 1. ID first
        all_keys = collect(keys(data[1]))
        h_id_idx = findfirst(k -> occursin("ID", uppercase(string(k))), all_keys)
        !isnothing(h_id_idx) && push!(cols_to_show, string(all_keys[h_id_idx]))

        # 2. Variables in Config Order
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

        # 3. Predictions in Config Order
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

        # 4. Score at the end
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

    # --- 10. LOGIC: PHASE PROPOSAL GENERATOR (FOR STEP 3) ---
    callback!(app,
        Output("lens-store-next-phase-proposal", "data"),
        Output("lens-prev-slider-zoom",  "value"),
        Output("lens-prev-slider-shift", "value"),
        Output("lens-prev-dd-method",    "value"),
        Input("lens-lead-btn-confirm",  "n_clicks"),
        Input("lens-prev-slider-zoom",  "value"),
        Input("lens-prev-slider-shift", "value"),
        Input("lens-prev-dd-method",    "value"),
        State("lens-wiz-dd-source",     "value"),
        State("lens-table-candidates",  "selected_rows"),
        State("lens-table-candidates",  "data"),
        State("store-master-vault",     "data"),
        prevent_initial_call=true
    ) do n_prev, zoom_p, shift_p, meth_p, src, sel_rows, cand_data, base64_file
        trig = BASE_GetTrigger_DDEF(callback_context())

        # Correct initialization logic: 
        # When coming from Step 2, use defaults. When adjusting in Step 3, use slider values.
        # Slider value 1-5 maps to [1.0, 0.75, 0.5, 0.25, 0.1]
        zoom_map = Float64[1.0, 0.75, 0.5, 0.25, 0.1]
        z_idx = isnothing(zoom_p) ? 3 : clamp(round(Int, zoom_p), 1, 5)

        z = (trig == "lens-lead-btn-confirm") ? 0.5 : zoom_map[z_idx]
        ret_idx = (trig == "lens-lead-btn-confirm") ? 3 : z_idx

        s = 0.0 # Shift is now always 0/centered as requested
        m = (trig == "lens-lead-btn-confirm") ? "TL09" : meth_p

        (isnothing(base64_file) || isnothing(sel_rows) || isempty(sel_rows)) && return Dict(), ret_idx, s, m

        row_sel = cand_data[sel_rows[1]+1]
        sel_id = haskey(row_sel, "EXP_ID") ? string(row_sel["EXP_ID"]) :
                 haskey(row_sel, "ID")     ? string(row_sel["ID"]) :
                 haskey(row_sel, :EXP_ID)  ? string(row_sel[:EXP_ID]) :
                 haskey(row_sel, :ID)      ? string(row_sel[:ID]) : ""

        # Load Config to ensure strict variable ordering
        C = Sys_Fast.FAST_Data_DDEC
        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)
        config_full = Sys_Fast.FAST_ReadConfig_DDEF(path)

        # Robustly extract ingredients list
        ingredients_raw = get(config_full, "Ingredients", [])
        ingredients = if ingredients_raw isa Dict
            [Dict{String,Any}(string(k) => v for (k, v) in pairs(val)) for val in values(ingredients_raw)]
        else
            [Dict{String,Any}(string(k) => v for (k, v) in pairs(val)) for val in ingredients_raw]
        end
        vars_config = filter(c -> get(c, "Role", "") == C.ROLE_VAR, ingredients)

        # Call Flow Propose logic (NextPhase) - Purely for preview calculation
        res = Sys_Flow.FLOW_NextPhase_DDEF(path, src, sel_id, Float64(z), Float64(s))
        Sys_Fast.FAST_CleanTransient_DDEF(path)

        res["SelectedZoom"]   = z
        res["SelectedShift"]  = s
        res["SelectedMethod"] = m

        # STRICT LEADER VALUES ORDERING: Follow the config variable order
        lead_vals = Float64[]
        for v_conf in vars_config
            v_name = get(v_conf, "Name", "")
            v_key = "$(C.PRE_INPUT)$v_name"
            val = get(row_sel, v_key, get(row_sel, v_name, 0.0))
            push!(lead_vals, Sys_Fast.FAST_SafeNum_DDEF(val))
        end
        res["LeaderValues"] = lead_vals

        return res, ret_idx, s, m
    end

    # --- 11. UI: RENDER PREVIEW CONTENT ---
    callback!(app,
        Output("lens-container-preview-table", "children"),
        Output("lens-container-preview-audit", "children"),
        Output("lens-graph-transition", "figure"),
        Input("lens-store-next-phase-proposal", "data"),
        prevent_initial_call=true
    ) do res
        (isnothing(res) || isempty(res) || res["Status"] != "OK") && return html_div("No proposal available."), "", Dict()

        conf = res["NewConfig"]

        # Transformation Visualisation — use OldConfig (original boundaries) so the chart
        # performs a single zoom/shift, matching the NewConfig values shown in the table.
        old_conf    = get(res, "OldConfig", conf)
        leader_vals = get(res, "LeaderValues", Float64[])
        zoom        = Float64(get(res, "SelectedZoom", 1.0))
        shift       = Float64(get(res, "SelectedShift", 0.0))

        # FLOW_RenderPhaseTransition_DDEF now returns a Dict, so we pass it directly
        fig = Sys_Flow.FLOW_RenderPhaseTransition_DDEF(old_conf, leader_vals, zoom, shift)

        # 1. Comparison Table
        rows = []
        for c in conf
            role = get(c, "Role", "Variable")
            lvls = get(c, "Levels", [0.0, 0.0, 0.0])
            push!(rows, html_tr([
                html_td(get(c, "Name", "???")),
                html_td(role, className = role == "Variable" ? "colourtx-c1sm" : "colourtx-v5pb", style=Dict(
                    "fontWeight" => role == "Variable" ? "bold" : "normal"
                )),
                html_td(round(lvls[1], digits=3)),
                html_td(html_b(round(lvls[2], digits=3)), className="colourbg-v0pw"),
                html_td(round(lvls[3], digits=3))
            ]))
        end

        tbl = html_table([
            html_thead(html_tr([
                html_th("Ingredient"), html_th("Role"), html_th("Min"), html_th("Centre"), html_th("Max")
            ])),
            html_tbody(rows)
        ], className="table table-sm table-hover align-middle small")

        # 2. Stoichiometry Audit
        # Robust key access helper (JSON3 compatibility)
        function get_val_local(o, k, d)
            haskey(o, string(k)) && return o[string(k)]
            haskey(o, Symbol(k)) && return o[Symbol(k)]
            return d
        end

        glb  = get_val_local(res, "Global", Dict())
        vol  = Float64(get_val_local(glb, "Volume", 5.0))
        conc = Float64(get_val_local(glb, "Concentration", 10.0))

        chem_rows = [Dict(
            "Name" => string(get_val_local(c, "Name", "")),
            "Role" => string(get_val_local(c, "Role", "Variable")),
            "L1"   => Float64(get_val_local(c, "Levels", [0.0, 0.0, 0.0])[1]),
            "L2"   => Float64(get_val_local(c, "Levels", [0.0, 0.0, 0.0])[2]),
            "L3"   => Float64(get_val_local(c, "Levels", [0.0, 0.0, 0.0])[3]),
            "MW"   => Float64(get_val_local(c, "MW", 0.0))
        ) for c in conf]

        # Use safe vol/conc and handle cases where audit might fail due to "no stoichiometry configured"
        audit_ok, audit_report, _, t_mass, _ = Main.Lib_Mole.MOLE_QuickAudit_DDEF(chem_rows, vol, conc)

        audit_html = if audit_ok
            dbc_alert([
                html_h5([html_i(className="fas fa-check-circle me-2"), "Stochiometry Audit (Proposed Phase): PASS"], className="alert-heading small fw-bold"),
                html_hr(),
                html_pre(audit_report, className="mb-0 x-small", style=Dict("fontFamily" => "monospace"))
            ], className="shadow-sm border-0 py-3 colourgl-c4tg colourtx-v5pb", style=Dict("borderColor" => "var(--colour-chr4-tongre)"))
        else
            dbc_alert([
                html_h6([html_i(className="fas fa-exclamation-triangle me-2"), "No stoichiometry configuration found for this system or composition is out of limits."], className="mb-0 small fw-bold")
            ], className="shadow-sm border-0 py-3 colourgl-c0hr colourtx-v0pw", style=Dict("borderColor" => "var(--colour-chr0-huered)"))
        end

        return tbl, audit_html, fig
    end

    # --- 12. LOGIC: COMMIT PHASE TO EXCEL ---
    callback!(app,
        Output("lens-download-phase", "data"),
        Output("lens-signal-process", "data"),
        Input("lens-prev-btn-commit", "n_clicks"),
        State("lens-store-next-phase-proposal", "data"),
        State("lens-table-candidates", "selected_rows"),
        State("lens-table-candidates", "data"),
        State("lens-wiz-dd-source",    "value"),
        State("store-master-vault",    "data"),
        prevent_initial_call=true
    ) do n_commit, proposal, sel_rows, cand_data, src, base64_file
        (isnothing(n_commit) || n_commit == 0 || isnothing(proposal) || get(proposal, "Status", "") != "OK") && return Dash.no_update()
        (isnothing(sel_rows) || isempty(sel_rows)) && return Dash.no_update()

        # Consistent ID extraction helper
        row_sel = cand_data[sel_rows[1]+1]
        sel_id = haskey(row_sel, "EXP_ID") ? string(row_sel["EXP_ID"]) :
                 haskey(row_sel, "ID")     ? string(row_sel["ID"]) :
                 haskey(row_sel, :EXP_ID)  ? string(row_sel[:EXP_ID]) :
                 haskey(row_sel, :ID)      ? string(row_sel[:ID]) : ""

        zoom  = get(proposal, "SelectedZoom", 0.5)
        shift = get(proposal, "SelectedShift", 0.0)
        meth  = get(proposal, "SelectedMethod", "TL09")

        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)
        res  = Sys_Flow.FLOW_BuildNextPhase_DDEF(path, src, sel_id, Float64(zoom), meth, Float64(shift))

        if res["Status"] == "OK"
            new_vault = Sys_Fast.FAST_ReadToStore_DDEF(path)
            # Need actual bytes for download
            _, bytes = Sys_Fast.FAST_PrepareDownload_DDEF(path)

            Sys_Fast.FAST_CleanTransient_DDEF(path)

            # Use smart naming
            fname = Sys_Fast.FAST_GenerateSmartName_DDEF("Daisho", res["TargetPhase"], "READY")

            return (
                Dict("filename" => fname, "content" => base64encode(bytes), "base64" => true),
                Dict("success"  => true, "msg" => "Phase Created Successfully", "base64" => new_vault)
            )
        else
            Sys_Fast.FAST_CleanTransient_DDEF(path)
            return Dash.no_update(), Dict("success" => false, "msg" => res["Message"])
        end
    end

    # --- 11. HIGH-RES PLOT EXPORT ---
    callback!(app,
        Output("lens-download-plots",        "data"),
        Output("lens-export-plots-status", "children"),
        Input("lens-btn-export-plots", "n_clicks"),
        State("lens-store-graphs",     "data"),
        State("lens-input-project",    "value"),
        State("lens-dd-phase",         "value"),
        prevent_initial_call=true
    ) do n, graphs, proj, phase
        (isnothing(n) || n == 0 || isnothing(graphs) || isempty(graphs)) &&
            return Dash.no_update(), Dash.no_update()

        try
            project = isnothing(proj) ? "Daisho" : proj
            ph      = isnothing(phase) ? "Phase1" : ph

            temp_uuid  = replace(string(Base.UUID(rand(UInt128))), "-" => "")
            export_dir = joinpath(tempdir(), "DaishoRender_$temp_uuid")
            mkpath(export_dir)

            count = 0
            for (i, g) in enumerate(graphs)
                fig_dict = JSON.parse(JSON.json(g["figure"]))
                title    = get(g, "title", "Plot_$i")

                # Apply Light Theme via BASE function
                fig_dict = BASE_ConvertThemePlotlyWhite!_DDEF(fig_dict)

                safe_title = replace(title, r"[^\w\-_\\.]" => "_")
                filepath   = joinpath(export_dir, "$(safe_title).png")

                traces     = [GenericTrace(d) for d in fig_dict["data"]]
                layout_obj = Layout(fig_dict["layout"])
                p          = Plot(traces, layout_obj)

                savefig(p, filepath; width=1200, height=800, scale=2)
                count += 1
            end

            zip_path = joinpath(tempdir(), "Daisho_$(project)_$(ph)_Plots.zip")
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
                Dict("filename" => "Daisho_$(project)_$(ph)_Plots.zip", "content" => base64encode(bytes), "base64" => true),
                html_span("✅ Successfully downloaded $count High-Res plots.", className="fw-bold colourtx-c4tg"),
            )
        catch e
            Sys_Fast.FAST_Log_DDEF("LENS", "Export_Error", string(e), "FAIL")
            return Dash.no_update(), html_span("❌ Error during plot export (Kaleido missing?): $e", className="fw-bold colourtx-c0hr")
        end
    end

    # --- 12. SCIENTIFIC EXCEL EXPORT ---
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

            # Use the ExportToExcel function from Lib_Vise
            success = Lib_Vise.VISE_ExportToExcel_DDEF(path, res)

            if success
                bytes = read(path)
                pj    = isnothing(proj) ? "Daisho" : proj
                ph    = isnothing(phase) ? "Phase1" : phase
                fname = "Daisho_$(pj)_$(ph)_Scientific_Analysis.xlsx"

                return (
                    Dict("filename" => fname, "content" => base64encode(bytes), "base64" => true),
                    html_span("✅ Scientific XLSX downloaded.", className="fw-bold small colourtx-c4tg")
                )
            else
                return Dash.no_update(), html_span("❌ Excel export failed.", className="small colourtx-c0hr")
            end
        catch e
            Sys_Fast.FAST_Log_DDEF("LENS", "EXCEL_EXPORT_FAIL", string(e), "FAIL")
            return Dash.no_update(), html_span("❌ Export Error: $e", className="small colourtx-c0hr")
        finally
            Sys_Fast.FAST_CleanTransient_DDEF(path)
        end
    end

    # --- 13. RADIO CORRECTION TOGGLE & SYNC ---
    callback!(app,
        Output("lens-store-radio-correct", "data"),
        Output("lens-btn-radio-correct",   "className"),
        Output("lens-btn-radio-correct",   "outline"),
        Output("lens-icon-radio-correct",  "className"),
        Input("lens-btn-radio-correct", "n_clicks"),
        Input("store-master-vault",     "data"),
        State("lens-store-radio-correct", "data"),
        prevent_initial_call=true
    ) do n, active_cont, current_state
        trig = BASE_GetTrigger_DDEF(callback_context())

        new_state = current_state

        if trig == "lens-btn-radio-correct"
            new_state = (current_state === nothing) ? true : !current_state
        elseif trig == "store-master-vault" && !isnothing(active_cont) && active_cont != ""
            try
                path   = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)
                config = Sys_Fast.FAST_ReadConfig_DDEF(path)
                saved_radio = get(config, "RadioOpts", Dict())
                new_state   = get(saved_radio, "Apply", false)
                rm(path; force=true)
            catch
                new_state = false
            end
        end

        btn_class = (new_state === true) ?
            "w-100 fw-bold lens-radio-active" :
            "w-100 fw-bold lens-radio-inactive"

        icon = (new_state === true) ? "fas fa-check me-2" : "fas fa-times me-2"

        return new_state, btn_class, false, icon
    end
end

end # module
