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

const _safe_rows = BASE_SafeRows_DDEF

# --------------------------------------------------------------------------------------
# SECTION 0: CONSTANTS
# --------------------------------------------------------------------------------------

const MAX_ROWS = 24

const ROLE_OPTIONS = [
    Dict("label" => "Variable", "value" => "Variable"),
    Dict("label" => "Fixed", "value" => "Fixed"),
]

const ROLE_COLORS = Dict(
    "Variable" => "#440154",
    "Fixed" => "#FDE725",
)

"""
    DECK_GetDefaultRow_DDEF(i) -> Dict
Generates a default factor row configuration based on its index.
"""
function DECK_GetDefaultRow_DDEF(i::Int)
    role_val = i <= 3 ? "Variable" : "Fixed"
    return Dict(
        "Name" => "", "Role" => role_val,
        "L1" => 0.0, "L2" => 0.0, "L3" => 0.0,
        "Min" => 0.0, "Max" => 0.0, "MW" => 0.0, "Unit" => "-",
        "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours",
        "IsFiller" => false
    )
end

# --------------------------------------------------------------------------------------
# SECTION 1: LAYOUT HELPERS
# --------------------------------------------------------------------------------------

"""
    DECK_BuildIdRowUI_DDEF(i, row, visible, [show_del]) -> html_tr
Table-based ID row including delete button (optional), name input, and property icons.
"""
function DECK_BuildIdRowUI_DDEF(i, row, visible, show_del=false)
    row_style = Dict("display" => visible ? "table-row" : "none")
    name_val = string(get(row, "Name", ""))
    is_filler = get(row, "IsFiller", false)

    name_input_style = Dict{String,Any}()
    is_filler && (name_input_style["borderLeft"] = "3px solid #F39C12")

    del_content = show_del ? html_button("×", id="deck-del-$i", n_clicks=0,
        style=Dict("cursor" => "pointer", "color" => "#666666", "fontSize" => "1.1rem", "fontWeight" => "700",
            "lineHeight" => "1", "background" => "none", "border" => "none", "padding" => "0")) : nothing

    mw_v = Float64(get(row, "MW", 0.0))
    hl_v = Float64(get(row, "HalfLife", 0.0))
    dot1_color = mw_v > 0.0 ? "#5EC962" : "#2C2C2C"
    dot2_color = hl_v > 0.0 ? "#5EC962" : "#2C2C2C"
    dots = html_span([
            html_span("●", id="deck-dot1-$i", style=Dict("color" => dot1_color, "fontSize" => "0.45rem", "marginRight" => "1px")),
            html_span("●", id="deck-dot2-$i", style=Dict("color" => dot2_color, "fontSize" => "0.45rem", "marginRight" => "2px")),
        ], style=Dict("display" => "inline-flex", "alignItems" => "center"))

    prop_btn = html_button(html_i(className="fas fa-cog", style=Dict("fontSize" => "0.80rem", "color" => is_filler ? "#F39C12" : "#A6A6A6")),
        id="btn-prop-$i", n_clicks=0,
        style=Dict("cursor" => "pointer", "background" => "none", "border" => "none", "padding" => "2px"))

    row_children = Any[]
    if show_del
        push!(row_children, html_td(del_content, style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "30px")), className="p-0"))
    end

    # Name cell
    push!(row_children, html_td(
        dcc_input(id="deck-name-$i", type="text", value=name_val, debounce=true, style=name_input_style),
        className="deck-name-cell p-0", style=BASE_STYLE_CELL)
    )

    push!(row_children, html_td(
        html_span([dots, prop_btn], style=Dict("display" => "inline-flex", "alignItems" => "center", "justifyContent" => "center")),
        style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "55px")), className="p-0")
    )

    return html_tr(row_children; style=row_style, id="deck-row-id-$i")
end

"""
    DECK_BuildLevelRowUI_DDEF(i, row, visible) -> html_tr
Renders the 3-column levels portion of the row (Lower, Centre, Upper).
"""
function DECK_BuildLevelRowUI_DDEF(i, row, visible)
    row_style = Dict("display" => visible ? "table-row" : "none")
    l1_val = get(row, "L1", 0.0)
    l2_val = get(row, "L2", 0.0)
    l3_val = get(row, "L3", 0.0)

    # Determine visibility of L1, L2, L3 based on row index
    show_l1 = (i <= 3) # Visible only for Variables
    show_l2 = (i <= 3 || i >= 5) # Visible for Variables and Constants
    show_l3 = (i <= 3) # Visible only for Variables

    html_tr([
            html_td(dcc_input(id="deck-l1-$i", type="number", value=l1_val, debounce=true, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px", "display" => show_l1 ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "33%")), className="p-0"),
            html_td(dcc_input(id="deck-l2-$i", type="number", value=l2_val, debounce=true, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px", "display" => show_l2 ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "33%")), className="p-0"),
            html_td(dcc_input(id="deck-l3-$i", type="number", value=l3_val, debounce=true, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px", "display" => show_l3 ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "34%")), className="p-0")
        ]; style=row_style, id="deck-row-level-$i")
end

"""
    DECK_BuildLimitsRowUI_DDEF(i, row, visible) -> html_tr
Renders the 3-column limits portion of the row (Min Limit, Unit, Max Limit).
"""
function DECK_BuildLimitsRowUI_DDEF(i, row, visible)
    row_style = Dict("display" => visible ? "table-row" : "none")
    min_val = get(row, "Min", 0.0)
    max_val = get(row, "Max", 0.0)
    unit_val = string(get(row, "Unit", "-"))

    show_minmax = (i <= 3)

    html_tr([
            html_td(dcc_input(id="deck-min-$i", type="number", value=min_val, debounce=true, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px", "display" => show_minmax ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "33%")), className="p-0"),
            html_td(dcc_input(id="deck-unit-$i", type="text", value=unit_val, debounce=true, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "34%")), className="p-0"),
            html_td(dcc_input(id="deck-max-$i", type="number", value=max_val, debounce=true, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px", "display" => show_minmax ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "33%")), className="p-0")
        ]; style=row_style, id="deck-row-limits-$i")
end

"""
    DECK_BuildOutRow_DDEF(i, def_name, def_unit) -> html_tr
Renders a row for the response metrics table.
"""
function DECK_BuildOutRow_DDEF(i, def_name, def_unit)
    # Indicator dot for decay correction status
    out_dot = html_span("●", id="deck-out-dot-$i",
        style=Dict("color" => "#2C2C2C", "fontSize" => "0.45rem", "marginRight" => "2px", "verticalAlign" => "middle"))

    prop_btn = html_button(html_i(className="fas fa-cog", style=Dict("fontSize" => "0.80rem", "color" => "#A6A6A6")),
        id="btn-out-prop-$i", n_clicks=0,
        style=Dict("cursor" => "pointer", "background" => "none", "border" => "none", "padding" => "2px"))

    return html_tr([
        html_td(dcc_input(id="deck-out-name-$i", type="text", value=def_name, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "40%")), className="p-0"),
        html_td(dcc_input(id="deck-out-unit-$i", type="text", value=def_unit, style=merge(BASE_STYLE_INPUT_CENTER, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_STYLE_CELL, Dict("width" => "40%")), className="p-0"),
        html_td(html_span([out_dot, prop_btn], style=Dict("display" => "inline-flex", "alignItems" => "center", "justifyContent" => "center")), style=merge(BASE_STYLE_CELL, Dict("textAlign" => "center", "width" => "20%")), className="p-0")
    ])
end

# --------------------------------------------------------------------------------------
# SECTION 1.1: LOCAL TABLE BUILDERS
# --------------------------------------------------------------------------------------

"""
    DECK_BuildIdTable_DDEF(rows_range, initial_rows, active_count, show_del) -> html_table
Constructs the identification portion of the factor table.
"""
function DECK_BuildIdTable_DDEF(rows_range, initial_rows, active_count, show_del)
    th_children = Any[]
    if show_del
        push!(th_children, html_th("", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "width" => "30px")), className="p-0"))
    end
    push!(th_children, html_th("NAME", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center")), className="p-0"))
    push!(th_children, html_th("", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "width" => "55px")), className="p-0"))

    html_table([
            html_thead(html_tr(th_children)),
            html_tbody([
                DECK_BuildIdRowUI_DDEF(i, initial_rows[i], i <= active_count, show_del)
                for i in rows_range
            ]),
        ]; style=Dict("width" => "100%", "borderCollapse" => "collapse", "color" => "#000000", "fontSize" => "10px", "tableLayout" => "fixed", "marginBottom" => "0"))
end

"""
    DECK_BuildLevelTable_DDEF(rows_range, initial_rows, active_count) -> html_table
Constructs the levels portion of the factor table.
"""
function DECK_BuildLevelTable_DDEF(rows_range, initial_rows, active_count)
    html_table([
            html_thead(html_tr([
                html_th("LOWER", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "33%")), className="p-0"),
                html_th("CENTRE", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "33%")), className="p-0"),
                html_th("UPPER", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "34%")), className="p-0"),
            ])),
            html_tbody([
                DECK_BuildLevelRowUI_DDEF(i, initial_rows[i], i <= active_count)
                for i in rows_range
            ]),
        ]; style=Dict("width" => "100%", "borderCollapse" => "collapse", "color" => "#000000", "fontSize" => "10px", "tableLayout" => "fixed", "marginBottom" => "0"))
end

"""
    DECK_BuildLimitsTable_DDEF(rows_range, initial_rows, active_count) -> html_table
Constructs the limits portion of the factor table.
"""
function DECK_BuildLimitsTable_DDEF(rows_range, initial_rows, active_count)
    html_table([
            html_thead(html_tr([
                html_th("MIN LIMIT", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "33%")), className="p-0"),
                html_th("UNIT", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "34%")), className="p-0"),
                html_th("MAX LIMIT", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "padding" => "2px", "width" => "33%")), className="p-0"),
            ])),
            html_tbody([
                DECK_BuildLimitsRowUI_DDEF(i, initial_rows[i], i <= active_count)
                for i in rows_range
            ]),
        ]; style=Dict("width" => "100%", "borderCollapse" => "collapse", "color" => "#000000", "fontSize" => "10px", "tableLayout" => "fixed", "marginBottom" => "0"))
end

"""
    DECK_Layout_DDEF()
Constructs the experimental design interface layout.
"""
function DECK_Layout_DDEF()
    try
        Defaults = Sys_Fast.FAST_GetLabDefaults_DDEF()

        # Start with 7 active rows by default
        initial_rows = [DECK_GetDefaultRow_DDEF(i) for i in 1:MAX_ROWS]
        active_count = 7


        return dbc_container(
            [
                # State Bus & Hidden DataTable
                dbc_row(dbc_col([
                        dcc_store(id="deck-store-factors",
                            data=Dict("rows" => [DECK_GetDefaultRow_DDEF(i) for i in 1:7], "count" => 7),
                            storage_type="memory"),
                        dcc_store(id="deck-store-outputs", data=Dict("rows" => [Dict("IsCorr" => false) for i in 1:3]), storage_type="memory"),
                        html_div([
                                dash_datatable(
                                    id="deck-table-in",
                                    columns=[
                                        Dict("name" => "Name", "id" => "Name", "type" => "text"),
                                        Dict("name" => "Role", "id" => "Role", "type" => "text"),
                                        Dict("name" => "L1", "id" => "L1", "type" => "numeric"),
                                        Dict("name" => "L2", "id" => "L2", "type" => "numeric"),
                                        Dict("name" => "L3", "id" => "L3", "type" => "numeric"),
                                        Dict("name" => "Min", "id" => "Min", "type" => "numeric"),
                                        Dict("name" => "Max", "id" => "Max", "type" => "numeric"),
                                        Dict("name" => "MW", "id" => "MW", "type" => "numeric"),
                                        Dict("name" => "Unit", "id" => "Unit", "type" => "text"),
                                    ],
                                    data=[DECK_GetDefaultRow_DDEF(i) for i in 1:5],
                                    editable=false,
                                ),
                                html_div(DECK_BuildIdTable_DDEF(4:4, initial_rows, active_count, false), style=Dict("display" => "none")),
                                html_div(DECK_BuildLimitsTable_DDEF(4:4, initial_rows, active_count), style=Dict("display" => "none")),
                                html_div(DECK_BuildLevelTable_DDEF(4:4, initial_rows, active_count), style=Dict("display" => "none")),
                                # Hidden MW, Role & Delete inputs (callbacks reference these IDs)
                                html_div([
                                        html_div([dcc_input(id="deck-mw-$i", type="number", value=0.0) for i in 1:MAX_ROWS]),
                                        html_div([dbc_select(id="deck-role-$i", options=ROLE_OPTIONS, value="Variable") for i in 1:MAX_ROWS]),
                                        html_div([html_button("", id="deck-del-$i", n_clicks=0) for i in 1:4])
                                    ], style=Dict("display" => "none")),
                            ]; style=Dict("display" => "none"))
                    ], xs=12)),

                # Page Header
                BASE_PageHeader_DDEF("Experimental Design and Protocol Management", "The system is architected to operate with 3 independent (x) and 3 dependent (y) variables, functioning with 5 degrees of freedom (df)."),

                # Main Workspace
                dbc_row([
                        # --- LEFT COLUMN ---
                        dbc_col([
                                # Variable Windows
                                dbc_row(dbc_col(BASE_GlassPanel_DDEF([html_i(className="fas fa-layer-group me-2"), "INDEPENDENT VARIABLES", html_span(" — Define analysis boundaries and corresponding levels for a 3-factor system.", className="ms-2 text-muted fw-normal", style=Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0"))], dbc_row([
                                                    dbc_col(DECK_BuildIdTable_DDEF(1:3, initial_rows, active_count, false), lg=4, className="pe-lg-1"),
                                                    dbc_col(DECK_BuildLimitsTable_DDEF(1:3, initial_rows, active_count), lg=4, className="px-lg-1"),
                                                    dbc_col(DECK_BuildLevelTable_DDEF(1:3, initial_rows, active_count), lg=4, className="ps-lg-1")
                                                ], className="g-0"); panel_class="mb-4 h-100", content_class="p-2"), xs=12), className="mb-3"),

                                # Constant Windows
                                dbc_row(dbc_col(BASE_GlassPanel_DDEF([html_i(className="fas fa-thumbtack me-2"), "CONSTANT PARAMETERS", html_span(" — Static background components strictly maintained throughout the entire analysis.", className="ms-2 text-muted fw-normal", style=Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0"))], dbc_row([
                                                    dbc_col(DECK_BuildIdTable_DDEF(5:MAX_ROWS, initial_rows, active_count, true), lg=4, className="pe-lg-1"),
                                                    dbc_col(DECK_BuildLimitsTable_DDEF(5:MAX_ROWS, initial_rows, active_count), lg=4, className="px-lg-1"),
                                                    dbc_col(DECK_BuildLevelTable_DDEF(5:MAX_ROWS, initial_rows, active_count), lg=4, className="ps-lg-1")
                                                ], className="g-0"); right_node=dbc_button([html_i(className="fas fa-plus me-1"), "Add Row"], id="deck-btn-add-row", n_clicks=0, color="secondary", outline=true, size="sm", className="px-2 py-1 fw-bold"), panel_class="mb-4 h-100", content_class="p-2"), xs=12), className="mb-3"),

                                # Row 2: Response Metrics
                                dbc_row([
                                        dbc_col(BASE_GlassPanel_DDEF([html_i(className="fas fa-bullseye me-2"), "DEPENDENT VARIABLES", html_span(" — Declare the 3 fundamental analysis parameters to be thoroughly investigated.", className="ms-2 text-muted fw-normal", style=Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0"))],
                                                html_div(html_table([
                                                            html_thead(html_tr([
                                                                html_th("RESPONSE NAME", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "paddingLeft" => "5px", "width" => "40%")), className="p-0"),
                                                                html_th("UNIT/METRIC", style=merge(BASE_STYLE_INLINE_HEADER, Dict("textAlign" => "center", "paddingLeft" => "5px", "width" => "40%")), className="p-0"),
                                                                html_th("", style=merge(BASE_STYLE_INLINE_HEADER, Dict("width" => "20%")), className="p-0")
                                                            ])),
                                                            html_tbody([DECK_BuildOutRow_DDEF(i, "", "-") for i in 1:3])
                                                        ], style=Dict("width" => "100%", "borderCollapse" => "collapse", "color" => "#000000", "fontSize" => "10px", "tableLayout" => "fixed")), className="table-responsive m-0 p-2");
                                                content_class="glass-content p-0", panel_class="h-100 mb-0"), lg=12),
                                    ], className="g-3 mb-3 d-flex align-items-stretch"),
                            ], xs=12, lg=9, className="mb-3 mb-lg-0"),

                        # --- RIGHT COLUMN ---
                        dbc_col([
                                dbc_row(dbc_col(BASE_GlassPanel_DDEF("PROTOCOL CONFIGURATION", [
                                            dbc_row(dbc_col(dcc_upload(id="deck-upload",
                                                    children=dbc_button(
                                                        [html_i(className="fas fa-file-import me-2"), "Import Dataset"],
                                                        color="secondary", outline=true, size="sm", className="w-100 mb-2"),
                                                    multiple=false), xs=12)),
                                            dbc_row(dbc_col(dcc_loading(html_div("No data source", id="deck-upload-status", className="glass-loading-status mb-2"),
                                                    type="default", color="#21918C"), xs=12)), dbc_row(dbc_col(html_hr(style=BASE_STYLE_HR, className="my-2"), xs=12)), dbc_row(dbc_col(html_div("PROFILES", className="small mb-1 fw-bold text-center"), xs=12)),
                                            dbc_row([
                                                    dbc_col(dbc_button([html_i(className="fas fa-download me-1"), " Save"], id="deck-btn-save-memo", n_clicks=0, color="secondary", outline=true, size="sm", className="w-100 fw-bold"), xs=6, className="pe-1 mb-2"),
                                                    dbc_col(dcc_upload(id="deck-upload-memo", children=dbc_button([html_i(className="fas fa-upload me-1"), " Load"], n_clicks=0, color="secondary", outline=true, size="sm", className="w-100 fw-bold"), multiple=false, className="w-100"), xs=6, className="ps-1 mb-2"),
                                                    dbc_col(dbc_button([html_i(className="fas fa-eye me-1"), " Sample"], id="deck-btn-template", n_clicks=0, color="secondary", outline=true, size="sm", className="w-100 fw-bold"), xs=6, className="pe-1 mb-3"),
                                                    dbc_col(dbc_button([html_i(className="fas fa-eraser me-1"), " Clear"], id="deck-btn-clear", n_clicks=0, color="secondary", outline=true, size="sm", className="w-100 fw-bold"), xs=6, className="ps-1 mb-3"),
                                                ], className="g-0"), dbc_row(dbc_col(html_div(id="deck-memo-msg", className="small mb-2 fw-bold text-center"), xs=12)), dbc_row(dbc_col([
                                                    dbc_label("Project Name", className="small mb-1"),
                                                    dbc_input(id="deck-input-project", type="text", value="",
                                                        placeholder="Enter project name...", className="mb-2 form-control-sm", debounce=false),
                                                ], xs=12)), dbc_row(dbc_col([
                                                    dbc_label("Phase", className="small mb-1"),
                                                    dcc_dropdown(id="deck-dd-phase",
                                                        options=[Dict("label" => "Phase 1", "value" => "Phase1")],
                                                        clearable=false, className="mb-3"),
                                                ], xs=12)), dbc_row(dbc_col([
                                                    dbc_label("Design Method", className="small mb-1"),
                                                    dcc_dropdown(id="deck-dd-method",
                                                        options=[
                                                            Dict("label" => "Box-Behnken (15 Runs, Quadratic)", "value" => "BoxBehnken"),
                                                            Dict("label" => "Taguchi L9 (9 Runs, Linear)", "value" => "Taguchi_L9"),
                                                        ],
                                                        value="BoxBehnken", clearable=false, className="mb-3"),
                                                ], xs=12)), dbc_row(dbc_col(html_hr(style=BASE_STYLE_HR, className="my-2"), xs=12)),
                                            # Stoichiometry Settings Button
                                            dbc_row(dbc_col(dbc_button([html_i(className="fas fa-flask me-2"), "Stoichiometry Settings"],
                                                    id="deck-btn-stoch-settings", n_clicks=0, color="secondary", outline=true, size="sm",
                                                    className="w-100 mb-2"), xs=12)),
                                            dbc_row(dbc_col(dbc_button([html_i(className="fas fa-vial me-2"), "Quick Audit"],
                                                    id="deck-btn-audit", n_clicks=0, color="secondary", outline=true, size="sm",
                                                    className="w-100 mb-2"), xs=12)), dbc_row(dbc_col(dcc_loading(html_div(id="deck-run-output", className="mt-2 small"),
                                                    type="default", color="#21918C"), xs=12)), dbc_row(dbc_col(dbc_button([html_i(className="fas fa-play me-2"), "Generate Protocol"],
                                                    id="deck-btn-run", n_clicks=0, color="primary", size="sm",
                                                    className="w-100 fw-bold mb-2"), xs=12)),
                                        ]; right_node=html_i(className="fas fa-sliders-h text-secondary"), panel_class="mb-3 h-auto"), xs=12)),
                            ], xs=12, lg=3),
                    ], className="g-3"),

                # Download components
                dcc_download(id="deck-download-xlsx"),
                dcc_download(id="deck-download-memo"),

                # Stoichiometry Settings Store
                dcc_store(id="deck-store-stoch-settings",
                    data=Dict("FillerName" => "", "FillerMW" => 0.0, "Volume" => 0.0, "Conc" => 0.0),
                    storage_type="memory"),
                dcc_store(id="deck-stoch-trigger-unit", data=0, storage_type="memory"),

                # Chemical Properties Modal
                dbc_modal([
                        dbc_modalheader(dbc_modaltitle([html_i(className="fas fa-flask me-2 text-primary"), html_span("Component Properties", id="deck-prop-title")])),
                        dbc_modalbody([
                            # Hidden store for tracking which row we are editing
                            dcc_store(id="deck-prop-target-id", data=Dict("type" => "", "index" => 0)),
                            dcc_store(id="deck-prop-trigger-save", data=0),
                            html_div("Chemical Definition", className="small fw-bold text-muted mb-2"),
                            dbc_row([
                                    dbc_col(dbc_label("Molecular Weight (g/mol)", className="small mb-1"), xs=12),
                                    dbc_col(dbc_input(id="deck-prop-mw", type="number", min=0, step="any", placeholder="e.g. 386.65", size="sm", className="mb-3"), xs=12),
                                ], className="mb-2 border-bottom pb-2"),
                            html_div("Radioactivity & Decay", className="small fw-bold text-muted mb-2"),
                            dbc_row([
                                dbc_col(dbc_label("Half-Life (T½)", className="small mb-1"), xs=6),
                                dbc_col(dbc_label("Unit", className="small mb-1"), xs=6),
                                dbc_col(dbc_input(id="deck-prop-hl", type="number", min=0, step="any", placeholder="e.g. 6.0", size="sm", className="mb-3"), xs=6),
                                dbc_col(dbc_select(id="deck-prop-hl-unit", options=[
                                            Dict("label" => "Seconds", "value" => "Seconds"),
                                            Dict("label" => "Minutes", "value" => "Minutes"),
                                            Dict("label" => "Hours", "value" => "Hours"),
                                            Dict("label" => "Days", "value" => "Days"),
                                            Dict("label" => "Years", "value" => "Years")
                                        ], value="Hours", size="sm", className="mb-3"), xs=6)
                            ]),
                            # Hidden dummy elements
                            html_div([
                                    dbc_switch(id="deck-prop-is-radio", value=false, style=Dict("display" => "none")),
                                    dbc_switch(id="deck-prop-is-filler", value=false, style=Dict("display" => "none")),
                                ], style=Dict("display" => "none")),
                        ]),
                        dbc_modalfooter([
                            dbc_button("Cancel", id="btn-prop-cancel", className="ms-auto", color="secondary", outline=true, size="sm"),
                            dbc_button("Save Properties", id="btn-prop-save", color="primary", size="sm")
                        ])
                    ],
                    id="deck-modal-prop", is_open=false, centered=true, backdrop="static"
                ),

                # Output/Response Properties Modal
                dbc_modal([
                        dbc_modalheader(dbc_modaltitle([html_i(className="fas fa-chart-line me-2 text-success"), html_span("Response Properties", id="deck-out-prop-title")])),
                        dbc_modalbody([
                            dcc_store(id="deck-out-prop-target-id", data=Dict("index" => 0)),
                            dcc_store(id="deck-out-prop-trigger-save", data=0),
                            html_div("Decay Analysis Correction", className="small fw-bold text-muted mb-2"),
                            html_p("Type YES below to apply radioactive decay correction to this response.", className="small text-secondary mb-2"),
                            dbc_row([
                                dbc_col(dbc_input(id="deck-out-prop-confirm", type="text", placeholder="Type YES...", size="sm", className="mb-2"), xs=12)
                            ]),
                            # Hidden dummy for removed switch ID
                            html_div(dbc_switch(id="deck-out-prop-is-corr", value=false, style=Dict("display" => "none")), style=Dict("display" => "none")),
                        ]),
                        dbc_modalfooter([
                            dbc_button("Cancel", id="btn-out-prop-cancel", className="ms-auto", color="secondary", outline=true, size="sm"),
                            dbc_button("Save Properties", id="btn-out-prop-save", color="primary", size="sm")
                        ])
                    ],
                    id="deck-modal-out-prop", is_open=false, centered=true, backdrop="static"
                ),

                # Stoichiometry Settings Modal
                dbc_modal([
                        dbc_modalheader(dbc_modaltitle([html_i(className="fas fa-flask me-2 text-warning"), "Stoichiometry Settings"])),
                        dbc_modalbody([
                            dbc_alert([
                                    html_i(className="fas fa-exclamation-triangle me-2"),
                                    html_strong("Stoichiometric Limit: "), "Total percentage of all chemical components must not exceed 100%.", html_br(), html_br(),
                                    html_i(className="fas fa-info-circle me-2"),
                                    html_strong("Automatic Unit Override"), html_br(),
                                    "Saving these settings will overwrite the UNIT column for all chemical components:", html_br(),
                                    html_span([
                                            html_strong("All 4 fields filled"), " (Filler + Vol + Conc) → units set to ", html_code("%M"), html_br(),
                                            html_strong("Only Vol + Conc filled"), " → units set to ", html_code("MR"), " (Molar Ratio)", html_br(),
                                            html_strong("None filled"), " → units remain as manually entered",
                                        ], className="d-block mt-1"),
                                ], color="warning", className="py-2 small mb-3"),
                            html_div("Filler Definition", className="small fw-bold text-muted mb-2"),
                            dbc_row([
                                    dbc_col([
                                            dbc_label("Filler Name", className="small mb-1"),
                                            dbc_input(id="deck-stoch-filler-name", type="text", placeholder="", size="sm", className="mb-2"),
                                        ], xs=6),
                                    dbc_col([
                                            dbc_label("Filler MW (g/mol)", className="small mb-1"),
                                            dbc_input(id="deck-stoch-filler-mw", type="number", min=0, step="any", placeholder="e.g. 734.05", size="sm", className="mb-2"),
                                        ], xs=6),
                                ], className="mb-2 border-bottom pb-2"),
                            html_div("Environment Parameters", className="small fw-bold text-muted mb-2"),
                            dbc_row([
                                dbc_col([
                                        dbc_label("Volume (mL)", className="small mb-1"),
                                        dbc_input(id="deck-stoch-vol", type="number", min=0, step="any", placeholder="e.g. 5.0", size="sm", className="mb-2"),
                                    ], xs=6),
                                dbc_col([
                                        dbc_label("Concentration (mM)", className="small mb-1"),
                                        dbc_input(id="deck-stoch-conc", type="number", min=0, step="any", placeholder="e.g. 20.0", size="sm", className="mb-2"),
                                    ], xs=6),
                            ]),
                            # Hidden inputs
                            html_div([
                                    dcc_input(id="deck-input-vol", type="number", value=0.0, style=Dict("display" => "none")),
                                    dcc_input(id="deck-input-conc", type="number", value=0.0, style=Dict("display" => "none")),
                                ], style=Dict("display" => "none")),
                        ]),
                        dbc_modalfooter([
                            dbc_button("Cancel", id="deck-btn-stoch-cancel", className="ms-auto", color="secondary", outline=true, size="sm"),
                            dbc_button("Save Settings", id="deck-btn-stoch-save", color="warning", size="sm")
                        ])
                    ],
                    id="deck-modal-stoch-settings", is_open=false, centered=true, backdrop="static"
                ),

                # Audit Modal
                BASE_Modal_DDEF("deck-modal-audit", "Quick Audit Report",
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

"""
    DECK_GenerateProtocol_DDEF(path, in_data, out_data, vol, conc, method)
Orchestrates the generation of an experimental protocol Excel file.
"""
function DECK_GenerateProtocol_DDEF(path, in_data, out_data, vol, conc, method)
    C = Sys_Fast.FAST_Constants_DDEF()
    try
        D = Lib_Mole.MOLE_ParseTable_DDEF(_safe_rows(in_data))
        num_vars = length(D["Idx_Var"])
        num_fills = length(D["Idx_Fill"])
        num_vars != 3 && return (false, "Requires exactly 3 Variable ingredients (Found: $num_vars).")
        num_fills > 1 && return (false, "Maximum 1 Filler allowed (Found: $num_fills).")

        # 1. Name Validity and Uniqueness Check
        all_names = String[]
        for (i, r) in enumerate(D["Rows"])
            n = strip(string(get(r, "Name", "")))
            if isempty(n)
                return (false, "Systematic Error: A valid name must be defined for row $i.")
            end
            if n in all_names
                return (false, "Systematic Error: Name '$n' is used more than once. All names must be unique.")
            end
            push!(all_names, n)

            # 2. Strict Level Increase Rule (L1 < L2 < L3)
            role = get(r, "Role", "")
            if role == "Variable"
                l1 = Sys_Fast.FAST_SafeNum_DDEF(get(r, "L1", 0.0))
                l2 = Sys_Fast.FAST_SafeNum_DDEF(get(r, "L2", 0.0))
                l3 = Sys_Fast.FAST_SafeNum_DDEF(get(r, "L3", 0.0))
                if !(l1 < l2 && l2 < l3)
                    return (false, "Systematic Error: Levels for '$n' (Variable) must show a strict increase (LOWER $l1 < CENTRE $l2 < UPPER $l3).")
                end
            end
        end

        # 3. Stoichiometry Sum Check (Max Limit 100%)
        if !isempty(D["Idx_Chem"]) || !isempty(D["Idx_Fill"])
            sum_max = 0.0
            for r in D["Rows"]
                if Sys_Fast.FAST_SafeNum_DDEF(get(r, "MW", 0.0)) > 0.0 || get(r, "IsFiller", false)
                    role = get(r, "Role", "")
                    if role == "Variable"
                        sum_max += Sys_Fast.FAST_SafeNum_DDEF(get(r, "L3", 0.0))
                    else
                        sum_max += Sys_Fast.FAST_SafeNum_DDEF(get(r, "L2", 0.0))
                    end
                end
            end
            if sum_max > 100.0 + 1e-4
                return (false, "Stoichiometry Error: Total percentage of all chemical components cannot exceed 100% (Sum of Limits Entered: $(round(sum_max; digits=2))%). Please adjust the upper limits.")
            end
        end

        # 4. Mandatory Response Validation
        output_data = _safe_rows(out_data)
        if length(output_data) != 3
            return (false, "Systematic Error: Exactly 3 Responses (Outputs) must be defined.")
        end
        all_out_names = String[]
        for (i, r) in enumerate(output_data)
            n = strip(string(get(r, "Name", "")))
            if isempty(n)
                return (false, "Systematic Error: Name for row $i in the Response Metrics table cannot be empty. All 3 outputs must be named.")
            end
            if n in all_out_names
                return (false, "Systematic Error: Response names must be unique. '$n' is repeated.")
            end
            push!(all_out_names, n)
        end

        # 5. Core Matrix Generation
        design_coded = Lib_Core.CORE_GenDesign_DDEF(method, num_vars)
        N_Runs = size(design_coded, 1)
        configs = [Dict("Levels" => [D["Rows"][i]["L1"], D["Rows"][i]["L2"], D["Rows"][i]["L3"]])
                   for i in D["Idx_Var"]]
        real_matrix = Lib_Core.CORE_MapLevels_DDEF(design_coded, configs)

        # 6. Session & Phase Logic
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
                if used > 100.0 + 1e-4
                    return (false, "Filler validation failed: Components exceed 100% in generated run $i (Sum: $(round(used; digits=2))%). Please adjust boundaries.")
                end
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

        # Response validation
        for r in output_data
            n = string(get(r, "Name", "Unknown"))
            df[!, "RESULT_$n"] = fill(missing, N_Runs)
            df[!, "PRED_$n"] = fill(missing, N_Runs)
        end
        df[!, C.COL_SCORE] = fill(missing, N_Runs)
        df[!, C.COL_NOTES] = fill("", N_Runs)

        f_name = ""
        f_mw = 0.0
        if !isempty(D["Idx_Fill"])
            f_row = D["Rows"][D["Idx_Fill"][1]]
            f_name = string(get(f_row, "Name", ""))
            f_mw = Sys_Fast.FAST_SafeNum_DDEF(get(f_row, "MW", 0.0))
        end

        ConfigDict = Dict(
            "Ingredients" => D["Rows"],
            "Global" => Dict("Volume" => sv, "Conc" => sc, "Method" => method, "FillerName" => f_name, "FillerMW" => f_mw),
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
Registers all GUI callbacks including state management and file operations.
"""
function DECK_RegisterCallbacks_DDEF(app)

    # --- 1. UI HYDRATION (Refreshes text boxes from State Bus) ---
    callback!(app,
        [Output("deck-row-id-$i", "style") for i in 1:MAX_ROWS]...,
        [Output("deck-row-level-$i", "style") for i in 1:MAX_ROWS]...,
        [Output("deck-row-limits-$i", "style") for i in 1:MAX_ROWS]...,
        [Output("deck-name-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-role-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-l1-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-l2-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-l3-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-min-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-max-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-mw-$i", "value") for i in 1:MAX_ROWS]...,
        [Output("deck-unit-$i", "value") for i in 1:MAX_ROWS]...,
        # Indicator dot styles (chemical + radioactive)
        [Output("deck-dot1-$i", "style") for i in 1:MAX_ROWS]...,
        [Output("deck-dot2-$i", "style") for i in 1:MAX_ROWS]...,
        Input("deck-store-factors", "data")
    ) do stored
        isnothing(stored) && return ntuple(_ -> Dash.no_update(), 14 * MAX_ROWS)
        rows = get(stored, "rows", [])
        count = get(stored, "count", 0)

        # All rows are now table-rows (ID, Level, Limits all use html_table)
        out_styles = [Dict("display" => (i <= 4 || i <= count) ? "table-row" : "none") for i in 1:MAX_ROWS]
        out_names = [i <= length(rows) ? string(get(rows[i], "Name", "")) : "" for i in 1:MAX_ROWS]
        out_roles = [i <= length(rows) ? string(get(rows[i], "Role", (i <= 3 ? "Variable" : (i == 4 ? "Filler" : "Fixed")))) : (i <= 3 ? "Variable" : (i == 4 ? "Filler" : "Fixed")) for i in 1:MAX_ROWS]
        out_l1s = [i <= length(rows) ? get(rows[i], "L1", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_l2s = [i <= length(rows) ? get(rows[i], "L2", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_l3s = [i <= length(rows) ? get(rows[i], "L3", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_mins = [i <= length(rows) ? get(rows[i], "Min", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_maxs = [i <= length(rows) ? get(rows[i], "Max", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_mws = [i <= length(rows) ? get(rows[i], "MW", 0.0) : 0.0 for i in 1:MAX_ROWS]
        out_units = [i <= length(rows) ? string(get(rows[i], "Unit", "")) : "" for i in 1:MAX_ROWS]

        # Indicator dot colours: green when MW/HL > 0
        dot1_styles = [Dict("color" => (i <= length(rows) && Float64(get(rows[i], "MW", 0.0)) > 0.0 ? "#5EC962" : "#2C2C2C"),
            "fontSize" => "0.45rem", "marginRight" => "1px") for i in 1:MAX_ROWS]
        dot2_styles = [Dict("color" => (i <= length(rows) && Float64(get(rows[i], "HalfLife", 0.0)) > 0.0 ? "#5EC962" : "#2C2C2C"),
            "fontSize" => "0.45rem", "marginRight" => "2px") for i in 1:MAX_ROWS]

        return (out_styles..., out_styles..., out_styles..., out_names..., out_roles..., out_l1s..., out_l2s..., out_l3s..., out_mins..., out_maxs..., out_mws..., out_units..., dot1_styles..., dot2_styles...)
    end



    # --- 2. MAIN STORE ORCHESTRATOR ---
    callback!(app,
        Output("deck-store-factors", "data"),
        Output("deck-table-in", "data"),
        Output("deck-dd-phase", "options"),
        Output("deck-input-vol", "value"),
        Output("deck-input-conc", "value"),
        Output("deck-input-project", "value"),
        Output("deck-dd-method", "value"),
        Output("deck-memo-msg", "children"),
        Output("deck-download-memo", "data"),
        Output("deck-upload-status", "children"),
        Output("deck-dd-phase", "value"),
        # Response Metrics Outputs
        [Output("deck-out-name-$i", "value") for i in 1:3]...,
        [Output("deck-out-unit-$i", "value") for i in 1:3]...,
        # Triggers
        Input("deck-btn-add-row", "n_clicks"),
        Input("deck-btn-clear", "n_clicks"),
        Input("deck-upload-memo", "contents"),
        Input("deck-btn-template", "n_clicks"),
        Input("deck-btn-save-memo", "n_clicks"),
        Input("store-session-config", "data"),
        Input("deck-upload", "contents"),
        Input("deck-prop-trigger-save", "data"),
        Input("deck-stoch-trigger-unit", "data"),
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
        [State("deck-min-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-max-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-mw-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-unit-$i", "value") for i in 1:MAX_ROWS]...,
        State("deck-input-vol", "value"),
        State("deck-input-conc", "value"),
        State("deck-prop-target-id", "data"),
        State("deck-prop-is-radio", "value"),
        State("deck-prop-hl", "value"),
        State("deck-prop-hl-unit", "value"),
        State("deck-prop-is-filler", "value"),
        State("deck-prop-mw", "value"),
        State("deck-store-stoch-settings", "data"),
        [State("deck-out-name-$i", "value") for i in 1:3]...,
        [State("deck-out-unit-$i", "value") for i in 1:3]...,
        State("deck-store-outputs", "data"),
        prevent_initial_call=false
    ) do args...
        try  # Global error guard for main orchestrator callback
            # UNPACKING ARCHITECTURE (Args Array Mapping)
            # 1..33: Inputs (9 single + 24 del buttons)
            # 34: deck-store-factors (STATE)
            # 35: deck-upload (STATE)
            # 36..251: Factor Table Row States (9 blocks of 24)
            # 252..253: Vol/Conc States (hidden, kept for compatibility)
            # 254..259: Property Modal States (TargetID, IsRadio, HL, HLUnit, IsFiller, MW)
            # 260: deck-store-stoch-settings (STATE)

            n_add, n_clear, up_memo, n_temp, n_save, session, up_cont = args[1:7]
            save_prop_trig = args[8]
            stoch_trig = args[9]
            ndels = args[10:33]
            store_data = args[34]
            fname = args[35]

            offset = 12 + MAX_ROWS
            all_names = collect(args[offset:offset+MAX_ROWS-1])
            all_roles = collect(args[offset+MAX_ROWS:offset+2MAX_ROWS-1])
            all_l1s = collect(args[offset+2MAX_ROWS:offset+3MAX_ROWS-1])
            all_l2s = collect(args[offset+3MAX_ROWS:offset+4MAX_ROWS-1])
            all_l3s = collect(args[offset+4MAX_ROWS:offset+5MAX_ROWS-1])
            all_mins = collect(args[offset+5MAX_ROWS:offset+6MAX_ROWS-1])
            all_maxs = collect(args[offset+6MAX_ROWS:offset+7MAX_ROWS-1])
            all_mws = collect(args[offset+7MAX_ROWS:offset+8MAX_ROWS-1])
            all_units = collect(args[offset+8MAX_ROWS:offset+9MAX_ROWS-1])

            ctx = callback_context()
            trig = ""
            if isempty(ctx.triggered)
                # Initialization check: Permit cross-page hydration if session has transition directives
                if !isnothing(session) && session != ""
                    try
                        res = JSON3.read(session)
                        if get(res, "Status", "") == "OK" && haskey(res, "TargetPhase") && haskey(res, "NewConfig")
                            trig = "store-session-config"
                        end
                    catch
                    end
                end

                if trig == ""
                    return (ntuple(_ -> Dash.no_update(), 17)...,)
                end
            else
                trig = split(ctx.triggered[1].prop_id, ".")[1]
            end

            # --- 6. PROP SAVE LOGIC ---
            if trig == "deck-prop-trigger-save"
                isnothing(save_prop_trig) && return ntuple(_ -> Dash.no_update(), 17)
                isnothing(store_data) && return ntuple(_ -> Dash.no_update(), 17)

                # Modal States extraction (explicit indices 254-259)
                target = args[254]
                is_rad = args[255]
                hl_val = args[256]
                hl_unit = args[257]
                is_fill = args[258]
                mw_modal = args[259]

                t_type = string(get(target, "type", get(target, :type, "")))
                t_idx = Int(get(target, "index", get(target, :index, 0)))

                if t_type == "in" && t_idx > 0 && t_idx <= length(store_data["rows"])
                    new_rows = []
                    for (i, r) in enumerate(store_data["rows"])
                        new_r = Dict{String,Any}(string(k) => v for (k, v) in r)
                        if i == t_idx
                            safe_mw = isnothing(mw_modal) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(mw_modal)
                            safe_mw = isnan(safe_mw) ? 0.0 : safe_mw
                            new_r["MW"] = safe_mw

                            safe_hl = isnothing(hl_val) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(hl_val)
                            safe_hl = isnan(safe_hl) ? 0.0 : safe_hl
                            new_r["IsRadioactive"] = safe_hl > 0.0
                            new_r["HalfLife"] = safe_hl
                            new_r["HalfLifeUnit"] = isnothing(hl_unit) ? "Hours" : string(hl_unit)
                            new_r["IsFiller"] = is_fill
                        end
                        push!(new_rows, new_r)
                    end
                    new_store = Dict{String,Any}()
                    for (k, v) in store_data
                        new_store[string(k)] = v
                    end
                    new_store["rows"] = new_rows

                    # Return new store data, updating ONLY the store part of the tuple
                    return (new_store, ntuple(_ -> Dash.no_update(), 16)...)
                end
                return ntuple(_ -> Dash.no_update(), 17)
            end

            # --- 6b. UNIT AUTO-LOGIC ---
            if trig == "deck-stoch-trigger-unit"
                isnothing(store_data) && return ntuple(_ -> Dash.no_update(), 17)
                stoch_data = args[260]  # deck-store-stoch-settings
                isnothing(stoch_data) && return ntuple(_ -> Dash.no_update(), 17)

                has_filler = get(stoch_data, "FillerName", "") != "" && Float64(get(stoch_data, "FillerMW", 0.0)) > 0.0
                has_env = Float64(get(stoch_data, "Volume", 0.0)) > 0.0 && Float64(get(stoch_data, "Conc", 0.0)) > 0.0

                if has_filler || has_env
                    target_unit = has_filler ? "%M" : "MR"
                    new_rows = []
                    filler_name = string(get(stoch_data, "FillerName", ""))
                    filler_mw = Float64(get(stoch_data, "FillerMW", 0.0))

                    for r in store_data["rows"]
                        new_r = Dict{String,Any}(string(k) => v for (k, v) in r)
                        mw = Float64(get(new_r, "MW", 0.0))
                        if mw > 0.0
                            new_r["Unit"] = target_unit
                        end
                        if has_filler && string(get(new_r, "Name", "")) == filler_name
                            new_r["IsFiller"] = true
                            new_r["MW"] = filler_mw
                            new_r["Unit"] = "%M"
                        end
                        push!(new_rows, new_r)
                    end

                    new_store = Dict{String,Any}()
                    for (k, v) in store_data
                        new_store[string(k)] = v
                    end
                    new_store["rows"] = new_rows

                    return (new_store, ntuple(_ -> Dash.no_update(), 16)...)
                end
                return ntuple(_ -> Dash.no_update(), 17)
            end

            NO = Dash.no_update()
            count = isnothing(store_data) ? 1 : get(store_data, "count", 1)

            _sn = Sys_Fast.FAST_SafeNum_DDEF
            _sn0(x) = (v = _sn(x); isnan(v) ? 0.0 : v)
            max_idx = min(count, length(all_names), length(all_roles), length(all_l1s), length(all_l2s), length(all_l3s), length(all_mins), length(all_maxs), length(all_mws), length(all_units))
            snap_rows() = [
                let
                    mw_val = _sn0(all_mws[i])
                    unit_val = !isnothing(all_units[i]) ? string(all_units[i]) : ""

                    # Check previous store state for MW change
                    is_rad = false
                    hl_val = 0.0
                    hl_unit = "Hours"
                    is_fill = false

                    if !isnothing(store_data) && (haskey(store_data, "rows") || haskey(store_data, :rows))
                        r_list = get(store_data, "rows", get(store_data, :rows, []))
                        if i <= length(r_list)
                            prow = r_list[i]
                            pmw = get(prow, "MW", get(prow, :MW, 0.0))
                            prev_mw = pmw isa String ? parse(Float64, pmw) : Float64(pmw)
                            mw_val = prev_mw > 0.0 ? prev_mw : mw_val # Trust store over hidden DOM input for MW
                            is_rad = get(prow, "IsRadioactive", get(prow, :IsRadioactive, false))
                            hl_val = Float64(get(prow, "HalfLife", get(prow, :HalfLife, 0.0)))
                            hl_unit = string(get(prow, "HalfLifeUnit", get(prow, :HalfLifeUnit, "Hours")))
                            is_fill = get(prow, "IsFiller", get(prow, :IsFiller, false))
                        end
                    end

                    # Automatic Unit Adjustment (transition from 0 -> >0)
                    if mw_val > 0.0 && prev_mw <= 0.0
                        if isempty(strip(unit_val)) || unit_val == "-"
                            unit_val = "%M"
                        end
                    end

                    Dict(
                        "Name" => !isnothing(all_names[i]) ? string(all_names[i]) : "",
                        "Role" => !isnothing(all_roles[i]) ? string(all_roles[i]) : "Variable",
                        "L1" => _sn0(all_l1s[i]),
                        "L2" => _sn0(all_l2s[i]),
                        "L3" => _sn0(all_l3s[i]),
                        "Min" => _sn0(all_mins[i]),
                        "Max" => _sn0(all_maxs[i]),
                        "MW" => mw_val,
                        "Unit" => unit_val,
                        "IsRadioactive" => is_rad,
                        "HalfLife" => hl_val,
                        "HalfLifeUnit" => hl_unit,
                        "IsFiller" => is_fill
                    )
                end for i in 1:max_idx
            ]

            # --- A. DELETE ROW ---
            del_ids = ["deck-del-$i" for i in 1:MAX_ROWS]
            if trig in del_ids
                rows = snap_rows()
                ri = findfirst(==(trig), del_ids)
                if ri !== nothing && ri <= length(rows) && ri > 4
                    deleteat!(rows, ri)
                end
                nc = max(4, length(rows))
                return Dict("rows" => rows, "count" => nc), rows, NO, NO, NO, NO, NO, NO, NO, NO, NO,
                NO, NO, NO, NO, NO, NO
            end

            # --- B. ADD ROW ---
            if trig == "deck-btn-add-row"
                rows = snap_rows()
                # Use length(rows) as the source of truth for current valid rows
                current_count = length(rows)
                new_count = min(current_count + 1, MAX_ROWS)
                if new_count > current_count
                    new_row = DECK_GetDefaultRow_DDEF(new_count)
                    new_row["Role"] = "Fixed"
                    push!(rows, new_row)
                end
                return Dict("rows" => rows, "count" => new_count), rows, NO, NO, NO, NO, NO, NO, NO, NO, NO,
                NO, NO, NO, NO, NO, NO

                # --- C0. CLEAR CANVAS ---
            elseif trig == "deck-btn-clear"
                rows = [DECK_GetDefaultRow_DDEF(i) for i in 1:5]
                lbl = html_div([html_i(className="fas fa-trash-alt me-2"), "Canvas Cleared"],
                    className="badge bg-danger text-white p-2 w-100", style=Dict("fontSize" => "0.85rem"))
                return Dict("rows" => rows, "count" => 5), rows, [Dict("label" => "Loading...", "value" => "NONE")], NO, NO, NO, "BoxBehnken", lbl, NO, "No data source", "NONE",
                "", "", "", "-", "-", "-"

                # --- C1. LOAD USER PROFILE ---
            elseif trig == "deck-upload-memo" && !isnothing(up_memo) && up_memo != ""
                try
                    base64_data = split(up_memo, ",")[end]
                    json_str = String(base64decode(base64_data))
                    memo = JSON3.read(json_str)
                    loaded_rows = map(get(memo, "Inputs", [])) do m
                        Dict("Name" => get(m, "Name", ""), "Role" => get(m, "Role", "Variable"),
                            "L1" => get(m, "L1", 0.0), "L2" => get(m, "L2", 0.0),
                            "L3" => get(m, "L3", 0.0), "Min" => get(m, "Min", 0.0),
                            "Max" => get(m, "Max", 0.0), "MW" => get(m, "MW", 0.0),
                            "Unit" => get(m, "Unit", "-"),
                            "IsRadioactive" => get(m, "IsRadioactive", false),
                            "HalfLife" => Float64(get(m, "HalfLife", 0.0)),
                            "HalfLifeUnit" => string(get(m, "HalfLifeUnit", "Hours")),
                            "IsFiller" => get(m, "IsFiller", false))
                    end
                    lbl = html_div([html_i(className="fas fa-folder-open me-2"), "Memory Loaded"],
                        className="badge bg-info text-white p-2 w-100", style=Dict("fontSize" => "0.85rem"))
                    nc = min(length(loaded_rows), MAX_ROWS)

                    g = get(memo, "Global", Dict())
                    vol_v = get(g, "Volume", NO)
                    conc_v = get(g, "Conc", NO)

                    # Populate Response Metrics from Memo if available
                    memo_outs = get(memo, "Outputs", [])
                    out_vals = vcat(
                        [i <= length(memo_outs) ? get(memo_outs[i], "Name", "") : "" for i in 1:3],
                        [i <= length(memo_outs) ? get(memo_outs[i], "Unit", "-") : "-" for i in 1:3]
                    )

                    return Dict("rows" => loaded_rows[1:nc], "count" => nc), loaded_rows[1:nc], NO, vol_v, conc_v, NO, NO, lbl, NO, NO, NO,
                    out_vals...
                catch e
                    return NO, NO, NO, NO, NO, NO, NO, html_div("❌ Load Error: $e", className="badge bg-danger text-white w-100 p-2"), NO, NO, NO,
                    NO, NO, NO, NO, NO, NO
                end

                # --- C2. LOAD TEMPLATE ---
            elseif trig == "deck-btn-template"
                loaded_rows = [
                    Dict("Name" => "Chol", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "Min" => 0.0, "Max" => 40.0, "MW" => 386.65, "Unit" => "%M"),
                    Dict("Name" => "PEG", "Role" => "Variable", "L1" => 1.0, "L2" => 3.0, "L3" => 5.0, "Min" => 0.0, "Max" => 10.0, "MW" => 2808.74, "Unit" => "%M"),
                    Dict("Name" => "Temperature", "Role" => "Variable", "L1" => 25.0, "L2" => 45.0, "L3" => 65.0, "Min" => 25.0, "Max" => 100.0, "MW" => 0.0, "Unit" => "°C"),
                    Dict("Name" => "DPPC", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0, "MW" => 734.05, "Unit" => "%M"),
                    Dict("Name" => "DOTA", "Role" => "Fixed", "L1" => 0.0, "L2" => 1.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0, "MW" => 3184.84, "Unit" => "%M"),
                ]
                lbl = html_div([html_i(className="fas fa-book-medical me-2"), "Template Applied"],
                    className="badge bg-primary text-white p-2 w-100", style=Dict("fontSize" => "0.85rem", "boxShadow" => "0 2px 5px #A6A6A6"))
                nc = min(length(loaded_rows), MAX_ROWS)
                # Get standard outputs from Sys_Fast
                def_outs = Sys_Fast.FAST_GetLabDefaults_DDEF()["Outputs"]
                out_vals = vcat(
                    [i <= length(def_outs) ? def_outs[i]["Name"] : "" for i in 1:3],
                    [i <= length(def_outs) ? def_outs[i]["Unit"] : "-" for i in 1:3]
                )

                return Dict("rows" => loaded_rows[1:nc], "count" => nc), loaded_rows[1:nc], [Dict("label" => "Phase 1", "value" => "Phase1")], 5.0, 20.0, "Sample", "BoxBehnken", lbl, NO, "Ready", "Phase1",
                out_vals...

                # --- D. SAVE PROFILE ---
            elseif trig == "deck-btn-save-memo"
                try
                    stoch_store = args[260]
                    vol_v = isnothing(stoch_store) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(get(stoch_store, "Volume", get(stoch_store, :Volume, 0.0)))
                    conc_v = isnothing(stoch_store) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(get(stoch_store, "Conc", get(stoch_store, :Conc, 0.0)))
                    g_dict = Dict{String,Any}("Volume" => vol_v, "Conc" => conc_v)
                    if !isnothing(stoch_store) && (haskey(stoch_store, "FillerName") || haskey(stoch_store, :FillerName))
                        g_dict["FillerName"] = string(get(stoch_store, "FillerName", get(stoch_store, :FillerName, "")))
                        g_dict["FillerMW"] = Sys_Fast.FAST_SafeNum_DDEF(get(stoch_store, "FillerMW", get(stoch_store, :FillerMW, 0.0)))
                    end

                    out_names = collect(args[261:263])
                    out_units = collect(args[264:266])
                    store_out = args[267]
                    out_d = Dict{String,Any}[]
                    out_rows_mem = isnothing(store_out) ? [] : get(store_out, "rows", get(store_out, :rows, []))
                    for i in 1:3
                        if !isnothing(out_names[i]) && strip(string(out_names[i])) != ""
                            is_rad = false
                            if i <= length(out_rows_mem)
                                is_rad = get(out_rows_mem[i], "IsCorr", get(out_rows_mem[i], :IsCorr, false))
                            end
                            push!(out_d, Dict("Name" => string(out_names[i]), "Unit" => isnothing(out_units[i]) ? "" : string(out_units[i]), "IsRadioactive" => is_rad))
                        end
                    end

                    json_str = JSON3.write(Dict("Inputs" => snap_rows(), "Outputs" => out_d, "Global" => g_dict))
                    b64 = base64encode(json_str)
                    dl_dict = Dict("filename" => "Daisho_Workspace.json", "content" => b64, "base64" => true)
                    lbl = html_div([html_i(className="fas fa-check-circle me-2"), "Workspace Exported"],
                        className="badge bg-success text-white p-2 w-100", style=Dict("fontSize" => "0.85rem", "boxShadow" => "0 2px 5px #A6A6A6"))
                    return NO, NO, NO, NO, NO, NO, NO, lbl, dl_dict, NO, NO,
                    NO, NO, NO, NO, NO, NO
                catch e
                    return NO, NO, NO, NO, NO, NO, NO, html_div("❌ Save Error: " * string(e), className="badge bg-danger text-white p-2 w-100", style=Dict("fontSize" => "0.6rem")), NO, NO, NO,
                    NO, NO, NO, NO, NO, NO
                end

                # --- E. PHASE TRANSITION ---
            elseif trig == "store-session-config" && !isnothing(session) && session != ""
                # DEPRECATED: Excel-Centric approach now handles phase transition.
                # Phase2 design is generated in Sys_Flow.FLOW_BuildNextPhase_DDEF and
                # written directly to Excel. User downloads from Analysis and uploads
                # to Design page. No cross-page state passing needed.
                nothing

                # --- F. IMPORT PROTOCOL ---
            elseif trig == "deck-upload" && !isnothing(up_cont)
                try
                    if up_cont == ""
                        return Dict("rows" => [DECK_GetDefaultRow_DDEF(i) for i in 1:5], "count" => 5), NO, [Dict("label" => "Loading...", "value" => "NONE")], NO, NO, NO, NO, NO, NO, "No data source", "NONE",
                        NO, NO, NO, NO, NO, NO
                    end
                    tmp = Sys_Fast.FAST_GetTransientPath_DDEF(up_cont)
                    cfg = Sys_Fast.FAST_ReadConfig_DDEF(tmp)
                    rm(tmp; force=true)
                    if !isempty(cfg) && haskey(cfg, "Ingredients")
                        g = get(cfg, "Global", Dict())
                        mapped = map(cfg["Ingredients"]) do itm
                            Dict("Name" => get(itm, "Name", ""), "Role" => get(itm, "Role", "Variable"),
                                "L1" => get(itm, "L1", 0.0), "L2" => get(itm, "L2", 0.0),
                                "L3" => get(itm, "L3", 0.0), "Min" => get(itm, "Min", 0.0), "Max" => get(itm, "Max", 0.0), "MW" => get(itm, "MW", 0.0),
                                "Unit" => get(itm, "Unit", "-"),
                                "IsRadioactive" => get(itm, "IsRadioactive", false),
                                "HalfLife" => Float64(get(itm, "HalfLife", 0.0)),
                                "HalfLifeUnit" => string(get(itm, "HalfLifeUnit", "Hours")),
                                "IsFiller" => get(itm, "IsFiller", false))
                        end
                        nc = min(length(mapped), MAX_ROWS)
                        method_val = get(g, "Method", "BoxBehnken")
                        outs = get(cfg, "Outputs", [])
                        out_vals = vcat(
                            [i <= length(outs) ? get(outs[i], "Name", "") : "" for i in 1:3],
                            [i <= length(outs) ? get(outs[i], "Unit", "-") : "-" for i in 1:3]
                        )
                        stat_msg = html_span("✅ Sync: $(length(fname) > 15 ? fname[1:15]*"..." : fname)", className="text-success small fw-bold")
                        ph_opts = [Dict("label" => "Phase 1 Initiated", "value" => "Phase1")]

                        return Dict("rows" => mapped[1:nc], "count" => nc), mapped[1:nc], ph_opts,
                        get(g, "Volume", NO), get(g, "Conc", NO), NO, method_val, NO, NO, stat_msg, "Phase1",
                        out_vals...
                    end
                catch e
                    @error "Import failed" exception = (e, catch_backtrace())
                end
            end

            # Default status for no content
            if trig == "deck-upload" && (isnothing(up_cont) || up_cont == "")
                return NO, NO, [Dict("label" => "Loading...", "value" => "NONE")], NO, NO, NO, NO, NO, NO, "No data source", "NONE",
                NO, NO, NO, NO, NO, NO
            end

            return ntuple(_ -> Dash.no_update(), 17)

        catch e  # Catch-all: surface error to UI instead of silent death
            bt = sprint(showerror, e, catch_backtrace())
            println("\e[31m[CRITICAL] DECK CALLBACK ERROR: $e\e[0m")
            println(bt)
            Sys_Fast.FAST_Log_DDEF("DECK", "CALLBACK_CRASH", bt, "FAIL")
            NO = Dash.no_update()
            return (ntuple(_ -> Dash.no_update(), 17)...,)
        end
    end

    # --- 3. AUDIT MODAL ---
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
        [State("deck-min-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-max-$i", "value") for i in 1:MAX_ROWS]...,
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
            all_mins = collect(args[offset+5MAX_ROWS:offset+6MAX_ROWS-1])
            all_maxs = collect(args[offset+6MAX_ROWS:offset+7MAX_ROWS-1])
            all_mws = collect(args[offset+7MAX_ROWS:offset+8MAX_ROWS-1])
            all_units = collect(args[offset+8MAX_ROWS:offset+9MAX_ROWS-1])

            ctx = callback_context()
            trig = isempty(ctx.triggered) ? "" : split(ctx.triggered[1].prop_id, ".")[1]
            trig == "deck-btn-audit-close" && return Dash.no_update(), false
            trig != "deck-btn-audit" && return Dash.no_update(), is_op

            _sn = Sys_Fast.FAST_SafeNum_DDEF
            _sn0(x) = (v = _sn(x); isnan(v) ? 0.0 : v)
            count = isnothing(store_data) ? 1 : get(store_data, "count", 1)
            rows = Dict{String,Any}[]
            for i in 1:count
                name = isnothing(all_names[i]) ? "" : strip(string(all_names[i]))
                minval = _sn0(all_mins[i])
                maxval = _sn0(all_maxs[i])
                l1val = _sn0(all_l1s[i])
                l2val = _sn0(all_l2s[i])
                l3val = _sn0(all_l3s[i])

                if i <= 3
                    mv_raw = _sn(all_mins[i])
                    xv_raw = _sn(all_maxs[i])
                    if isempty(name) || isnan(mv_raw) || isnan(xv_raw)
                        return html_div([
                                html_i(className="fas fa-exclamation-triangle me-2"),
                                html_span("Audit Failed: Variables 1-3 must have Name, Min, and Max fields fully filled.", className="fw-bold"),
                            ], className="text-danger h5 mb-3"), true
                    end

                    if l1val < minval || l3val > maxval || l1val > l2val || l2val > l3val
                        return html_div([
                                html_i(className="fas fa-exclamation-triangle me-2"),
                                html_span("Audit Failed: Variable '$name' must strictly obey Min <= Low <= Centre <= High <= Max boundary logic. (Got: $minval <= $l1val <= $l2val <= $l3val <= $maxval)", className="fw-bold"),
                            ], className="text-danger h5 mb-3"), true
                    end
                end

                if i > 3 && isempty(name)
                    continue
                end

                push!(rows, Dict(
                    "Name" => name,
                    "Role" => isnothing(all_roles[i]) ? (i <= 3 ? "Variable" : (i == 4 ? "Filler" : "Fixed")) : string(all_roles[i]),
                    "L1" => l1val,
                    "L2" => l2val,
                    "L3" => l3val,
                    "Min" => minval,
                    "Max" => maxval,
                    "MW" => _sn0(all_mws[i]),
                    "Unit" => isnothing(all_units[i]) ? "" : string(all_units[i]),
                ))
            end

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

    # --- 4. PROTOCOL GENERATION ---
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
        State("store-master-vault", "data"),
        State("deck-store-outputs", "data"),
        [State("deck-name-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-role-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l1-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l2-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-l3-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-min-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-max-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-mw-$i", "value") for i in 1:MAX_ROWS]...,
        [State("deck-unit-$i", "value") for i in 1:MAX_ROWS]...,
        prevent_initial_call=true
    ) do args...
        try  # Error guard for protocol generation callback
            n, project = args[1:2]
            out_names = collect(args[3:5])
            out_units = collect(args[6:8])
            vol, conc, method, session_data, store_data, master_vault, store_out = args[9:15]
            (n === nothing || n == 0) && return Dash.no_update(), "", Dash.no_update()

            offset = 16
            all_names = collect(args[offset:offset+MAX_ROWS-1])
            all_roles = collect(args[offset+MAX_ROWS:offset+2MAX_ROWS-1])

            out_d = Dict{String,Any}[]
            out_rows_mem = isnothing(store_out) ? [] : get(store_out, "rows", get(store_out, :rows, []))
            for i in 1:3
                if !isnothing(out_names[i]) && strip(string(out_names[i])) != ""
                    is_rad = false
                    if i <= length(out_rows_mem)
                        is_rad = get(out_rows_mem[i], "IsCorr", get(out_rows_mem[i], :IsCorr, false))
                    end
                    push!(out_d, Dict("Name" => string(out_names[i]), "Unit" => isnothing(out_units[i]) ? "" : string(out_units[i]), "IsRadioactive" => is_rad))
                end
            end
            all_l1s = collect(args[offset+2MAX_ROWS:offset+3MAX_ROWS-1])
            all_l2s = collect(args[offset+3MAX_ROWS:offset+4MAX_ROWS-1])
            all_l3s = collect(args[offset+4MAX_ROWS:offset+5MAX_ROWS-1])
            all_mins = collect(args[offset+5MAX_ROWS:offset+6MAX_ROWS-1])
            all_maxs = collect(args[offset+6MAX_ROWS:offset+7MAX_ROWS-1])
            all_mws = collect(args[offset+7MAX_ROWS:offset+8MAX_ROWS-1])
            all_units = collect(args[offset+8MAX_ROWS:offset+9MAX_ROWS-1])

            _sn = Sys_Fast.FAST_SafeNum_DDEF
            _sn0(x) = (v = _sn(x); isnan(v) ? 0.0 : v)
            count = isnothing(store_data) ? 1 : get(store_data, "count", 1)
            in_d = Dict{String,Any}[]
            for i in 1:count
                name = isnothing(all_names[i]) ? "" : strip(string(all_names[i]))
                minval = _sn0(all_mins[i])
                maxval = _sn0(all_maxs[i])
                l1val = _sn0(all_l1s[i])
                l2val = _sn0(all_l2s[i])
                l3val = _sn0(all_l3s[i])

                if i <= 3
                    mv_raw = _sn(all_mins[i])
                    xv_raw = _sn(all_maxs[i])
                    if isempty(name) || isnan(mv_raw) || isnan(xv_raw)
                        return Dash.no_update(), html_div([html_i(className="fas fa-exclamation-triangle me-1"), "Error: Variables 1-3 must have Name, Min, and Max properties filled!"], className="text-danger fw-bold"), Dash.no_update()
                    end
                    if l1val < minval || l3val > maxval || l1val > l2val || l2val > l3val
                        return Dash.no_update(), html_div([html_i(className="fas fa-exclamation-triangle me-1"), "Error: Variable '$name' breaks boundary rules (Got: $minval <= $l1val <= $l2val <= $l3val <= $maxval)!"], className="text-danger fw-bold"), Dash.no_update()
                    end
                end

                if i > 3 && isempty(name)
                    continue
                end

                is_rad = false
                hl_val = 0.0
                hl_unit = "Hours"
                is_fill = false
                if !isnothing(store_data) && (haskey(store_data, "rows") || haskey(store_data, :rows))
                    r_list = get(store_data, "rows", get(store_data, :rows, []))
                    if i <= length(r_list)
                        prow = r_list[i]
                        is_rad = get(prow, "IsRadioactive", get(prow, :IsRadioactive, false))
                        hl_val = Float64(get(prow, "HalfLife", get(prow, :HalfLife, 0.0)))
                        hl_unit = string(get(prow, "HalfLifeUnit", get(prow, :HalfLifeUnit, "Hours")))
                        is_fill = get(prow, "IsFiller", get(prow, :IsFiller, false))
                    end
                end

                push!(in_d, Dict(
                    "Name" => name,
                    "Role" => isnothing(all_roles[i]) ? (i <= 3 ? "Variable" : (i == 4 ? "Filler" : "Fixed")) : string(all_roles[i]),
                    "L1" => l1val,
                    "L2" => l2val,
                    "L3" => l3val,
                    "Min" => minval,
                    "Max" => maxval,
                    "MW" => _sn0(all_mws[i]),
                    "Unit" => isnothing(all_units[i]) ? "" : string(all_units[i]),
                    "IsRadioactive" => is_rad,
                    "HalfLife" => hl_val,
                    "HalfLifeUnit" => hl_unit,
                    "IsFiller" => is_fill
                ))
            end

            if !isnothing(session_data) && session_data != "" && !isnothing(master_vault) && master_vault != ""
                path = Sys_Fast.FAST_GetTransientPath_DDEF(master_vault)
            else
                path = Sys_Fast.FAST_GetTransientPath_DDEF()
            end
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

    # --- 5. CHEM PROPERTIES MODAL ---
    callback!(app,
        Output("deck-modal-prop", "is_open"),
        Output("deck-prop-title", "children"),
        Output("deck-prop-target-id", "data"),
        Output("deck-prop-is-radio", "value"),
        Output("deck-prop-hl", "value"),
        Output("deck-prop-hl-unit", "value"),
        Output("deck-prop-is-filler", "value"),
        Output("deck-prop-trigger-save", "data"),
        Output("deck-prop-mw", "value"),
        Input("btn-prop-cancel", "n_clicks"),
        Input("btn-prop-save", "n_clicks"),
        [Input("btn-prop-$i", "n_clicks") for i in 1:MAX_ROWS]...,
        State("deck-prop-is-radio", "value"),
        State("deck-prop-is-filler", "value"),
        State("deck-store-factors", "data"),
        prevent_initial_call=true
    ) do args...

        ctx = callback_context()
        isempty(ctx.triggered) && return (ntuple(_ -> Dash.no_update(), 9)...,)
        trig = split(ctx.triggered[1].prop_id, ".")[1]

        if trig == "btn-prop-cancel"
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update()
        end

        if trig == "btn-prop-save"
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), (randn()), Dash.no_update()
        end

        m = match(r"btn-prop-(\d+)", trig)
        if m !== nothing
            idx = parse(Int, m.captures[1])
            store_data = args[end]

            title = "Input Component #$idx Properties"
            mw_state = 0.0
            hl_state, hlu_state = 0.0, "Hours"
            rad_state, fill_state = false, false

            if !isnothing(store_data) && (haskey(store_data, "rows") || haskey(store_data, :rows))
                r_list = get(store_data, "rows", get(store_data, :rows, []))
                if idx <= length(r_list)
                    prow = r_list[idx]
                    mw_state = Sys_Fast.FAST_SafeNum_DDEF(get(prow, "MW", get(prow, :MW, 0.0)))
                    rad_state = get(prow, "IsRadioactive", get(prow, :IsRadioactive, false))
                    hl_state = Sys_Fast.FAST_SafeNum_DDEF(get(prow, "HalfLife", get(prow, :HalfLife, 0.0)))
                    hlu_state = string(get(prow, "HalfLifeUnit", get(prow, :HalfLifeUnit, "Hours")))
                    fill_state = get(prow, "IsFiller", get(prow, :IsFiller, false))
                    cur_name = get(prow, "Name", get(prow, :Name, ""))
                    if cur_name != ""
                        title = "Properties: $cur_name"
                    end
                end
            end

            return true, title, Dict("type" => "in", "index" => idx), rad_state, hl_state, hlu_state, fill_state, Dash.no_update(), mw_state
        end

        return (ntuple(_ -> Dash.no_update(), 9)...,)
    end

    # --- 6. RESPONSE PROPERTIES MODAL ---
    callback!(app,
        Output("deck-modal-out-prop", "is_open"),
        Output("deck-out-prop-title", "children"),
        Output("deck-out-prop-target-id", "data"),
        Output("deck-out-prop-is-corr", "value"),
        Output("deck-store-outputs", "data"),
        Output("deck-out-prop-confirm", "value"),
        Input("deck-upload", "contents"),
        Input("store-session-config", "data"),
        Input("deck-upload-memo", "contents"),
        Input("btn-out-prop-cancel", "n_clicks"),
        Input("btn-out-prop-save", "n_clicks"),
        [Input("btn-out-prop-$i", "n_clicks") for i in 1:3]...,
        State("deck-out-prop-is-corr", "value"),
        State("deck-store-outputs", "data"),
        State("deck-out-prop-target-id", "data"),
        State("deck-out-prop-confirm", "value"),
        prevent_initial_call=false
    ) do up_cont, session, up_memo, n_cancel, n_save, args...

        ctx = callback_context()
        trig = ""
        if isempty(ctx.triggered)
            if !isnothing(session) && session != ""
                try
                    res = JSON3.read(session)
                    if get(res, "Status", "") == "OK" && haskey(res, "TargetPhase") && haskey(res, "NewConfig")
                        trig = "store-session-config"
                    end
                catch
                end
            end
            if trig == ""
                return (ntuple(_ -> Dash.no_update(), 6)...,)
            end
        else
            trig = split(ctx.triggered[1].prop_id, ".")[1]
        end

        s_corr = args[4]
        store_out = args[5]
        target_data = args[6]
        s_confirm = args[7]

        if trig == "deck-upload" && !isnothing(up_cont) && up_cont != ""
            try
                tmp = Sys_Fast.FAST_GetTransientPath_DDEF(up_cont)
                cfg = Sys_Fast.FAST_ReadConfig_DDEF(tmp)
                rm(tmp; force=true)
                if !isempty(cfg) && haskey(cfg, "Outputs")
                    o_rows = []
                    for (i, o) in enumerate(cfg["Outputs"])
                        i > 3 && break
                        push!(o_rows, Dict("IsCorr" => get(o, "IsRadioactive", false)))
                    end
                    while length(o_rows) < 3
                        push!(o_rows, Dict("IsCorr" => false))
                    end
                    new_store_out = Dict{String,Any}("rows" => o_rows)
                    return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), new_store_out, ""
                end
            catch
            end
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
        end

        if trig == "store-session-config" && !isnothing(session) && session != ""
            try
                res = JSON3.read(session)
                if get(res, "Status", "") == "OK" && haskey(res, "Outputs")
                    o_rows = []
                    for (i, o) in enumerate(res["Outputs"])
                        i > 3 && break
                        push!(o_rows, Dict("IsCorr" => get(o, "IsRadioactive", false)))
                    end
                    while length(o_rows) < 3
                        push!(o_rows, Dict("IsCorr" => false))
                    end
                    new_store_out = Dict{String,Any}("rows" => o_rows)
                    return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), new_store_out, ""
                end
            catch
            end
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
        end

        if trig == "deck-upload-memo" && !isnothing(up_memo) && up_memo != ""
            try
                base64_data = split(up_memo, ",")[end]
                json_str = String(base64decode(base64_data))
                memo = JSON3.read(json_str)
                if haskey(memo, "Outputs")
                    o_rows = []
                    for (i, o) in enumerate(memo["Outputs"])
                        i > 3 && break
                        push!(o_rows, Dict("IsCorr" => get(o, "IsRadioactive", false)))
                    end
                    while length(o_rows) < 3
                        push!(o_rows, Dict("IsCorr" => false))
                    end
                    new_store_out = Dict{String,Any}("rows" => o_rows)
                    return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), new_store_out, ""
                end
            catch
            end
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
        end

        if trig == "btn-out-prop-cancel"
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
        end

        if trig == "btn-out-prop-save"
            t_v = isnothing(target_data) ? 0 : get(target_data, "index", get(target_data, :index, 0))
            t_idx = t_v isa Number ? Int(t_v) : parse(Int, string(t_v))
            if !isnothing(target_data) && t_idx > 0
                idx = t_idx
                if isnothing(store_out) || !(haskey(store_out, "rows") || haskey(store_out, :rows))
                    store_out = Dict{String,Any}("rows" => [Dict("IsCorr" => false) for _ in 1:3])
                end

                rows_val = get(store_out, "rows", get(store_out, :rows, []))

                # Create fresh normalized row structure to avoid immutability issues
                new_rows = []
                for (i, rv) in enumerate(rows_val)
                    new_r = Dict{String,Any}()
                    if rv isa Dict
                        for (k, v) in rv
                            new_r[string(k)] = v
                        end
                    end
                    if i == idx
                        new_r["IsCorr"] = !isnothing(s_confirm) && strip(uppercase(string(s_confirm))) == "YES"
                    end
                    push!(new_rows, new_r)
                end

                new_store_out = Dict{String,Any}()
                if store_out isa Dict
                    for (k, v) in store_out
                        new_store_out[string(k)] = v
                    end
                end
                new_store_out["rows"] = new_rows

                return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), new_store_out, ""
            end
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
        end

        m_out = match(r"btn-out-prop-(\d+)", trig)
        if m_out !== nothing
            idx = parse(Int, m_out.captures[1])
            title = "Response Component #$idx Properties"

            corr_state = false
            confirm_val = ""
            if !isnothing(store_out)
                r_list = get(store_out, "rows", get(store_out, :rows, []))
                if idx <= length(r_list)
                    corr_state = get(r_list[idx], "IsCorr", get(r_list[idx], :IsCorr, false))
                    confirm_val = corr_state ? "YES" : ""
                end
            end

            return true, title, Dict("index" => idx), corr_state, Dash.no_update(), confirm_val
        end

        return (ntuple(_ -> Dash.no_update(), 6)...,)
    end

    # --- 7. STOICHIOMETRY SETTINGS MODAL ---
    callback!(app,
        Output("deck-modal-stoch-settings", "is_open"),
        Output("deck-store-stoch-settings", "data"),
        Output("deck-stoch-filler-name", "value"),
        Output("deck-stoch-filler-mw", "value"),
        Output("deck-stoch-vol", "value"),
        Output("deck-stoch-conc", "value"),
        Output("deck-stoch-trigger-unit", "data"),
        Input("deck-btn-stoch-settings", "n_clicks"),
        Input("deck-btn-stoch-cancel", "n_clicks"),
        Input("deck-btn-stoch-save", "n_clicks"),
        Input("deck-btn-template", "n_clicks"),
        Input("deck-btn-clear", "n_clicks"),
        Input("deck-upload-memo", "contents"),
        Input("deck-upload", "contents"),
        State("deck-modal-stoch-settings", "is_open"),
        State("deck-store-stoch-settings", "data"),
        State("deck-stoch-filler-name", "value"),
        State("deck-stoch-filler-mw", "value"),
        State("deck-stoch-vol", "value"),
        State("deck-stoch-conc", "value"),
        prevent_initial_call=true
    ) do n_open, n_cancel, n_save, n_template, n_clear, up_memo, up_cont, is_open, store_data, f_name, f_mw, s_vol, s_conc
        NO = Dash.no_update()
        ctx = callback_context()
        isempty(ctx.triggered) && return (ntuple(_ -> NO, 7)...,)
        trig = split(ctx.triggered[1].prop_id, ".")[1]

        if trig == "deck-btn-stoch-settings"
            # Open modal and populate from store
            if !isnothing(store_data)
                return true, NO,
                string(get(store_data, "FillerName", get(store_data, :FillerName, ""))),
                Sys_Fast.FAST_SafeNum_DDEF(get(store_data, "FillerMW", get(store_data, :FillerMW, 0.0))),
                Sys_Fast.FAST_SafeNum_DDEF(get(store_data, "Volume", get(store_data, :Volume, 0.0))),
                Sys_Fast.FAST_SafeNum_DDEF(get(store_data, "Conc", get(store_data, :Conc, 0.0))), NO
            end
            return true, NO, "", 0.0, 0.0, 0.0, NO
        end

        if trig == "deck-btn-stoch-cancel"
            return false, NO, NO, NO, NO, NO, NO
        end

        # Template auto-fills the stoichiometry modal with sample data
        if trig == "deck-btn-template"
            sample_stoch = Dict(
                "FillerName" => "DPPC", "FillerMW" => 734.05,
                "Volume" => 5.0, "Conc" => 20.0)
            return false, sample_stoch, "DPPC", 734.05, 5.0, 20.0, NO
        end
        # Clear button resets stoichiometry store
        if trig == "deck-btn-clear"
            return false, Dict{String,Any}(), "", 0.0, 0.0, 0.0, randn()
        end

        # Load from Memo
        if trig == "deck-upload-memo" && !isnothing(up_memo) && up_memo != ""
            try
                base64_data = split(up_memo, ",")[end]
                json_str = String(base64decode(base64_data))
                memo = JSON3.read(json_str)
                g = get(memo, "Global", Dict())
                loaded_stoch = Dict(
                    "FillerName" => string(get(g, "FillerName", "")),
                    "FillerMW" => Float64(get(g, "FillerMW", 0.0)),
                    "Volume" => Float64(get(g, "Volume", 0.0)),
                    "Conc" => Float64(get(g, "Conc", 0.0))
                )
                return false, loaded_stoch, NO, NO, NO, NO, randn()
            catch e
                return false, NO, NO, NO, NO, NO, NO
            end
        end

        # Load from Uploaded Data File
        if trig == "deck-upload" && !isnothing(up_cont) && up_cont != ""
            try
                tmp = Sys_Fast.FAST_GetTransientPath_DDEF(up_cont)
                cfg = Sys_Fast.FAST_ReadConfig_DDEF(tmp)
                rm(tmp; force=true)
                g = get(cfg, "Global", Dict())
                loaded_stoch = Dict(
                    "FillerName" => string(get(g, "FillerName", "")),
                    "FillerMW" => Float64(get(g, "FillerMW", 0.0)),
                    "Volume" => Float64(get(g, "Volume", 0.0)),
                    "Conc" => Float64(get(g, "Conc", 0.0))
                )
                return false, loaded_stoch, NO, NO, NO, NO, randn()
            catch e
                return false, NO, NO, NO, NO, NO, NO
            end
        end

        if trig == "deck-btn-stoch-save"
            _sn = Sys_Fast.FAST_SafeNum_DDEF
            _sn0(x) = (v = _sn(x); isnan(v) ? 0.0 : v)
            new_data = Dict(
                "FillerName" => isnothing(f_name) ? "" : strip(string(f_name)),
                "FillerMW" => isnothing(f_mw) ? 0.0 : _sn0(f_mw),
                "Volume" => isnothing(s_vol) ? 0.0 : _sn0(s_vol),
                "Conc" => isnothing(s_conc) ? 0.0 : _sn0(s_conc),
            )
            # Trigger fires → orchestrator applies unit auto-logic
            return false, new_data, NO, NO, NO, NO, randn()
        end

        return (ntuple(_ -> NO, 7)...,)
    end

    # --- 8. RESPONSE DOT INDICATOR UPDATE ---
    callback!(app,
        [Output("deck-out-dot-$i", "style") for i in 1:3]...,
        Input("deck-store-outputs", "data"),
        prevent_initial_call=true
    ) do store_out
        isnothing(store_out) && return (ntuple(_ -> Dash.no_update(), 3)...,)
        rows = get(store_out, "rows", get(store_out, :rows, []))
        return Tuple(
            Dict("color" => (i <= length(rows) && get(rows[i], "IsCorr", get(rows[i], :IsCorr, false)) ? "#5EC962" : "#2C2C2C"),
                "fontSize" => "0.45rem", "marginRight" => "2px", "verticalAlign" => "middle")
            for i in 1:3
        )
    end
end
end # module
