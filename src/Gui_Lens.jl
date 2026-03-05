module Gui_Lens

# ======================================================================================
# DAISHODOE - GUI LENS (STATISTICAL ANALYSIS ENGINE)
# ======================================================================================
# Purpose: Data analysis, model fitting (GLM), and high-fidelity visualization.
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

export LENS_Layout_DDEF, LENS_RegisterCallbacks_DDEF

# --------------------------------------------------------------------------------------
# SECTION 1: INTERFACE LAYOUT
# --------------------------------------------------------------------------------------

"""
    LENS_BuildGoalRow_DDEF(i)
Constructs a single goal-specification row for the optimisation objectives table.
"""
function LENS_BuildGoalRow_DDEF(i)
    return html_tr([
        html_td(dcc_input(id="lens-goal-name-$i", type="text", value="", style=merge(BASE_STYLE_INPUT_CENTRE, Dict("fontSize" => "10px")), className="px-1 py-0", disabled=true), style=merge(BASE_STYLE_CELL, Dict("width" => "20%", "backgroundColor" => "#FFFFFF", "borderBottom" => "none")), className="p-0"),
        html_td(dcc_input(id="lens-goal-min-$i", type="number", value=nothing, style=merge(BASE_STYLE_INPUT_CENTRE, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "15%", "borderBottom" => "none")), className="p-0"),
        html_td(dcc_input(id="lens-goal-target-$i", type="number", value=nothing, style=merge(BASE_STYLE_INPUT_CENTRE, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "15%", "borderBottom" => "none")), className="p-0"),
        html_td(dcc_input(id="lens-goal-max-$i", type="number", value=nothing, style=merge(BASE_STYLE_INPUT_CENTRE, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "15%", "borderBottom" => "none")), className="p-0"),
        html_td(dbc_select(id="lens-goal-type-$i", options=[
                    Dict("label" => "Nominal", "value" => "Nominal"),
                    Dict("label" => "Maximise", "value" => "Maximise"),
                    Dict("label" => "Minimise", "value" => "Minimise"),
                ], value="Nominal", className="form-select form-select-sm border-0 py-0", style=Dict("width" => "100%", "fontSize" => "10px", "backgroundColor" => "transparent", "color" => "#000000", "boxShadow" => "none")), style=merge(BASE_STYLE_CELL, Dict("width" => "20%")), className="p-1"),
        html_td(dbc_select(id="lens-goal-weight-$i", options=[
                    Dict("label" => "★☆☆☆☆", "value" => "0.25"),
                    Dict("label" => "★★☆☆☆", "value" => "0.50"),
                    Dict("label" => "★★★☆☆", "value" => "1.00"),
                    Dict("label" => "★★★★☆", "value" => "2.50"),
                    Dict("label" => "★★★★★", "value" => "5.00"),
                ], value="1.00", className="form-select form-select-sm border-0 py-0 text-center", style=Dict("width" => "100%", "fontSize" => "12px", "backgroundColor" => "transparent", "color" => "#B8860B", "boxShadow" => "none")), style=merge(BASE_STYLE_CELL, Dict("width" => "15%", "borderBottom" => "none")), className="p-1")
    ])
end

"""
    LENS_Layout_DDEF()
Constructs the statistical analysis and visualisation interface layout.
"""
function LENS_Layout_DDEF()
    return dbc_container(
        [
            # Page Header
            BASE_PageHeader_DDEF("Statistical Modelling and Data Optimisation", "Analyse experimental outcomes, evaluate complex factor interactions via robust mathematical models, and ascertain optimal solution matrices."),

            # Main Workspace
            dbc_row([
                    # --- LEFT COLUMN ---
                    dbc_col([
                            dbc_row(dbc_col(BASE_GlassPanel_DDEF("ANALYSIS CONFIGURATION", [
                                        # Data Ingestion
                                        dbc_row(dbc_col(dcc_upload(id="lens-upload-data",
                                                children=dbc_button([html_i(className="fas fa-file-import me-2"), "Import Dataset"],
                                                    color="secondary", outline=true, size="sm", className="w-100 mb-2"),
                                                multiple=false), xs=12)),
                                        dbc_row(dbc_col(dcc_loading(html_div(id="lens-upload-status", className="glass-loading-status mb-2"),
                                                type="default", color="#21918C"), xs=12)),
                                        dbc_row(dbc_col(html_hr(style=BASE_STYLE_HR, className="my-2"), xs=12)),

                                        # Exports Section
                                        dbc_row(dbc_col(html_div("EXPORT", className="small mb-1 fw-bold text-center"), xs=12)),
                                        dbc_row(dbc_col(dbc_button([html_i(className="fas fa-camera-retro me-1"), " Plots"],
                                                id="lens-btn-export-plots", color="secondary", outline=true, size="sm",
                                                className="w-100 fw-bold mb-2"), xs=12)),
                                        dbc_row(dbc_col(dbc_button([html_i(className="fas fa-file-export me-1"), " Report"],
                                                id="lens-btn-download-report", color="secondary", outline=true, size="sm",
                                                className="w-100 fw-bold mb-3"), xs=12)),
                                        dbc_row(dbc_col(html_hr(style=BASE_STYLE_HR, className="my-2"), xs=12)),

                                        # Control Settings
                                        dbc_row(dbc_col([
                                                dbc_label("Project Name", className="small mb-1"),
                                                dbc_input(id="lens-input-project", type="text", value="",
                                                    placeholder="Enter project name...", className="mb-2 form-control-sm"),
                                            ], xs=12)),
                                        dbc_row(dbc_col([
                                                dbc_label("Phase", className="small mb-1"),
                                                dcc_dropdown(id="lens-dd-phase",
                                                    options=[Dict("label" => "Phase 1", "value" => "Phase1")],
                                                    clearable=false, className="mb-3"),
                                            ], xs=12)),
                                        dbc_row(dbc_col([
                                                dbc_label("Model", className="small mb-1"),
                                                dcc_dropdown(id="lens-dd-model", options=[
                                                        Dict("label" => "Automatic", "value" => "Auto"),
                                                        Dict("label" => "Linear", "value" => "Linear"),
                                                        Dict("label" => "Quadratic", "value" => "Quadratic"),
                                                    ], value="Auto", clearable=false, className="mb-3"),
                                            ], xs=12)),
                                        dbc_row(dbc_col(html_hr(style=BASE_STYLE_HR, className="my-2"), xs=12)),

                                        # Radioactivity Panel
                                        html_div(id="lens-panel-radio", className="d-none", children=[
                                            dbc_row(dbc_col(html_div([html_i(className="fas fa-radiation-alt me-2 text-warning"), "RADIOACTIVITY"], className="small mb-2 fw-bold text-center"), xs=12)),
                                            dbc_row([
                                                dbc_col([
                                                        dbc_label("t_cal", className="small mb-0 text-muted", style=Dict("fontSize" => "10px")),
                                                        dbc_input(id="lens-date-cal", type="datetime-local", className="mb-2 form-control-sm", style=Dict("fontSize" => "11px")),
                                                    ], xs=12)
                                            ]),
                                            dbc_row([
                                                dbc_col([
                                                        dbc_label("t_exp", className="small mb-0 text-muted", style=Dict("fontSize" => "10px")),
                                                        dbc_input(id="lens-date-exp", type="datetime-local", className="mb-2 form-control-sm", style=Dict("fontSize" => "11px")),
                                                    ], xs=12)
                                            ]),
                                            dbc_row(dbc_col([
                                                    dbc_checklist(
                                                        id="lens-check-radio-correct",
                                                        options=[Dict("label" => "Decay Correction", "value" => true)],
                                                        value=[true],
                                                        className="small mb-2 fw-bold text-success",
                                                        switch=true
                                                    )
                                                ], xs=12)),
                                            dbc_row(dbc_col(html_hr(style=BASE_STYLE_HR, className="my-2"), xs=12)),
                                        ]),

                                        # Main Operations
                                        dbc_row(dbc_col(dbc_button([html_i(className="fas fa-file-alt me-2"), "Summary"],
                                                id="lens-btn-view-report", color="secondary", outline=true, size="sm", className="w-100 fw-bold mb-2", disabled=true), xs=12)),
                                        dbc_row(dbc_col(dbc_button([html_i(className="fas fa-forward me-2"), "Next Phase"],
                                                id="lens-btn-next-phase", color="secondary", outline=true, size="sm",
                                                className="w-100 fw-bold mb-2", disabled=true), xs=12)),
                                        dbc_row(dbc_col(dbc_button([html_i(className="fas fa-play me-2"), "Run Analysis"],
                                                id="lens-btn-run", color="primary", size="sm", className="w-100 fw-bold mb-2"), xs=12)), dcc_download(id="lens-download-result"),
                                        dcc_download(id="lens-download-plots"),
                                        dbc_row(dbc_col(dcc_loading(html_div(id="lens-run-output", className="mt-2 small"),
                                                type="default", color="#21918C"), xs=12)),
                                        dbc_row(dbc_col(dcc_loading(html_div(id="lens-export-output", className="mt-1 small"),
                                                type="default", color="#21918C"), xs=12)),
                                    ]; right_node=html_i(className="fas fa-sliders-h text-secondary"), overflow="visible"), xs=12)),
                        ]; xs=12, lg=3, className="mb-3 mb-lg-0"),

                    # --- RIGHT COLUMN ---
                    dbc_col([
                            # Optimisation Objectives Panel
                            BASE_GlassPanel_DDEF(["OPTIMISATION OBJECTIVES", html_span("", className="ms-2 text-muted fw-normal")], [
                                    dbc_row(dbc_col([
                                            html_div(html_table([
                                                        html_thead(html_tr([
                                                            html_th("RESPONSE", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "20%")), className="p-0"),
                                                            html_th("LOWER", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "15%")), className="p-0"),
                                                            html_th("TARGET", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "15%")), className="p-0"),
                                                            html_th("UPPER", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "15%")), className="p-0"),
                                                            html_th("OBJECTIVE", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "20%")), className="p-0"),
                                                            html_th("OVERALL IMPORTANCE", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "15%")), className="p-0"),
                                                        ])),
                                                        html_tbody([LENS_BuildGoalRow_DDEF(i) for i in 1:3])
                                                    ], style=Dict("width" => "100%", "borderCollapse" => "collapse", "color" => "#000000", "fontSize" => "10px", "tableLayout" => "fixed")), className="table-responsive m-0")
                                        ], xs=12)),
                                ]; panel_class="mb-3", content_class="glass-content p-2"),

                            # Model Performance Panel
                            BASE_GlassPanel_DDEF(["MODEL PERFORMANCE", html_span("", className="ms-2 text-muted fw-normal")], [
                                    dbc_row(dbc_col(html_div(id="lens-results-text", className="small px-2 table-responsive"), xs=12)),
                                ]; panel_class="mb-3", content_class="glass-content p-2"),

                            # Leader Candidates Panel
                            BASE_GlassPanel_DDEF(["LEADER CANDIDATES", html_span("", className="ms-2 text-muted fw-normal")], [
                                    dbc_row(dbc_col(html_div(id="lens-leaders-text", className="small px-2 table-responsive"), xs=12)),
                                ]; panel_class="mb-3", content_class="glass-content p-2"),

                            # Graph Index Panel
                            BASE_GlassPanel_DDEF("GRAPH INDEX", [
                                    html_div(id="lens-graph-info", className="p-1"),
                                ]; panel_class="mb-3", content_class="glass-content p-2"),

                            # Chart Viewer Panel
                            html_div([
                                    html_div(id="lens-graph-title",
                                        className="text-center small text-secondary mb-1 fw-bold"),
                                    dcc_loading(
                                        dcc_graph(
                                            id="lens-graph-main",
                                            style=Dict("minHeight" => "500px"),
                                            config=Dict("displayModeBar" => true, "displaylogo" => false, "responsive" => true),
                                            figure=BASE_EMPTY_FIGURE,
                                        ); type="default", color="#21918C"),
                                ], className="glass-panel mb-2 p-2", style=Dict("border" => "1px solid #DCDCDC", "borderRadius" => "8px")),

                            # Graph Navigation Controls
                            dbc_row(dbc_col(html_div([
                                        dbc_button(html_i(className="fas fa-chevron-left"),
                                            id="lens-btn-prev", color="secondary", outline=true, size="sm", className="me-1 px-2 py-1"),
                                        dcc_input(id="lens-graph-input", type="number", min=1, step=1, value=1, className="form-control form-control-sm mx-1 text-center bg-transparent border-secondary", style=Dict("width" => "60px", "height" => "28px", "fontSize" => "12px", "color" => "#000000")),
                                        html_span(id="lens-graph-counter", className="text-secondary small mx-1"),
                                        dbc_button(html_i(className="fas fa-chevron-right"),
                                            id="lens-btn-next", color="secondary", outline=true, size="sm", className="ms-1 px-2 py-1"),
                                    ], className="d-flex align-items-center justify-content-center py-2"), xs=12)),

                            # Persistent Stores
                            dcc_store(id="lens-store-graphs", data=[]),
                            dcc_store(id="lens-store-index", data=0),
                            dcc_store(id="lens-store-report", data=""),
                            dcc_store(id="lens-signal-process", data=Dict("ts" => 0, "success" => false)),
                        ]; xs=12, lg=9),
                ], className="g-3"),

            # Modal Dialogs
            BASE_Modal_DDEF("lens-modal-report", "DaishoDoE Scientific Intelligence Report",
                html_pre(id="lens-report-content", className="bg-dark text-success p-3 rounded small", style=Dict("whiteSpace" => "pre-wrap", "fontFamily" => "monospace", "maxHeight" => "500px", "overflowY" => "auto")),
                dbc_button("Download Report (TXT)", id="lens-btn-download-txt", color="success", className="w-100"); size="lg"),
            # Phase Wizard Modal
            BASE_Modal_DDEF("lens-modal-wizard", "Phase Transition Wizard",
                dbc_row(dbc_col([
                        html_p("The system will generate a new experimental phase based on the centre point you select.",
                            className="text-muted small"),
                        dbc_label("Source Phase"),
                        dcc_dropdown(id="lens-wiz-dd-source", options=[], clearable=false, className="mb-3"),
                        dbc_label("Generated Target Phase"),
                        dbc_input(id="lens-wiz-input-target", disabled=true, className="mb-3 text-success fw-bold"),
                    ], xs=12)),
                html_div([
                    dbc_button("Cancel", id="lens-wiz-btn-cancel", color="secondary", outline=true, className="me-2"),
                    dbc_button("Next: Select Leader", id="lens-wiz-btn-next", color="primary"),
                ]); close_button=false),

            # Leader Selection Modal
            BASE_Modal_DDEF("lens-modal-leader", [html_i(className="fas fa-magic me-2 text-primary"), "Select Leader Experiment"],
                dbc_row(dbc_col([
                        dbc_alert([
                                html_i(className="fas fa-info-circle me-2"),
                                "The system has algorithmically identified potential leaders based on your optimisation objectives. ",
                                "Please select the most promising run to serve as the reference centre for the next phase."
                            ], color="info", className="small py-2 mb-3"),
                        html_div(BASE_DataTable_DDEF("lens-table-candidates", [
                                    Dict("name" => "ID", "id" => "ID"),
                                    Dict("name" => "Score", "id" => "Score")
                                ], []; row_selectable="single", selected_rows=[]), id="lens-container-candidates", className="table-responsive"),
                    ], xs=12)),
                dbc_row([
                        dbc_col(dbc_button([html_i(className="fas fa-chevron-left me-1"), "Back"], id="lens-lead-btn-back", color="secondary", outline=true, size="sm", className="w-100 mb-2 mb-md-0"), xs=12, md=2),
                        dbc_col(dbc_button([html_i(className="fas fa-times me-1"), "Cancel"], id="lens-lead-btn-cancel", color="secondary", outline=true, size="sm", className="w-100 mb-2 mb-md-0"), xs=12, md=2, className="ms-md-auto"),
                        dbc_col(dbc_button([html_i(className="fas fa-save me-1"), "SAVE & GENERATE NEXT PHASE"], id="lens-lead-btn-confirm", color="primary", disabled=true, size="sm", className="w-100"), xs=12, md=5),
                    ], className="w-100 g-2"); size="xl", close_button=false),], fluid=true, className="px-4 py-3")
end

# --------------------------------------------------------------------------------------
# SECTION 2: REACTIVE LOGIC (CALLBACKS)
# --------------------------------------------------------------------------------------

"""
    LENS_RegisterCallbacks_DDEF(app)
Orchestrates all reactive behavior for the LENS module.
"""
function LENS_RegisterCallbacks_DDEF(app)
    C = Sys_Fast.FAST_Constants_DDEF()

    # --- 1A. PIPELINE: LOCAL UPLOAD -> GLOBAL SYNC BUS ---
    callback!(app,
        Output("sync-lens-content", "data"),
        Input("lens-upload-data", "contents"),
        prevent_initial_call=true
    ) do cont
        (isnothing(cont) || cont == "") && return Dash.no_update()
        # Return raw base64 content to the sync store (app.jl will push to Master Vault)
        return cont
    end

    # --- 1B. PIPELINE: GLOBAL SYNC -> GOAL INITIALIZATION ---
    callback!(app,
        Output("lens-dd-phase", "options"),
        Output("lens-upload-status", "children"),
        Output("lens-dd-phase", "value"),
        [Output("lens-goal-name-$i", "value") for i in 1:3]...,
        [Output("lens-goal-min-$i", "value") for i in 1:3]...,
        [Output("lens-goal-target-$i", "value") for i in 1:3]...,
        [Output("lens-goal-max-$i", "value") for i in 1:3]...,
        [Output("lens-goal-type-$i", "value") for i in 1:3]...,
        [Output("lens-goal-weight-$i", "value") for i in 1:3]...,
        Output("lens-dd-model", "options"),
        Output("lens-dd-model", "value"),
        Output("lens-panel-radio", "className"),
        Output("lens-check-radio-correct", "value"),
        Output("lens-date-cal", "value"),
        Output("lens-date-exp", "value"),
        Input("store-master-vault", "data"),
        prevent_initial_call=true
    ) do active_cont
        # Determine temp path BEFORE try for guaranteed cleanup
        path = ""
        try  # Error guard for sync callback
            (isnothing(active_cont) || active_cont == "") &&
                return [], "No Data Source", nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., Dash.no_update(), Dash.no_update(), "d-none", [true], "", ""

            Sys_Fast.FAST_Log_DDEF("LENS", "Sync", "Synchronizing from Master Vault...", "INFO")
            path = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)

            df = Sys_Fast.FAST_ReadExcel_DDEF(path, C.SHEET_DATA)
            isempty(df) && (df = Sys_Fast.FAST_ReadExcel_DDEF(path, "DATA_RECORDS"))

            phases = map(unique(df[:, Symbol(C.COL_PHASE)])) do p
                Dict("label" => string(p), "value" => string(p))
            end

            out_cols = filter(c -> startswith(c, C.PRE_RESULT), names(df))
            goals_name = fill("", 3)
            goals_min = fill(0.0, 3)
            goals_target = fill(0.0, 3)
            goals_max = fill(0.0, 3)
            goals_type = fill("Nominal", 3)
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
                goals_name[i] = replace(c, C.PRE_RESULT => "")
                goals_type[i] = "Nominal"
                goals_min[i] = round(mn; digits=2)
                goals_max[i] = round(mx; digits=2)
                goals_target[i] = round((mn + mx) / 2; digits=2)
            end

            config = Sys_Fast.FAST_ReadConfig_DDEF(path)
            method = get(get(config, "Global", Dict()), "Method", "")

            if method == "Taguchi_L9"
                model_opts = [Dict("label" => "Linear (Taguchi Constraint)", "value" => "Linear")]
                model_val = "Linear"
            elseif method == "BoxBehnken"
                model_opts = [Dict("label" => "Quadratic (Standard BB)", "value" => "Quadratic"), Dict("label" => "Linear", "value" => "Linear")]
                model_val = "Quadratic"
            else
                model_opts = [
                    Dict("label" => "Automatic (Auto)", "value" => "Auto"),
                    Dict("label" => "Linear", "value" => "Linear"),
                    Dict("label" => "Quadratic", "value" => "Quadratic")
                ]
                model_val = "Auto"
            end

            # --- GOAL OVERRIDES ---
            saved_goals = get(config, "LensGoals", [])
            for (i, name) in enumerate(goals_name)
                g_idx = findfirst(g -> get(g, "Name", "") == name, saved_goals)
                if !isnothing(g_idx)
                    saved_g = saved_goals[g_idx]
                    goals_type[i] = string(get(saved_g, "Type", "Nominal"))
                    goals_weight[i] = Printf.@sprintf("%.2f", Main.Sys_Fast.FAST_SafeNum_DDEF(get(saved_g, "Weight", 1.0)))
                    goals_target[i] = Float64(get(saved_g, "Target", goals_target[i]))
                    goals_min[i] = Float64(get(saved_g, "Min", goals_min[i]))
                    goals_max[i] = Float64(get(saved_g, "Max", goals_max[i]))
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
            rad_apply = get(saved_radio, "Apply", true) ? [true] : []
            rad_t_cal = string(get(saved_radio, "t_cal", ""))
            rad_t_exp = string(get(saved_radio, "t_exp", ""))

            return (
                phases,
                html_span("✅ System Synced", className="text-success small fw-bold"),
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
                rad_apply,
                rad_t_cal,
                rad_t_exp
            )

        catch e  # Surface sync errors to status area
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "SYNC_FAIL", bt, "FAIL")
            return [], html_span("❌ Sync Error: $(first(string(e), 120))", className="text-danger small"),
            nothing, ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)..., ntuple(_ -> "1.00", 3)..., Dash.no_update(), Dash.no_update(), "d-none", [true], "", ""
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
        Output("lens-store-graphs", "data"),
        Output("lens-results-text", "children"),
        Output("lens-run-output", "children"),
        Output("lens-btn-next-phase", "disabled"),
        Output("lens-btn-view-report", "disabled"),
        Output("lens-store-report", "data"),
        Output("sync-lens-analysis", "data"),
        Output("lens-leaders-text", "children"),
        Input("lens-btn-run", "n_clicks"),
        State("lens-dd-phase", "value"),
        State("lens-dd-model", "value"),
        [State("lens-goal-name-$i", "value") for i in 1:3]...,
        [State("lens-goal-min-$i", "value") for i in 1:3]...,
        [State("lens-goal-target-$i", "value") for i in 1:3]...,
        [State("lens-goal-max-$i", "value") for i in 1:3]...,
        [State("lens-goal-type-$i", "value") for i in 1:3]...,
        [State("lens-goal-weight-$i", "value") for i in 1:3]...,
        State("lens-check-radio-correct", "value"),
        State("lens-date-cal", "value"),
        State("lens-date-exp", "value"),
        State("store-master-vault", "data"),
        prevent_initial_call=true
    ) do args...
        n, phase, model = args[1:3]

        rad_apply_val = args[22]
        is_rad_apply = !isnothing(rad_apply_val) && !isempty(rad_apply_val) && rad_apply_val[1] == true
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
                    "Name" => string(gnames[i]),
                    "Min" => isnothing(gmins[i]) ? 0.0 : Float64(gmins[i]),
                    "Target" => isnothing(gtargets[i]) ? 0.0 : Float64(gtargets[i]),
                    "Max" => isnothing(gmaxes[i]) ? 0.0 : Float64(gmaxes[i]),
                    "Type" => isnothing(gtypes[i]) ? "Nominal" : string(gtypes[i]),
                    "Weight" => isnothing(gweights[i]) ? 1.0 : parse(Float64, string(gweights[i]))
                ))
            end
        end
        (n === nothing || n == 0) && return [], "", "", true, true, "", Dash.no_update(), Dash.no_update()
        isnothing(base64_file) &&
            return [], "", html_span("Please upload data first.", className="text-warning"), true, true, "", Dash.no_update(), Dash.no_update()

        # Race condition lock: reject concurrent analysis requests
        if !Sys_Fast.FAST_AcquireLock_DDEF("VISE_ANALYSIS")
            Sys_Fast.FAST_Log_DDEF("LENS", "LOCK_REJECT",
                "Analysis already running. New request rejected.", "WARN")
            return Dash.no_update(), Dash.no_update(),
            html_span("⚠ An analysis is already in progress. Please wait.",
                className="text-warning fw-bold"), true, true, Dash.no_update(), Dash.no_update(), Dash.no_update()
        end

        # Create temp file BEFORE try so finally can always clean it
        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)

        try  # Error guard for analysis engine
            Sys_Fast.FAST_Log_DDEF("LENS", "Process", "Starting GLM Analysis (Phase: $phase)...", "WAIT")

            opts = Dict{String,Any}(
                "RadioOpts" => Dict(
                    "Apply" => is_rad_apply,
                    "t_cal" => t_cal,
                    "t_exp" => t_exp
                )
            )

            phase_str = isnothing(phase) ? "Phase1" : string(phase)
            model_str = isnothing(model) ? "Auto" : string(model)

            res = Lib_Vise.VISE_Execute_DDEF(path, phase_str, goals, model_str; Opts=opts)

            if res["Status"] != "OK"
                return [], "", html_span("❌ Analysis Failed: $(res["Message"])", className="text-danger"), true, true, "", Dash.no_update(), ""
            end

            # Generate and capture Scientific Report
            sci_report = Lib_Vise.VISE_GenerateScientificReport_DDEF(res)

            # Serialise PlotlyJS objects to JSON for Dash
            graphs = [
                Dict("figure" => JSON.parse(JSON.json(g["Plot"])), "title" => g["Title"])
                for g in res["Graphs"]
            ]

            # Build Model Summary View
            summary_rows = [
                html_tr([
                        html_td(n, style=Dict("textAlign" => "center", "padding" => "6px"), className="fw-bold"),
                        html_td(@sprintf("%.3f", res["R2_Adj"][i]), style=Dict("textAlign" => "center", "padding" => "6px")),
                        html_td(@sprintf("%.3f", res["R2_Pred"][i]), style=Dict("textAlign" => "center", "padding" => "6px")),
                        html_td(
                            (haskey(res["Models"][i], "P_Value") && !isnan(res["Models"][i]["P_Value"])) ?
                            @sprintf("%.5f", res["Models"][i]["P_Value"]) : "N/A", style=Dict("textAlign" => "center", "padding" => "6px")
                        ),
                    ], style=Dict("borderBottom" => "1px solid #DCDCDC")) for (i, n) in enumerate(res["OutNames"])
            ]

            summary = html_div([
                html_table([
                        html_thead(html_tr([
                            html_th("Output", style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC", "padding" => "8px")),
                            html_th("R² (Adj)", style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC", "padding" => "8px")),
                            html_th("Q² (Pred)", style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC", "padding" => "8px")),
                            html_th("P-Value", style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC", "padding" => "8px"))
                        ])),
                        html_tbody(summary_rows, style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC")),
                    ], className="table table-sm table-borderless caption-top mb-1 mx-auto", style=Dict("width" => "95%", "marginTop" => "5px")),

                # --- NEW: SCIENTIFIC VITALS TABLE ---
                (haskey(res, "Vitals") ? html_div([
                    html_hr(style=Dict("height" => "1px", "border" => "none", "borderTop" => "1px dashed #DCDCDC", "margin" => "10px 0")),
                    html_div([
                            html_div([
                                    html_span("D-Efficiency: ", className="text-secondary"),
                                    html_span(@sprintf("%.3f", res["Vitals"]["D"]), className="fw-bold text-dark"),
                                ], className="me-4"),
                            html_div([
                                    html_span("Max VIF: ", className="text-secondary"),
                                    html_span(@sprintf("%.2f", res["Vitals"]["MaxVIF"]),
                                        className=res["Vitals"]["MaxVIF"] > 10 ? "fw-bold text-danger" : "fw-bold text-success"),
                                ], className="me-4"),
                            html_div([
                                    html_span("Lack-of-Fit P: ", className="text-secondary"),
                                    html_span(@sprintf("%.3f", res["Vitals"]["LOF"]),
                                        className=res["Vitals"]["LOF"] < 0.05 ? "fw-bold text-danger" : "fw-bold text-success"),
                                ], className="me-4"),
                            html_div([
                                html_span("Matrix Condition: ", className="text-secondary"),
                                html_span(@sprintf("%.1e", res["Vitals"]["Condition"]), className="fw-bold text-dark"),
                            ]),
                        ], className="d-flex justify-content-center small py-1 bg-light rounded")
                ]) : html_div())
            ])

            # --- Persist Analysis Configuration (Goals & RadioOpts) ---
            Sys_Fast.FAST_UpdateConfig_DDEF(path, Dict("LensGoals" => goals, "RadioOpts" => opts["RadioOpts"]))

            updated_base64 = Sys_Fast.FAST_ReadToStore_DDEF(path)

            # --- Build Leader Candidates Table ---
            leaders_html = ""
            if haskey(res, "Leaders") && !isempty(res["Leaders"])
                ldf = res["Leaders"]
                C = Sys_Fast.FAST_Constants_DDEF()
                lcols = names(ldf)

                # Column ordering: ID, Input Variables, Predicted Outputs, Score
                id_col = findfirst(c -> c == C.COL_EXP_ID || c == C.COL_ID, lcols)
                in_cols_l = filter(c -> startswith(c, C.PRE_INPUT), lcols)
                pred_cols_l = filter(c -> startswith(c, C.PRE_PRED), lcols)
                score_col = findfirst(==(C.COL_SCORE), lcols)

                # Build display header names
                display_cols = String[]
                display_names = String[]
                if !isnothing(id_col)
                    push!(display_cols, lcols[id_col])
                    push!(display_names, "ID")
                end
                for c in in_cols_l
                    push!(display_cols, c)
                    push!(display_names, replace(c, C.PRE_INPUT => ""))
                end
                for c in pred_cols_l
                    push!(display_cols, c)
                    push!(display_names, replace(c, C.PRE_PRED => ""))
                end
                if !isnothing(score_col)
                    push!(display_cols, lcols[score_col])
                    push!(display_names, "Score")
                end

                th_style = Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC", "padding" => "4px 6px", "fontSize" => "10px", "whiteSpace" => "nowrap")
                td_style = Dict("textAlign" => "center", "padding" => "3px 6px", "fontSize" => "10px")

                header_row = html_tr([html_th(n, style=th_style) for n in display_names])
                body_rows = [html_tr([
                        html_td(
                            let v = ldf[r, Symbol(c)]
                                ismissing(v) ? "-" : (v isa Number ? @sprintf("%.3f", v) : string(v))
                            end,
                            style=merge(td_style, c == C.COL_SCORE ? Dict("fontWeight" => "bold", "color" => "#21918C") : Dict())
                        ) for c in display_cols
                    ], style=Dict("borderBottom" => "1px solid #E6E6E6")) for r in 1:nrow(ldf)]

                leaders_html = html_table([
                        html_thead(header_row),
                        html_tbody(body_rows),
                    ], className="table table-sm table-borderless mb-0 mx-auto", style=Dict("width" => "100%", "marginTop" => "5px"))
            end

            # Show elapsed time in analysis success message
            elapsed_str = get(res, "Elapsed", "")
            elapsed_badge = isempty(elapsed_str) ? "" :
                            html_span(" ($elapsed_str)", className="text-muted")

            return graphs, summary, html_span(["✅ Analysis Complete", elapsed_badge],
                className="text-success fw-bold small"), false, false, sci_report, updated_base64, leaders_html

        catch e  # Surface analysis errors to UI
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "ANALYSIS_CRASH", bt, "FAIL")
            return [], "",
            html_span("❌ Critical Error: $(first(string(e), 150))", className="text-danger fw-bold"), true, true, "", Dash.no_update(), ""
        finally
            # Guaranteed temp file cleanup (prevents disk leak)
            Sys_Fast.FAST_CleanTransient_DDEF(path)
            # Always release the lock, even if an error occurred
            Sys_Fast.FAST_ReleaseLock_DDEF("VISE_ANALYSIS")
        end
    end

    # --- 3. UI: VISUALIZATION SLIDE NAVIGATION ---
    callback!(app,
        Output("lens-store-index", "data"),
        Output("lens-graph-input", "value"),
        Output("lens-graph-input", "max"),
        Input("lens-store-graphs", "data"),
        Input("lens-btn-next", "n_clicks"),
        Input("lens-btn-prev", "n_clicks"),
        Input("lens-graph-input", "value"),
        State("lens-store-index", "data"),
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
        Output("lens-graph-main", "figure"),
        Output("lens-graph-title", "children"),
        Output("lens-graph-counter", "children"),
        Output("lens-graph-info", "children"),
        Input("lens-store-index", "data"),
        State("lens-store-graphs", "data")
    ) do i, g
        (isnothing(g) || isempty(g)) && return Dict(), "No Visualization Data", "/ 0", ""
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
            push!(info_parts, "$t ($curr_start-$(curr_start+c-1))")
            curr_start += c
        end

        function format_line(items)
            return html_div([
                    html_span(item, style=Dict(
                        "width" => "33.3%", 
                        "textAlign" => "center", 
                        "whiteSpace" => "nowrap", 
                        "padding" => "4px 0", 
                        "fontSize" => "11px", 
                        "fontWeight" => "600",
                        "color" => "#2C3E50"
                    )) for item in items
                ], style=Dict("display" => "flex", "width" => "100%", "justifyContent" => "space-around"))
        end

        info_html = html_div([
                format_line(info_parts[1:min(length(info_parts), 3)]),
                length(info_parts) > 3 ? format_line(info_parts[4:min(length(info_parts), 6)]) : html_div(),
                length(info_parts) > 6 ? format_line(info_parts[7:min(length(info_parts), 9)]) : html_div()
            ], style=Dict("display" => "flex", "flexDirection" => "column", "width" => "100%", "padding" => "2px 0"))

        return g[idx]["figure"], g[idx]["title"], "/ $(length(g))", info_html
    end

    # --- 5. PIPELINE: WIZARD ENTRANCE ---
    callback!(app,
        Output("lens-modal-wizard", "is_open"),
        Output("lens-wiz-dd-source", "options"),
        Output("lens-wiz-dd-source", "value"),
        Output("lens-wiz-input-target", "value"),
        Input("lens-btn-next-phase", "n_clicks"),
        Input("lens-lead-btn-back", "n_clicks"),
        Input("lens-wiz-btn-cancel", "n_clicks"),
        Input("lens-wiz-btn-next", "n_clicks"),
        State("lens-dd-phase", "value"),
        prevent_initial_call=true
    ) do n, b, c, n_nxt, ph
        trig = BASE_GetTrigger_DDEF(callback_context())
        trig == "lens-wiz-btn-cancel" && return false, [], "", ""
        trig == "lens-wiz-btn-next" && return false, Dash.no_update(), Dash.no_update(), Dash.no_update()

        src_phase = isnothing(ph) ? "Phase1" : ph
        digit_match = match(r"\d+", src_phase)
        next_val = isnothing(digit_match) ? 2 : parse(Int, digit_match.match) + 1

        Sys_Fast.FAST_Log_DDEF("LENS", "Wizard",
            "Initiating phase transition: $src_phase -> Phase$next_val", "INFO")

        return true, [Dict("label" => src_phase, "value" => src_phase)], src_phase, "Phase$next_val"
    end

    # --- 6. UI: CANDIDATE DATA LOADER ---
    callback!(app,
        Output("lens-table-candidates", "data"),
        Output("lens-table-candidates", "columns"),
        Input("lens-modal-leader", "is_open"),
        State("lens-wiz-dd-source", "value"),
        State("store-master-vault", "data"),
        prevent_initial_call=true
    ) do is_open, src, base64_file
        # Guard: only load candidates when the leader modal is opening
        !is_open && return Dash.no_update(), Dash.no_update()
        isnothing(base64_file) && return [], []

        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)
        data = Sys_Flow.FLOW_GetCandidates_DDEF(path, src)
        Sys_Fast.FAST_CleanTransient_DDEF(path)

        if isempty(data)
            return [], []
        end

        # --- DYNAMIC COLUMN GENERATION ---
        # Identify all keys in the first candidate (collect to avoid KeySet iteration bug)
        all_keys = collect(keys(data[1]))

        # Filter and prioritize columns
        # Priority: ID, then VARIA_, then PRED_, then SCORE (last)
        cols_to_show = String[]

        # Find ID column key
        h_id_idx = findfirst(k -> occursin("ID", uppercase(string(k))), all_keys)
        !isnothing(h_id_idx) && push!(cols_to_show, string(all_keys[h_id_idx]))

        # Add Input Variables
        v_cols = sort(filter(k -> startswith(uppercase(string(k)), "VARIA_"), collect(all_keys)))
        append!(cols_to_show, string.(v_cols))

        # Add Predictions
        p_cols = sort(filter(k -> startswith(uppercase(string(k)), "PRED_"), collect(all_keys)))
        append!(cols_to_show, string.(p_cols))

        # Score at the END
        h_score_idx = findfirst(k -> uppercase(string(k)) == "SCORE", all_keys)
        !isnothing(h_score_idx) && push!(cols_to_show, string(all_keys[h_score_idx]))

        columns = [Dict{String,Any}("name" => replace(c, r"^(VARIA_|PRED_)" => ""), "id" => c) for c in cols_to_show]

        # Add formatting for Score
        for col in columns
            if col["id"] == "Score" || col["id"] == "SCORE"
                col["type"] = "numeric"
                col["format"] = Dict("specifier" => ".4f")
            end
        end

        return data, columns
    end


    # --- 7. UI: MODAL SEQUENTIAL SWITCHING ---
    callback!(app,
        Output("lens-modal-leader", "is_open"),
        Input("lens-wiz-btn-next", "n_clicks"),
        Input("lens-lead-btn-cancel", "n_clicks"),
        Input("lens-lead-btn-back", "n_clicks"),
        Input("lens-signal-process", "data")
    ) do n_nxt, n_cncl, n_bck, sig
        trig = BASE_GetTrigger_DDEF(callback_context())
        trig == "lens-wiz-btn-next" && return true
        (trig == "lens-lead-btn-cancel" || trig == "lens-lead-btn-back") && return false
        trig == "lens-signal-process" && return !(get(sig, "success", false))
        return Dash.no_update()
    end

    # --- 8. UI: REPORT MODAL CONTROL ---
    callback!(app,
        Output("lens-modal-report", "is_open"),
        Output("lens-report-content", "children"),
        Input("lens-btn-view-report", "n_clicks"),
        State("lens-store-report", "data"),
        prevent_initial_call=true
    ) do n, report
        n > 0 && return true, report
        return false, ""
    end
    # --- 9. UI: CONDITIONAL ACTION ENABLING ---
    callback!(app,
        Output("lens-lead-btn-confirm", "disabled"),
        Input("lens-table-candidates", "selected_rows")
    ) do s
        return isnothing(s) || isempty(s)
    end

    # --- 10. LOGIC: RESULT FINALIZATION ---
    callback!(app,
        Output("lens-download-result", "data"),
        Output("lens-signal-process", "data"),
        Input("lens-lead-btn-confirm", "n_clicks"),
        Input("lens-btn-download-report", "n_clicks"),
        State("lens-input-project", "value"),
        State("lens-table-candidates", "selected_rows"),
        State("lens-table-candidates", "data"),
        State("lens-wiz-dd-source", "value"),
        State("store-master-vault", "data"),
        prevent_initial_call=true
    ) do n_sav, n_rep, project, row, data, src, base64_file
        (isnothing(n_sav) || n_sav == 0) && (isnothing(n_rep) || n_rep == 0) && return Dash.no_update(), Dash.no_update()

        # Create path before try for guaranteed cleanup
        path = ""
        try  # Error guard for finalization callback
            trig = BASE_GetTrigger_DDEF(callback_context())

            isnothing(base64_file) && return nothing, Dash.no_update()
            path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)

            # Excel-Centric Phase Transition: generate Phase2 design and write to Excel
            target_phase_label = isnothing(src) ? "Phase1" : src
            if trig == "lens-lead-btn-confirm"
                sel_row = data[row[1]+1]
                sel_keys = collect(keys(sel_row))
                id_idx = findfirst(k -> occursin("ID", uppercase(string(k))), sel_keys)
                id = !isnothing(id_idx) ? string(sel_row[sel_keys[id_idx]]) : ""

                res_build = Sys_Flow.FLOW_BuildNextPhase_DDEF(path, isnothing(src) ? "Phase1" : src, id)
                if res_build["Status"] == "OK"
                    target_phase_label = res_build["TargetPhase"]
                    Sys_Fast.FAST_Log_DDEF("FLOW", "PHASE_COMPLETE",
                        "$(res_build["TargetPhase"]) ($(res_build["N_Runs"]) runs) ready for download.", "OK")
                else
                    Sys_Fast.FAST_Log_DDEF("FLOW", "PHASE_FAIL",
                        "Phase transition failed: $(get(res_build, "Message", "Unknown"))", "FAIL")
                end
            end

            # Read updated file (now contains Phase2 data) and prepare download
            ok, bytes = Sys_Fast.FAST_PrepareDownload_DDEF(path)
            updated_base64 = Sys_Fast.FAST_ReadToStore_DDEF(path)

            fname = Sys_Fast.FAST_GenerateSmartName_DDEF(
                isnothing(project) ? "Daisho" : project, target_phase_label, "READY")

            return (
                Dict("filename" => fname, "content" => base64encode(bytes), "base64" => true),
                Dict("success" => ok, "base64" => updated_base64),
            )

        catch e  # Surface finalization errors
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "FINALIZE_CRASH", bt, "FAIL")
            return nothing, Dict("success" => false)
        finally
            # Guaranteed temp file cleanup
            !isempty(path) && try
                rm(path; force=true)
            catch
            end
        end
    end

    # --- 11. HIGH-RES PLOT EXPORT ---
    callback!(app,
        Output("lens-download-plots", "data"),
        Output("lens-export-output", "children"),
        Input("lens-btn-export-plots", "n_clicks"),
        State("lens-store-graphs", "data"),
        State("lens-input-project", "value"),
        State("lens-dd-phase", "value"),
        prevent_initial_call=true
    ) do n, graphs, proj, phase
        (isnothing(n) || n == 0 || isnothing(graphs) || isempty(graphs)) &&
            return Dash.no_update(), Dash.no_update()

        try
            project = isnothing(proj) ? "Daisho" : proj
            ph = isnothing(phase) ? "Phase1" : phase

            temp_uuid = replace(string(Base.UUID(rand(UInt128))), "-" => "")
            export_dir = joinpath(tempdir(), "DaishoRender_$temp_uuid")
            mkpath(export_dir)

            count = 0
            for (i, g) in enumerate(graphs)
                fig_dict = JSON.parse(JSON.json(g["figure"]))
                title = get(g, "title", "Plot_$i")

                # Apply Light Theme via BASE function
                fig_dict = BASE_ConvertThemePlotlyWhite_DDEF!(fig_dict)

                safe_title = replace(title, r"[^\w\-_\\.]" => "_")
                filepath = joinpath(export_dir, "$(safe_title).png")

                traces = [GenericTrace(d) for d in fig_dict["data"]]
                layout_obj = Layout(fig_dict["layout"])
                p = Plot(traces, layout_obj)

                savefig(p, filepath; width=1200, height=800, scale=2)
                count += 1
            end

            zip_path = joinpath(tempdir(), "Daisho_$(project)_$(ph)_Plots.zip")
            let zdir = ZipFile.Writer(zip_path)
                for file in readdir(export_dir)
                    fpath = joinpath(export_dir, file)
                    f = ZipFile.addfile(zdir, file; method=ZipFile.Deflate)
                    write(f, read(fpath))
                end
                close(zdir)
            end

            bytes = read(zip_path)
            rm(export_dir; recursive=true, force=true)
            rm(zip_path; force=true)

            Sys_Fast.FAST_Log_DDEF("LENS", "Export", "Zipped $count high-res plots.", "OK")
            return (
                Dict("filename" => "Daisho_$(project)_$(ph)_Plots.zip",
                    "content" => base64encode(bytes), "base64" => true),
                html_span("✅ Successfully downloaded $count High-Res plots.",
                    className="text-success fw-bold"),
            )
        catch e
            Sys_Fast.FAST_Log_DDEF("LENS", "Export_Error", string(e), "FAIL")
            return Dash.no_update(),
            html_span("❌ Error during plot export (Kaleido missing?): $e",
                className="text-danger fw-bold")
        end
    end
end

end # module
