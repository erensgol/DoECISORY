module Gui_Deck

# ======================================================================================
# DAISHODOE - GUI DECK (EXPERIMENTAL DESIGN)
# ======================================================================================
# Purpose: Factor configuration, design method selection, and protocol generation.
# Module Tag: DECK
# ======================================================================================

using Dash
using DashBootstrapComponents
using Base64
using DataFrames
using Main.Sys_Fast
using Main.Lib_Core
using Main.Lib_Mole
using Main.Gui_Base
using Printf
using JSON3
using Dates

export DECK_Layout_DDEF, DECK_RegisterCallbacks_DDEF

const _safe_rows = BASE_safe_rows

# --------------------------------------------------------------------------------------
# SECTION 0: CONSTANTS
# --------------------------------------------------------------------------------------

const MAX_ROWS = 24

const ROLE_OPTIONS = [
    Dict("label" => "Variable", "value" => "Variable"),
    Dict("label" => "Fixed", "value" => "Fixed"),
    Dict("label" => "Filler", "value" => "Filler"),
]

const ROLE_COLORS = Dict(
    "Variable" => "#21918C",
    "Fixed" => "#FDE725",
    "Filler" => "#3B528B",
)

function DECK_GetDefaultRow_DDEF(i::Int)
    if i <= 3
        return Dict("Name" => "", "Role" => "Variable", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 0.0, "Unit" => "-")
    else
        return Dict("Name" => "", "Role" => "Fixed", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 0.0, "Unit" => "-")
    end
end

# --------------------------------------------------------------------------------------
# SECTION 1: LAYOUT HELPERS
# --------------------------------------------------------------------------------------


"""
    DECK_BuildRowUI_DDEF(i, row, visible) -> html_tr
Renders a single factor row with fixed IDs. Visibility controlled via style.
"""
function DECK_BuildRowUI_DDEF(i, row, visible)
    row_style = Dict("display" => visible ? "table-row" : "none")

    role_val = string(get(row, "Role", "Variable"))
    name_val = string(get(row, "Name", ""))
    l1_val = get(row, "L1", 0.0)
    l2_val = get(row, "L2", 0.0)
    l3_val = get(row, "L3", 0.0)
    mw_val = get(row, "MW", 0.0)
    unit_val = string(get(row, "Unit", ""))

    del_content = html_span("×", id="deck-del-$i",
        style=Dict("cursor" => "pointer", "color" => "#666666",
            "fontSize" => "1.1rem", "fontWeight" => "700",
            "lineHeight" => "1", "userSelect" => "none"))
    html_tr([
            # Delete button
            html_td(
                del_content,
                style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "3%")),
                className="p-1"
            ),
            # Factor Name
            html_td(
                dcc_input(id="deck-name-$i", type="text",
                    value=name_val, debounce=true, style=merge(BASE_STYLE_INPUT, Dict("fontSize" => "10px")), className="px-1 py-0"),
                style=merge(BASE_STYLE_CELL, Dict("width" => "22%")), className="p-0"
            ),
            # Role dropdown
            html_td(
                dbc_select(id="deck-role-$i",
                    options=ROLE_OPTIONS, value=role_val,
                    className="form-select form-select-sm border-0 py-0", style=Dict("fontSize" => "10px", "boxShadow" => "none")),
                style=merge(BASE_STYLE_CELL, Dict("width" => "12%")),
                className="p-1"
            ),
            # L1
            html_td(
                dcc_input(id="deck-l1-$i", type="number", value=l1_val, debounce=true,
                    style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-0 py-0"),
                style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "13%")), className="p-0"
            ),
            # L2
            html_td(
                dcc_input(id="deck-l2-$i", type="number", value=l2_val, debounce=true,
                    style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-0 py-0"),
                style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "13%")), className="p-0"
            ),
            # L3
            html_td(
                dcc_input(id="deck-l3-$i", type="number", value=l3_val, debounce=true,
                    style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-0 py-0"),
                style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "13%")), className="p-0"
            ),
            # MW
            html_td(
                dcc_input(id="deck-mw-$i", type="number", value=mw_val, debounce=true,
                    style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-0 py-0"),
                style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "11%")), className="p-0"
            ),
            # Unit
            html_td(
                dcc_input(id="deck-unit-$i", type="text", value=unit_val, debounce=true,
                    style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0"),
                style=merge(BASE_STYLE_CELL, Dict("width" => "13%")), className="p-0"
            ),
        ]; style=row_style, id="deck-row-$i")
end

function DECK_BuildOutRow_DDEF(i, def_name, def_unit)
    return html_tr([
        html_td(dcc_input(id="deck-out-name-$i", type="text", value=def_name, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "50%")), className="p-0"),
        html_td(dcc_input(id="deck-out-unit-$i", type="text", value=def_unit, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "50%")), className="p-0")
    ])
end

"""
    DECK_Layout_DDEF()
Constructs the experimental design interface layout.
"""
function DECK_Layout_DDEF()
    try
        Defaults = Sys_Fast.FAST_GetLabDefaults_DDEF()

        # Start with 3 empty rows by default
        initial_rows = [DECK_GetDefaultRow_DDEF(i) for i in 1:MAX_ROWS]
        active_count = 3

        factor_table = html_table([
                html_thead(html_tr([
                    html_th("", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "width" => "3%")), className="p-0"),
                    html_th("NAME", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "width" => "25%")), className="p-0"),
                    html_th("ROLE", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "width" => "12%")), className="p-0"),
                    html_th("LOW", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "12%")), className="p-0"),
                    html_th("CENTER", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "12%")), className="p-0"),
                    html_th("HIGH", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "12%")), className="p-0"),
                    html_th("MW", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "12%")), className="p-0"),
                    html_th("UNIT", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "12%")), className="p-0"),
                ])),
                html_tbody([
                    DECK_BuildRowUI_DDEF(i, initial_rows[i], i <= active_count)
                    for i in 1:MAX_ROWS
                ]),
            ]; style=Dict("width" => "100%", "borderCollapse" => "collapse",
                "color" => "#000000", "fontSize" => "10px", "tableLayout" => "fixed"))

        return dbc_container([
                # State Bus & Hidden DataTable
                dbc_row(dbc_col([
                        dcc_store(id="deck-store-factors",
                            data=Dict("rows" => [DECK_GetDefaultRow_DDEF(1), DECK_GetDefaultRow_DDEF(2), DECK_GetDefaultRow_DDEF(3)], "count" => 3),
                            storage_type="memory"),
                        html_div([
                                dash_datatable(
                                    id="deck-table-in",
                                    columns=[
                                        Dict("name" => "Name", "id" => "Name", "type" => "text"),
                                        Dict("name" => "Role", "id" => "Role", "type" => "text"),
                                        Dict("name" => "L1", "id" => "L1", "type" => "numeric"),
                                        Dict("name" => "L2", "id" => "L2", "type" => "numeric"),
                                        Dict("name" => "L3", "id" => "L3", "type" => "numeric"),
                                        Dict("name" => "MW", "id" => "MW", "type" => "numeric"),
                                        Dict("name" => "Unit", "id" => "Unit", "type" => "text"),
                                    ],
                                    data=[DECK_GetDefaultRow_DDEF(1), DECK_GetDefaultRow_DDEF(2), DECK_GetDefaultRow_DDEF(3)],
                                    editable=false,
                                ),
                            ]; style=Dict("display" => "none"))
                    ], xs=12)),

                # Page Header
                BASE_PageHeader("Experimental Design Protocol", "Define factors and generate the experimental matrix."),

                # Main Workspace
                dbc_row([
                        # --- LEFT COLUMN ---
                        dbc_col([
                                # Factor Configuration Panel
                                dbc_row(dbc_col(BASE_GlassPanel("FACTOR CONFIGURATION",
                                        dcc_loading(html_div(factor_table, className="table-responsive",
                                                style=Dict("overflowX" => "auto", "overflowY" => "visible", "paddingBottom" => "4px")), type="default", color="#21918C");
                                        right_node=html_div([
                                                dbc_button("+ Add Fixed/Filler", id="deck-btn-add-row", n_clicks=0,
                                                    color="secondary", size="sm", className="px-2 py-1 border-0"),
                                                dbc_button("📋 Base", id="deck-btn-template", n_clicks=0,
                                                    color="info", outline=true, size="sm", className="ms-1 px-2 py-1"),
                                                dbc_button("🗑️ Clear", id="deck-btn-clear", n_clicks=0,
                                                    color="danger", outline=true, size="sm", className="ms-1 px-2 py-1"),
                                                dcc_upload(id="deck-upload-memo", children=dbc_button("📂 Load", n_clicks=0,
                                                        color="secondary", outline=true, size="sm", className="px-2 py-1 border-0"),
                                                    multiple=false, className="ms-1", style=Dict("display" => "inline-block")),
                                                dbc_button("💾 Save", id="deck-btn-save-memo", n_clicks=0,
                                                    color="primary", outline=true, size="sm", className="ms-1 px-2 py-1 border-0"),
                                            ], className="ms-auto d-flex align-items-center"),
                                        panel_class="mb-3", content_class="", overflow="visible"), xs=12)),

                                # Response Variables Panel
                                dbc_row(dbc_col(BASE_GlassPanel("RESPONSE VARIABLES",
                                        html_div(html_table([
                                                    html_tr([
                                                        html_th("RESPONSE NAME", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "paddingLeft" => "5px", "width" => "50%")), className="p-0"),
                                                        html_th("UNIT/METRIC", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "paddingLeft" => "5px", "width" => "50%")), className="p-0")
                                                    ]),
                                                    html_tbody([
                                                        DECK_BuildOutRow_DDEF(i,
                                                            i <= length(Defaults["Outputs"]) ? Defaults["Outputs"][i]["Name"] : "",
                                                            i <= length(Defaults["Outputs"]) ? Defaults["Outputs"][i]["Unit"] : ""
                                                        ) for i in 1:3
                                                    ])
                                                ], style=Dict("width" => "100%", "borderCollapse" => "collapse", "color" => "#000000", "fontSize" => "10px", "tableLayout" => "fixed")), className="table-responsive m-0");
                                        content_class="glass-content p-0", panel_class=""), xs=12)),
                            ], xs=12, lg=9, className="mb-3 mb-lg-0"),

                        # --- RIGHT COLUMN ---
                        dbc_col([
                                dbc_row(dbc_col(BASE_GlassPanel("PROTOCOL SETTINGS", [
                                            dbc_row(dbc_col(html_div(id="deck-memo-msg", className="small mb-2 fw-bold"), xs=12)),
                                            dbc_row(dbc_col([
                                                    dbc_label("Project Name", className="small mb-1"),
                                                    dbc_input(id="deck-input-project", type="text", value="",
                                                        placeholder="Enter project name...", className="mb-3 form-control-sm", debounce=false),
                                                ], xs=12)),
                                            dbc_row(dbc_col([
                                                        dbc_label("Volume (mL)", className="small mb-1"),
                                                        dbc_input(id="deck-input-vol", type="number", value=0.0,
                                                            min=0.0, className="form-control-sm", debounce=false),
                                                    ], xs=12), className="mb-3"),
                                            dbc_row(dbc_col([
                                                        dbc_label("Conc. (mM)", className="small mb-1"),
                                                        dbc_input(id="deck-input-conc", type="number", value=0.0,
                                                            min=0.0, className="form-control-sm", debounce=false),
                                                    ], xs=12), className="mb-3"),
                                            dbc_row(dbc_col([
                                                    dbc_label("Design Method", className="small mb-1"),
                                                    dcc_dropdown(id="deck-dd-method",
                                                        options=[
                                                            Dict("label" => "Box-Behnken (3-Level)", "value" => "BoxBehnken"),
                                                            Dict("label" => "Taguchi L9 (3-Level)", "value" => "Taguchi_L9"),
                                                        ],
                                                        value="BoxBehnken", clearable=false, className="mb-3"),
                                                ], xs=12)),
                                            dbc_row(dbc_col(html_hr(className="my-2", style=Dict("borderColor" => "#DCDCDC")), xs=12)),
                                            dbc_row(dbc_col(dbc_button([html_i(className="fas fa-vial me-2"), "Quick Audit"],
                                                    id="deck-btn-audit", n_clicks=0, color="secondary", outline=true, size="sm",
                                                    className="w-100 mb-2"), xs=12)),
                                            dbc_row(dbc_col(dcc_upload(id="deck-upload",
                                                    children=dbc_button(
                                                        [html_i(className="fas fa-file-import me-2"), "Import Protocol"],
                                                        color="secondary", outline=true, size="sm", className="w-100"),
                                                    multiple=false, className="mb-2"), xs=12)),
                                            dbc_row(dbc_col(dbc_button([html_i(className="fas fa-file-export me-2"), "Generate Protocol"],
                                                    id="deck-btn-run", n_clicks=0, color="primary", size="sm",
                                                    className="w-100 fw-bold mb-2"), xs=12)),
                                            dbc_row(dbc_col(dcc_loading(html_div(id="deck-upload-status",
                                                        style=Dict("display" => "none")), type="default", color="#21918C"), xs=12)),
                                            dbc_row(dbc_col(dcc_loading(html_div(id="deck-run-output", className="mt-2 small"),
                                                    type="default", color="#21918C"), xs=12)),
                                            dbc_row(dbc_col(html_div(id="deck-phase-notification", className="mt-1"), xs=12)),
                                        ]; right_node=html_i(className="fas fa-sliders-h text-secondary"), panel_class="h-100"), xs=12)),
                            ], xs=12, lg=3),
                    ], className="g-3"),

                # Safe placement for download components to prevent DOM unmounting on loading rerenders
                dcc_download(id="deck-download-xlsx"),
                dcc_download(id="deck-download-memo"),

                # Audit Modal
                BASE_Modal("deck-modal-audit", "Quick Audit Report",
                    dbc_row(dbc_col(html_div(id="deck-audit-output"), xs=12)),
                    dbc_button("Close", id="deck-btn-audit-close", className="ms-auto")),
            ], fluid=true, className="px-4 py-3")
    catch e
        @error "DECK LAYOUT ERROR" exception = (e, catch_backtrace())
        return html_div("Layout Error: $e", className="text-danger p-4")
    end
end

# --------------------------------------------------------------------------------------
# SECTION 2: CORE PROTOCOL LOGIC
# --------------------------------------------------------------------------------------

function DECK_GenerateProtocol_DDEF(path, in_data, out_data, vol, conc, method)
    C = Sys_Fast.FAST_Constants_DDEF()
    try
        D = Lib_Mole.MOLE_ParseTable_DDEF(_safe_rows(in_data))
        num_vars = length(D["Idx_Var"])
        num_fills = length(D["Idx_Fill"])
        num_vars != 3 && return (false, "Requires exactly 3 Variable ingredients (Found: $num_vars).")
        num_fills > 1 && return (false, "Maximum 1 Filler allowed (Found: $num_fills).")

        design_coded = Lib_Core.CORE_GenDesign_DDEF(method, num_vars)
        N_Runs = size(design_coded, 1)
        configs = [Dict("Levels" => [D["Rows"][i]["L1"], D["Rows"][i]["L2"], D["Rows"][i]["L3"]])
                   for i in D["Idx_Var"]]
        real_matrix = Lib_Core.CORE_MapLevels_DDEF(design_coded, configs)

        phase_num = 1
        current_phase = "Phase1"
        try
            if isfile(path)
                df_old = Sys_Fast.FAST_ReadExcel_DDEF(path, C.SHEET_DATA)
                if !isempty(df_old) && hasproperty(df_old, Symbol(C.COL_PHASE))
                    phases = filter(!ismissing, unique(df_old[!, Symbol(C.COL_PHASE)]))
                    nums = [
                        let m = match(r"\d+", string(p))
                            isnothing(m) ? 1 : parse(Int, m.match)
                        end
                        for p in phases
                    ]
                    phase_num = isempty(nums) ? 1 : maximum(nums) + 1
                    current_phase = "Phase$phase_num"
                end
            end
        catch
        end

        df = DataFrame(
            C.COL_EXP_ID => ["EXP_P$(phase_num)_$(lpad(i, 2, '0'))" for i in 1:N_Runs],
            C.COL_PHASE => fill(current_phase, N_Runs),
            C.COL_RUN_ORDER => 1:N_Runs,
            C.COL_STATUS => fill("Pending", N_Runs),
        )

        for (k, idx) in enumerate(D["Idx_Var"])
            df[!, C.PRE_INPUT*D["Names"][idx]] = real_matrix[:, k]
        end
        for idx in D["Idx_Fix"]
            df[!, C.PRE_FIXED*D["Names"][idx]] = fill(Sys_Fast.FAST_SafeNum_DDEF(D["Rows"][idx]["L2"]), N_Runs)
        end
        for idx in D["Idx_Fill"]
            df[!, C.PRE_FILL*D["Names"][idx]] = fill(0.0, N_Runs)
        end

        sv = Sys_Fast.FAST_SafeNum_DDEF(vol)
        sc = Sys_Fast.FAST_SafeNum_DDEF(conc)
        mass_cols = Dict{String,Vector{Float64}}()

        for i in 1:N_Runs
            RowMap = Dict{String,Float64}()
            for col in names(df), pfx in (C.PRE_INPUT, C.PRE_FIXED, C.PRE_FILL)
                startswith(col, pfx) && (RowMap[replace(col, pfx => "")] = df[i, col])
            end

            if !isempty(D["Idx_Fill"])
                used = sum(get(RowMap, D["Names"][r], 0.0) for r in D["Idx_Chem"] if r ∉ D["Idx_Fill"])
                f_val = max(0.0, 100.0 - used)
                for f in D["Idx_Fill"]
                    RowMap[D["Names"][f]] = f_val
                    df[i, C.PRE_FILL*D["Names"][f]] = f_val
                end
            end

            chems = D["Idx_Chem"]
            m_df = Lib_Mole.MOLE_CalcMass_DDEF(
                D["Names"][chems], D["MWs"][chems],
                [get(RowMap, n, 0.0) for n in D["Names"][chems]], sv, sc)
            for r in eachrow(m_df)
                k = "MASS_" * r.Component * "_mg"
                haskey(mass_cols, k) || (mass_cols[k] = zeros(N_Runs))
                mass_cols[k][i] = r.TARGET_MASS_mg
            end
        end

        for idx in D["Idx_Chem"]
            k = "MASS_" * D["Names"][idx] * "_mg"
            haskey(mass_cols, k) && (df[!, k] = mass_cols[k])
        end

        output_data = _safe_rows(out_data)
        for r in output_data
            n = string(get(r, "Name", "Unknown"))
            df[!, "RESULT_$n"] = fill(missing, N_Runs)
            df[!, "PRED_$n"] = fill(missing, N_Runs)
        end
        df[!, C.COL_SCORE] = fill(missing, N_Runs)
        df[!, C.COL_NOTES] = fill("", N_Runs)

        ConfigDict = Dict(
            "Ingredients" => D["Rows"],
            "Global" => Dict("Volume" => sv, "Conc" => sc),
            "Outputs" => output_data,
        )
        success = Sys_Fast.FAST_InitMaster_DDEF(path,
            [string(get(r, "Name", "")) for r in _safe_rows(in_data)],
            [string(get(r, "Name", "")) for r in output_data],
            df, ConfigDict)

        return (success, success ? "Success" : "Master Initialization Failed")
    catch e
        @error "DECK GENERATION FAILED" exception = (e, catch_backtrace())
        return (false, string(e))
    end
end

# --------------------------------------------------------------------------------------
# SECTION 3: CALLBACK BUS
# --------------------------------------------------------------------------------------

"""
    DECK_RegisterCallbacks_DDEF(app)
Uses fixed-ID row system (no pattern-matching). Guaranteed compatible with Dash.jl.
"""
function DECK_RegisterCallbacks_DDEF(app)

    # ── 1. UI Hydration (Refreshes text boxes from State Bus) ───────────────────────
    callback!(app,
        [Output("deck-row-$i", "style") for i in 1:MAX_ROWS]...,
        [Output("deck-name-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-role-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-l1-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-l2-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-l3-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-mw-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-unit-$i", "value") for i in 1:MAX_ROWS]...,
        Input("deck-store-factors", "data")
    ) do stored
        isnothing(stored) && return ntuple(_ -> Dash.no_update(), 8 * MAX_ROWS)
        rows = get(stored, "rows", [])
        count = get(stored, "count", 0)

        out_styles = [Dict("display" => i <= count ? "table-row" : "none") for i in 1:MAX_ROWS]
        out_names = [i <= length(rows) ? string(get(rows[i], "Name", "")) : "" for i in 1:MAX_ROWS]
        out_roles = [i <= length(rows) ? string(get(rows[i], "Role", "Variable")) : "Variable" for i in 1:MAX_ROWS]
        out_l1s = [i <= length(rows) ? get(rows[i], "L1", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_l2s = [i <= length(rows) ? get(rows[i], "L2", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_l3s = [i <= length(rows) ? get(rows[i], "L3", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_mws = [i <= length(rows) ? get(rows[i], "MW", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_units = [i <= length(rows) ? string(get(rows[i], "Unit", "")) : "" for i in 1:MAX_ROWS]

        return (out_styles..., out_names..., out_roles..., out_l1s..., out_l2s..., out_l3s..., out_mws..., out_units...)
    end

    # ── 2. Main Store Orchestrator ─────────────────────────────────────────────────────
    callback!(app,
        Output("deck-store-factors", "data"),
        Output("deck-table-in", "data"),
        Output("deck-phase-notification", "children"),
        Output("deck-input-vol", "value"),
        Output("deck-input-conc", "value"),
        Output("deck-input-project", "value"),
        Output("deck-memo-msg", "children"),
        Output("deck-download-memo", "data"),
        # Triggers
        Input("deck-btn-add-row", "n_clicks"),
        Input("deck-btn-clear", "n_clicks"),
        Input("deck-upload-memo", "contents"),
        Input("deck-btn-template", "n_clicks"),
        Input("deck-btn-save-memo", "n_clicks"),
        Input("store-session-config", "data"),
        Input("deck-upload", "contents"),
        # Delete buttons as Inputs
        [Input("deck-del-$i", "n_clicks") for i in 1:MAX_ROWS]...,
        # States
        State("deck-store-factors", "data"),
        State("deck-upload", "filename"),
        [State("deck-name-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-role-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l1-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l2-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l3-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-mw-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-unit-$i", "value") for i in 1:MAX_ROWS]...,
        State("deck-input-vol", "value"),
        State("deck-input-conc", "value"),
        prevent_initial_call=true
    ) do args...
        try  # Global error guard for main orchestrator callback
            # Unpack arguments
            n_add, n_clear, up_memo, n_temp, n_save, session, up_cont = args[1:7]
            ndels = args[8:7+MAX_ROWS]
            store_data = args[8+MAX_ROWS]
            fname = args[9+MAX_ROWS]

            offset = 10 + MAX_ROWS
            all_names = collect(args[offset:offset+MAX_ROWS-1])
            all_roles = collect(args[offset+MAX_ROWS:offset+2MAX_ROWS-1])
            all_l1s = collect(args[offset+2MAX_ROWS:offset+3MAX_ROWS-1])
            all_l2s = collect(args[offset+3MAX_ROWS:offset+4MAX_ROWS-1])
            all_l3s = collect(args[offset+4MAX_ROWS:offset+5MAX_ROWS-1])
            all_mws = collect(args[offset+5MAX_ROWS:offset+6MAX_ROWS-1])
            all_units = collect(args[offset+6MAX_ROWS:offset+7MAX_ROWS-1])

            ctx = callback_context()
            isempty(ctx.triggered) && return ntuple(_ -> Dash.no_update(), 8)
            trig = split(ctx.triggered[1].prop_id, ".")[1]

            NO = Dash.no_update()
            count = isnothing(store_data) ? 1 : get(store_data, "count", 1)

            max_idx = min(count, length(all_names), length(all_roles), length(all_l1s), length(all_l2s), length(all_l3s), length(all_mws), length(all_units))
            snap_rows() = [Dict(
                "Name" => !isnothing(all_names[i]) ? string(all_names[i]) : "",
                "Role" => !isnothing(all_roles[i]) ? string(all_roles[i]) : "Variable",
                "L1" => !isnothing(all_l1s[i]) ? Float64(all_l1s[i]) : 0.0,
                "L2" => !isnothing(all_l2s[i]) ? Float64(all_l2s[i]) : 0.0,
                "L3" => !isnothing(all_l3s[i]) ? Float64(all_l3s[i]) : 0.0,
                "MW" => !isnothing(all_mws[i]) ? Float64(all_mws[i]) : 0.0,
                "Unit" => !isnothing(all_units[i]) ? string(all_units[i]) : "",
            ) for i in 1:max_idx]

            # ── A. Delete Row ─────────────────────────────────────────────────────────────
            del_ids = ["deck-del-$i" for i in 1:MAX_ROWS]
            if trig in del_ids
                rows = snap_rows()
                ri = findfirst(==(trig), del_ids)
                if ri !== nothing && ri <= length(rows)
                    if get(rows[ri], "Role", "Variable") == "Variable"
                        num_vars = sum(get(r, "Role", "Variable") == "Variable" ? 1 : 0 for r in rows)
                        if num_vars <= 3
                            lbl = html_div([html_i(className="fas fa-exclamation-triangle me-2"), "Minimum 3 variables required!"],
                                className="badge bg-danger text-white p-2 w-100", style=Dict("fontSize" => "0.85rem"))
                            return Dict("rows" => rows, "count" => length(rows)), rows, NO, NO, NO, NO, lbl, NO
                        end
                    end
                    deleteat!(rows, ri)
                end
                nc = max(0, length(rows))
                return Dict("rows" => rows, "count" => nc), rows, NO, NO, NO, NO, NO, NO
            end

            # ── B. Add Row ──────────────────────────────────────────────────────────────
            if trig == "deck-btn-add-row"
                rows = snap_rows()

                # Check for filler constraint: Only 1 filler allowed across canvas
                fillers = sum(get(r, "Role", "") == "Filler" ? 1 : 0 for r in rows)

                # Assign default role for new row: If filler exists, force "Fixed"
                new_role = fillers >= 1 ? "Fixed" : "Filler"

                new_count = min(count + 1, MAX_ROWS)
                if new_count > count
                    new_row = DECK_GetDefaultRow_DDEF(new_count)
                    new_row["Role"] = new_role
                    push!(rows, new_row)
                end

                return Dict("rows" => rows, "count" => new_count), rows, NO, NO, NO, NO, NO, NO

                # ── C0. Clear Memo ───────────────────────────────────────────────────────────
            elseif trig == "deck-btn-clear"
                rows = [DECK_GetDefaultRow_DDEF(1), DECK_GetDefaultRow_DDEF(2), DECK_GetDefaultRow_DDEF(3)]
                lbl = html_div([html_i(className="fas fa-trash-alt me-2"), "Canvas Cleared"],
                    className="badge bg-danger text-white p-2 w-100", style=Dict("fontSize" => "0.85rem"))
                return Dict("rows" => rows, "count" => 3), rows, NO, NO, NO, NO, lbl, NO

                # ── C1. Load User Memo ───────────────────────────────────────────────────────
            elseif trig == "deck-upload-memo" && !isnothing(up_memo) && up_memo != ""
                try
                    base64_data = split(up_memo, ",")[end]
                    json_str = String(base64decode(base64_data))
                    memo = JSON3.read(json_str)
                    loaded_rows = map(get(memo, "Inputs", [])) do m
                        Dict("Name" => get(m, "Name", ""), "Role" => get(m, "Role", "Variable"),
                            "L1" => get(m, "L1", 0.0), "L2" => get(m, "L2", 0.0),
                            "L3" => get(m, "L3", 0.0), "MW" => get(m, "MW", 0.0),
                            "Unit" => get(m, "Unit", "-"))
                    end
                    lbl = html_div([html_i(className="fas fa-folder-open me-2"), "Memory Loaded"],
                        className="badge bg-info text-white p-2 w-100", style=Dict("fontSize" => "0.85rem"))
                    nc = min(length(loaded_rows), MAX_ROWS)

                    g = get(memo, "Global", Dict())
                    vol_v = get(g, "Volume", NO)
                    conc_v = get(g, "Conc", NO)

                    return Dict("rows" => loaded_rows[1:nc], "count" => nc), loaded_rows[1:nc], NO, vol_v, conc_v, NO, lbl, NO
                catch e
                    return NO, NO, NO, NO, NO, NO, html_div("❌ Load Error: $e", className="badge bg-danger text-white w-100 p-2"), NO
                end

                # ── C2. Load Template ────────────────────────────────────────────────────────
            elseif trig == "deck-btn-template"
                loaded_rows = [
                    Dict("Name" => "DPPC", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 734.0, "Unit" => "MR"),
                    Dict("Name" => "Chol", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 386.6, "Unit" => "%M"),
                    Dict("Name" => "PEG", "Role" => "Variable", "L1" => 1.0, "L2" => 3.0, "L3" => 5.0, "MW" => 2800.0, "Unit" => "%M"),
                    Dict("Name" => "DOTA", "Role" => "Fixed", "L1" => 5.0, "L2" => 5.0, "L3" => 5.0, "MW" => 500.0, "Unit" => "%M"),
                    Dict("Name" => "Temperature", "Role" => "Variable", "L1" => 25.0, "L2" => 45.0, "L3" => 65.0, "MW" => 0.0, "Unit" => "°C"),
                ]
                lbl = html_div([html_i(className="fas fa-book-medical me-2"), "Template Applied"],
                    className="badge bg-primary text-white p-2 w-100", style=Dict("fontSize" => "0.85rem", "boxShadow" => "0 2px 5px rgba(33,145,140,0.3)"))
                nc = min(length(loaded_rows), MAX_ROWS)
                return Dict("rows" => loaded_rows[1:nc], "count" => nc), loaded_rows[1:nc], NO, 5.0, 20.0, NO, lbl, NO

                # ── D. Save Memo (Download) ──────────────────────────────────────────────────
            elseif trig == "deck-btn-save-memo"
                try
                    vol_v = isnothing(args[end-1]) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(args[end-1])
                    conc_v = isnothing(args[end]) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(args[end])
                    json_str = JSON3.write(Dict("Inputs" => snap_rows(), "Global" => Dict("Volume" => vol_v, "Conc" => conc_v)))
                    b64 = base64encode(json_str)
                    dl_dict = Dict("filename" => "Daisho_Workspace.json", "content" => b64, "base64" => true)
                    lbl = html_div([html_i(className="fas fa-check-circle me-2"), "Workspace Exported"],
                        className="badge bg-success text-white p-2 w-100", style=Dict("fontSize" => "0.85rem", "boxShadow" => "0 2px 5px rgba(94,201,98,0.3)"))
                    return NO, NO, NO, NO, NO, NO, lbl, dl_dict
                catch e
                    return NO, NO, NO, NO, NO, NO, html_div("❌ Save Error", className="badge bg-danger text-white p-2 w-100"), NO
                end

                # ── E. Phase Transition ──────────────────────────────────────────────────────
            elseif trig == "store-session-config" && !isnothing(session) && session != ""
                try
                    res = JSON3.read(session)
                    if get(res, "Status", "") == "OK"
                        items = get(res, "NewConfig", [])
                        mapped = map(items) do itm
                            levs = get(itm, "Levels", [NaN, NaN, NaN])
                            Dict("Name" => get(itm, "Name", ""), "Role" => get(itm, "Role", "Variable"),
                                "L1" => levs[1], "L2" => levs[2], "L3" => levs[3],
                                "MW" => get(itm, "MW", 0.0), "Unit" => get(itm, "Unit", ""))
                        end
                        nc = min(length(mapped), MAX_ROWS)
                        g = get(res, "Global", Dict())
                        # Apply to project name logic safely
                        saved_project = get(res, "Project", NO)
                        if saved_project isa String && isempty(strip(saved_project))
                            saved_project = "Daisho"
                        end

                        msg = html_div([
                                html_i(className="fas fa-magic me-2 text-success"),
                                html_span("Adaptive Recipe Loaded", className="text-success fw-bold"),
                            ], className="alert alert-success py-2 mt-2")
                        return Dict("rows" => mapped[1:nc], "count" => nc), mapped[1:nc], msg,
                        get(g, "Volume", NO), get(g, "Conc", NO), saved_project, NO, NO
                    end
                catch e
                    Sys_Fast.FAST_Log_DDEF("DECK", "HANDSHAKE_ERROR", "$e", "FAIL")
                end

                # ── F. Import Protocol ───────────────────────────────────────────────────────
            elseif trig == "deck-upload" && !isnothing(up_cont)
                try
                    tmp = Sys_Fast.FAST_GetTransientPath_DDEF(up_cont)
                    cfg = Sys_Fast.FAST_ReadConfig_DDEF(tmp)
                    rm(tmp; force=true)
                    if !isempty(cfg) && haskey(cfg, "Ingredients")
                        mapped = map(cfg["Ingredients"]) do itm
                            Dict("Name" => get(itm, "Name", ""), "Role" => get(itm, "Role", "Variable"),
                                "L1" => get(itm, "L1", 0.0), "L2" => get(itm, "L2", 0.0),
                                "L3" => get(itm, "L3", 0.0), "MW" => get(itm, "MW", 0.0),
                                "Unit" => get(itm, "Unit", "-"))
                        end
                        nc = min(length(mapped), MAX_ROWS)
                        g = get(cfg, "Global", Dict())
                        msg = html_div([
                                html_i(className="fas fa-file-import me-2 text-info"),
                                html_span("Imported: $fname", className="text-info fw-bold"),
                            ], className="alert alert-info py-2 mt-2")
                        return Dict("rows" => mapped[1:nc], "count" => nc), mapped[1:nc], msg,
                        get(g, "Volume", NO), get(g, "Conc", NO), NO, NO, NO
                    end
                catch e
                    @error "Import failed" exception = (e, catch_backtrace())
                end
            end

            return ntuple(_ -> Dash.no_update(), 8)

        catch e  # Catch-all: surface error to UI instead of silent death
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("DECK", "CALLBACK_CRASH", bt, "FAIL")
            NO = Dash.no_update()
            return NO, NO, NO, NO, NO, NO,
            html_span("⚠ System Error: $(first(string(e), 120))", className="text-danger fw-bold"), NO
        end
    end

    # ── 3. Audit Modal ─────────────────────────────────────────────────────────────────
    callback!(app,
        Output("deck-audit-output", "children"),
        Output("deck-modal-audit", "is_open"),
        Input("deck-btn-audit", "n_clicks"),
        Input("deck-btn-audit-close", "n_clicks"),
        State("deck-modal-audit", "is_open"),
        State("deck-store-factors", "data"),
        State("deck-input-vol", "value"),
        State("deck-input-conc", "value"),
        [State("deck-name-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-role-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l1-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l2-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l3-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-mw-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-unit-$i", "value") for i in 1:MAX_ROWS]...,
        prevent_initial_call=true
    ) do args...
        try  # Error guard for audit callback
            n_op, n_cl, is_op, store_data, vol, conc = args[1:6]
            offset = 7
            all_names = collect(args[offset:offset+MAX_ROWS-1])
            all_roles = collect(args[offset+MAX_ROWS:offset+2MAX_ROWS-1])
            all_l1s = collect(args[offset+2MAX_ROWS:offset+3MAX_ROWS-1])
            all_l2s = collect(args[offset+3MAX_ROWS:offset+4MAX_ROWS-1])
            all_l3s = collect(args[offset+4MAX_ROWS:offset+5MAX_ROWS-1])
            all_mws = collect(args[offset+5MAX_ROWS:offset+6MAX_ROWS-1])
            all_units = collect(args[offset+6MAX_ROWS:offset+7MAX_ROWS-1])

            ctx = callback_context()
            trig = isempty(ctx.triggered) ? "" : split(ctx.triggered[1].prop_id, ".")[1]
            trig == "deck-btn-audit-close" && return Dash.no_update(), false
            trig != "deck-btn-audit" && return Dash.no_update(), is_op

            count = isnothing(store_data) ? 1 : get(store_data, "count", 1)
            rows = [Dict(
                "Name" => isnothing(all_names[i]) ? "" : string(all_names[i]),
                "Role" => isnothing(all_roles[i]) ? "Variable" : string(all_roles[i]),
                "L1" => isnothing(all_l1s[i]) ? 0.0 : Float64(all_l1s[i]),
                "L2" => isnothing(all_l2s[i]) ? 0.0 : Float64(all_l2s[i]),
                "L3" => isnothing(all_l3s[i]) ? 0.0 : Float64(all_l3s[i]),
                "MW" => isnothing(all_mws[i]) ? 0.0 : Float64(all_mws[i]),
                "Unit" => isnothing(all_units[i]) ? "" : string(all_units[i]),
            ) for i in 1:count]

            res_status, res_text, _, mass, msg = Lib_Mole.MOLE_QuickAudit_DDEF(
                rows, Sys_Fast.FAST_SafeNum_DDEF(vol), Sys_Fast.FAST_SafeNum_DDEF(conc))

            icon = res_status ? "fa-check-circle" : "fa-exclamation-triangle"
            label = res_status ? "Audit Passed" : "Audit Failed"
            cls = res_status ? "text-success" : "text-danger"

            header = html_div([
                    html_i(className="fas $icon me-2"),
                    html_span(label, className="fw-bold"),
                ], className="$cls mb-3 h5")

            return html_div([
                header,
                html_div([
                        html_span("Base Mass: ", className="text-secondary"),
                        html_span(@sprintf("%.4f mg", mass), className="fw-bold"),
                    ], className="mb-3"),
                html_div(html_pre(res_text, style=Dict(
                        "backgroundColor" => "#FFFFFF", "color" => "#000000", "padding" => "15px",
                        "borderRadius" => "6px", "fontSize" => "0.8rem",
                        "fontFamily" => "SFMono-Regular, Consolas, monospace",
                        "border" => "1px solid #DCDCDC", "maxHeight" => "400px", "overflowY" => "auto",
                    )), className="mb-3"),
                html_div(msg, className="small text-info fw-bold border-top pt-2"),
            ]), true

        catch e  # Surface audit errors to modal
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("DECK", "AUDIT_CRASH", bt, "FAIL")
            return html_div([
                html_i(className="fas fa-exclamation-triangle me-2 text-danger"),
                html_span("Audit Error: $(first(string(e), 150))", className="text-danger"),
            ]), true
        end
    end

    # ── 4. Protocol Generation ─────────────────────────────────────────────────────────
    callback!(app,
        Output("deck-download-xlsx", "data"),
        Output("deck-run-output", "children"),
        Output("sync-deck-content", "data"),
        Input("deck-btn-run", "n_clicks"),
        State("deck-input-project", "value"),
        [State("deck-out-name-$i", "value") for i in 1:3]...,
        [State("deck-out-unit-$i", "value") for i in 1:3]...,
        State("deck-input-vol", "value"),
        State("deck-input-conc", "value"),
        State("deck-dd-method", "value"),
        State("store-session-config", "data"),
        State("deck-store-factors", "data"),
        [State("deck-name-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-role-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l1-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l2-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l3-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-mw-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-unit-$i", "value") for i in 1:MAX_ROWS]...,
        prevent_initial_call=true
    ) do args...
        try  # Error guard for protocol generation callback
            n, project = args[1:2]
            out_names = collect(args[3:5])
            out_units = collect(args[6:8])
            vol, conc, method, session_data, store_data = args[9:13]
            (n === nothing || n == 0) && return Dash.no_update(), "", Dash.no_update()

            offset = 14
            all_names = collect(args[offset:offset+MAX_ROWS-1])
            all_roles = collect(args[offset+MAX_ROWS:offset+2MAX_ROWS-1])

            out_d = Dict{String,Any}[]
            for i in 1:3
                !isnothing(out_names[i]) && strip(string(out_names[i])) != "" && push!(out_d, Dict("Name" => string(out_names[i]), "Unit" => isnothing(out_units[i]) ? "" : string(out_units[i])))
            end
            all_l1s = collect(args[offset+2MAX_ROWS:offset+3MAX_ROWS-1])
            all_l2s = collect(args[offset+3MAX_ROWS:offset+4MAX_ROWS-1])
            all_l3s = collect(args[offset+4MAX_ROWS:offset+5MAX_ROWS-1])
            all_mws = collect(args[offset+5MAX_ROWS:offset+6MAX_ROWS-1])
            all_units = collect(args[offset+6MAX_ROWS:offset+7MAX_ROWS-1])

            count = isnothing(store_data) ? 1 : get(store_data, "count", 1)
            in_d = [Dict(
                "Name" => isnothing(all_names[i]) ? "" : string(all_names[i]),
                "Role" => isnothing(all_roles[i]) ? "Variable" : string(all_roles[i]),
                "L1" => isnothing(all_l1s[i]) ? 0.0 : Float64(all_l1s[i]),
                "L2" => isnothing(all_l2s[i]) ? 0.0 : Float64(all_l2s[i]),
                "L3" => isnothing(all_l3s[i]) ? 0.0 : Float64(all_l3s[i]),
                "MW" => isnothing(all_mws[i]) ? 0.0 : Float64(all_mws[i]),
                "Unit" => isnothing(all_units[i]) ? "" : string(all_units[i]),
            ) for i in 1:count]

            path = Sys_Fast.FAST_GetTransientPath_DDEF()
            ok, msg = DECK_GenerateProtocol_DDEF(path, in_d, out_d, vol, conc, method)
            !ok && return Dash.no_update(), html_div(msg, className="text-danger"), Dash.no_update()

            store_content = Sys_Fast.FAST_ReadToStore_DDEF(path)
            raw_base64 = base64encode(read(path))

            current_phase = "P1"
            if !isnothing(session_data) && session_data != ""
                try
                    current_phase = get(JSON3.read(session_data), "TargetPhase", "P1")
                catch
                end
            end
            fname = Sys_Fast.FAST_GenerateSmartName_DDEF(project, current_phase, "DESIGN")
            rm(path; force=true)

            return (
                Dict("filename" => fname, "content" => raw_base64, "base64" => true),
                html_span([html_i(className="fas fa-check-circle me-1"),
                        "Protocol generated."], className="text-success"),
                store_content,
            )

        catch e  # Surface protocol generation errors
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("DECK", "PROTOCOL_CRASH", bt, "FAIL")
            return Dash.no_update(),
            html_span("⚠ Generation Error: $(first(string(e), 120))", className="text-danger fw-bold"),
            Dash.no_update()
        end
    end
end

end # module
