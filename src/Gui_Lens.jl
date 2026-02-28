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
using PlotlyJS: JSON, savefig, Plot, GenericTrace, Layout  # Used for graph serialization and export
using ZipFile
using Base64

export LENS_Layout_DDEF, LENS_RegisterCallbacks_DDEF

# --------------------------------------------------------------------------------------
# SECTION 1: INTERFACE LAYOUT
# --------------------------------------------------------------------------------------

"""
    LENS_Layout_DDEF()
Constructs the statistical analysis and visualization interface.
"""
function LENS_BuildGoalRow_DDEF(i)
    return html_tr([
        html_td(dcc_input(id="lens-goal-name-$i", type="text", value="", style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0", disabled=true), style=merge(BASE_STYLE_CELL, Dict("width" => "24%", "backgroundColor" => "#FFFFFF", "borderBottom" => "none")), className="p-0"),
        html_td(dcc_input(id="lens-goal-min-$i", type="number", value=nothing, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "19%", "borderBottom" => "none")), className="p-0"),
        html_td(dcc_input(id="lens-goal-target-$i", type="number", value=nothing, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "19%", "borderBottom" => "none")), className="p-0"),
        html_td(dcc_input(id="lens-goal-max-$i", type="number", value=nothing, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "19%", "borderBottom" => "none")), className="p-0"),
        html_td(dbc_select(id="lens-goal-type-$i", options=[
                    Dict("label" => "Nominal", "value" => "Nominal"),
                    Dict("label" => "Maximise", "value" => "Maximize"),
                    Dict("label" => "Minimise", "value" => "Minimize"),
                    Dict("label" => "Monitor", "value" => "Monitor"),
                ], value="Nominal", className="form-select form-select-sm border-0 py-0", style=Dict("width" => "100%", "fontSize" => "10px", "backgroundColor" => "transparent", "color" => "#000000", "boxShadow" => "none")), style=merge(BASE_STYLE_CELL, Dict("width" => "19%")), className="p-1")
    ])
end

function LENS_Layout_DDEF()
    return dbc_container([
            # A. Page Header
            BASE_PageHeader("Statistical Analysis Engine", "Analyze experiment results, optimize factors, and visualize data."),

            # B. Workspace Context
            dbc_row([
                    # --- LEFT COLUMN: Configuration & Goals ---
                    dbc_col([
                            dbc_row(dbc_col(BASE_GlassPanel("ANALYSIS CONFIGURATION", [
                                        # 1. Data Ingestion
                                        dbc_row(dbc_col(dcc_upload(id="lens-upload-data",
                                                children=dbc_button([html_i(className="fas fa-file-import me-2"), "Import Dataset"],
                                                    color="secondary", outline=true, size="sm", className="w-100 mb-2"),
                                                multiple=false), xs=12)),
                                        dbc_row(dbc_col(dcc_loading(html_div(id="lens-upload-status", className="glass-loading-status mb-2"),
                                                type="default", color="#21918C"), xs=12)),
                                        dbc_row(dbc_col(html_hr(style=BASE_STYLE_HR, className="my-2"), xs=12)),

                                        # 2. Downloads Section
                                        dbc_row(dbc_col(html_div("DOWNLOADS", className="small mb-1 fw-bold text-center"), xs=12)),
                                        dbc_row(dbc_col(dbc_button([html_i(className="fas fa-camera-retro me-1"), " Plots"],
                                                id="lens-btn-export-plots", color="secondary", outline=true, size="sm",
                                                className="w-100 fw-bold mb-2"), xs=12)),
                                        dbc_row(dbc_col(dbc_button([html_i(className="fas fa-file-export me-1"), " Report"],
                                                id="lens-btn-download-report", color="secondary", outline=true, size="sm",
                                                className="w-100 fw-bold mb-3"), xs=12)),
                                        dbc_row(dbc_col(html_hr(style=BASE_STYLE_HR, className="my-2"), xs=12)),

                                        # 3. Control Settings
                                        dbc_row(dbc_col([
                                                dbc_label("Project Name", className="small mb-1"),
                                                dbc_input(id="lens-input-project", type="text", value="",
                                                    placeholder="Enter project name...", className="mb-2 form-control-sm"),
                                            ], xs=12)),
                                        dbc_row(dbc_col([
                                                dbc_label("Phase", className="small mb-1"),
                                                dcc_dropdown(id="lens-dd-phase",
                                                    options=[Dict("label" => "Loading...", "value" => "NONE")],
                                                    clearable=false, className="mb-3"),
                                            ], xs=12)),
                                        dbc_row(dbc_col([
                                                dbc_label("Model", className="small mb-1"),
                                                dcc_dropdown(id="lens-dd-model", options=[
                                                        Dict("label" => "Auto", "value" => "Auto"),
                                                        Dict("label" => "Linear", "value" => "Linear"),
                                                        Dict("label" => "Quadratic", "value" => "Quadratic"),
                                                    ], value="Auto", clearable=false, className="mb-3"),
                                            ], xs=12)),
                                        dbc_row(dbc_col(html_hr(style=BASE_STYLE_HR, className="my-2"), xs=12)),

                                        # 4. Main Operations
                                        dbc_row(dbc_col(dbc_button([html_i(className="fas fa-rocket me-2"), "Next Phase"],
                                                id="lens-btn-next-phase", color="secondary", outline=true, size="sm",
                                                className="w-100 fw-bold mb-2", disabled=true), xs=12)),
                                        dbc_row(dbc_col(dbc_button([html_i(className="fas fa-play me-2"), "Run Analysis"],
                                                id="lens-btn-run", color="primary", size="sm", className="w-100 fw-bold mb-2"), xs=12)),

                                        # Application & Export Group hidden state loaders
                                        dcc_download(id="lens-download-result"),
                                        dcc_download(id="lens-download-plots"),
                                        dbc_row(dbc_col(dcc_loading(html_div(id="lens-run-output", className="mt-2 small"),
                                                type="default", color="#21918C"), xs=12)),
                                        dbc_row(dbc_col(dcc_loading(html_div(id="lens-export-output", className="mt-1 small"),
                                                type="default", color="#21918C"), xs=12)),
                                    ]; right_node=html_i(className="fas fa-cog text-secondary"), overflow="visible"), xs=12)),
                        ]; xs=12, lg=3, className="mb-3 mb-lg-0"),

                    # --- RIGHT COLUMN: Visualization Deck ---
                    dbc_col([
                            BASE_GlassPanel(["OPTIMIZATION TARGETS", html_span(" — Configure desirability objectives to guide the algorithmic search.", className="ms-2 text-muted fw-normal", style=Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0"))], [
                                    dbc_row(dbc_col([
                                            html_div(html_table([
                                                        html_thead(html_tr([
                                                            html_th("RESPONSE", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "24%")), className="p-0"),
                                                            html_th("LOWER", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "19%")), className="p-0"),
                                                            html_th("TARGET", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "19%")), className="p-0"),
                                                            html_th("UPPER", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "19%")), className="p-0"),
                                                            html_th("OBJECTIVE", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "19%")), className="p-0"),
                                                        ])),
                                                        html_tbody([LENS_BuildGoalRow_DDEF(i) for i in 1:3])
                                                    ], style=Dict("width" => "100%", "borderCollapse" => "collapse", "color" => "#000000", "fontSize" => "10px", "tableLayout" => "fixed")), className="table-responsive m-0")
                                        ], xs=12)),
                                ]; panel_class="mb-3", content_class="glass-content p-2"), BASE_GlassPanel(["VISUALIZATION PANEL", html_span(" — Interactive evaluation of the mathematical models and surface geometry.", className="ms-2 text-muted fw-normal", style=Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0"))], [
                                    dbc_row(dbc_col(html_div(id="lens-graph-info", className="mb-2 p-1", style=Dict("backgroundColor" => "#FFFFFF", "border" => "1px solid #DCDCDC", "borderRadius" => "4px")), xs=12)),
                                    dbc_row(dbc_col(html_div(id="lens-results-text", className="mb-3 small px-2 table-responsive"), xs=12)),
                                    dcc_loading(html_div([
                                            html_div(id="lens-graph-title",
                                                className="text-center small text-secondary mb-2 fw-bold"),
                                            dcc_graph(
                                                id="lens-graph-main",
                                                style=Dict("height" => "45vh", "minHeight" => "300px"),
                                                config=Dict("displayModeBar" => true, "displaylogo" => false, "responsive" => true),
                                                figure=BASE_EMPTY_FIGURE,
                                            ),
                                        ]); type="default", color="#21918C"),]; right_node=html_div([
                                        dcc_input(id="lens-graph-input", type="number", min=1, step=1, value=1, className="form-control form-control-sm me-1 text-center bg-transparent border-secondary", style=Dict("width" => "110px", "height" => "28px", "fontSize" => "12px", "color" => "#000000")),
                                        html_span(id="lens-graph-counter", className="text-secondary small me-3"),
                                        dbc_button(html_i(className="fas fa-chevron-left"),
                                            id="lens-btn-prev", color="secondary", outline=true, size="sm", className="me-1 px-2 py-1"),
                                        dbc_button(html_i(className="fas fa-chevron-right"),
                                            id="lens-btn-next", color="secondary", outline=true, size="sm", className="px-2 py-1"),
                                    ], className="d-flex align-items-center"), panel_class="h-100"),

                            # Persistent Stores
                            dcc_store(id="lens-store-graphs", data=[]),
                            dcc_store(id="lens-store-index", data=0),
                            dcc_store(id="lens-signal-process", data=Dict("ts" => 0, "success" => false)),
                        ]; xs=12, lg=9),
                ], className="g-3"),

            # C. MODAL DIALOGS
            # Phase Wizard Modal
            BASE_Modal("lens-modal-wizard", "Phase Transition Wizard",
                dbc_row(dbc_col([
                        html_p("The system will generate a new experimental phase based on the center point you select.",
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
            BASE_Modal("lens-modal-leader", "Select Leader Experiment",
                dbc_row(dbc_col([
                        html_p("Identify the optimal run to serve as the reference center for the next phase:",
                            className="text-muted small"),
                        html_div(BASE_DataTable("lens-table-candidates", [
                                    Dict("name" => "ID", "id" => "ID"),
                                    Dict("name" => "Score", "id" => "Score", "type" => "numeric",
                                        "format" => Dict("specifier" => ".4f")),
                                    Dict("name" => "Data Context", "id" => "Data_Str"),
                                ], []; row_selectable="single", selected_rows=[]), className="table-responsive"),
                    ], xs=12)),
                dbc_row([
                        dbc_col(dbc_button("Back", id="lens-lead-btn-back", color="secondary", outline=true, className="w-100 mb-2 mb-md-0"), xs=12, md=3),
                        dbc_col(dbc_button("Cancel", id="lens-lead-btn-cancel", color="secondary", outline=true, className="w-100 mb-2 mb-md-0"), xs=12, md=3, className="ms-md-auto"),
                        dbc_col(dbc_button("SAVE & GENERATE NEXT PHASE", id="lens-lead-btn-confirm", color="success", disabled=true, className="w-100"), xs=12, md=5),
                    ], className="w-100 g-2"); size="xl", close_button=false),
        ], fluid=true, className="px-4 py-3")
end

# --------------------------------------------------------------------------------------
# SECTION 2: REACTIVE LOGIC (CALLBACKS)
# --------------------------------------------------------------------------------------

"""
    _get_trigger(ctx) -> String
Extract the trigger component ID from callback context.
"""
_get_trigger(ctx) = isempty(ctx.triggered) ? "" : split(ctx.triggered[1].prop_id, ".")[1]

"""
    LENS_RegisterCallbacks_DDEF(app)
Orchestrates all reactive behavior for the LENS module.
"""
function LENS_RegisterCallbacks_DDEF(app)
    C = Sys_Fast.FAST_Constants_DDEF()

    # 1. Pipeline: File Upload / Global Sync -> Phase Detection -> Goal Initialization
    callback!(app,
        Output("lens-dd-phase", "options"),
        Output("lens-upload-status", "children"),
        Output("lens-dd-phase", "value"),
        Output("sync-lens-content", "data"),
        [Output("lens-goal-name-$i", "value") for i in 1:3]...,
        [Output("lens-goal-min-$i", "value") for i in 1:3]...,
        [Output("lens-goal-target-$i", "value") for i in 1:3]...,
        [Output("lens-goal-max-$i", "value") for i in 1:3]...,
        [Output("lens-goal-type-$i", "value") for i in 1:3]...,
        Input("lens-upload-data", "contents"),
        Input("store-master-file-content", "data"),
        State("lens-upload-data", "filename"),
        prevent_initial_call=true
    ) do cont, master_cont, fname
        # Determine temp path BEFORE try for guaranteed cleanup
        path = ""
        try  # Error guard for upload/sync callback
            ctx = callback_context()
            trig = _get_trigger(ctx)

            active_cont = trig == "store-master-file-content" ? master_cont : cont
            src_name = trig == "store-master-file-content" ? "Global Store" : fname

            (isnothing(active_cont) || active_cont == "") &&
                return [], "No Data Source", nothing, Dash.no_update(), ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)...

            Sys_Fast.FAST_Log_DDEF("LENS", "Sync", "Experiment data from: $src_name", "INFO")
            path = Sys_Fast.FAST_GetTransientPath_DDEF(active_cont)
            base64_content = split(active_cont, ",")[end]

            df = Sys_Fast.FAST_ReadExcel_DDEF(path, C.SHEET_DATA)
            isempty(df) && (df = Sys_Fast.FAST_ReadExcel_DDEF(path, "VERI_KAYITLARI"))

            phases = map(unique(df[:, Symbol(C.COL_PHASE)])) do p
                Dict("label" => string(p), "value" => string(p))
            end

            out_cols = filter(c -> startswith(c, C.PRE_RESULT), names(df))
            goals_name = fill("", 3)
            goals_min = fill(0.0, 3)
            goals_target = fill(0.0, 3)
            goals_max = fill(0.0, 3)
            goals_type = fill("Nominal", 3)

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

            short_name = length(src_name) > 15 ? src_name[1:15] * "..." : src_name
            return (
                phases,
                html_span("✅ Sync: $short_name", className="text-success small fw-bold"),
                isempty(phases) ? nothing : phases[end]["value"],
                base64_content,
                goals_name...,
                goals_min...,
                goals_target...,
                goals_max...,
                goals_type...
            )

        catch e  # Surface upload errors to status area
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "UPLOAD_CRASH", bt, "FAIL")
            return [], html_span("❌ Sync Error: $(first(string(e), 120))", className="text-danger small"),
            nothing, Dash.no_update(), ntuple(_ -> "", 3)..., ntuple(_ -> nothing, 9)..., ntuple(_ -> "Nominal", 3)...
        finally
            # Guaranteed temp file cleanup
            !isempty(path) && try
                rm(path; force=true)
            catch
            end
        end
    end

    # 2. Engine: Run GLM Analysis & Optimization
    callback!(app,
        Output("lens-store-graphs", "data"),
        Output("lens-results-text", "children"),
        Output("lens-run-output", "children"),
        Output("lens-btn-next-phase", "disabled"),
        Output("sync-lens-analysis", "data"),
        Input("lens-btn-run", "n_clicks"),
        State("lens-dd-phase", "value"),
        State("lens-dd-model", "value"),
        [State("lens-goal-name-$i", "value") for i in 1:3]...,
        [State("lens-goal-min-$i", "value") for i in 1:3]...,
        [State("lens-goal-target-$i", "value") for i in 1:3]...,
        [State("lens-goal-max-$i", "value") for i in 1:3]...,
        [State("lens-goal-type-$i", "value") for i in 1:3]...,
        State("store-master-file-content", "data"),
        prevent_initial_call=true
    ) do args...
        n, phase, model = args[1:3]
        base64_file = args[19]

        goals = Dict{String,Any}[]
        gnames = collect(args[4:6])
        gmins = collect(args[7:9])
        gtargets = collect(args[10:12])
        gmaxes = collect(args[13:15])
        gtypes = collect(args[16:18])

        for i in 1:3
            if !isnothing(gnames[i]) && strip(string(gnames[i])) != ""
                push!(goals, Dict(
                    "Name" => string(gnames[i]),
                    "Min" => isnothing(gmins[i]) ? 0.0 : Float64(gmins[i]),
                    "Target" => isnothing(gtargets[i]) ? 0.0 : Float64(gtargets[i]),
                    "Max" => isnothing(gmaxes[i]) ? 0.0 : Float64(gmaxes[i]),
                    "Type" => isnothing(gtypes[i]) ? "Nominal" : string(gtypes[i])
                ))
            end
        end
        (n === nothing || n == 0) && return [], "", "", true, Dash.no_update()
        isnothing(base64_file) &&
            return [], "", html_span("Please upload data first.", className="text-warning"), true, Dash.no_update()

        # Race condition lock: reject concurrent analysis requests
        if !Sys_Fast.FAST_AcquireLock_DDEF("VISE_ANALYSIS")
            Sys_Fast.FAST_Log_DDEF("LENS", "LOCK_REJECT",
                "Analysis already running. New request rejected.", "WARN")
            return Dash.no_update(), Dash.no_update(),
            html_span("⚠ An analysis is already in progress. Please wait.",
                className="text-warning fw-bold"), true, Dash.no_update()
        end

        # Create temp file BEFORE try so finally can always clean it
        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)

        try  # Error guard for analysis engine
            Sys_Fast.FAST_Log_DDEF("LENS", "Process", "Starting GLM Analysis (Phase: $phase)...", "WAIT")

            res = Lib_Vise.VISE_Execute_DDEF(path, phase, goals, model)

            if res["Status"] != "OK"
                return [], "", html_span("❌ Analysis Failed: $(res["Message"])", className="text-danger"), true, Dash.no_update()
            end

            # Serialize PlotlyJS objects to JSON for Dash
            graphs = [
                Dict("figure" => JSON.parse(JSON.json(g["Plot"].plot)), "title" => g["Title"])
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

            summary = html_table([
                    html_thead(html_tr([
                        html_th("Output", style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC", "padding" => "8px")),
                        html_th("R² (Adj)", style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC", "padding" => "8px")),
                        html_th("Q² (Pred)", style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC", "padding" => "8px")),
                        html_th("P-Value", style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC", "padding" => "8px"))
                    ])),
                    html_tbody(summary_rows, style=Dict("textAlign" => "center", "borderBottom" => "2px solid #DCDCDC")),
                ], className="table table-sm table-borderless caption-top mb-0 mx-auto", style=Dict("width" => "90%", "marginTop" => "10px"))

            updated_base64 = Sys_Fast.FAST_ReadToStore_DDEF(path)
            return graphs, summary, "", false, updated_base64

        catch e  # Surface analysis errors to UI
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "ANALYSIS_CRASH", bt, "FAIL")
            return [], "",
            html_span("❌ Critical Error: $(first(string(e), 150))", className="text-danger fw-bold"), true, Dash.no_update()
        finally
            # Guaranteed temp file cleanup (prevents disk leak)
            try
                rm(path; force=true)
            catch
            end
            # Always release the lock, even if an error occurred
            Sys_Fast.FAST_ReleaseLock_DDEF("VISE_ANALYSIS")
        end
    end

    # 3. UI: Visualization Slide Navigation
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
        trig = _get_trigger(callback_context())

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

    # 4. UI: Graph Render Sync
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
                    html_span(item, style=Dict("flex" => "1", "textAlign" => "center", "minWidth" => "20%", "whiteSpace" => "nowrap", "padding" => "0 5px", "fontSize" => "12px")) for item in items
                ], style=Dict("display" => "flex", "justifyContent" => "space-around", "width" => "100%", "maxWidth" => "800px", "margin" => "0 auto"))
        end

        if length(info_parts) > 4
            info_html = html_div([
                    format_line(info_parts[1:min(length(info_parts), 4)]),
                    format_line(info_parts[5:end])
                ], style=Dict("display" => "flex", "flexDirection" => "column", "gap" => "4px", "width" => "100%", "justifyContent" => "center", "alignItems" => "center"))
        else
            info_html = format_line(info_parts)
        end

        return g[idx]["figure"], g[idx]["title"], "/ $(length(g))", info_html
    end

    # 5. Pipeline: Wizard Entrance
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
        trig = _get_trigger(callback_context())
        (trig == "lens-wiz-btn-cancel" || trig == "lens-wiz-btn-next") && return false, [], "", ""

        src_phase = isnothing(ph) ? "Phase1" : ph
        digit_match = match(r"\d+", src_phase)
        next_val = isnothing(digit_match) ? 2 : parse(Int, digit_match.match) + 1

        Sys_Fast.FAST_Log_DDEF("LENS", "Wizard",
            "Initiating phase transition: $src_phase -> Phase$next_val", "INFO")

        return true, [Dict("label" => src_phase, "value" => src_phase)], src_phase, "Phase$next_val"
    end

    # 6. Data: Load Candidates
    callback!(app,
        Output("lens-table-candidates", "data"),
        Input("lens-wiz-btn-next", "n_clicks"),
        State("lens-wiz-dd-source", "value"),
        State("store-master-file-content", "data"),
        prevent_initial_call=true
    ) do n, src, base64_file
        isnothing(base64_file) && return []
        path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)
        data = Sys_Flow.FLOW_GetCandidates_DDEF(path, src)
        rm(path; force=true)
        return data
    end

    # 7. UI: Modal Sequential Switching
    callback!(app,
        Output("lens-modal-leader", "is_open"),
        Input("lens-wiz-btn-next", "n_clicks"),
        Input("lens-lead-btn-cancel", "n_clicks"),
        Input("lens-lead-btn-back", "n_clicks"),
        Input("lens-signal-process", "data")
    ) do n_nxt, n_cncl, n_bck, sig
        trig = _get_trigger(callback_context())
        trig == "lens-wiz-btn-next" && return true
        (trig == "lens-lead-btn-cancel" || trig == "lens-lead-btn-back") && return false
        trig == "lens-signal-process" && return !(get(sig, "success", false))
        return Dash.no_update()
    end

    # 8. UI: Conditional Action Enabling
    callback!(app,
        Output("lens-lead-btn-confirm", "disabled"),
        Input("lens-table-candidates", "selected_rows")
    ) do s
        return isnothing(s) || isempty(s)
    end

    # 9. Logic: Result Finalization & Download Bridge
    callback!(app,
        Output("lens-download-result", "data"),
        Output("lens-signal-process", "data"),
        Output("store-session-config", "data"),
        Input("lens-lead-btn-confirm", "n_clicks"),
        Input("lens-btn-download-report", "n_clicks"),
        State("lens-input-project", "value"),
        State("lens-table-candidates", "selected_rows"),
        State("lens-table-candidates", "data"),
        State("lens-wiz-dd-source", "value"),
        State("store-master-file-content", "data"),
        prevent_initial_call=true
    ) do n_sav, n_rep, project, row, data, src, base64_file
        (isnothing(n_sav) || n_sav == 0) && (isnothing(n_rep) || n_rep == 0) && return Dash.no_update(), Dash.no_update(), Dash.no_update()

        # Create path before try for guaranteed cleanup
        path = ""
        try  # Error guard for finalization callback
            trig = _get_trigger(callback_context())

            isnothing(base64_file) && return nothing, Dash.no_update(), Dash.no_update()
            path = Sys_Fast.FAST_GetTransientPath_DDEF(base64_file)
            updated_base64 = base64_file

            # Phase Transition Logic
            next_phase_config = Dash.no_update()
            if trig == "lens-lead-btn-confirm"
                id = (!isnothing(row) && !isempty(row)) ? data[row[1]+1]["ID"] : ""

                res_next = Sys_Flow.FLOW_NextPhase_DDEF(path, isnothing(src) ? "Phase1" : src, id)
                if res_next["Status"] == "OK"
                    res_next["Project"] = isnothing(project) ? "Daisho" : project
                    next_phase_config = JSON3.write(res_next)
                    Sys_Fast.FAST_Log_DDEF("FLOW", "ADAPTIVE_SEARCH",
                        "Next phase configuration ready for: $(res_next["TargetPhase"])", "OK")
                else
                    Sys_Fast.FAST_Log_DDEF("FLOW", "ADAPTIVE_SEARCH",
                        "Failed to compute next phase: $(res_next["Message"])", "WARN")
                end
            end

            ok, bytes = Sys_Fast.FAST_PrepareDownload_DDEF(path)

            fname = Sys_Fast.FAST_GenerateSmartName_DDEF(
                project, isnothing(src) ? "Phase1" : src, "ANALYSIS")

            return (
                Dict("filename" => fname, "content" => base64encode(bytes), "base64" => true),
                Dict("success" => ok, "base64" => updated_base64),
                next_phase_config,
            )

        catch e  # Surface finalization errors
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("LENS", "FINALIZE_CRASH", bt, "FAIL")
            return nothing, Dict("success" => false), Dash.no_update()
        finally
            # Guaranteed temp file cleanup
            !isempty(path) && try
                rm(path; force=true)
            catch
            end
        end
    end

    # 10. High-Res Plot Export
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
                fig_dict = BASE_ConvertTheme_PlotlyWhite!(fig_dict)

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
