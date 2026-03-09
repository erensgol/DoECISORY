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

# --------------------------------------------------------------------------------------
# SECTION 0: CONSTANTS
# --------------------------------------------------------------------------------------

const DECK_MaxRows_DDEC = 24

const DECK_RoleOptions_DDEC = [
    Dict("label" => "Variable", "value" => "Variable"),
    Dict("label" => "Fixed", "value" => "Fixed"),
    Dict("label" => "Filler", "value" => "Filler"),
]

# --- DECK_RoleColours_DDEC REMOVED per user feedback (Dash styling limitations) ---


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

# --- RESTRUCTURING: DECK_BuildIdRowUi_DDEF, DECK_BuildLevelRowUi_DDEF, DECK_BuildLimitsRowUi_DDEF 
# ARE NOW MOVED TO Gui_Base.jl AS BASE_BuildIdRow_DDEF, etc.

"""
    DECK_BuildOutRow_DDEF(i, def_name, def_unit) -> html_tr
Renders a row for the response metrics table.
"""
function DECK_BuildOutRow_DDEF(i, def_name, def_unit)
    # Indicator dot for decay correction status (Fixed color as per user request)
    out_dot = BASE_StatusIcon_DDEF("●", "deck-out-dot-$i", color="#666666")

    prop_btn = BASE_IconButton_DDEF("btn-out-prop-$i", "fas fa-cog")

    return html_tr([
        html_td(dcc_input(id="deck-out-name-$i", type="text", value=def_name, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "40%")), className="p-0"),
        html_td(dcc_input(id="deck-out-unit-$i", type="text", value=def_unit, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "40%")), className="p-0"),
        html_td(html_span([out_dot, prop_btn], style=Dict("display" => "inline-flex", "alignItems" => "center", "justifyContent" => "center")), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "20%")), className="p-0")
    ])
end

# --------------------------------------------------------------------------------------
# SECTION 1.2: MODAL WINDOWS
# --------------------------------------------------------------------------------------

function DECK_ModalChemical_DDEF()
    return dbc_modal([
            dbc_modalheader(dbc_modaltitle([html_i(className="fas fa-flask me-2 text-primary"), html_span("Component Properties", id="deck-prop-title")])),
            dbc_modalbody([
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
                                Dict("label" => "Minutes", "value" => "Minutes"),
                                Dict("label" => "Hours", "value" => "Hours"),
                                Dict("label" => "Days", "value" => "Days"),
                                Dict("label" => "Years", "value" => "Years")
                            ], value="Hours", size="sm", className="mb-3"), xs=6)
                ])
            ]),
            dbc_modalfooter([
                dbc_button("Cancel", id="btn-prop-cancel", className="ms-auto", color="secondary", outline=true, size="sm"),
                dbc_button("Save Properties", id="btn-prop-save", color="primary", size="sm")
            ])
        ], id="deck-modal-prop", is_open=false, centered=true, backdrop="static")
end

function DECK_ModalResponse_DDEF()
    return dbc_modal([
            dbc_modalheader(dbc_modaltitle([html_i(className="fas fa-chart-line me-2 text-success"), html_span("Response Properties", id="deck-out-prop-title")])),
            dbc_modalbody([
                dcc_store(id="deck-out-prop-target-id", data=Dict("index" => 0)),
                dcc_store(id="deck-out-prop-trigger-save", data=0),
                dbc_row(dbc_col([
                        dbc_label([html_i(className="fas fa-history text-success me-2"), "Decay Correction"], className="small mb-0"),
                        html_p("Mathematically correct this response for radioactive decay between calibration and experiment. Please type 'YES' below to confirm.",
                            className="text-muted mb-2", style=Dict("fontSize" => "10px")),
                    ], xs=12)),
                dbc_row(dbc_col([
                        dbc_label("Confirm Decay Correction (Type 'YES')", className="small mb-1"),
                        dbc_input(id="deck-out-prop-confirm", type="text", value="", placeholder="YES", size="sm"),
                        # REMOVED: Inactive switch component for Radioactive Correction as per user request.
                    ], xs=12)),
            ]),
            dbc_modalfooter([
                dbc_button("Cancel", id="btn-out-prop-cancel", className="ms-auto", color="secondary", outline=true, size="sm"),
                dbc_button("Save Properties", id="btn-out-prop-save", color="primary", size="sm")
            ])
        ], id="deck-modal-out-prop", is_open=false, centered=true, backdrop="static")
end

function DECK_ModalStoch_DDEF()
    return dbc_modal([
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
                dbc_alert([
                        html_i(className="fas fa-info-circle me-2"),
                        html_strong("Solid Component Constraint: "), "This system is strictly designed for stoichiometric calculations of solid ingredients. Liquid molarity calculations are not supported; all concentrations assume solids are filled with solvent (water/buffer) to the final target volume.",
                    ], color="info", className="py-2 small mb-3"),
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
                html_div([
                        dcc_input(id="deck-input-vol", type="number", value=0.0, style=Dict("display" => "none")),
                        dcc_input(id="deck-input-conc", type="number", value=0.0, style=Dict("display" => "none")),
                    ], style=Dict("display" => "none")),
            ]),
            dbc_modalfooter([
                dbc_button("Cancel", id="deck-btn-stoch-cancel", className="ms-auto", color="secondary", outline=true, size="sm"),
                dbc_button("Save Settings", id="deck-btn-stoch-save", color="warning", size="sm")
            ])
        ], id="deck-modal-stoch-settings", is_open=false, centered=true, backdrop="static")
end

function DECK_ModalAudit_DDEF()
    return html_div([
        BASE_Modal_DDEF("deck-modal-audit", "Quick Audit Report",
            dbc_row(dbc_col(html_div(id="deck-audit-output"), xs=12)),
            dbc_button("Close", id="deck-btn-audit-close", className="ms-auto")),
        BASE_Modal_DDEF("deck-modal-sci-audit", [html_i(className="fas fa-certificate me-2 text-info"), "Detailed Scientific Audit"],
            dbc_row(dbc_col(dcc_loading(html_div(id="deck-sci-audit-output"), type="default", color="#21918C"), xs=12)),
            dbc_button("Close", id="deck-btn-sci-audit-close", className="ms-auto", color="secondary", outline=true))
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
    push!(th_children, BASE_TableHeader_DDEF("", width="30px", style=merge(BASE_StyleInlineHeader_DDEC, Dict("display" => show_del ? "table-cell" : "none"))))
    push!(th_children, BASE_TableHeader_DDEF("NAME"))
    push!(th_children, BASE_TableHeader_DDEF("", width="55px"))

    html_table([
            html_thead(html_tr(th_children)),
            html_tbody([
                BASE_BuildIdRow_DDEF(i, initial_rows[i], i <= active_count, show_del)
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
                BASE_TableHeader_DDEF("LOWER", width="33%"),
                BASE_TableHeader_DDEF("CENTRE", width="33%"),
                BASE_TableHeader_DDEF("UPPER", width="34%"),
            ])),
            html_tbody([
                BASE_BuildLevelRow_DDEF(i, initial_rows[i], i <= active_count)
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
                BASE_TableHeader_DDEF("MIN LIMIT", width="33%"),
                BASE_TableHeader_DDEF("UNIT", width="34%"),
                BASE_TableHeader_DDEF("MAX LIMIT", width="33%"),
            ])),
            html_tbody([
                BASE_BuildLimitsRow_DDEF(i, initial_rows[i], i <= active_count)
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
        initial_rows = [DECK_GetDefaultRow_DDEF(i) for i in 1:DECK_MaxRows_DDEC]
        active_count = 7


        return dbc_container([
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
                                html_div([
                                        html_div([dcc_input(id="deck-mw-$i", type="number", value=0.0) for i in 1:DECK_MaxRows_DDEC]),
                                        html_div([dbc_select(id="deck-role-$i", options=DECK_RoleOptions_DDEC, value="Variable") for i in 1:DECK_MaxRows_DDEC]),
                                    ], style=Dict("display" => "none"))
                            ], style=Dict("display" => "none"))
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
                                                    dbc_col(DECK_BuildIdTable_DDEF(5:DECK_MaxRows_DDEC, initial_rows, active_count, true), lg=4, className="pe-lg-1"),
                                                    dbc_col(DECK_BuildLimitsTable_DDEF(5:DECK_MaxRows_DDEC, initial_rows, active_count), lg=4, className="px-lg-1"),
                                                    dbc_col(DECK_BuildLevelTable_DDEF(5:DECK_MaxRows_DDEC, initial_rows, active_count), lg=4, className="ps-lg-1")
                                                ], className="g-0"); right_node=dbc_button([html_i(className="fas fa-plus me-1"), "Add Row"], id="deck-btn-add-row", n_clicks=0, color="secondary", outline=true, size="sm", className="px-2 py-1 fw-bold"), panel_class="mb-4 h-100", content_class="p-2"), xs=12), className="mb-3"),

                                # Row 2: Response Metrics
                                dbc_row([
                                        dbc_col(BASE_GlassPanel_DDEF([html_i(className="fas fa-bullseye me-2"), "DEPENDENT VARIABLES", html_span(" — Declare the 3 fundamental analysis parameters to be thoroughly investigated.", className="ms-2 text-muted fw-normal", style=Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0"))],
                                                html_div(html_table([
                                                            html_thead(html_tr([
                                                                html_th("RESPONSE NAME", style=merge(BASE_StyleInlineHeader_DDEC, Dict("textAlign" => "center", "paddingLeft" => "5px", "width" => "40%")), className="p-0"),
                                                                BASE_TableHeader_DDEF("UNIT/METRIC", width="40%"),
                                                                BASE_TableHeader_DDEF("", width="20%")
                                                            ])),
                                                            html_tbody([DECK_BuildOutRow_DDEF(i, "", "-") for i in 1:3])
                                                        ], style=Dict("width" => "100%", "borderCollapse" => "collapse", "color" => "#000000", "fontSize" => "10px", "tableLayout" => "fixed")), className="table-responsive m-0 p-2");
                                                content_class="glass-content p-0", panel_class="h-100 mb-0"), lg=12),
                                    ], className="g-3 mb-3 d-flex align-items-stretch"),
                            ], xs=12, lg=9, className="mb-3 mb-lg-0"),

                        # --- RIGHT COLUMN ---
                        dbc_col(
                            BASE_GlassPanel_DDEF([html_i(className="fas fa-cogs me-2"), "SYSTEM CONFIGURATION"], [
                                    BASE_SidebarHeader_DDEF("DATA ACQUISITION", icon="fas fa-database"),
                                    BASE_Upload_DDEF("deck-upload", "Import Dataset", "fas fa-file-import"),
                                    BASE_Loading_DDEF("deck-upload-status", "No data source", class="glass-loading-status mb-2"),
                                    BASE_Separator_DDEF(),
                                    BASE_SidebarHeader_DDEF("PROFILES"),
                                    dbc_row([
                                            dbc_col(BASE_ActionButton_DDEF("deck-btn-save-memo", "Save", "fas fa-download", class="w-100 fw-bold"), xs=6, className="pe-1 mb-2"),
                                            dbc_col(dcc_upload(id="deck-upload-memo", children=BASE_ActionButton_DDEF("deck-upload-memo-btn", "Load", "fas fa-upload", class="w-100 fw-bold"), multiple=false, className="w-100"), xs=6, className="ps-1 mb-2"),
                                            dbc_col(BASE_ActionButton_DDEF("deck-btn-template", "Sample", "fas fa-eye", class="w-100 fw-bold"), xs=6, className="pe-1 mb-3"),
                                            dbc_col(BASE_ActionButton_DDEF("deck-btn-clear", "Clear", "fas fa-eraser", class="w-100 fw-bold"), xs=6, className="ps-1 mb-3"),
                                        ], className="g-0"),
                                    dbc_row(dbc_col(html_div(id="deck-memo-msg", className="small mb-2 fw-bold text-center"), xs=12)),
                                    BASE_ControlGroup_DDEF("Project Name",
                                        dbc_input(id="deck-input-project", type="text", value="",
                                            placeholder="Enter project name...", className="mb-2 form-control-sm", debounce=false)),
                                    BASE_ControlGroup_DDEF("Phase",
                                        dcc_dropdown(id="deck-dd-phase",
                                            options=[Dict("label" => "Phase 1", "value" => "Phase1")],
                                            value="Phase1", clearable=false, className="mb-3")),
                                    BASE_ControlGroup_DDEF("Design Method",
                                        dcc_dropdown(id="deck-dd-method",
                                            options=[
                                                Dict("label" => "Box-Behnken (15 Runs, Quadratic)", "value" => "BB15"),
                                                Dict("label" => "D-Optimal (15 Runs, Quadratic)", "value" => "DOPT15"),
                                                Dict("label" => "Taguchi L9 (9 Runs, Linear)", "value" => "TL09"),
                                                Dict("label" => "D-Optimal (9 Runs, Linear)", "value" => "DOPT09"),
                                            ],
                                            value="BB15", clearable=false, className="mb-3")),
                                    BASE_Separator_DDEF(),
                                    # Stoichiometry Settings Button
                                    BASE_ActionButton_DDEF("deck-btn-stoch-settings", "Stoichiometry Settings", "fas fa-flask", class="w-100 mb-2"),
                                    BASE_ActionButton_DDEF("deck-btn-audit", "Quick Audit", "fas fa-vial", class="w-100 mb-2"),
                                    BASE_ActionButton_DDEF("deck-btn-sci-audit", "Scientific Audit", "fas fa-microscope", class="w-100 mb-2"),
                                    BASE_Loading_DDEF("deck-run-output", ""),
                                    BASE_NextButton_DDEF("deck-btn-run", "Generate Protocol"),
                                ]; right_node=html_i(className="fas fa-sliders-h text-secondary"), panel_class="mb-3 h-auto"),
                            xs=12, lg=3),
                    ], className="g-3"),

                # Download components
                dcc_download(id="deck-download-xlsx"),
                dcc_download(id="deck-download-memo"),

                # Stoichiometry Settings Store
                dcc_store(id="deck-store-stoch-settings",
                    data=Dict("FillerName" => "", "FillerMW" => 0.0, "Volume" => 0.0, "Conc" => 0.0),
                    storage_type="memory"),
                dcc_store(id="deck-stoch-trigger-unit", data=0, storage_type="memory"),

                # Modals
                DECK_ModalChemical_DDEF(),
                DECK_ModalResponse_DDEF(),
                DECK_ModalStoch_DDEF(),
                DECK_ModalAudit_DDEF()
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
    C = Sys_Fast.FAST_Data_DDEC
    try
        D = Lib_Mole.MOLE_ParseTable_DDEF(BASE_SafeRows_DDEF(in_data))
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

            # 2b. Unit Validation Check
            unit = string(get(r, "Unit", ""))
            mw = Float64(get(r, "MW", 0.0))
            if mw > 0.0 && !isempty(unit) && unit != "-" && unit != "%M" && unit != "MR"
                ok_m, _, _ = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF(unit, "Mass")
                ok_c, _, _ = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF(unit, "Concentration")
                if !ok_m && !ok_c
                    return (false, "Unit Error: Ingredient '$n' has invalid chemical unit '$unit'.")
                end
            end

            # 2c. Strict Level Increase Rule (L1 < L2 < L3)
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
        output_data = BASE_SafeRows_DDEF(out_data)
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

        # 5b. Matrix Validation (Det-Check)
        valid_dsgn, dsgn_issues = Lib_Core.CORE_ValidateDesign_DDEF(real_matrix, configs)
        if !valid_dsgn
            return (false, "Validation Error: " * dsgn_issues)
        end

        d_eff = Lib_Core.CORE_D_Efficiency_DDEF(real_matrix)

        # 5c. Stoichiometric Feasibility Check
        valid_stoi, stoi_issues = Lib_Mole.MOLE_ValidateDesignFeasibility_DDEF(real_matrix, D["Rows"])
        if !valid_stoi
            return (false, "Stoichiometric Error: " * stoi_issues)
        end

        # 5d. Total Mass Audit
        run_masses = Lib_Mole.MOLE_AuditMatrix_DDEF(real_matrix, D["Names"][D["Idx_Chem"]], D["MWs"][D["Idx_Chem"]], Sys_Fast.FAST_SafeNum_DDEF(vol), Sys_Fast.FAST_SafeNum_DDEF(conc))
        if any(isnan, run_masses) || any(<(0.0), run_masses)
            return (false, "Mass Calculation Error: One or more runs resulted in invalid chemical mass. Please check your MW and Concentration values.")
        end

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
            "Global" => Dict("Volume" => sv, "Conc" => sc, "Method" => method, "FillerName" => f_name, "FillerMW" => f_mw, "DEfficiency" => d_eff),
            "Outputs" => output_data,
        )
        success = Sys_Fast.FAST_InitMaster_DDEF(path,
            [string(get(r, "Name", "")) for r in BASE_SafeRows_DDEF(in_data)],
            [string(get(r, "Name", "")) for r in output_data],
            df, ConfigDict)

        msg = success ? "Protocol successfully generated. (D-Efficiency: $(round(d_eff, digits=4)))" : "Master Initialization Failed"
        return (success, msg)
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
        [Output("deck-row-id-$i", "style") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-row-level-$i", "style") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-row-limits-$i", "style") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-name-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-role-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-l1-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-l2-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-l3-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-min-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-max-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-mw-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-unit-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        # Indicator dot styles (chemical + radioactive)
        [Output("deck-dot1-$i", "style") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-dot2-$i", "style") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-unit-$i", "style") for i in 1:DECK_MaxRows_DDEC]...,
        Input("deck-store-factors", "data")
    ) do stored
        isnothing(stored) && return ntuple(_ -> Dash.no_update(), 15 * DECK_MaxRows_DDEC)
        rows = get(stored, "rows", [])
        count = get(stored, "count", 0)


        # All rows are now table-rows (ID, Level, Limits all use html_table)
        out_styles = [Dict("display" => (i <= 4 || i <= count) ? "table-row" : "none") for i in 1:DECK_MaxRows_DDEC]
        out_names = [i <= length(rows) ? string(get(rows[i], "Name", "")) : "" for i in 1:DECK_MaxRows_DDEC]
        out_roles = [i <= length(rows) ? string(get(rows[i], "Role", (i <= 3 ? "Variable" : (i == 4 ? "Filler" : "Fixed")))) : (i <= 3 ? "Variable" : (i == 4 ? "Filler" : "Fixed")) for i in 1:DECK_MaxRows_DDEC]
        out_l1s = [i <= length(rows) ? get(rows[i], "L1", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_l2s = [i <= length(rows) ? get(rows[i], "L2", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_l3s = [i <= length(rows) ? get(rows[i], "L3", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_mins = [i <= length(rows) ? get(rows[i], "Min", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_maxs = [i <= length(rows) ? get(rows[i], "Max", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_mws = [i <= length(rows) ? get(rows[i], "MW", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_units = [i <= length(rows) ? string(get(rows[i], "Unit", "")) : "" for i in 1:DECK_MaxRows_DDEC]

        # Indicator dot colours: green when MW/HL > 0
        dot1_styles = [Dict("color" => (
                let r = (i <= length(rows) ? rows[i] : Dict())
                    Float64(get(r, "MW", get(r, :MW, 0.0))) > 0.0 ? "#5EC962" : "#2C2C2C"
                end
            ),
            "fontSize" => "0.45rem", "marginRight" => "1px") for i in 1:DECK_MaxRows_DDEC]
        dot2_styles = [Dict("color" => (
                let r = (i <= length(rows) ? rows[i] : Dict())
                    Float64(get(r, "HalfLife", get(r, :HalfLife, 0.0))) > 0.0 ? "#5EC962" : "#2C2C2C"
                end
            ),
            "fontSize" => "0.45rem", "marginRight" => "2px") for i in 1:DECK_MaxRows_DDEC]

        # Real-time unit validation styles
        unit_styles = [
            let
                s = merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px"))
                if i <= length(rows) && i <= count
                    u = string(get(rows[i], "Unit", ""))
                    mw = Float64(get(rows[i], "MW", 0.0))
                    if mw > 0.0 && !isempty(u) && u != "-" && u != "%M" && u != "MR"
                        ok_m, _, _ = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF(u, "Mass")
                        ok_c, _, _ = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF(u, "Concentration")
                        if !ok_m && !ok_c
                            s["color"] = "#FF0000"
                            s["fontWeight"] = "bold"
                            s["border"] = "1px solid #FF0000"
                        else
                            s["color"] = "#21918C"
                        end
                    end
                end
                s
            end for i in 1:DECK_MaxRows_DDEC
        ]

        return (out_styles..., out_styles..., out_styles..., out_names..., out_roles..., out_l1s..., out_l2s..., out_l3s..., out_mins..., out_maxs..., out_mws..., out_units..., dot1_styles..., dot2_styles..., unit_styles...)
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
        [Output("deck-out-name-$i", "value") for i in 1:3]...,
        [Output("deck-out-unit-$i", "value") for i in 1:3]...,
        Output("deck-store-stoch-settings", "data"),
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
        Input("deck-btn-stoch-save", "n_clicks"),
        # Delete buttons as Inputs
        [Input("deck-del-$i", "n_clicks") for i in 1:DECK_MaxRows_DDEC]...,
        # States
        State("deck-store-factors", "data"),
        State("deck-upload", "filename"),
        [State("deck-name-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-role-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l1-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l2-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l3-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-min-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-max-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-mw-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-unit-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        State("deck-input-vol", "value"),
        State("deck-input-conc", "value"),
        State("deck-prop-target-id", "data"),
        State("deck-prop-hl", "value"),
        State("deck-prop-hl-unit", "value"),
        State("deck-prop-mw", "value"),
        State("deck-store-stoch-settings", "data"),
        [State("deck-out-name-$i", "value") for i in 1:3]...,
        [State("deck-out-unit-$i", "value") for i in 1:3]...,
        State("deck-store-outputs", "data"),
        State("deck-stoch-filler-name", "value"),
        State("deck-stoch-filler-mw", "value"),
        State("deck-stoch-vol", "value"),
        State("deck-stoch-conc", "value"),
        State("deck-input-project", "value"),
        State("deck-dd-phase", "value"),
        prevent_initial_call=false
    ) do args...
        try  # Global error guard for main orchestrator callback
            # --- ARGUMENT MAPPING (LEGACY INDEXING) ---
            # 1..11: Core Action Triggers (Buttons, Stores, Uploads)
            # 12..35: Delete Button Triggers (ndels)
            # 36: Factor Store (store_data)
            # 37: Upload Filename (fname)
            # 38..253: Row States (9 parameters * 24 rows)
            # 254..255: Global Vol/Conc States
            # 256..259: Property Modal States (Target, IsRadio, HL, MW)
            # 260: Stoichiometry Settings Store
            # 261..266: Response Table Values (Names/Units)
            # 267: Response Store
            # 268..271: Stoichiometry Modal Inputs
            # 272..273: Project/Phase States

            n_add, n_clear, up_memo, n_temp, n_save, session, up_cont = args[1:7]
            save_prop_trig = args[8]
            stoch_trig = args[9]
            n_stoch_save = args[10]
            ndels = args[11:34]
            store_data = args[35]
            fname = args[36]

            offset = 13 + DECK_MaxRows_DDEC
            all_names = collect(args[offset:offset+DECK_MaxRows_DDEC-1])
            all_roles = collect(args[offset+DECK_MaxRows_DDEC:offset+2DECK_MaxRows_DDEC-1])
            all_l1s = collect(args[offset+2DECK_MaxRows_DDEC:offset+3DECK_MaxRows_DDEC-1])
            all_l2s = collect(args[offset+3DECK_MaxRows_DDEC:offset+4DECK_MaxRows_DDEC-1])
            all_l3s = collect(args[offset+4DECK_MaxRows_DDEC:offset+5DECK_MaxRows_DDEC-1])
            all_mins = collect(args[offset+5DECK_MaxRows_DDEC:offset+6DECK_MaxRows_DDEC-1])
            all_maxs = collect(args[offset+6DECK_MaxRows_DDEC:offset+7DECK_MaxRows_DDEC-1])
            all_mws = collect(args[offset+7DECK_MaxRows_DDEC:offset+8DECK_MaxRows_DDEC-1])
            all_units = collect(args[offset+8DECK_MaxRows_DDEC:offset+9DECK_MaxRows_DDEC-1])

            # RECENT FIX: Ensure Dash.callback_context() is used explicitly for stability
            ctx = Dash.callback_context()
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
                    return (ntuple(_ -> Dash.no_update(), 18)...,)
                end
            else
                trig = split(ctx.triggered[1].prop_id, ".")[1]
            end

            if trig != "" && trig != "sys-ready-poll"
                Sys_Fast.FAST_Log_DDEF("DECK", "Callback", "Triggered by: $trig", "INFO")
            end

            # --- 0. COMMON RETURN HELPER ---
            function DECK_Return_DDEF(store, table, ph_opts, vol, conc, proj, method, msg, dl, up_stat, ph_val, out_vals, stoch)
                # Strict arity check: we must return 18 items (11 + 6 + 1)
                return (store, table, ph_opts, vol, conc, proj, method, msg, dl, up_stat, ph_val, out_vals..., stoch)
            end
            RET_NO = ntuple(_ -> Dash.no_update(), 18)

            # Robust Key Access Helper: handles string or symbol keys and NEVER returns nothing if default is provided
            function DECK_GetSafeKey_DDEF(d, k, def)
                isnothing(d) && return def
                # Check string key
                v = get(d, string(k), nothing)
                !isnothing(v) && return v
                # Check symbol key
                v = get(d, Symbol(k), nothing)
                !isnothing(v) && return v
                return def
            end

            # --- 6. PROP SAVE LOGIC ---
            if trig == "deck-prop-trigger-save"
                isnothing(save_prop_trig) && return ntuple(_ -> Dash.no_update(), 18)
                isnothing(store_data) && return ntuple(_ -> Dash.no_update(), 18)

                # Modal States extraction (Corrected indices)
                target = args[255]
                hl_val = args[256]
                hl_unit = args[257]
                mw_modal = args[258]

                # Automatic Radioactive Check
                is_rad = !isnothing(hl_val) && Sys_Fast.FAST_SafeNum_DDEF(hl_val) > 0.0

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
                            new_r["IsRadioactive"] = is_rad
                            new_r["HalfLife"] = safe_hl
                            new_r["HalfLifeUnit"] = isnothing(hl_unit) ? "Hours" : string(hl_unit)
                            # is_filler is maintained only via Stoichiometry Settings or internal row state
                        end
                        push!(new_rows, new_r)
                    end
                    new_store = Dict{String,Any}()
                    for (k, v) in store_data
                        new_store[string(k)] = v
                    end
                    new_store["rows"] = new_rows

                    return (new_store, ntuple(_ -> Dash.no_update(), 17)...)
                end
                return ntuple(_ -> Dash.no_update(), 18)
            end

            # --- 6b. UNIT AUTO-LOGIC ---
            if trig == "deck-stoch-trigger-unit"
                isnothing(store_data) && return ntuple(_ -> Dash.no_update(), 18)
                stoch_data = args[259]  # deck-store-stoch-settings
                isnothing(stoch_data) && return ntuple(_ -> Dash.no_update(), 18)

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

                    return (new_store, ntuple(_ -> Dash.no_update(), 16)..., NO)
                end
                return ntuple(_ -> Dash.no_update(), 18)
            end

            NO = Dash.no_update()
            count = isnothing(store_data) ? 1 : DECK_GetSafeKey_DDEF(store_data, "count", 1)

            DECK_SafeNumZero_DDEF(x) = (v = Sys_Fast.FAST_SafeNum_DDEF(x); isnan(v) ? 0.0 : v)
            max_idx = min(count, length(all_names), length(all_roles), length(all_l1s), length(all_l2s), length(all_l3s), length(all_mins), length(all_maxs), length(all_mws), length(all_units))
            # Robust Data Capture Logic: trust DOM but sync with Store for properties
            DECK_SnapRows_DDEF() = [
                let
                    mw_val = DECK_SafeNumZero_DDEF(all_mws[i])
                    unit_val = !isnothing(all_units[i]) ? string(all_units[i]) : ""

                    is_rad = false
                    hl_val = 0.0
                    hl_unit = "Hours"
                    is_fill = false
                    prev_mw = 0.0

                    if !isnothing(store_data) && (haskey(store_data, "rows") || haskey(store_data, :rows))
                        r_list = DECK_GetSafeKey_DDEF(store_data, "rows", [])
                        if i <= length(r_list)
                            prow = r_list[i]
                            # Use system safe num to avoid Float64(nothing) errors
                            pmw = DECK_GetSafeKey_DDEF(prow, "MW", 0.0)
                            prev_mw = Sys_Fast.FAST_SafeNum_DDEF(pmw)

                            # If stored MW exists, it usually means a property modal was saved; trust it.
                            mw_val = prev_mw > 0.0 ? prev_mw : mw_val

                            is_rad = Bool(DECK_GetSafeKey_DDEF(prow, "IsRadioactive", false))
                            hl_val = Sys_Fast.FAST_SafeNum_DDEF(DECK_GetSafeKey_DDEF(prow, "HalfLife", 0.0))
                            hl_unit = string(DECK_GetSafeKey_DDEF(prow, "HalfLifeUnit", "Hours"))
                            is_fill = Bool(DECK_GetSafeKey_DDEF(prow, "IsFiller", false))
                        end
                    end

                    # Auto-assign unit if MW becomes defined
                    if mw_val > 0.0 && prev_mw <= 0.0
                        if isempty(strip(unit_val)) || unit_val == "-"
                            unit_val = "%M"
                        end
                    end

                    Dict(
                        "Name" => !isnothing(all_names[i]) ? string(all_names[i]) : "",
                        "Role" => !isnothing(all_roles[i]) ? string(all_roles[i]) : "Variable",
                        "L1" => DECK_SafeNumZero_DDEF(all_l1s[i]),
                        "L2" => DECK_SafeNumZero_DDEF(all_l2s[i]),
                        "L3" => DECK_SafeNumZero_DDEF(all_l3s[i]),
                        "Min" => DECK_SafeNumZero_DDEF(all_mins[i]),
                        "Max" => DECK_SafeNumZero_DDEF(all_maxs[i]),
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
            del_ids = ["deck-del-$i" for i in 1:DECK_MaxRows_DDEC]
            if trig in del_ids
                rows = DECK_SnapRows_DDEF()
                ri = findfirst(==(trig), del_ids)
                if ri !== nothing && ri <= length(rows) && ri > 4
                    deleteat!(rows, ri)
                end
                nc = max(4, length(rows))
                return DECK_Return_DDEF(Dict("rows" => rows, "count" => nc), rows, NO, NO, NO, NO, NO, NO, NO, NO, NO, fill(NO, 6), NO)
            end

            # --- B. ADD ROW ---
            if trig == "deck-btn-add-row"
                rows = DECK_SnapRows_DDEF()
                current_count = isnothing(store_data) ? length(rows) : get(store_data, "count", get(store_data, :count, length(rows)))
                new_count = min(current_count + 1, DECK_MaxRows_DDEC)
                if new_count > current_count
                    new_row = DECK_GetDefaultRow_DDEF(new_count)
                    new_row["Role"] = "Fixed"
                    push!(rows, new_row)
                else
                    new_count = current_count # Cap at MaxRows
                end
                return DECK_Return_DDEF(Dict("rows" => rows, "count" => new_count), rows, NO, NO, NO, NO, NO, NO, NO, NO, NO, fill(NO, 6), NO)

                # --- C0. CLEAR CANVAS ---
            elseif trig == "deck-btn-clear"
                # Reset to 3 Variables + 1 Filler + 3 Constants (Total 7 active rows)
                rows = [DECK_GetDefaultRow_DDEF(i) for i in 1:7]
                lbl = html_div([html_i(className="fas fa-trash-alt me-2"), "Canvas Cleared"],
                    className="badge bg-danger text-white p-2 w-100", style=Dict("fontSize" => "0.85rem"))
                empty_stoch = Dict("FillerName" => "", "FillerMW" => 0.0, "Volume" => 0.0, "Conc" => 0.0)
                return DECK_Return_DDEF(Dict("rows" => rows, "count" => 7), rows, [Dict("label" => "Phase 1", "value" => "Phase1")], 0.0, 0.0, "", "BoxBehnken", lbl, NO, "No data source", "Phase1",
                    vcat(["", "", ""], ["-", "-", "-"]), empty_stoch)

                # --- C1. LOAD USER PROFILE ---
            elseif trig == "deck-upload-memo" && !isnothing(up_memo) && up_memo != ""
                try
                    base64_data = split(up_memo, ",")[end]
                    json_str = String(base64decode(base64_data))
                    memo = JSON3.read(json_str)
                    loaded_rows = map(DECK_GetSafeKey_DDEF(memo, "Inputs", [])) do m
                        Dict("Name" => DECK_GetSafeKey_DDEF(m, "Name", ""), "Role" => DECK_GetSafeKey_DDEF(m, "Role", "Variable"),
                            "L1" => DECK_GetSafeKey_DDEF(m, "L1", 0.0), "L2" => DECK_GetSafeKey_DDEF(m, "L2", 0.0),
                            "L3" => DECK_GetSafeKey_DDEF(m, "L3", 0.0), "Min" => DECK_GetSafeKey_DDEF(m, "Min", 0.0),
                            "Max" => DECK_GetSafeKey_DDEF(m, "Max", 0.0), "MW" => DECK_GetSafeKey_DDEF(m, "MW", 0.0),
                            "Unit" => DECK_GetSafeKey_DDEF(m, "Unit", "-"),
                            "IsRadioactive" => DECK_GetSafeKey_DDEF(m, "IsRadioactive", false),
                            "HalfLife" => Float64(DECK_GetSafeKey_DDEF(m, "HalfLife", 0.0)),
                            "HalfLifeUnit" => string(DECK_GetSafeKey_DDEF(m, "HalfLifeUnit", "Hours")),
                            "IsFiller" => DECK_GetSafeKey_DDEF(m, "IsFiller", false))
                    end
                    lbl = html_div([html_i(className="fas fa-folder-open me-2"), "Memory Loaded"],
                        className="badge bg-info text-white p-2 w-100", style=Dict("fontSize" => "0.85rem"))
                    nc = min(length(loaded_rows), DECK_MaxRows_DDEC)

                    g = get(memo, "Global", Dict())
                    vol_v = get(g, "Volume", 0.0)
                    conc_v = get(g, "Conc", 0.0)
                    loaded_stoch = Dict(
                        "FillerName" => string(get(g, "FillerName", "")),
                        "FillerMW" => Float64(get(g, "FillerMW", 0.0)),
                        "Volume" => Float64(vol_v),
                        "Conc" => Float64(conc_v)
                    )

                    memo_outs = get(memo, "Outputs", [])
                    out_vals = vcat(
                        [i <= length(memo_outs) ? get(memo_outs[i], "Name", "") : "" for i in 1:3],
                        [i <= length(memo_outs) ? get(memo_outs[i], "Unit", "-") : "-" for i in 1:3]
                    )

                    return DECK_Return_DDEF(Dict("rows" => loaded_rows[1:nc], "count" => nc), loaded_rows[1:nc], NO, vol_v, conc_v, NO, NO, lbl, NO, NO, NO, out_vals, loaded_stoch)
                catch e
                    err_lbl = html_div("❌ Load Error: $e", className="badge bg-danger text-white w-100 p-2")
                    return DECK_Return_DDEF(NO, NO, NO, NO, NO, NO, NO, err_lbl, NO, NO, NO, fill(NO, 6), NO)
                end

                # --- C2. LOAD TEMPLATE ---
            elseif trig == "deck-btn-template"
                loaded_rows = [
                    Dict("Name" => "Chol", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "Min" => 0.0, "Max" => 40.0, "MW" => 386.65, "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours", "IsFiller" => false),
                    Dict("Name" => "PEG", "Role" => "Variable", "L1" => 1.0, "L2" => 3.0, "L3" => 5.0, "Min" => 0.0, "Max" => 10.0, "MW" => 2808.74, "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours", "IsFiller" => false),
                    Dict("Name" => "Temperature", "Role" => "Variable", "L1" => 25.0, "L2" => 45.0, "L3" => 65.0, "Min" => 25.0, "Max" => 100.0, "MW" => 0.0, "Unit" => "°C", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours", "IsFiller" => false),
                    Dict("Name" => "DPPC", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0, "MW" => 734.05, "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours", "IsFiller" => true),
                    Dict("Name" => "DOTA", "Role" => "Fixed", "L1" => 0.0, "L2" => 1.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0, "MW" => 3184.84, "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours", "IsFiller" => false),
                ]
                lbl = html_div([html_i(className="fas fa-book-medical me-2"), "Template Applied"],
                    className="badge bg-primary text-white p-2 w-100", style=Dict("fontSize" => "0.85rem", "boxShadow" => "0 2px 5px #A6A6A6"))
                sample_stoch = Dict("FillerName" => "DPPC", "FillerMW" => 734.05, "Volume" => 5.0, "Conc" => 20.0)
                nc = min(length(loaded_rows), DECK_MaxRows_DDEC)
                def_outs = Sys_Fast.FAST_GetLabDefaults_DDEF()["Outputs"]
                out_vals = vcat(
                    [i <= length(def_outs) ? def_outs[i]["Name"] : "" for i in 1:3],
                    [i <= length(def_outs) ? def_outs[i]["Unit"] : "-" for i in 1:3]
                )

                return DECK_Return_DDEF(Dict("rows" => loaded_rows[1:nc], "count" => nc), loaded_rows[1:nc], [Dict("label" => "Phase 1", "value" => "Phase1")], 5.0, 20.0, "Sample_Project", "BoxBehnken", lbl, NO, "Ready", "Phase1", out_vals, sample_stoch)

                # --- D. SAVE PROFILE ---

                # --- D. SAVE PROFILE ---
            elseif trig == "deck-btn-save-memo"
                try
                    stoch_store = args[259]
                    vol_v = isnothing(stoch_store) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(get(stoch_store, "Volume", get(stoch_store, :Volume, 0.0)))
                    conc_v = isnothing(stoch_store) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(get(stoch_store, "Conc", get(stoch_store, :Conc, 0.0)))
                    g_dict = Dict{String,Any}("Volume" => vol_v, "Conc" => conc_v)
                    if !isnothing(stoch_store) && (haskey(stoch_store, "FillerName") || haskey(stoch_store, :FillerName))
                        g_dict["FillerName"] = string(get(stoch_store, "FillerName", get(stoch_store, :FillerName, "")))
                        g_dict["FillerMW"] = Sys_Fast.FAST_SafeNum_DDEF(get(stoch_store, "FillerMW", get(stoch_store, :FillerMW, 0.0)))
                    end

                    out_names = collect(args[260:262])
                    out_units = collect(args[263:265])
                    store_out = args[266]
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

                    json_str = JSON3.write(Dict("Inputs" => DECK_SnapRows_DDEF(), "Outputs" => out_d, "Global" => g_dict))
                    b64 = base64encode(json_str)

                    # Correctly capture Project and Phase for smart naming in JSON export
                    proj_v = string(args[271])
                    phase_v = string(args[272])
                    fname = Sys_Fast.FAST_GenerateSmartName_DDEF(proj_v, phase_v, "WS")
                    fname = replace(fname, ".xlsx" => ".json")

                    dl_dict = Dict("filename" => fname, "content" => b64, "base64" => true)
                    lbl = html_div([html_i(className="fas fa-check-circle me-2"), "Workspace Exported"],
                        className="badge bg-success text-white p-2 w-100", style=Dict("fontSize" => "0.85rem", "boxShadow" => "0 2px 5px #A6A6A6"))
                    return DECK_Return_DDEF(NO, NO, NO, NO, NO, NO, NO, lbl, dl_dict, NO, NO, fill(NO, 6), NO)
                catch e
                    err_lbl = html_div("❌ Save Error: " * string(e), className="badge bg-danger text-white w-100 p-2", style=Dict("fontSize" => "0.6rem"))
                    return DECK_Return_DDEF(NO, NO, NO, NO, NO, NO, NO, err_lbl, NO, NO, NO, fill(NO, 6), NO)
                end

                # --- C3. SAVE STOICHIOMETRY ---
            elseif trig == "deck-btn-stoch-save"
                # Extraction Modal Values from args (indices verified)

                # Extract Modal Values from args (indices verified)
                f_name_modal = args[267]
                f_mw_modal = args[268]
                s_vol_modal = args[269]
                s_conc_modal = args[270]

                new_stoch = Dict(
                    "FillerName" => isnothing(f_name_modal) ? "" : strip(string(f_name_modal)),
                    "FillerMW" => isnothing(f_mw_modal) ? 0.0 : DECK_SafeNumZero_DDEF(f_mw_modal),
                    "Volume" => isnothing(s_vol_modal) ? 0.0 : DECK_SafeNumZero_DDEF(s_vol_modal),
                    "Conc" => isnothing(s_conc_modal) ? 0.0 : DECK_SafeNumZero_DDEF(s_conc_modal),
                )

                # Apply Unit Auto-Logic and Filler Sync to the factor store
                new_store = NO
                if !isnothing(store_data)
                    f_name = new_stoch["FillerName"]
                    f_mw = new_stoch["FillerMW"]
                    has_f = !isempty(f_name) && f_mw > 0.0
                    has_e = new_stoch["Volume"] > 0.0 && new_stoch["Conc"] > 0.0

                    # Determine target unit based on user rule: Filler+Vol+Conc -> %M, Vol+Conc -> MR
                    t_unit = has_f ? "%M" : (has_e ? "MR" : NO)

                    new_rows = []
                    for r in store_data["rows"]
                        nr = Dict{String,Any}(string(k) => v for (k, v) in r)
                        # Switch unit if it's a chemical component (MW > 0)
                        if t_unit != NO && Float64(get(nr, "MW", 0.0)) > 0.0
                            nr["Unit"] = t_unit
                        end
                        # Strict Filler Synchronization
                        if has_f && string(get(nr, "Name", "")) == f_name
                            nr["IsFiller"] = true
                            nr["MW"] = f_mw
                            nr["Role"] = "Filler"
                            nr["Unit"] = "%M"
                        end
                        push!(new_rows, nr)
                    end
                    new_store = Dict{String,Any}("rows" => new_rows, "count" => get(store_data, "count", length(new_rows)))
                end

                # Update store, hidden vol/conc inputs, and stoch store
                return DECK_Return_DDEF(new_store, NO, NO, new_stoch["Volume"], new_stoch["Conc"], NO, NO, NO, NO, NO, NO, fill(NO, 6), new_stoch)

                # --- F. IMPORT PROTOCOL ---
            elseif trig == "deck-upload" && !isnothing(up_cont)
                try
                    if up_cont == ""
                        rows = [DECK_GetDefaultRow_DDEF(i) for i in 1:5]
                        return DECK_Return_DDEF(Dict("rows" => rows, "count" => 5), rows, [Dict("label" => "Loading...", "value" => "NONE")], 0.0, 0.0, "", "BoxBehnken", NO, NO, "No data source", "NONE", fill(NO, 6), NO)
                    end
                    tmp = Sys_Fast.FAST_GetTransientPath_DDEF(up_cont)
                    cfg = Sys_Fast.FAST_ReadConfig_DDEF(tmp)
                    rm(tmp; force=true)
                    if !isempty(cfg) && haskey(cfg, "Ingredients") || haskey(cfg, :Ingredients)
                        g = DECK_GetSafeKey_DDEF(cfg, "Global", Dict())
                        mapped = map(DECK_GetSafeKey_DDEF(cfg, "Ingredients", [])) do itm
                            Dict("Name" => DECK_GetSafeKey_DDEF(itm, "Name", ""), "Role" => DECK_GetSafeKey_DDEF(itm, "Role", "Variable"),
                                "L1" => DECK_GetSafeKey_DDEF(itm, "L1", 0.0), "L2" => DECK_GetSafeKey_DDEF(itm, "L2", 0.0),
                                "L3" => DECK_GetSafeKey_DDEF(itm, "L3", 0.0), "Min" => DECK_GetSafeKey_DDEF(itm, "Min", 0.0), "Max" => DECK_GetSafeKey_DDEF(itm, "Max", 0.0), "MW" => DECK_GetSafeKey_DDEF(itm, "MW", 0.0),
                                "Unit" => DECK_GetSafeKey_DDEF(itm, "Unit", "-"),
                                "IsRadioactive" => DECK_GetSafeKey_DDEF(itm, "IsRadioactive", false),
                                "HalfLife" => Float64(DECK_GetSafeKey_DDEF(itm, "HalfLife", 0.0)),
                                "HalfLifeUnit" => string(DECK_GetSafeKey_DDEF(itm, "HalfLifeUnit", "Hours")),
                                "IsFiller" => DECK_GetSafeKey_DDEF(itm, "IsFiller", false))
                        end
                        nc = min(length(mapped), DECK_MaxRows_DDEC)
                        method_val = get(g, "Method", "BoxBehnken")
                        outs = get(cfg, "Outputs", [])
                        out_vals = vcat(
                            [i <= length(outs) ? get(outs[i], "Name", "") : "" for i in 1:3],
                            [i <= length(outs) ? get(outs[i], "Unit", "-") : "-" for i in 1:3]
                        )
                        stat_msg = html_span("✅ Sync: $(length(fname) > 15 ? fname[1:15]*"..." : fname)", className="text-success small fw-bold")
                        ph_opts = [Dict("label" => "Phase 1 Initiated", "value" => "Phase1")]

                        loaded_stoch = Dict(
                            "FillerName" => string(get(g, "FillerName", "")),
                            "FillerMW" => Float64(get(g, "FillerMW", 0.0)),
                            "Volume" => Float64(get(g, "Volume", 0.0)),
                            "Conc" => Float64(get(g, "Conc", 0.0))
                        )

                        return DECK_Return_DDEF(Dict("rows" => mapped[1:nc], "count" => nc), mapped[1:nc], ph_opts,
                            get(g, "Volume", 0.0), get(g, "Conc", 0.0), NO, method_val, NO, NO, stat_msg, "Phase1", out_vals, loaded_stoch)
                    end
                catch e
                    @error "Import failed" exception = (e, catch_backtrace())
                    return DECK_Return_DDEF(NO, NO, NO, NO, NO, NO, NO, html_div("❌ Import Failed: $e", className="badge bg-danger text-white w-100 p-2"), NO, NO, NO, fill(NO, 6), NO)
                end
            end

            if trig == "deck-upload" && (isnothing(up_cont) || up_cont == "")
                return DECK_Return_DDEF(NO, NO, [Dict("label" => "Loading...", "value" => "NONE")], NO, NO, NO, NO, NO, NO, "No data source", "NONE", fill(NO, 6), NO)
            end

            return (ntuple(_ -> Dash.no_update(), 18)...,)

        catch e  # Catch-all: surface error to UI instead of silent death
            bt = sprint(showerror, e, catch_backtrace())
            println("\e[31m[CRITICAL] DECK ORCHESTRATOR ERROR: $e\e[0m")
            println(bt)
            Sys_Fast.FAST_Log_DDEF("DECK", "CALLBACK_CRASH", "Exception: $(first(string(e), 200))", "FAIL")

            err_msg = html_div([
                    html_i(className="fas fa-exclamation-triangle me-2"),
                    html_span("Design Orchestrator Error: $(first(string(e), 60))", className="fw-bold")
                ], className="badge bg-danger text-white w-100 p-2 shadow-sm", style=Dict("fontSize" => "0.75rem"))

            return (Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(),
                Dash.no_update(), Dash.no_update(), err_msg, Dash.no_update(), Dash.no_update(),
                Dash.no_update(), ntuple(_ -> Dash.no_update(), 6)..., Dash.no_update())
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
        [State("deck-name-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-role-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l1-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l2-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l3-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-min-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-max-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-mw-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-unit-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        prevent_initial_call=true
    ) do args...
        try  # Error guard for audit callback
            n_op, n_cl, is_op, store_data, vol, conc = args[1:6]
            offset = 7
            all_names = collect(args[offset:offset+DECK_MaxRows_DDEC-1])
            all_roles = collect(args[offset+DECK_MaxRows_DDEC:offset+2DECK_MaxRows_DDEC-1])
            all_l1s = collect(args[offset+2DECK_MaxRows_DDEC:offset+3DECK_MaxRows_DDEC-1])
            all_l2s = collect(args[offset+3DECK_MaxRows_DDEC:offset+4DECK_MaxRows_DDEC-1])
            all_l3s = collect(args[offset+4DECK_MaxRows_DDEC:offset+5DECK_MaxRows_DDEC-1])
            all_mins = collect(args[offset+5DECK_MaxRows_DDEC:offset+6DECK_MaxRows_DDEC-1])
            all_maxs = collect(args[offset+6DECK_MaxRows_DDEC:offset+7DECK_MaxRows_DDEC-1])
            all_mws = collect(args[offset+7DECK_MaxRows_DDEC:offset+8DECK_MaxRows_DDEC-1])
            all_units = collect(args[offset+8DECK_MaxRows_DDEC:offset+9DECK_MaxRows_DDEC-1])

            ctx = callback_context()
            trig = isempty(ctx.triggered) ? "" : split(ctx.triggered[1].prop_id, ".")[1]
            trig == "deck-btn-audit-close" && return Dash.no_update(), false
            trig != "deck-btn-audit" && return Dash.no_update(), is_op

            DECK_SafeNumZero_DDEF(x) = (v = Sys_Fast.FAST_SafeNum_DDEF(x); isnan(v) ? 0.0 : v)
            count = isnothing(store_data) ? 1 : get(store_data, "count", 1)
            rows = Dict{String,Any}[]
            for i in 1:count
                name = isnothing(all_names[i]) ? "" : strip(string(all_names[i]))
                minval = DECK_SafeNumZero_DDEF(all_mins[i])
                maxval = DECK_SafeNumZero_DDEF(all_maxs[i])
                l1val = DECK_SafeNumZero_DDEF(all_l1s[i])
                l2val = DECK_SafeNumZero_DDEF(all_l2s[i])
                l3val = DECK_SafeNumZero_DDEF(all_l3s[i])

                if i <= 3
                    mv_raw = Sys_Fast.FAST_SafeNum_DDEF(all_mins[i])
                    xv_raw = Sys_Fast.FAST_SafeNum_DDEF(all_maxs[i])
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
                    "MW" => DECK_SafeNumZero_DDEF(all_mws[i]),
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
        [State("deck-name-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-role-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l1-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l2-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l3-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-min-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-max-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-mw-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-unit-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        prevent_initial_call=true
    ) do args...
        try  # Error guard for protocol generation callback
            n, project = args[1:2]
            out_names = collect(args[3:5])
            out_units = collect(args[6:8])
            vol, conc, method, session_data, store_data, master_vault, store_out = args[9:15]
            (n === nothing || n == 0) && return Dash.no_update(), "", Dash.no_update()

            offset = 16
            all_names = collect(args[offset:offset+DECK_MaxRows_DDEC-1])
            all_roles = collect(args[offset+DECK_MaxRows_DDEC:offset+2DECK_MaxRows_DDEC-1])

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
            all_l1s = collect(args[offset+2DECK_MaxRows_DDEC:offset+3DECK_MaxRows_DDEC-1])
            all_l2s = collect(args[offset+3DECK_MaxRows_DDEC:offset+4DECK_MaxRows_DDEC-1])
            all_l3s = collect(args[offset+4DECK_MaxRows_DDEC:offset+5DECK_MaxRows_DDEC-1])
            all_mins = collect(args[offset+5DECK_MaxRows_DDEC:offset+6DECK_MaxRows_DDEC-1])
            all_maxs = collect(args[offset+6DECK_MaxRows_DDEC:offset+7DECK_MaxRows_DDEC-1])
            all_mws = collect(args[offset+7DECK_MaxRows_DDEC:offset+8DECK_MaxRows_DDEC-1])
            all_units = collect(args[offset+8DECK_MaxRows_DDEC:offset+9DECK_MaxRows_DDEC-1])

            DECK_SafeNumZero_DDEF(x) = (v = Sys_Fast.FAST_SafeNum_DDEF(x); isnan(v) ? 0.0 : v)
            count = isnothing(store_data) ? 1 : get(store_data, "count", 1)
            in_d = Dict{String,Any}[]
            for i in 1:count
                name = isnothing(all_names[i]) ? "" : strip(string(all_names[i]))
                minval = DECK_SafeNumZero_DDEF(all_mins[i])
                maxval = DECK_SafeNumZero_DDEF(all_maxs[i])
                l1val = DECK_SafeNumZero_DDEF(all_l1s[i])
                l2val = DECK_SafeNumZero_DDEF(all_l2s[i])
                l3val = DECK_SafeNumZero_DDEF(all_l3s[i])

                if i <= 3
                    mv_raw = Sys_Fast.FAST_SafeNum_DDEF(all_mins[i])
                    xv_raw = Sys_Fast.FAST_SafeNum_DDEF(all_maxs[i])
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
                    "MW" => DECK_SafeNumZero_DDEF(all_mws[i]),
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

    # --- 5. INPUT PROPERTIES MODAL ---
    callback!(app,
        Output("deck-modal-prop", "is_open"),
        Output("deck-prop-title", "children"),
        Output("deck-prop-target-id", "data"),
        Output("deck-prop-hl", "value"),
        Output("deck-prop-hl-unit", "value"),
        Output("deck-prop-trigger-save", "data"),
        Output("deck-prop-mw", "value"),
        Input("btn-prop-cancel", "n_clicks"),
        Input("btn-prop-save", "n_clicks"),
        [Input("btn-prop-$i", "n_clicks") for i in 1:DECK_MaxRows_DDEC]...,
        State("deck-store-factors", "data"),
        prevent_initial_call=true
    ) do args...

        ctx = callback_context()
        isempty(ctx.triggered) && return (ntuple(_ -> Dash.no_update(), 9)...,)
        trig = split(ctx.triggered[1].prop_id, ".")[1]

        if trig == "btn-prop-cancel"
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update()
        end

        if trig == "btn-prop-save"
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), (randn()), Dash.no_update()
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

            return true, title, Dict("type" => "in", "index" => idx), hl_state, hlu_state, Dash.no_update(), mw_state
        end

        return (ntuple(_ -> Dash.no_update(), 9)...,)
    end

    # --- 6. RESPONSE PROPERTIES MODAL ---
    callback!(app,
        Output("deck-modal-out-prop", "is_open"),
        Output("deck-out-prop-title", "children"),
        Output("deck-out-prop-target-id", "data"),
        Output("deck-store-outputs", "data"),
        Output("deck-out-prop-confirm", "value"),
        Input("deck-upload", "contents"),
        Input("store-session-config", "data"),
        Input("deck-upload-memo", "contents"),
        Input("btn-out-prop-cancel", "n_clicks"),
        Input("btn-out-prop-save", "n_clicks"),
        [Input("btn-out-prop-$i", "n_clicks") for i in 1:3]...,
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
                return (ntuple(_ -> Dash.no_update(), 5)...,)
            end
        else
            trig = split(ctx.triggered[1].prop_id, ".")[1]
        end

        store_out = args[4]
        target_data = args[5]
        s_confirm = args[6]

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
                    return false, Dash.no_update(), Dash.no_update(), new_store_out, ""
                end
            catch
            end
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
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
                    return false, Dash.no_update(), Dash.no_update(), new_store_out, ""
                end
            catch
            end
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
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
                    return false, Dash.no_update(), Dash.no_update(), new_store_out, ""
                end
            catch
            end
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
        end

        if trig == "btn-out-prop-cancel"
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
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
                        new_r["IsCorr"] = !isnothing(s_confirm) && uppercase(strip(string(s_confirm))) == "YES"
                        new_r["IsRadioactive"] = new_r["IsCorr"] # Sync both for internal logic
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

                return false, Dash.no_update(), Dash.no_update(), new_store_out, ""
            end
            return false, Dash.no_update(), Dash.no_update(), Dash.no_update(), ""
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
                    prow = r_list[idx]
                    corr_state = get(prow, "IsRadioactive", get(prow, :IsRadioactive, get(prow, "IsCorr", get(prow, :IsCorr, false))))
                    confirm_val = corr_state ? "YES" : ""
                end
            end

            return true, title, Dict("index" => idx), Dash.no_update(), confirm_val
        end

        return (ntuple(_ -> Dash.no_update(), 5)...,)
    end

    # --- 7. STOICHIOMETRY SETTINGS MODAL ---
    callback!(app,
        Output("deck-modal-stoch-settings", "is_open"),
        Output("deck-stoch-filler-name", "value"),
        Output("deck-stoch-filler-mw", "value"),
        Output("deck-stoch-vol", "value"),
        Output("deck-stoch-conc", "value"),
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
        isempty(ctx.triggered) && return (ntuple(_ -> NO, 6)...,)
        trig = split(ctx.triggered[1].prop_id, ".")[1]

        if trig == "deck-btn-stoch-settings"
            # Open modal and populate from store
            if !isnothing(store_data)
                return true,
                string(get(store_data, "FillerName", get(store_data, :FillerName, ""))),
                Sys_Fast.FAST_SafeNum_DDEF(get(store_data, "FillerMW", get(store_data, :FillerMW, 0.0))),
                Sys_Fast.FAST_SafeNum_DDEF(get(store_data, "Volume", get(store_data, :Volume, 0.0))),
                Sys_Fast.FAST_SafeNum_DDEF(get(store_data, "Conc", get(store_data, :Conc, 0.0)))
            end
            return true, "", 0.0, 0.0, 0.0
        end

        if trig == "deck-btn-stoch-cancel"
            return false, NO, NO, NO, NO
        end

        # Template auto-fills the stoichiometry modal with sample data
        if trig == "deck-btn-template"
            return false, "DPPC", 734.05, 5.0, 20.0
        end
        # Clear button resets stoichiometry store
        if trig == "deck-btn-clear"
            return false, "", 0.0, 0.0, 0.0
        end

        # Load from Memo / Uploaded Protocol (Handled by Orchestrator)
        if trig in ("deck-upload-memo", "deck-upload")
            return false, NO, NO, NO, NO
        end

        if trig == "deck-btn-stoch-save"
            return false, NO, NO, NO, NO
        end

        return (ntuple(_ -> NO, 5)...,)
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

    # --- 9. DETAILED SCIENTIFIC AUDIT MODAL ---
    callback!(app,
        Output("deck-sci-audit-output", "children"),
        Output("deck-modal-sci-audit", "is_open"),
        Input("deck-btn-sci-audit", "n_clicks"),
        Input("deck-btn-sci-audit-close", "n_clicks"),
        State("deck-modal-sci-audit", "is_open"),
        State("deck-dd-method", "value"),
        State("deck-input-vol", "value"),
        State("deck-input-conc", "value"),
        State("deck-store-factors", "data"),
        [State("deck-name-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-role-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l1-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l2-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l3-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-min-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-max-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-mw-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-unit-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        prevent_initial_call=true
    ) do args...
        try
            n_op, n_cl, is_op, method, vol, conc, store_data = args[1:7]
            ctx = callback_context()
            trig = isempty(ctx.triggered) ? "" : split(ctx.triggered[1].prop_id, ".")[1]
            trig == "deck-btn-sci-audit-close" && return Dash.no_update(), false
            trig != "deck-btn-sci-audit" && return Dash.no_update(), is_op

            # Unpack factors
            offset = 8
            all_names = collect(args[offset:offset+DECK_MaxRows_DDEC-1])
            all_roles = collect(args[offset+DECK_MaxRows_DDEC:offset+2DECK_MaxRows_DDEC-1])
            all_l1s = collect(args[offset+2DECK_MaxRows_DDEC:offset+3DECK_MaxRows_DDEC-1])
            all_l2s = collect(args[offset+3DECK_MaxRows_DDEC:offset+4DECK_MaxRows_DDEC-1])
            all_l3s = collect(args[offset+4DECK_MaxRows_DDEC:offset+5DECK_MaxRows_DDEC-1])
            all_mws = collect(args[offset+7DECK_MaxRows_DDEC:offset+8DECK_MaxRows_DDEC-1])
            all_units = collect(args[offset+8DECK_MaxRows_DDEC:offset+9DECK_MaxRows_DDEC-1])

            count = isnothing(store_data) ? 1 : get(store_data, "count", 1)
            rows = Dict{String,Any}[]
            for i in 1:count
                name = isnothing(all_names[i]) ? "" : strip(string(all_names[i]))
                if i > 3 && isempty(name)
                    continue
                end
                push!(rows, Dict(
                    "Name" => name,
                    "Role" => isnothing(all_roles[i]) ? (i <= 3 ? "Variable" : (i == 4 ? "Filler" : "Fixed")) : string(all_roles[i]),
                    "L1" => Sys_Fast.FAST_SafeNum_DDEF(all_l1s[i]),
                    "L2" => Sys_Fast.FAST_SafeNum_DDEF(all_l2s[i]),
                    "L3" => Sys_Fast.FAST_SafeNum_DDEF(all_l3s[i]),
                    "MW" => Sys_Fast.FAST_SafeNum_DDEF(all_mws[i]),
                    "Unit" => isnothing(all_units[i]) ? "" : string(all_units[i]),
                ))
            end

            D = Lib_Mole.MOLE_ParseTable_DDEF(rows)
            num_vars = length(D["Idx_Var"])
            num_vars != 3 && return html_div("Protocol requires exactly 3 Variables. Detection: $num_vars", className="text-danger fw-bold"), true

            # Generate virtual design for audit
            design_coded = Lib_Core.CORE_GenDesign_DDEF(method, 3)
            configs = [Dict("Levels" => [D["Rows"][i]["L1"], D["Rows"][i]["L2"], D["Rows"][i]["L3"]]) for i in D["Idx_Var"]]
            real_matrix = Lib_Core.CORE_MapLevels_DDEF(design_coded, configs)

            # 1. Mathematical Health
            d_eff = Lib_Core.CORE_D_Efficiency_DDEF(real_matrix)
            metrics = Lib_Core.CORE_CalcDesignMetrics_DDEF(real_matrix)

            # 2. Stoichiometry Feasibility (Full Matrix)
            valid_stoi, stoi_issues = Lib_Mole.MOLE_ValidateDesignFeasibility_DDEF(real_matrix, D["Rows"])

            # 3. Mass Audit (Full Matrix)
            masses = Lib_Mole.MOLE_AuditMatrix_DDEF(real_matrix, D["Names"][D["Idx_Chem"]], D["MWs"][D["Idx_Chem"]], Sys_Fast.FAST_SafeNum_DDEF(vol), Sys_Fast.FAST_SafeNum_DDEF(conc))
            min_mass = isempty(masses) ? 0.0 : minimum(masses)
            max_mass = isempty(masses) ? 0.0 : maximum(masses)

            # Build UI Report
            return html_div([
                html_h5("DESIGN INTEGRITY REPORT", className="text-info fw-bold mb-3"),

                # Efficiency Section
                html_div([
                    html_div("Mathematical Efficiency", className="small fw-bold text-muted mb-1"),
                    dbc_row([
                            dbc_col(Gui_Base.BASE_MiniVitals_DDEF("D-Efficiency", @sprintf("%.1f%%", d_eff * 100), d_eff > 0.6 ? "success" : "warning"), xs=6, md=3),
                            dbc_col(Gui_Base.BASE_MiniVitals_DDEF("Condition #", @sprintf("%.1e", metrics["Condition"]), metrics["Condition"] < 1e4 ? "success" : "danger"), xs=6, md=3),
                            dbc_col(Gui_Base.BASE_MiniVitals_DDEF("A-Efficiency", @sprintf("%.2f", metrics["A"]), "info"), xs=6, md=3),
                            dbc_col(Gui_Base.BASE_MiniVitals_DDEF("G-Efficiency", @sprintf("%.2f", metrics["G"]), "info"), xs=6, md=3),
                        ], className="mb-3 g-2")
                ]),

                # Stoichiometry Section
                html_div([
                    html_div("Chemical Stoichiometry", className="small fw-bold text-muted mb-1"),
                    dbc_alert([
                            html_i(className="fas $(valid_stoi ? "fa-check-circle" : "fa-exclamation-triangle") me-2"),
                            html_strong(valid_stoi ? "PHASE FEASIBLE: " : "PHASE VIOLATION: "),
                            valid_stoi ? "All experimental coordinates are physically accessible within the search space." : stoi_issues
                        ], color=valid_stoi ? "success" : "danger", className="py-2 small mb-3")
                ]),

                # Mass Audit Section
                html_div([
                    html_div("Mass Inventory (per run)", className="small fw-bold text-muted mb-1"),
                    dbc_row([
                            dbc_col(html_div([
                                    html_span("Min Mass: ", className="text-secondary small"),
                                    html_span(@sprintf("%.4f mg", min_mass), className="fw-bold")
                                ]), xs=6),
                            dbc_col(html_div([
                                    html_span("Max Mass: ", className="text-secondary small"),
                                    html_span(@sprintf("%.4f mg", max_mass), className="fw-bold")
                                ]), xs=6),
                        ], className="bg-light p-2 rounded small mb-3")
                ]), html_div([
                        html_i(className="fas fa-info-circle me-2"),
                        "This audit simulates the full experimental matrix based on your current settings. Passing this check ensures a high probability of successful protocol execution."
                    ], className="text-muted small italic border-top pt-2")
            ]), true

        catch e
            bt = sprint(showerror, e, catch_backtrace())
            return html_div("Scientific Audit Failed: $e", className="text-danger"), true
        end
    end
end
end # module
