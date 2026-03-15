module Gui_Deck

# ======================================================================================
# DAISHODOE - GUI DECK (EXPERIMENTAL DESIGN)
# ======================================================================================
# Description: Experimental design workspace, matrix generation, and protocol export.
# Module Tag:  DECK
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

const DECK_MaxRows_DDEC = 15

const DECK_RoleOptions_DDEC = [
    Dict("label" => "Variable", "value" => "Variable"),
    Dict("label" => "Fixed", "value" => "Fixed"),
]


"""
    DECK_GetDefaultRow_DDEF(i) -> Dict
Generates a default factor row configuration based on its positional index.
"""
function DECK_GetDefaultRow_DDEF(i::Int)
    role_val = i <= 3 ? "Variable" : "Fixed"
    return Dict(
        "Name" => "", "Role" => role_val,
        "L1" => 0.0, "L2" => 0.0, "L3" => 0.0,
        "Min" => 0.0, "Max" => 0.0, "MW" => 0.0, "Unit" => "-",
        "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"
    )
end

# --------------------------------------------------------------------------------------
# SECTION 1: LAYOUT HELPERS
# --------------------------------------------------------------------------------------

"""
    DECK_BuildOutRow_DDEF(i, def_name, def_unit) -> Tr
Constructs a table row for defining dependent response metrics.
"""
function DECK_BuildOutRow_DDEF(i, def_name, def_unit)
    return html_tr([
        html_td(dcc_input(id="deck-out-name-$i", type="text", value=def_name, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "50%")), className="p-0"),
        html_td(dcc_input(id="deck-out-unit-$i", type="text", value=def_unit, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "50%")), className="p-0"),
        # REMOVED: Decay correction indicator and settings button for dependent variables as per user request.
    ])
end

# --------------------------------------------------------------------------------------
# SECTION 1.2: MODAL WINDOWS
# --------------------------------------------------------------------------------------
function DECK_ModalChemical_DDEF()
    return dbc_modal([
        dbc_modalheader(dbc_modaltitle([
            html_i(className="fas fa-flask me-2 colourtx-c1sm"),
            html_span("Component Properties", id="deck-prop-title")
        ])),
        dbc_modalbody([
            dcc_store(id="deck-prop-target-id", data=Dict("type" => "", "index" => 0)),
            dcc_store(id="deck-prop-trigger-save", data=0),

            html_div("Chemical Definition", 
                className = "small fw-bold mb-2 colourtx-v3dl"
            ),

            dbc_row([
                dbc_col(dbc_label("Molecular Weight (g/mol)", className="small mb-1"), xs=12),
                dbc_col(dbc_input(id="deck-prop-mw", type="number", min=0, step="any", placeholder="e.g. 386.65", size="sm", className="mb-3"), xs=12),
            ], className="mb-2 border-bottom pb-2"),

            html_div("Radioactivity & Decay", 
                className = "small fw-bold mb-2 colourtx-v3dl"
            ),

            dbc_row([
                dbc_col(dbc_label("Half-Life (T½)", className="small mb-1"), xs=12, sm=6),
                dbc_col(dbc_label("Unit", className="small mb-1"), xs=12, sm=6),
                dbc_col(dbc_input(id="deck-prop-hl", type="number", min=0, step="any", placeholder="e.g. 6.0", size="sm", className="mb-3"), xs=12, sm=6),
                dbc_col(dbc_select(
                    id="deck-prop-hl-unit",
                    options=[
                        Dict("label" => "Minutes", "value" => "Minutes"),
                        Dict("label" => "Hours",   "value" => "Hours"),
                        Dict("label" => "Days",    "value" => "Days")
                    ], 
                    value="Hours", 
                    size="sm", 
                    className="mb-3"
                ), xs=12, sm=6)
            ])
        ]),
        dbc_modalfooter([
            dbc_button("Cancel",          id="btn-prop-cancel", className="ms-auto colourgl-c0hr", outline=false, size="sm"),
            dbc_button("Save Properties", id="btn-prop-save",   className="colourgl-c4tg", size="sm")
        ])
    ], id="deck-modal-prop", is_open=false, centered=true, size="md", backdrop="static")
end

function DECK_ModalStoch_DDEF()
    return dbc_modal([
        dbc_modalheader(dbc_modaltitle([
            html_i(className="fas fa-flask me-2 colourtx-c5hy"),
            "Stoichiometry Settings"
        ])),
        dbc_modalbody([
            dbc_alert([
                html_i(className="fas fa-info-circle me-2"),
                html_strong("Universal Stoichiometry Mode"), 
                html_br(),
                "Define your system using a mix of absolute and relational units. The engine calculates dry mass and solvent requirements automatically.", 
                html_br(), html_br(),
                html_div([
                    html_table([
                        html_thead(html_tr([
                            html_th("Unit Type", style=Dict("width"=>"30%")),
                            html_th("Supported Units"),
                            html_th("Calculation Model")
                        ])),
                        html_tbody([
                            html_tr([
                                html_td(html_strong("Absolute")),
                                html_td("g, mg, mcg, ug, ng"),
                                html_td("Fixed mass. Concentration is ignored.")
                            ]),
                            html_tr([
                                html_td(html_strong("Relational")),
                                html_td("%M"),
                                html_td("Molar percentage of target concentration.")
                            ]),
                            html_tr([
                                html_td(html_strong("Relational")),
                                html_td("MR, Ratio"),
                                html_td("Molar ratio parts.")
                            ]),
                            html_tr([
                                html_td(html_strong("Relational")),
                                html_td("%w/w, %"),
                                html_td("Percentage of total mass (Filler balance).")
                            ])
                        ])
                    ], className="table table-sm table-borderless colourtx-v5pb mb-0 small")
                ], className="p-2 rounded colourbg-v1lh")
            ], 
            className = "py-2 small mb-3 border-0 shadow-sm colourgl-c4tg colourtx-v5pb"),
            
            dbc_alert([
                html_i(className="fas fa-flask me-2"),
                html_strong("Matrix & Solvent Rule: "), 
                "If Volume > 0, the audit will specify the solvent volume needed to reach the target. If a Filler is defined below, it acts as the molar balancer for any remaining relational gap.",
            ], className="py-2 small mb-3 border-0 shadow-sm colourgl-c5hy colourtx-v5pb"),

            dbc_alert([
                html_i(className="fas fa-info-circle me-2"),
                html_strong("Solid Component Constraint: "), 
                "This system is strictly designed for stoichiometric calculations of solid ingredients. Liquid molarity calculations are not supported; all concentrations assume solids are filled with solvent (water/buffer) to the final target volume.",
            ], 
            className = "py-2 small mb-3 border-0 shadow-sm colourgl-c1sm colourtx-v5pb"),

            html_div("Filler Definition", 
                className = "small fw-bold mb-2 colourtx-v3dl"
            ),
            
            dbc_row([
                dbc_col([
                    dbc_label("Filler Name", className="small mb-1"),
                    dbc_input(id="deck-stoch-filler-name", type="text", placeholder="", size="sm", className="mb-2"),
                ], xs=12, sm=6),
                dbc_col([
                    dbc_label("Filler MW (g/mol)", className="small mb-1"),
                    dbc_input(id="deck-stoch-filler-mw", type="number", min=0, step="any", placeholder="e.g. 734.05", size="sm", className="mb-2"),
                ], xs=12, sm=6),
            ], className="mb-2 border-bottom pb-2"),

            html_div("Environment Parameters", 
                className = "small fw-bold mb-2 colourtx-v3dl"
            ),

            dbc_row([
                dbc_col([
                    dbc_label("Volume (mL)", className="small mb-1"),
                    dbc_input(id="deck-stoch-vol", type="number", min=0, step="any", placeholder="e.g. 5.0", size="sm", className="mb-2"),
                ], xs=12, sm=6),
                dbc_col([
                    dbc_label("Concentration (mM)", className="small mb-1"),
                    dbc_input(id="deck-stoch-conc", type="number", min=0, step="any", placeholder="e.g. 20.0", size="sm", className="mb-2"),
                ], xs=12, sm=6),
            ]),

            html_div([
                dcc_input(id="deck-input-vol",  type="number", value=0.0, style=Dict("display" => "none")),
                dcc_input(id="deck-input-conc", type="number", value=0.0, style=Dict("display" => "none")),
            ], style=Dict("display" => "none")),
        ]),

        dbc_modalfooter([
            dbc_button("Cancel",        id="deck-btn-stoch-cancel", className="ms-auto colourgl-c0hr", outline=false, size="sm"),
            dbc_button("Save Settings", id="deck-btn-stoch-save",   className="colourgl-c4tg", size="sm")
        ])
    ], id="deck-modal-stoch-settings", is_open=false, centered=true, size="lg", backdrop="static")
end

function DECK_ModalAudit_DDEF()
    return html_div([
        BASE_Modal_DDEF("deck-modal-audit", "Quick Audit Report",
            dbc_row(dbc_col(html_div(id="deck-audit-output"), xs=12)),
            dbc_button("Close", id="deck-btn-audit-close", className="ms-auto colourgl-c0hr", outline=false)),
 BASE_Modal_DDEF("deck-modal-sci-audit", [html_i(className="fas fa-certificate me-2 colourtx-c1sm"),"Detailed Scientific Audit"],
            dbc_row(dbc_col(dcc_loading(html_div(id="deck-sci-audit-output"), type="default", color="var(--colour-chr1-shamag)"), xs=12)),
            dbc_button("Close", id="deck-btn-sci-audit-close", className="ms-auto colourgl-c0hr", outline=false))
    ])
end

# --------------------------------------------------------------------------------------
# SECTION 1.1: LOCAL TABLE BUILDERS
# --------------------------------------------------------------------------------------

"""
    DECK_BuildIdTable_DDEF(rows_range, initial_rows, active_count, show_del) -> Table
Constructs the identification segment of the experimental factor table.
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
        ]; className="colourtx-v5pb", style=Dict("width" => "100%", "borderCollapse" => "collapse", "fontSize" => "10px", "tableLayout" => "fixed", "marginBottom" => "0"))
end

"""
    DECK_BuildLevelTable_DDEF(rows_range, initial_rows, active_count) -> Table
Constructs the level-specification segment of the experimental factor table.
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
        ]; className="colourtx-v5pb", style=Dict("width" => "100%", "borderCollapse" => "collapse", "fontSize" => "10px", "tableLayout" => "fixed", "marginBottom" => "0"))
end

"""
    DECK_BuildLimitsTable_DDEF(rows_range, initial_rows, active_count) -> Table
Constructs the boundary-limit segment of the experimental factor table.
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
        ]; className="colourtx-v5pb", style=Dict("width" => "100%", "borderCollapse" => "collapse", "fontSize" => "10px", "tableLayout" => "fixed", "marginBottom" => "0"))
end

"""
    DECK_Layout_DDEF() -> Container
Constructs the primary experimental design interface and workspace layout.
"""
function DECK_Layout_DDEF()
    try
        Defaults = Sys_Fast.FAST_GetLabDefaults_DDEF()

        # Start with 6 active rows by default (3 Var + 3 Fixed)
        initial_rows = [DECK_GetDefaultRow_DDEF(i) for i in 1:DECK_MaxRows_DDEC]
        active_count = 6

        return dbc_container([
            # Persistent Application State & Data Storage
            dbc_row(dbc_col([
                dcc_store(
                    id           = "deck-store-factors",
                    data         = Dict("rows" => [DECK_GetDefaultRow_DDEF(i) for i in 1:6], "count" => 6),
                    storage_type = "memory"
                ),
                dcc_store(
                    id           = "deck-store-outputs", 
                    data         = Dict("rows" => [Dict() for i in 1:3]), 
                    storage_type = "memory"
                ),

                html_div([
                    dash_datatable(
                        id = "deck-table-in",
                        columns = [
                            Dict("name" => "Name", "id" => "Name", "type" => "text"),
                            Dict("name" => "Role", "id" => "Role", "type" => "text"),
                            Dict("name" => "L1",   "id" => "L1",   "type" => "numeric"),
                            Dict("name" => "L2",   "id" => "L2",   "type" => "numeric"),
                            Dict("name" => "L3",   "id" => "L3",   "type" => "numeric"),
                            Dict("name" => "Min",  "id" => "Min",  "type" => "numeric"),
                            Dict("name" => "Max",  "id" => "Max",  "type" => "numeric"),
                            Dict("name" => "MW",   "id" => "MW",   "type" => "numeric"),
                            Dict("name" => "Unit", "id" => "Unit", "type" => "text"),
                        ],
                        data     = [DECK_GetDefaultRow_DDEF(i) for i in 1:5],
                        editable = false,
                    ),
                        html_div([
                            html_div([dcc_input(id="deck-mw-$i",   type="number", value=0.0)                                                                            for i in 1:DECK_MaxRows_DDEC]),
                            html_div([dbc_select(id="deck-role-$i", options=DECK_RoleOptions_DDEC, value=(i <= 3 ? "Variable" : "Fixed")) for i in 1:DECK_MaxRows_DDEC]),
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
                        dbc_row(dbc_col(BASE_GlassPanel_DDEF(
                            [
                                html_i(className="fas fa-layer-group me-2"),
                                "INDEPENDENT VARIABLES",
                                html_span(" — Define analysis boundaries and corresponding levels for a 3-factor system.",
                                    className = "ms-2 fw-normal colourtx-v3dl",
                                    style     = Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0")
                                )
                            ],
                            dbc_row([
                                dbc_col(DECK_BuildIdTable_DDEF(1:3,     initial_rows, active_count, false), md=4, className="pe-md-1"),
                                dbc_col(DECK_BuildLimitsTable_DDEF(1:3, initial_rows, active_count),        md=4, className="px-md-1"),
                                dbc_col(DECK_BuildLevelTable_DDEF(1:3,  initial_rows, active_count),        md=4, className="ps-md-1")
                            ], className="g-0");
                            panel_class   = "mb-4 h-100",
                            content_class = "p-2"
                        ), xs=12), className="mb-3"),

                        # Constant Windows
                        dbc_row(dbc_col(BASE_GlassPanel_DDEF(
                            [
                                html_i(className="fas fa-thumbtack me-2"),
                                "CONSTANT PARAMETERS",
                                html_span(" — Static background components strictly maintained throughout the entire analysis.",
                                    className = "ms-2 fw-normal colourtx-v3dl",
                                    style     = Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0")
                                )
                            ],
                            dbc_row([
                                dbc_col(DECK_BuildIdTable_DDEF(4:DECK_MaxRows_DDEC,     initial_rows, active_count, true),  md=4, className="pe-md-1"),
                                dbc_col(DECK_BuildLimitsTable_DDEF(4:DECK_MaxRows_DDEC, initial_rows, active_count),        md=4, className="px-md-1"),
                                dbc_col(DECK_BuildLevelTable_DDEF(4:DECK_MaxRows_DDEC,  initial_rows, active_count),        md=4, className="ps-md-1")
                            ], className="g-0");
                            right_node    = dbc_button([html_i(className="fas fa-plus me-1"), "Add Row"], id="deck-btn-add-row", n_clicks=0, className="px-2 py-1 fw-bold colourtx-v4dh colourbg-v0pw", outline=true, size="sm", style=Dict("borderColor" => "var(--colour-val1-lighig)")),
                            panel_class   = "mb-4 h-100",
                            content_class = "p-2"
                        ), xs=12), className="mb-3"),

                        # Row 2: Response Metrics & Stoichiometric Components
                        dbc_row([
                            dbc_col(BASE_GlassPanel_DDEF(
                                [
                                    html_i(className="fas fa-bullseye me-2"),
                                    "DEPENDENT VARIABLES",
                                    html_span(" — Declare the 3 fundamental analysis parameters to be thoroughly investigated.",
                                        className = "ms-2 fw-normal colourtx-v3dl",
                                        style     = Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0")
                                    )
                                ],
                                html_div(html_table([
                                    html_thead(html_tr([
                                        html_th("RESPONSE NAME", style=merge(BASE_StyleInlineHeader_DDEC, Dict("textAlign" => "center", "paddingLeft" => "5px", "width" => "50%")), className="p-0"),
                                        BASE_TableHeader_DDEF("UNIT/METRIC", width="50%")
                                    ])),
                                    html_tbody([DECK_BuildOutRow_DDEF(i, "", "-") for i in 1:3])
                                ], className="colourtx-v5pb", style=Dict("width" => "100%", "borderCollapse" => "collapse", "fontSize" => "10px", "tableLayout" => "fixed")), className="table-responsive m-0 p-2");
                                content_class = "glass-content p-0",
                                panel_class   = "h-100 mb-0"
                            ), md=6),

                            dbc_col(BASE_GlassPanel_DDEF(
                                [
                                    html_i(className="fas fa-list-check me-2"),
                                    "STOICHIOMETRIC COMPONENTS",
                                    html_span(" — Active ingredients participating in the dry mass and molar balance.",
                                        className = "ms-2 fw-normal colourtx-v3dl",
                                        style     = Dict("fontSize" => "0.65rem", "textTransform" => "none", "letterSpacing" => "0")
                                    )
                                ],
                                html_div(id="deck-stoch-list-display", 
                                    className="p-2", 
                                    style=Dict("maxHeight" => "140px", "overflowY" => "auto", "backgroundColor" => "var(--colour-val0-purwhi)")
                                );
                                content_class = "glass-content p-0 d-flex flex-column",
                                panel_class   = "h-100 mb-0"
                            ), md=6),
                        ], className="g-3 mb-3 d-flex align-items-stretch"),
                    ], xs=12, md=9, className="mb-3 mb-md-0"),

                    # --- RIGHT COLUMN ---
                    dbc_col(
                        BASE_GlassPanel_DDEF(
                            [html_i(className="fas fa-cogs me-2"), "SYSTEM CONFIGURATION"], 
                            [
                                BASE_SidebarHeader_DDEF("DATA ACQUISITION", icon="fas fa-database"),
                                BASE_Upload_DDEF("deck-upload", "Import Dataset", "fas fa-file-import"),
                                BASE_Loading_DDEF("deck-upload-status", "No data source", class="glass-loading-status mb-2"),
                                
                                BASE_Separator_DDEF(),
                                
                                BASE_SidebarHeader_DDEF("PROFILES"),
                                dbc_row([
                                    dbc_col(BASE_ActionButton_DDEF("deck-btn-save-memo", "Save",   "fas fa-download", class="w-100 fw-bold"), xs=6, className="pe-1 mb-2"),
                                    dbc_col(dcc_upload(
                                        id       = "deck-upload-memo", 
                                        children = BASE_ActionButton_DDEF("deck-upload-memo-btn", "Load", "fas fa-upload", class="w-100 fw-bold"), 
                                        multiple = false, 
                                        className = "w-100"
                                    ), xs=6, className="ps-1 mb-2"),
                                    dbc_col(BASE_ActionButton_DDEF("deck-btn-template",  "Sample", "fas fa-eye",    class="w-100 fw-bold"), xs=6, className="pe-1 mb-3"),
                                    dbc_col(BASE_ActionButton_DDEF("deck-btn-clear",     "Clear",  "fas fa-eraser", class="w-100 fw-bold"), xs=6, className="ps-1 mb-3"),
                                ], className="g-0"),

                                dbc_row(dbc_col(html_div(id="deck-memo-msg", className="small mb-2 fw-bold text-center"), xs=12)),

                                BASE_ControlGroup_DDEF("Project Name",
                                    dbc_input(id="deck-input-project", type="text", value="", placeholder="Enter project name...", className="mb-2 form-control-sm", debounce=false)),
                                
                                BASE_ControlGroup_DDEF("Phase",
                                    dcc_dropdown(id="deck-dd-phase", options=[Dict("label" => "Phase 1", "value" => "Phase1")], value="Phase1", clearable=false, className="mb-3")),
                                
                                BASE_ControlGroup_DDEF("Design Method",
                                    dcc_dropdown(id="deck-dd-method",
                                        options = [
                                            Dict("label" => "Box-Behnken (15 Runs, Quadratic)", "value" => "BB15"),
                                            Dict("label" => "D-Optimal (15 Runs, Quadratic)",   "value" => "DOPT15"),
                                            Dict("label" => "Taguchi L9 (9 Runs, Linear)",       "value" => "TL09"),
                                            Dict("label" => "D-Optimal (9 Runs, Linear)",       "value" => "DOPT09"),
                                        ],
                                        value     = "BB15", 
                                        clearable = false, 
                                        className = "mb-3"
                                    )),
                                
                                BASE_Separator_DDEF(),
                                
                                # Stoichiometry Settings Button
                                BASE_ActionButton_DDEF("deck-btn-stoch-settings", "Stoichiometry Settings", "fas fa-flask",      class="w-100 mb-2"),
                                BASE_ActionButton_DDEF("deck-btn-audit",          "Quick Audit",            "fas fa-vial",       class="w-100 mb-2"),
                                BASE_ActionButton_DDEF("deck-btn-sci-audit",      "Scientific Audit",       "fas fa-microscope", class="w-100 mb-2"),
                                
                                BASE_Loading_DDEF("deck-run-output", ""),
                                BASE_NextButton_DDEF("deck-btn-run", "Generate Protocol"),
                            ]; panel_class = "mb-3 h-auto"
                        ),
                        xs=12, md=3
                    ),
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
                DECK_ModalStoch_DDEF(),
                DECK_ModalAudit_DDEF()
            ], fluid=true, className="px-4 py-3")
    catch e
        @error "DECK LAYOUT ERROR" exception = (e, catch_backtrace())
 return html_div("Layout Error: $e", className="p-4 colourtx-c0hr")
    end
end

# --------------------------------------------------------------------------------------
# SECTION 2: CORE PROTOCOL LOGIC
# --------------------------------------------------------------------------------------

"""
    DECK_GenerateProtocol_DDEF(path, in_data, out_data, vol, conc, method) -> (Success, Message)
Orchestrates the generation and validation of an experimental protocol Excel document.
"""
function DECK_GenerateProtocol_DDEF(path, in_data, out_data, vol, conc, method, stoch_data, project="Daisho")
    C = Sys_Fast.FAST_Data_DDEC
    # Local aliases for scoping
    L_PT   = Main.Lib_Mole.MOLE_ParseTable_DDEF
    L_VDF  = Main.Lib_Mole.MOLE_ValidateDesignFeasibility_DDEF
    L_AMM  = Main.Lib_Mole.MOLE_AuditMatrix_DDEF
    L_CM   = Main.Lib_Mole.MOLE_CalcMass_DDEF
    L_VPU  = Main.Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF
    
    try
        # 0. Virtual Filler Injection
        raw_rows       = BASE_SafeRows_DDEF(in_data)
        processed_rows = filter(r -> get(r, "Role", get(r, :Role, "")) != "Filler", raw_rows)
        
        st_data = isnothing(stoch_data) ? Dict() : stoch_data
        f_name  = strip(string(get(st_data, "FillerName", get(st_data, :FillerName, ""))))
        f_mw    = Sys_Fast.FAST_SafeNum_DDEF(get(st_data, "FillerMW", get(st_data, :FillerMW, 0.0)))
        
        if !isempty(f_name) && f_mw > 0.0
            push!(processed_rows, Dict(
                "Name" => f_name, "Role" => "Filler", "MW" => f_mw,
                "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0,
                "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"
            ))
        end

        D         = L_PT(processed_rows)
        num_vars  = length(D["Idx_Var"])
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
            mw   = Float64(get(r, "MW", 0.0))
            if mw > 0.0 && !isempty(unit) && unit != "-" && unit != "%M" && unit != "MR"
                ok_m, _, _ = L_VPU(unit, "Mass")
                ok_c, _, _ = L_VPU(unit, "Concentration")
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
            sum_max_pct = 0.0
            sv = Sys_Fast.FAST_SafeNum_DDEF(vol)
            sc = Sys_Fast.FAST_SafeNum_DDEF(conc)
            
            if sv > 0 && sc > 0
                for r in D["Rows"]
                    mw   = Sys_Fast.FAST_SafeNum_DDEF(get(r, "MW", 0.0))
                    unit = string(get(r, "Unit", "-"))
                    role = get(r, "Role", "")
                    val  = (role == "Variable") ? Sys_Fast.FAST_SafeNum_DDEF(get(r, "L3", 0.0)) : Sys_Fast.FAST_SafeNum_DDEF(get(r, "L2", 0.0))
                    
                    # Convert this component's value to its percentage equivalent in the system
                    pct_eq = Main.Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(val, unit, mw, sv, sc)
                    sum_max_pct += pct_eq
                end
                
                if sum_max_pct > 100.0 + 1e-4
                    return (false, "Stoichiometry Error: Total molar budget exceeded at upper boundaries (Sum: $(round(sum_max_pct; digits=2))%). Please adjust limits, volume, or concentration.")
                end
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
        N_Runs       = size(design_coded, 1)
        configs      = [Dict("Levels" => [D["Rows"][i]["L1"], D["Rows"][i]["L2"], D["Rows"][i]["L3"]]) for i in D["Idx_Var"]]
        real_matrix  = Lib_Core.CORE_MapLevels_DDEF(design_coded, configs)

        # 5b. Matrix Validation (Det-Check)
        valid_dsgn, dsgn_issues = Lib_Core.CORE_ValidateDesign_DDEF(real_matrix, configs)
        if !valid_dsgn
            return (false, "Validation Error: " * dsgn_issues)
        end

        d_eff = Lib_Core.CORE_D_Efficiency_DDEF(real_matrix)

        # 5c. Stoichiometric Feasibility Check
        sv = Sys_Fast.FAST_SafeNum_DDEF(vol)
        sc = Sys_Fast.FAST_SafeNum_DDEF(conc)
        valid_stoi, stoi_issues = L_VDF(real_matrix, D["Rows"], sv, sc)
        if !valid_stoi
            return (false, "Stoichiometric Error: " * stoi_issues)
        end

        # 5d. Total Mass Audit
        chem_indices = D["Idx_Chem"]
        chem_units = [string(get(r, "Unit", "-")) for r in D["Rows"][chem_indices]]
        run_masses = L_AMM(real_matrix, D["Names"][chem_indices], D["MWs"][chem_indices], Sys_Fast.FAST_SafeNum_DDEF(vol), Sys_Fast.FAST_SafeNum_DDEF(conc), chem_units)
        if any(isnan, run_masses) || any(<(0.0), run_masses)
            return (false, "Mass Calculation Error: One or more runs resulted in invalid chemical mass. Please check your MW and Concentration values.")
        end

        # 6. Session & Phase Logic
        phase_num     = 1
        current_phase = "Phase1"
        try
            if isfile(path)
                df_old = Sys_Fast.FAST_ReadExcel_DDEF(path, C.SHEET_DATA)
                phase_col = Sys_Fast.FAST_GetCol_DDEF(df_old, C.COL_PHASE)
                if !isempty(df_old) && !isempty(phase_col)
                    phases = filter(!ismissing, unique(df_old[!, Symbol(phase_col)]))
                    nums   = [let m = match(r"\d+", string(p)); isnothing(m) ? 1 : parse(Int, m.match) end for p in phases]
                    phase_num     = isempty(nums) ? 1 : maximum(nums) + 1
                    current_phase = "Phase$phase_num"
                end
            end
        catch
        end

        # 7. CENTRALIZED STOICHIOMETRY ENGINE (Lib_Mole)
        df_chem = Lib_Mole.MOLE_ProcessDesign_DDEF(real_matrix, processed_rows, sv, sc)

        # 8. FINAL PROTOCOL INTEGRITY (Merging System Metadata with Chemical Logic)
        df_sys = DataFrame(
            C.COL_EXP_ID    => ["EXP_P$(phase_num)_$(lpad(i, 2, '0'))" for i in 1:N_Runs],
            C.COL_PHASE     => fill(current_phase, N_Runs),
            C.COL_RUN_ORDER => 1:N_Runs,
            C.COL_STATUS    => fill("Pending", N_Runs),
        )

        # Assemble: System Meta + Chemical Gradient Design
        df = hcat(df_sys, df_chem)

        # Add Response/Prediction placeholders
        for r in output_data
            n = string(get(r, "Name", "Unknown"))
            u = string(get(r, "Unit", ""))
            res_header  = (isempty(u) || u == "-") ? C.PRE_RESULT * n : C.PRE_RESULT * n * "_" * u
            pred_header = (isempty(u) || u == "-") ? C.PRE_PRED * n   : C.PRE_PRED * n   * "_" * u
            df[!, res_header] = fill(missing, N_Runs)
            df[!, pred_header] = fill(missing, N_Runs)
        end

        df[!, C.COL_SCORE] = fill(missing, N_Runs)
        df[!, C.COL_NOTES] = fill("", N_Runs)

        # CHRO (Chronological/Radioactivity) Management
        if any(r -> get(r, "IsRadioactive", false), D["Rows"])
            df[!, "CHRO_HOUR"] = fill(0.0, N_Runs)
            df[!, "CHRO_MIN"]  = fill(0.0, N_Runs)
        end

        # Extract Filler Metadata for Master Config
        f_name = ""; f_mw = 0.0
        if !isempty(D["Idx_Fill"])
            f_row = D["Rows"][D["Idx_Fill"][1]]
            f_name = string(get(f_row, "Name", ""))
            f_mw   = Sys_Fast.FAST_SafeNum_DDEF(get(f_row, "MW", 0.0))
        end

        ConfigDict = Dict(
            "Ingredients" => D["Rows"],
            "Global"      => Dict("Volume" => sv, "Conc" => sc, "Method" => method, "ProjectName" => project, "FillerName" => f_name, "FillerMW" => f_mw, "DEfficiency" => d_eff),
            "Outputs"     => output_data,
        )
        
        success = Sys_Fast.FAST_InitMaster_DDEF(path,
            [string(get(r, "Name", "")) for r in BASE_SafeRows_DDEF(in_data)],
            [string(get(r, "Name", "")) for r in output_data],
            df, ConfigDict)

        msg = success ? "Protocol successfully generated. (D-Efficiency: $(round(d_eff, digits=4)))" : "Master Initialisation Failed"
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
    DECK_RegisterCallbacks_DDEF(app) -> Nothing
Initialises the callback registry for the Design Deck workspace.
"""
function DECK_RegisterCallbacks_DDEF(app)
    # --- Reference Aliases for Scoped Execution ---
    Lib_Mole_PT  = Main.Lib_Mole.MOLE_ParseTable_DDEF
    Lib_Mole_VPU = Main.Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF
    Lib_Mole_AMM = Main.Lib_Mole.MOLE_AuditMatrix_DDEF
    Lib_Mole_CM  = Main.Lib_Mole.MOLE_CalcMass_DDEF
    Lib_Mole_QA  = Main.Lib_Mole.MOLE_QuickAudit_DDEF
    Lib_Mole_VDF  = Main.Lib_Mole.MOLE_ValidateDesignFeasibility_DDEF
    Lib_Mole_AB   = Main.Lib_Mole.MOLE_AuditBatch_DDEF
    
    # --- UI SYNCHRONISATION (Updates interface from persistent state) ---
    callback!(app,
        [Output("deck-row-id-$i",     "style") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-row-level-$i",  "style") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-row-limits-$i", "style") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-name-$i",       "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-role-$i",       "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-l1-$i",         "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-l2-$i",         "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-l3-$i",         "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-min-$i",        "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-max-$i",        "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-mw-$i",         "value") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-unit-$i",       "value") for i in 1:DECK_MaxRows_DDEC]...,
        # Indicator dot styles (chemical + radioactive)
        [Output("deck-dot1-$i",       "className") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-dot2-$i",       "className") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("deck-unit-$i",       "style") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("tip-deck-dot1-$i",   "children") for i in 1:DECK_MaxRows_DDEC]...,
        [Output("tip-deck-dot2-$i",   "children") for i in 1:DECK_MaxRows_DDEC]...,
        Input("deck-store-factors", "data"),
        prevent_initial_call = true
    ) do stored
        isnothing(stored) && return ntuple(_ -> Dash.no_update(), 17 * DECK_MaxRows_DDEC)
        rows  = get(stored, "rows", [])
        count = get(stored, "count", 0)


        # All rows are now table-rows (ID, Level, Limits all use html_table)
        out_styles = [Dict("display" => (i <= 3 || i <= count) ? "table-row" : "none") for i in 1:DECK_MaxRows_DDEC]
        out_names  = [i <= length(rows) ? string(get(rows[i], "Name", "")) : "" for i in 1:DECK_MaxRows_DDEC]
        out_roles  = [(i <= 3 ? "Variable" : "Fixed") for i in 1:DECK_MaxRows_DDEC]
        out_l1s    = [i <= length(rows) ? get(rows[i], "L1", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_l2s    = [i <= length(rows) ? get(rows[i], "L2", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_l3s    = [i <= length(rows) ? get(rows[i], "L3", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_mins   = [i <= length(rows) ? get(rows[i], "Min", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_maxs   = [i <= length(rows) ? get(rows[i], "Max", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_mws    = [i <= length(rows) ? get(rows[i], "MW", 0.0) : 0.0 for i in 1:DECK_MaxRows_DDEC]
        out_units  = [i <= length(rows) ? string(get(rows[i], "Unit", "")) : "" for i in 1:DECK_MaxRows_DDEC]

        # Indicator dot colours: Blue for MW presence (Chemical), Green for Radioactivity
        dot1_classes = [
            (let r = (i <= length(rows) ? rows[i] : Dict()); Float64(get(r, "MW", get(r, :MW, 0.0))) > 0.0 ? "colourtx-c3tc" : "colourtx-v3dl" end)
            for i in 1:DECK_MaxRows_DDEC
        ]
        dot2_classes = [
            (let r = (i <= length(rows) ? rows[i] : Dict()); (get(r, "IsRadioactive", false) == true) || (Float64(get(r, "HalfLife", get(r, :HalfLife, 0.0))) > 0.0) ? "colourtx-c4tg" : "colourtx-v3dl" end)
            for i in 1:DECK_MaxRows_DDEC
        ]

        # Dynamic tooltips
        dot1_tips = [
            (let r = (i <= length(rows) ? rows[i] : Dict()); Float64(get(r, "MW", get(r, :MW, 0.0))) > 0.0 ? "Molecular Weight defined (Scientific context ACTIVE)" : "No Molecular Weight defined" end)
            for i in 1:DECK_MaxRows_DDEC
        ]
        dot2_tips = [
            (let r = (i <= length(rows) ? rows[i] : Dict()); (get(r, "IsRadioactive", false) == true) || (Float64(get(r, "HalfLife", get(r, :HalfLife, 0.0))) > 0.0) ? "Radioactive Decay data present (Kinetic engine ACTIVE)" : "No half-life data" end)
            for i in 1:DECK_MaxRows_DDEC
        ]

        # Real-time unit & MW validation styles
        # Capture functions in local scope for robust closure access
        vpu_func = Main.Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF
        unit_styles = [
            let
                s = merge(Main.Gui_Base.BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px"))
                if i <= length(rows) && i <= count
                    u  = lowercase(strip(string(get(rows[i], "Unit", ""))))
                    mw = Float64(get(rows[i], "MW", 0.0))
                    
                    # High-priority validation: MW missing for relational & absolute molarity (M)
                    if (u == "%m" || u == "mr" || u == "ratio" || u == "m") && mw <= 0.0
                        s["backgroundColor"] = "var(--colour-chr0-huered)"
                        s["color"]           = "white"
                        s["fontWeight"]      = "bold"
                        s["border"]          = "2px solid white"
                        s["boxShadow"]       = "0 0 15px rgba(255, 0, 0, 0.6)"
                    elseif mw > 0.0 && !isempty(u) && u != "-" && u != "%m" && u != "mr" && u != "ratio"
                        # Use captured function reference
                        ok_m, _, _ = Lib_Mole_VPU(u, "Mass")
                        ok_c, _, _ = Lib_Mole_VPU(u, "Concentration")
                        if !ok_m && !ok_c
                            s["color"]      = "var(--colour-chr3-toncya)"
                            s["fontWeight"] = "bold"
                            s["border"]     = "1px solid var(--colour-chr3-toncya)"
                        else
                            s["color"]      = "var(--colour-chr3-toncya)"
                        end
                    end
                end
                s
            end for i in 1:DECK_MaxRows_DDEC
        ]

        return (
            out_styles..., out_styles..., out_styles..., 
            out_names..., out_roles..., 
            out_l1s..., out_l2s..., out_l3s..., 
            out_mins..., out_maxs..., out_mws..., out_units..., 
            dot1_classes..., dot2_classes..., unit_styles...,
            dot1_tips..., dot2_tips...
        )
    end

    # --- 2. APPLICATION STATE ORCHESTRATOR ---
    callback!(app,
        Output("deck-store-factors", "data"),
        Output("deck-table-in",      "data"),
        Output("deck-dd-phase",      "options"),
        Output("deck-input-vol",     "value"),
        Output("deck-input-conc",    "value"),
        Output("deck-input-project", "value"),
        Output("deck-dd-method",     "value"),
        Output("deck-memo-msg",      "children"),
        Output("deck-download-memo", "data"),
        Output("deck-upload-status", "children"),
        Output("deck-dd-phase",      "value"),
        [Output("deck-out-name-$i",  "value") for i in 1:3]...,
        [Output("deck-out-unit-$i",  "value") for i in 1:3]...,
        Output("deck-store-stoch-settings", "data"),
        
        # Triggers
        Input("deck-btn-add-row",        "n_clicks"),
        Input("deck-btn-clear",          "n_clicks"),
        Input("deck-upload-memo",        "contents"),
        Input("deck-btn-template",       "n_clicks"),
        Input("deck-btn-save-memo",      "n_clicks"),
        Input("store-session-config",    "data"),
        Input("deck-upload",             "contents"),
        Input("deck-prop-trigger-save",  "data"),
        Input("deck-stoch-trigger-unit", "data"),
        Input("deck-btn-stoch-save",     "n_clicks"),
        
        # Delete buttons as Inputs
        [Input("deck-del-$i", "n_clicks") for i in 1:DECK_MaxRows_DDEC]...,
        
        # States
        State("deck-store-factors",        "data"),
        State("deck-upload",               "filename"),
        [State("deck-name-$i",             "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-role-$i",             "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l1-$i",               "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l2-$i",               "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l3-$i",               "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-min-$i",              "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-max-$i",              "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-mw-$i",               "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-unit-$i",             "value") for i in 1:DECK_MaxRows_DDEC]...,
        State("deck-input-vol",            "value"),
        State("deck-input-conc",           "value"),
        State("deck-prop-target-id",       "data"),
        State("deck-prop-hl",              "value"),
        State("deck-prop-hl-unit",         "value"),
        State("deck-prop-mw",              "value"),
        State("deck-store-stoch-settings", "data"),
        [State("deck-out-name-$i",         "value") for i in 1:3]...,
        [State("deck-out-unit-$i",         "value") for i in 1:3]...,
        State("deck-stoch-filler-name",    "value"),
        State("deck-stoch-filler-mw",      "value"),
        State("deck-stoch-vol",            "value"),
        State("deck-stoch-conc",           "value"),
        State("deck-input-project",        "value"),
        State("deck-dd-phase",             "value"),
        State("deck-dd-method",            "value"),
        prevent_initial_call=false
    ) do args...
        try  # Global error guard for main orchestrator callback
            # --- ARGUMENT MAPPING (LEGACY INDEXING) ---
            trig      = Dash.callback_context().triggered
            trig      = isempty(trig) ? "" : split(string(trig[1].prop_id), ".")[1]
            
            # 1..10: Core Action Triggers (Buttons, Stores, Uploads)
            # 11..11+DECK_MaxRows_DDEC-1: Delete Button Triggers (ndels)
            # 11+DECK_MaxRows_DDEC: Factor Store (store_data)
            # 11+DECK_MaxRows_DDEC+1: Upload Filename (fname)
            # 11+DECK_MaxRows_DDEC+2.. (+ 9*DECK_MaxRows_DDEC): Row States
            # Post Row States: Global Vol/Conc, Property Modal States, Stoch Settings, Response Table/Store, Modal Inputs, Project/Phase.

            n_add, n_clear, up_memo, n_temp, n_save, session, up_cont = args[1:7]
            save_prop_trig = args[8]
            stoch_trig = args[9]
            n_stoch_save = args[10]
            ndels = args[11:11+DECK_MaxRows_DDEC-1]
            store_data = args[11+DECK_MaxRows_DDEC]
            fname = isnothing(args[11+DECK_MaxRows_DDEC+1]) ? "" : string(args[11+DECK_MaxRows_DDEC+1])

            offset = 11 + DECK_MaxRows_DDEC + 2 
            all_names = collect(args[offset:offset+DECK_MaxRows_DDEC-1])
            all_roles = collect(args[offset+DECK_MaxRows_DDEC:offset+2DECK_MaxRows_DDEC-1])
            all_l1s = collect(args[offset+2DECK_MaxRows_DDEC:offset+3DECK_MaxRows_DDEC-1])
            all_l2s = collect(args[offset+3DECK_MaxRows_DDEC:offset+4DECK_MaxRows_DDEC-1])
            all_l3s = collect(args[offset+4DECK_MaxRows_DDEC:offset+5DECK_MaxRows_DDEC-1])
            all_mins = collect(args[offset+5DECK_MaxRows_DDEC:offset+6DECK_MaxRows_DDEC-1])
            all_maxs = collect(args[offset+6DECK_MaxRows_DDEC:offset+7DECK_MaxRows_DDEC-1])
            all_mws = collect(args[offset+7DECK_MaxRows_DDEC:offset+8DECK_MaxRows_DDEC-1])
            all_units = collect(args[offset+8DECK_MaxRows_DDEC:offset+9DECK_MaxRows_DDEC-1])

            # Explicitly utilise Dash.callback_context() for state stability.
            ctx = Dash.callback_context()
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

            DECK_SafeNumZero_DDEF(x) = (v = Sys_Fast.FAST_SafeNum_DDEF(x); isnan(v) ? 0.0 : v)

            # --- GLOBALS EXTRACTION (Consistent across all branches) ---
            idx_gl = 11 + DECK_MaxRows_DDEC + 2 + 9 * DECK_MaxRows_DDEC
            vol_v    = DECK_SafeNumZero_DDEF(args[idx_gl])
            conc_v   = DECK_SafeNumZero_DDEF(args[idx_gl+1])
            proj_v   = isnothing(args[idx_gl+17]) ? "Daisho" : string(args[idx_gl+17])
            phase_v  = isnothing(args[idx_gl+18]) ? "Phase1" : string(args[idx_gl+18])
            method_v = isnothing(args[idx_gl+19]) ? "BB15" : string(args[idx_gl+19])
            
            # Robust Data Capture Logic: trust DOM but sync with Store for properties
            # This is CRITICAL for data persistence during property/stoch changes.
            DECK_SnapRows_DDEF() = let
                n = isnothing(store_data) ? 7 : Int(DECK_GetSafeKey_DDEF(store_data, "count", 7))
                [
                    let
                        mw_val = DECK_SafeNumZero_DDEF(all_mws[i])
                        unit_val = !isnothing(all_units[i]) ? string(all_units[i]) : ""

                        is_rad = false
                        hl_val = 0.0
                        hl_unit = "Hours"
                        prev_mw = 0.0

                        if !isnothing(store_data) && (haskey(store_data, "rows") || haskey(store_data, :rows))
                            r_list = DECK_GetSafeKey_DDEF(store_data, "rows", [])
                            if i <= length(r_list)
                                prow = r_list[i]
                                pmw = DECK_GetSafeKey_DDEF(prow, "MW", 0.0)
                                prev_mw = Sys_Fast.FAST_SafeNum_DDEF(pmw)
                                mw_val = prev_mw > 0.0 ? prev_mw : mw_val
                                is_rad = Bool(DECK_GetSafeKey_DDEF(prow, "IsRadioactive", false))
                                hl_val = Sys_Fast.FAST_SafeNum_DDEF(DECK_GetSafeKey_DDEF(prow, "HalfLife", 0.0))
                                hl_unit = string(DECK_GetSafeKey_DDEF(prow, "HalfLifeUnit", "Hours"))
                            end
                        end

                        if contains(unit_val, "%")
                            l1_val = clamp(DECK_SafeNumZero_DDEF(all_l1s[i]), 0.0, 100.0)
                            l2_val = clamp(DECK_SafeNumZero_DDEF(all_l2s[i]), 0.0, 100.0)
                            l3_val = clamp(DECK_SafeNumZero_DDEF(all_l3s[i]), 0.0, 100.0)
                            min_v  = clamp(DECK_SafeNumZero_DDEF(all_mins[i]), 0.0, 100.0)
                            max_v  = clamp(DECK_SafeNumZero_DDEF(all_maxs[i]), 0.0, 100.0)
                        else
                            l1_val = DECK_SafeNumZero_DDEF(all_l1s[i])
                            l2_val = DECK_SafeNumZero_DDEF(all_l2s[i])
                            l3_val = DECK_SafeNumZero_DDEF(all_l3s[i])
                            min_v  = DECK_SafeNumZero_DDEF(all_mins[i])
                            max_v  = DECK_SafeNumZero_DDEF(all_maxs[i])
                        end

                        Dict(
                            "Name" => !isnothing(all_names[i]) ? string(all_names[i]) : "",
                            "Role" => (i <= 3 ? "Variable" : "Fixed"),
                            "L1" => l1_val, "L2" => l2_val, "L3" => l3_val,
                            "Min" => min_v, "Max" => max_v, "MW" => mw_val,
                            "Unit" => unit_val, "IsRadioactive" => is_rad,
                            "HalfLife" => hl_val, "HalfLifeUnit" => hl_unit
                        )
                    end for i in 1:min(n, DECK_MaxRows_DDEC)
                ]
            end

            # --- 6. PROP SAVE LOGIC ---
            if trig == "deck-prop-trigger-save"
                isnothing(save_prop_trig) && return ntuple(_ -> Dash.no_update(), 18)
                
                # GET CURRENT SNAPSHOT TO PRESERVE INTERMEDIATE EDITS
                current_rows = DECK_SnapRows_DDEF()

                # Modal States extraction (Corrected indices)
                # Global param offset: idx_gl
                
                target   = args[idx_gl+2]    # deck-prop-target-id
                hl_val   = args[idx_gl+3]    # deck-prop-hl
                hl_unit  = args[idx_gl+4]    # deck-prop-hl-unit
                mw_modal = args[idx_gl+5]    # deck-prop-mw

                # Automatic Radioactive Check
                is_rad = !isnothing(hl_val) && Sys_Fast.FAST_SafeNum_DDEF(hl_val) > 0.0

                t_type = string(get(target, "type", get(target, :type, "")))
                t_idx = Int(get(target, "index", get(target, :index, 0)))

                if t_type == "in" && t_idx > 0 && t_idx <= length(current_rows)
                    new_rows = []
                    for (i, r) in enumerate(current_rows)
                        new_r = Dict{String,Any}(string(k) => v for (k, v) in r)
                        if i == t_idx
                            safe_mw = isnothing(mw_modal) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(mw_modal)
                            safe_mw = isnan(safe_mw) ? 0.0 : safe_mw
                            new_r["MW"] = safe_mw

                            # Clamp values if unit is percentage (0-100 range)
                            if contains(string(get(new_r, "Unit", "")), "%")
                                new_r["L1"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(new_r, "L1", 0.0)), 0.0, 100.0)
                                new_r["L2"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(new_r, "L2", 0.0)), 0.0, 100.0)
                                new_r["L3"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(new_r, "L3", 0.0)), 0.0, 100.0)
                                new_r["Min"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(new_r, :Min, get(new_r, "Min", 0.0))), 0.0, 100.0)
                                new_r["Max"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(new_r, :Max, get(new_r, "Max", 0.0))), 0.0, 100.0)
                            end

                            safe_hl = isnothing(hl_val) ? 0.0 : Sys_Fast.FAST_SafeNum_DDEF(hl_val)
                            safe_hl = isnan(safe_hl) ? 0.0 : safe_hl
                            new_r["IsRadioactive"] = is_rad
                            new_r["HalfLife"] = safe_hl
                            new_r["HalfLifeUnit"] = isnothing(hl_unit) ? "Hours" : string(hl_unit)
                        end
                        push!(new_rows, new_r)
                    end
                    
                    count_val = isnothing(store_data) ? length(new_rows) : DECK_GetSafeKey_DDEF(store_data, "count", length(new_rows))
                    new_store = Dict{String,Any}("rows" => new_rows, "count" => count_val)
                    return (new_store, ntuple(_ -> Dash.no_update(), 17)...)
                end
                return ntuple(_ -> Dash.no_update(), 18)
            end

            # --- 6b. UNIT AUTO-LOGIC (Internal Refinement) ---
            if trig == "deck-stoch-trigger-unit"
                # Extraction Modal Values from args (indices verified)
                st_data = args[idx_gl+6] 
                isnothing(st_data) && return ntuple(_ -> Dash.no_update(), 18)

                has_fill = get(st_data, "FillerName", "") != "" && DECK_SafeNumZero_DDEF(get(st_data, "FillerMW", 0.0)) > 0.0

                if has_fill
                    new_rows = []
                    f_name = lowercase(strip(string(get(st_data, "FillerName", ""))))
                    f_mw = Float64(get(st_data, "FillerMW", 0.0))

                    for r in DECK_SnapRows_DDEF()
                        nr = Dict{String,Any}(string(k) => v for (k, v) in r)
                        if lowercase(strip(string(get(nr, "Name", "")))) == f_name
                            nr["MW"] = f_mw
                            nr["Role"] = "Fixed" 
                        end
                        push!(new_rows, nr)
                    end
                    ns = Dict{String,Any}("rows" => new_rows, "count" => isnothing(store_data) ? length(new_rows) : DECK_GetSafeKey_DDEF(store_data, "count", length(new_rows)))
                    return (ns, ntuple(_ -> Dash.no_update(), 17)...)
                end
                return ntuple(_ -> Dash.no_update(), 18)
            end

            NO = Dash.no_update()

            # --- A. DELETE ROW ---
            del_ids = ["deck-del-$i" for i in 1:DECK_MaxRows_DDEC]
            if trig in del_ids
                rows = DECK_SnapRows_DDEF()
                ri = findfirst(==(trig), del_ids)
                if ri !== nothing && ri <= length(rows) && ri > 3
                    deleteat!(rows, ri)
                end
                nc = length(rows)
                return DECK_Return_DDEF(Dict("rows" => rows, "count" => nc), rows, NO, NO, NO, NO, NO, NO, NO, NO, NO, fill(NO, 6), NO)

            # --- B. ADD ROW ---
            elseif trig == "deck-btn-add-row"
                rows = DECK_SnapRows_DDEF()
                current_count = isnothing(store_data) ? length(rows) : get(store_data, "count", get(store_data, :count, length(rows)))
                new_count = min(current_count + 1, DECK_MaxRows_DDEC)
                if new_count > current_count
                    new_row = DECK_GetDefaultRow_DDEF(new_count)
                    new_row["Role"] = "Fixed"
                    push!(rows, new_row)
                else
                    new_count = current_count 
                end
                return DECK_Return_DDEF(Dict("rows" => rows, "count" => new_count), rows, NO, NO, NO, NO, NO, NO, NO, NO, NO, fill(NO, 6), NO)

            # --- C0. CLEAR CANVAS ---
            elseif trig == "deck-btn-clear"
                rows = [DECK_GetDefaultRow_DDEF(i) for i in 1:6]
                lbl = html_div([html_i(className="fas fa-trash-alt me-2"), "Canvas Cleared"],
                               className="badge p-2 w-100", style=Dict("color" => "var(--colour-val0-purwhi)", "backgroundColor" => "var(--colour-chr0-huered)", "fontSize" =>"0.85rem"))
                empty_stoch = Dict("FillerName" => "", "FillerMW" => 0.0, "Volume" => 0.0, "Conc" => 0.0)
                return DECK_Return_DDEF(Dict("rows" => rows, "count" => 6), rows, [Dict("label" => "Phase 1", "value" => "Phase1")], 0.0, 0.0, "", "BoxBehnken", lbl, NO, "No data source", "Phase1", vcat(["", "", ""], ["-", "-", "-"]), empty_stoch)

            # --- C1. LOAD USER PROFILE ---
            elseif trig == "deck-upload-memo" && !isnothing(up_memo) && up_memo != ""
                try
                    base64_data = split(up_memo, ",")[end]
                    json_str = String(base64decode(base64_data))
                    memo = JSON3.read(json_str)
                    loaded_rows = map(enumerate(DECK_GetSafeKey_DDEF(memo, "Inputs", []))) do (i, m)
                        Dict("Name" => DECK_GetSafeKey_DDEF(m, "Name", ""), 
                            "Role" => (i <= 3 ? "Variable" : "Fixed"),
                            "L1" => DECK_GetSafeKey_DDEF(m, "L1", 0.0), "L2" => DECK_GetSafeKey_DDEF(m, "L2", 0.0),
                            "L3" => DECK_GetSafeKey_DDEF(m, "L3", 0.0), "Min" => DECK_GetSafeKey_DDEF(m, "Min", 0.0),
                            "Max" => DECK_GetSafeKey_DDEF(m, "Max", 0.0), "MW" => DECK_GetSafeKey_DDEF(m, "MW", 0.0),
                            "Unit" => DECK_GetSafeKey_DDEF(m, "Unit", "-"),
                            "IsRadioactive" => DECK_GetSafeKey_DDEF(m, "IsRadioactive", false),
                            "HalfLife" => Float64(DECK_GetSafeKey_DDEF(m, "HalfLife", 0.0)),
                            "HalfLifeUnit" => string(DECK_GetSafeKey_DDEF(m, "HalfLifeUnit", "Hours")))
                    end
                    lbl = html_div([html_i(className="fas fa-folder-open me-2"), "Memory Loaded"],
                                   className="badge p-2 w-100", style=Dict("color" => "var(--colour-val0-purwhi)", "backgroundColor" => "var(--colour-chr3-toncya)", "fontSize" =>"0.85rem"))
                    real_count = 0
                    for (i, r) in enumerate(loaded_rows)
                        if !isempty(strip(string(get(r, "Name", ""))))
                            real_count = i
                        end
                    end
                    # Ensure minimum of 6 rows (3 Var + 3 Default Fixed)
                    nc = max(6, real_count)
                    
                    # Padding to ensure stability in UI hydration
                    while length(loaded_rows) < DECK_MaxRows_DDEC
                        push!(loaded_rows, DECK_GetDefaultRow_DDEF(length(loaded_rows) + 1))
                    end

                    g = get(memo, "Global", Dict())
                    vol_v = get(g, "Volume", 0.0); conc_v = get(g, "Conc", 0.0)
                    
                    # Override globals if present in JSON
                    p_name = string(get(g, "ProjectName", ""))
                    if !isempty(p_name) proj_v = p_name end
                    
                    m_val = string(get(g, "Method", ""))
                    if !isempty(m_val) method_v = m_val end

                    loaded_stoch = Dict("FillerName" => string(get(g, "FillerName", "")), "FillerMW" => Float64(get(g, "FillerMW", 0.0)), "Volume" => Float64(vol_v), "Conc" => Float64(conc_v))
                    memo_outs = get(memo, "Outputs", [])
                    out_vals = vcat([i <= length(memo_outs) ? get(memo_outs[i], "Name", "") : "" for i in 1:3], [i <= length(memo_outs) ? get(memo_outs[i], "Unit", "-") : "-" for i in 1:3])
                    return DECK_Return_DDEF(Dict("rows" => loaded_rows[1:DECK_MaxRows_DDEC], "count" => nc), loaded_rows[1:DECK_MaxRows_DDEC], NO, vol_v, conc_v, proj_v, method_v, lbl, NO, NO, NO, out_vals, loaded_stoch)
                catch e
                    err_lbl = html_div("❌ Load Error: $e", className="badge w-100 p-2", style=Dict("color" => "var(--colour-val0-purwhi)", "backgroundColor" => "var(--colour-chr0-huered)"))
                    return DECK_Return_DDEF(NO, NO, NO, NO, NO, NO, NO, err_lbl, NO, NO, NO, fill(NO, 6), NO)
                end

            # --- C2. LOAD TEMPLATE ---
            elseif trig == "deck-btn-template"
                loaded_rows = [
                    Dict("Name" => "Chol", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "Min" => 0.0, "Max" => 40.0, "MW" => 386.65, "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"),
                    Dict("Name" => "PEG", "Role" => "Variable", "L1" => 1.0, "L2" => 3.0, "L3" => 5.0, "Min" => 0.0, "Max" => 10.0, "MW" => 2808.74, "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"),
                    Dict("Name" => "Temperature", "Role" => "Variable", "L1" => 25.0, "L2" => 45.0, "L3" => 65.0, "Min" => 25.0, "Max" => 100.0, "MW" => 0.0, "Unit" => "°C", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"),
                    Dict("Name" => "DPPC", "Role" => "Fixed", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0, "MW" => 734.05, "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"),
                    Dict("Name" => "DOTA", "Role" => "Fixed", "L1" => 0.0, "L2" => 1.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0, "MW" => 3184.84, "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"),
                ]
                lbl = html_div([html_i(className="fas fa-book-medical me-2"), "Template Applied"],
                               className="badge p-2 w-100", style=Dict("color" => "var(--colour-val0-purwhi)", "backgroundColor" => "var(--colour-chr1-shamag)", "fontSize" =>"0.85rem","boxShadow" =>"0 2px 5px var(--colour-val3-darlow)"))
                sample_stoch = Dict("FillerName" => "DPPC", "FillerMW" => 734.05, "Volume" => 5.0, "Conc" => 20.0)
                nc = min(length(loaded_rows), DECK_MaxRows_DDEC)
                def_outs = Sys_Fast.FAST_GetLabDefaults_DDEF()["Outputs"]
                out_vals = vcat([i <= length(def_outs) ? def_outs[i]["Name"] : "" for i in 1:3], [i <= length(def_outs) ? def_outs[i]["Unit"] : "-" for i in 1:3])
                return DECK_Return_DDEF(Dict("rows" => loaded_rows[1:nc], "count" => nc), loaded_rows[1:nc], [Dict("label" => "Phase 1", "value" => "Phase1")], 5.0, 20.0, "Sample_Project", "BoxBehnken", lbl, NO, "Ready", "Phase1", out_vals, sample_stoch)
            elseif trig == "deck-btn-save-memo"
                try
                    stoch_store = args[idx_gl+6]
                    
                    g_dict = Dict{String,Any}("Volume" => vol_v, "Conc" => conc_v, "ProjectName" => proj_v, "Method" => method_v)
                    if !isnothing(stoch_store) && (haskey(stoch_store, "FillerName") || haskey(stoch_store, :FillerName))
                        g_dict["FillerName"] = string(get(stoch_store, "FillerName", get(stoch_store, :FillerName, "")))
                        g_dict["FillerMW"] = Sys_Fast.FAST_SafeNum_DDEF(get(stoch_store, "FillerMW", get(stoch_store, :FillerMW, 0.0)))
                    end

                    out_names = collect(args[idx_gl+7:idx_gl+9])
                    out_units = collect(args[idx_gl+10:idx_gl+12])
                    out_d = Dict{String,Any}[]
                    for i in 1:3
                        if !isnothing(out_names[i]) && strip(string(out_names[i])) != ""
                            push!(out_d, Dict("Name" => string(out_names[i]), "Unit" => isnothing(out_units[i]) ? "" : string(out_units[i]), "IsRadioactive" => false))
                        end
                    end

                    json_str = JSON3.write(Dict("Inputs" => DECK_SnapRows_DDEF(), "Outputs" => out_d, "Global" => g_dict))
                    b64 = base64encode(json_str)

                    # Standardized Naming: Project, Phase, Tag (MEMO), Extension (json)
                    fname = Sys_Fast.FAST_GenerateSmartName_DDEF(proj_v, phase_v, "MEMO", "json")

                    dl_dict = Dict("filename" => fname, "content" => b64, "base64" => true)
                    lbl = html_div([html_i(className="fas fa-check-circle me-2"), "Workspace Exported"],
 className="badge p-2 w-100", style=Dict("color" => "var(--colour-val0-purwhi)", "backgroundColor" => "var(--colour-chr4-tongre)", "fontSize" =>"0.85rem","boxShadow" =>"0 2px 5px var(--colour-val3-darlow)"))
                    return DECK_Return_DDEF(NO, NO, NO, NO, NO, NO, NO, lbl, dl_dict, NO, NO, fill(NO, 6), NO)
                catch e
 err_lbl = html_div("❌ Save Error:" * string(e), className="badge w-100 p-2", style=Dict("color" => "var(--colour-val0-purwhi)", "backgroundColor" => "var(--colour-chr0-huered)", "fontSize" =>"0.6rem"))
                    return DECK_Return_DDEF(NO, NO, NO, NO, NO, NO, NO, err_lbl, NO, NO, NO, fill(NO, 6), NO)
                end

                # --- C3. SAVE STOICHIOMETRY ---
            elseif trig == "deck-btn-stoch-save"
                f_name_modal = args[idx_gl+13]
                f_mw_modal = args[idx_gl+14]
                s_vol_modal = args[idx_gl+15]
                s_conc_modal = args[idx_gl+16]

                new_stoch = Dict(
                    "FillerName" => isnothing(f_name_modal) ? "" : strip(string(f_name_modal)),
                    "FillerMW" => isnothing(f_mw_modal) ? 0.0 : DECK_SafeNumZero_DDEF(f_mw_modal),
                    "Volume" => isnothing(s_vol_modal) ? 0.0 : DECK_SafeNumZero_DDEF(s_vol_modal),
                    "Conc" => isnothing(s_conc_modal) ? 0.0 : DECK_SafeNumZero_DDEF(s_conc_modal),
                )

                # Use Snapshot to capture table state
                current_rows = DECK_SnapRows_DDEF()
                
                new_rs = []
                for r in current_rows
                    nr = Dict{String,Any}(string(k) => v for (k, v) in r)
                    u_s = lowercase(strip(string(get(nr, "Unit", ""))))
                    if contains(u_s, "%")
                        nr["L1"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(nr, "L1", 0.0)), 0.0, 100.0)
                        nr["L2"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(nr, "L2", 0.0)), 0.0, 100.0)
                        nr["L3"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(nr, "L3", 0.0)), 0.0, 100.0)
                        nr["Min"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(nr, "Min", 0.0)), 0.0, 100.0)
                        nr["Max"] = clamp(Sys_Fast.FAST_SafeNum_DDEF(get(nr, "Max", 0.0)), 0.0, 100.0)
                    end
                    push!(new_rs, nr)
                end
                
                n_st = Dict{String,Any}("rows" => new_rs, "count" => isnothing(store_data) ? length(new_rs) : DECK_GetSafeKey_DDEF(store_data, "count", length(new_rs)))
                return DECK_Return_DDEF(n_st, NO, NO, new_stoch["Volume"], new_stoch["Conc"], NO, NO, NO, NO, NO, NO, fill(NO, 6), new_stoch)

                # --- F. IMPORT PROTOCOL (from Smart Vault) ---
            elseif trig == "deck-upload" && !isnothing(up_cont)
                try
                    if up_cont == ""
                        rows = [DECK_GetDefaultRow_DDEF(i) for i in 1:5]
                        return DECK_Return_DDEF(Dict("rows" => rows, "count" => 5), rows, [Dict("label" => "Loading...", "value" => "NONE")], 0.0, 0.0, "Daisho", "BoxBehnken", NO, NO, "No data source", "NONE", fill(NO, 6), NO)
                    end
                    
                    # Project Name Extraction from Filename
                    extracted_proj = Sys_Fast.FAST_ExtractProjectFromFilename_DDEF(fname)
                    # If empty, keep current or default to "Daisho"
                    if extracted_proj != ""
                        proj_v = extracted_proj
                    end

                    # Check extension for JSON support
                    is_json = lowercase(splitext(fname)[2]) == ".json"

                    if is_json
                        # Support JSON import (Workspace format)
                        base64_data = split(up_cont, ",")[end]
                        json_str = String(base64decode(base64_data))
                        data = JSON3.read(json_str)
                        
                        ingreds = DECK_GetSafeKey_DDEF(data, "Ingredients", DECK_GetSafeKey_DDEF(data, "Inputs", []))
                        mapped = map(ingreds) do itm
                            Dict("Name" => DECK_GetSafeKey_DDEF(itm, "Name", ""), "Role" => DECK_GetSafeKey_DDEF(itm, "Role", "Variable"),
                                "L1" => DECK_GetSafeKey_DDEF(itm, "L1", 0.0), "L2" => DECK_GetSafeKey_DDEF(itm, "L2", 0.0),
                                "L3" => DECK_GetSafeKey_DDEF(itm, "L3", 0.0), "Min" => DECK_GetSafeKey_DDEF(itm, "Min", 0.0), "Max" => DECK_GetSafeKey_DDEF(itm, "Max", 0.0), "MW" => DECK_GetSafeKey_DDEF(itm, "MW", 0.0),
                                "Unit" => DECK_GetSafeKey_DDEF(itm, "Unit", "-"),
                                "IsRadioactive" => DECK_GetSafeKey_DDEF(itm, "IsRadioactive", false),
                                "HalfLife" => Float64(DECK_GetSafeKey_DDEF(itm, "HalfLife", 0.0)),
                                "HalfLifeUnit" => string(DECK_GetSafeKey_DDEF(itm, "HalfLifeUnit", "Hours")),
                                )
                        end
                        real_count = 0
                        for (i, r) in enumerate(mapped)
                            if !isempty(strip(string(get(r, "Name", ""))))
                                real_count = i
                            end
                        end
                        nc = max(6, real_count)
                        
                        while length(mapped) < DECK_MaxRows_DDEC
                            push!(mapped, DECK_GetDefaultRow_DDEF(length(mapped) + 1))
                        end
                        
                        g = DECK_GetSafeKey_DDEF(data, "Global", Dict())
                        method_val = get(g, "Method", "BB15")
                        project_json = string(get(g, "ProjectName", ""))
                        if !isempty(project_json)
                            proj_v = project_json
                        end
                        outs = DECK_GetSafeKey_DDEF(data, "Outputs", [])
                        out_vals = vcat(
                            [i <= length(outs) ? get(outs[i], "Name", "") : "" for i in 1:3],
                            [i <= length(outs) ? get(outs[i], "Unit", "-") : "-" for i in 1:3]
                        )
                        stat_msg = html_span("✅ Sync: JSON Loaded", className="small fw-bold", style=Dict("color" => "var(--colour-chr4-tongre)"))
                        ph_opts = [Dict("label" => "Phase 1 Initiated", "value" => "Phase1")]
                        
                        loaded_stoch = Dict(
                            "FillerName" => string(get(g, "FillerName", "")),
                            "FillerMW" => Float64(get(g, "FillerMW", 0.0)),
                            "Volume" => Float64(get(g, "Volume", 0.0)),
                            "Conc" => Float64(get(g, "Conc", 0.0))
                        )
                        return DECK_Return_DDEF(Dict("rows" => mapped[1:DECK_MaxRows_DDEC], "count" => nc), mapped[1:DECK_MaxRows_DDEC], ph_opts,
                            get(g, "Volume", 0.0), get(g, "Conc", 0.0), proj_v, method_val, NO, NO, stat_msg, "Phase1", out_vals, loaded_stoch)
                    else
                        # Protocol import (Excel/Smart Vault format)
                        tmp = Sys_Fast.FAST_GetTransientPath_DDEF(up_cont)
                        if !isfile(tmp)
                             return DECK_Return_DDEF(NO, NO, NO, NO, NO, proj_v, NO, html_div("❌ Data session stale. Please re-upload.", className="badge w-100 p-2", style=Dict("color" => "var(--colour-val0-purwhi)", "backgroundColor" => "var(--colour-chr0-huered)")), NO, NO, NO, fill(NO, 6), NO)
                        end

                        cfg = Sys_Fast.FAST_ReadConfig_DDEF(tmp)
                        Sys_Fast.FAST_CleanTransient_DDEF(tmp)
                        
                        if !isempty(cfg) && (haskey(cfg, "Ingredients") || haskey(cfg, :Ingredients))
                            g = DECK_GetSafeKey_DDEF(cfg, "Global", Dict())
                            all_ingreds = DECK_GetSafeKey_DDEF(cfg, "Ingredients", [])
                            filtered_ingreds = filter(itm -> string(get(itm, "Role", get(itm, :Role, ""))) != "Filler", all_ingreds)
                            
                            mapped = map(enumerate(filtered_ingreds)) do (i, itm)
                                Dict("Name" => DECK_GetSafeKey_DDEF(itm, "Name", ""), 
                                    "Role" => (i <= 3 ? "Variable" : "Fixed"),
                                    "L1" => DECK_GetSafeKey_DDEF(itm, "L1", 0.0), "L2" => DECK_GetSafeKey_DDEF(itm, "L2", 0.0),
                                    "L3" => DECK_GetSafeKey_DDEF(itm, "L3", 0.0), "Min" => DECK_GetSafeKey_DDEF(itm, "Min", 0.0), "Max" => DECK_GetSafeKey_DDEF(itm, "Max", 0.0), "MW" => DECK_GetSafeKey_DDEF(itm, "MW", 0.0),
                                    "Unit" => DECK_GetSafeKey_DDEF(itm, "Unit", "-"),
                                    "IsRadioactive" => DECK_GetSafeKey_DDEF(itm, "IsRadioactive", false),
                                    "HalfLife" => Float64(DECK_GetSafeKey_DDEF(itm, "HalfLife", 0.0)),
                                    "HalfLifeUnit" => string(DECK_GetSafeKey_DDEF(itm, "HalfLifeUnit", "Hours")))
                            end
                            real_count = 0
                            for (i, r) in enumerate(mapped)
                                if !isempty(strip(string(get(r, "Name", ""))))
                                    real_count = i
                                end
                            end
                            nc = max(6, real_count)
                            
                            while length(mapped) < DECK_MaxRows_DDEC
                                push!(mapped, DECK_GetDefaultRow_DDEF(length(mapped) + 1))
                            end

                            method_val = get(g, "Method", "BB15")
                            project_cfg = string(get(g, "ProjectName", ""))
                            if !isempty(project_cfg)
                                proj_v = project_cfg
                            end
                            outs = get(cfg, "Outputs", [])
                            out_vals = vcat(
                                [i <= length(outs) ? get(outs[i], "Name", "") : "" for i in 1:3],
                                [i <= length(outs) ? get(outs[i], "Unit", "-") : "-" for i in 1:3]
                            )
                            stat_msg = html_span("✅ Sync: Valid Workspace", className="small fw-bold", style=Dict("color" => "var(--colour-chr4-tongre)"))
                            ph_opts = [Dict("label" => "Phase 1 Initiated", "value" => "Phase1")]

                            loaded_stoch = Dict(
                                "FillerName" => string(get(g, "FillerName", "")),
                                "FillerMW" => Float64(get(g, "FillerMW", 0.0)),
                                "Volume" => Float64(get(g, "Volume", 0.0)),
                                "Conc" => Float64(get(g, "Conc", 0.0))
                            )

                            return DECK_Return_DDEF(Dict("rows" => mapped[1:DECK_MaxRows_DDEC], "count" => nc), mapped[1:DECK_MaxRows_DDEC], ph_opts,
                                get(g, "Volume", 0.0), get(g, "Conc", 0.0), proj_v, method_val, NO, NO, stat_msg, "Phase1", out_vals, loaded_stoch)
                        end
                    end
                catch e
                    @error "Import failed" exception = (e, catch_backtrace())
                    return DECK_Return_DDEF(NO, NO, NO, NO, NO, NO, NO, html_div("❌ Import Failed: $e", className="badge w-100 p-2", style=Dict("color" => "var(--colour-val0-purwhi)", "backgroundColor" => "var(--colour-chr0-huered)")), NO, NO, NO, fill(NO, 6), NO)
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
 ], className="badge w-100 p-2 shadow-sm", style=Dict("color" => "var(--colour-val0-purwhi)", "backgroundColor" => "var(--colour-chr0-huered)", "fontSize" =>"0.75rem"))

            return (Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(), Dash.no_update(),
                Dash.no_update(), Dash.no_update(), err_msg, Dash.no_update(), Dash.no_update(),
                Dash.no_update(), ntuple(_ -> Dash.no_update(), 6)..., Dash.no_update())
        end
    end

    # --- 3. AUDIT MODAL ORCHESTRATION ---
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
        State("deck-store-stoch-settings", "data"),
        prevent_initial_call=true
    ) do args...
        try  # Error guard for audit callback
            n_op, n_cl, is_op, store_data, vol, conc = args[1:6]
            stoch_settings = args[end]
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
                                        ], className="h6 mb-3", style=Dict("color" => "var(--colour-chr0-huered)")), true
                    end

                    if l1val < minval || l3val > maxval || l1val > l2val || l2val > l3val
                        return html_div([
                                html_i(className="fas fa-exclamation-triangle me-2"),
                                html_span("Audit Failed: Variable '$name' must strictly obey Min <= Low <= Centre <= High <= Max boundary logic. (Got: $minval <= $l1val <= $l2val <= $l3val <= $maxval)", className="fw-bold"),
                                        ], className="h6 mb-3", style=Dict("color" => "var(--colour-chr0-huered)")), true
                    end
                end

                if i > 3 && isempty(name)
                    continue
                end

                push!(rows, Dict(
                    "Name" => name,
                    "Role" => (i <= 3 ? "Variable" : "Fixed"),
                    "L1" => l1val,
                    "L2" => l2val,
                    "L3" => l3val,
                    "Min" => minval,
                    "Max" => maxval,
                    "MW" => DECK_SafeNumZero_DDEF(all_mws[i]),
                    "Unit" => isnothing(all_units[i]) ? "" : string(all_units[i]),
                ))
            end

            # 3. Virtual Filler Injection
            processed_rows = filter(r -> get(r, "Role", get(r, :Role, "")) != "Filler", copy(rows))
            
            if !isnothing(stoch_settings)
                f_name = strip(string(get(stoch_settings, "FillerName", get(stoch_settings, :FillerName, ""))))
                f_mw   = Sys_Fast.FAST_SafeNum_DDEF(get(stoch_settings, "FillerMW", get(stoch_settings, :FillerMW, 0.0)))
                if !isempty(f_name) && f_mw > 0.0
                    push!(processed_rows, Dict(
                        "Name" => f_name, "Role" => "Filler", "MW" => f_mw,
                        "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0,
                        "Unit" => "%M"
                    ))
                end
            end

            sv_raw = Sys_Fast.FAST_SafeNum_DDEF(vol)
            sc_raw = Sys_Fast.FAST_SafeNum_DDEF(conc)
            
            if isnan(sv_raw) || sv_raw <= 0 || isnan(sc_raw) || sc_raw <= 0
                return html_div([
                    html_i(className="fas fa-exclamation-triangle me-2"),
                    html_span("Audit Blocked: Global Volume and Concentration must be defined as positive non-zero values for stoichiometric validation.", className="fw-bold"),
                ], className="h6 mb-3", style=Dict("color" => "var(--colour-chr0-huered)")), true
            end
            
            sv_calc = sv_raw
            sc_calc = sc_raw

            res_status, res_text, _, mass, msg = Lib_Mole.MOLE_QuickAudit_DDEF(
                processed_rows, sv_calc, sc_calc)

            icon = res_status ? "fa-check-circle" : "fa-exclamation-triangle"
            label = res_status ? "Audit Passed" : "Audit Failed"
            cls = res_status ? "" : ""

            header = html_div([
                    html_i(className="fas $icon me-2"),
                    html_span(label, className="fw-bold"),
                ], className="$cls mb-3 h5")

            return html_div([
                header,
                html_div([
 html_span("Base Mass:", className="", style=Dict("color" => "var(--colour-val4-darhig)")),
                        html_span(@sprintf("%.4f mg", mass), className="fw-bold"),
                    ], className="mb-3"),
                html_div(html_pre(res_text, style=Dict(
                        "backgroundColor" => "var(--colour-val0-purwhi)", "color" => "var(--colour-val5-purbla)", "padding" => "15px",
                        "borderRadius" => "6px", "fontSize" => "0.8rem",
                        "fontFamily" => "SFMono-Regular, Consolas, monospace",
                        "border" => "1px solid var(--colour-val2-liglow)", "maxHeight" => "400px", "overflowY" => "auto",
                    )), className="mb-3"),
 html_div(msg, className="small fw-bold border-top pt-2", style=Dict("color" => "var(--colour-chr3-toncya)")),
            ]), true

        catch e  # Surface audit errors to modal
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("DECK", "AUDIT_CRASH", bt, "FAIL")
            return html_div([
 html_i(className="fas fa-exclamation-triangle me-2", style=Dict("color" => "var(--colour-chr0-huered)")),
 html_span("Audit Error: $(first(string(e), 150))", className="", style=Dict("color" => "var(--colour-chr0-huered)")),
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
        [State("deck-name-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-role-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l1-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l2-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-l3-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-min-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-max-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-mw-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        [State("deck-unit-$i", "value") for i in 1:DECK_MaxRows_DDEC]...,
        State("deck-store-stoch-settings", "data"),
        prevent_initial_call=true
    ) do args...
        try  # Error guard for protocol generation callback
            n, project = args[1:2]
            out_names = collect(args[3:5])
            out_units = collect(args[6:8])
            vol, conc, method, session_data, store_data, master_vault = args[9:14]
            stoch_settings = args[end]
            (n === nothing || n == 0) && return Dash.no_update(), "", Dash.no_update()
 
            offset = 15
            all_names = collect(args[offset:offset+DECK_MaxRows_DDEC-1])
            all_roles = collect(args[offset+DECK_MaxRows_DDEC:offset+2DECK_MaxRows_DDEC-1])

            out_d = Dict{String,Any}[]
            for i in 1:3
                if !isnothing(out_names[i]) && strip(string(out_names[i])) != ""
                    push!(out_d, Dict("Name" => string(out_names[i]), "Unit" => isnothing(out_units[i]) ? "" : string(out_units[i]), "IsRadioactive" => false))
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
 return Dash.no_update(), html_div([html_i(className="fas fa-exclamation-triangle me-1", style=Dict("color" => "var(--colour-chr0-huered)")),"Error: Variables 1-3 must have Name, Min, and Max properties filled!"], className="fw-bold"), Dash.no_update()
                    end
                    if l1val < minval || l3val > maxval || l1val > l2val || l2val > l3val
 return Dash.no_update(), html_div([html_i(className="fas fa-exclamation-triangle me-1", style=Dict("color" => "var(--colour-chr0-huered)")),"Error: Variable '$name' breaks boundary rules (Got: $minval <= $l1val <= $l2val <= $l3val <= $maxval)!"], className="fw-bold"), Dash.no_update()
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
                        is_fill = false # CRITICAL: No table row can be a filler anymore
                    end
                end

                push!(in_d, Dict(
                    "Name" => name,
                    "Role" => (i <= 3 ? "Variable" : "Fixed"),
                    "L1" => l1val,
                    "L2" => l2val,
                    "L3" => l3val,
                    "Min" => minval,
                    "Max" => maxval,
                    "MW" => DECK_SafeNumZero_DDEF(all_mws[i]),
                    "Unit" => isnothing(all_units[i]) ? "" : string(all_units[i]),
                    "IsRadioactive" => is_rad,
                    "HalfLife" => hl_val,
                    "HalfLifeUnit" => hl_unit
                ))
            end

            # Virtual filler is now injected inside DECK_GenerateProtocol_DDEF to avoid duplication.

            if !isnothing(session_data) && session_data != "" && !isnothing(master_vault) && master_vault != ""
                path = Sys_Fast.FAST_GetTransientPath_DDEF(master_vault)
            else
                path = Sys_Fast.FAST_GetTransientPath_DDEF()
            end
            ok, msg = DECK_GenerateProtocol_DDEF(path, in_d, out_d, vol, conc, method, stoch_settings, project)
 !ok && return Dash.no_update(), html_div(msg, className="", style=Dict("color" => "var(--colour-chr0-huered)")), Dash.no_update()

            store_content = Sys_Fast.FAST_ReadToStore_DDEF(path)
            raw_base64 = base64encode(read(path))

            current_phase = "P1"
            if !isnothing(session_data) && session_data != ""
                try
                    current_phase = get(JSON3.read(session_data), "TargetPhase", "P1")
                catch
                end
            end
            # Standardized Naming: Project, Phase, Tag (DOE), Extension (xlsx)
            fname = Sys_Fast.FAST_GenerateSmartName_DDEF(project, current_phase, "DOE", "xlsx")
            rm(path; force=true)

            return (
                Dict("filename" => fname, "content" => raw_base64, "base64" => true),
                html_span([html_i(className="fas fa-check-circle me-1"),
"Protocol generated."], className="", style=Dict("color" => "var(--colour-chr4-tongre)")),
                store_content,
            )

        catch e  # Surface protocol generation errors
            bt = sprint(showerror, e, catch_backtrace())
            Sys_Fast.FAST_Log_DDEF("DECK", "PROTOCOL_CRASH", bt, "FAIL")
            return Dash.no_update(),
 html_span("⚠ Generation Error: $(first(string(e), 120))", className="fw-bold", style=Dict("color" => "var(--colour-chr0-huered)")),
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
                    fill_state = false # No table row is a filler
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

    # REMOVED: RESPONSE DOT INDICATOR callback as per user request.

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
        State("deck-store-stoch-settings", "data"),
        prevent_initial_call=true
    ) do args...
        try
            n_op, n_cl, is_op, method, vol, conc, store_data = args[1:7]
            stoch_settings = args[end]
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
            all_mins = collect(args[offset+5DECK_MaxRows_DDEC:offset+6DECK_MaxRows_DDEC-1])
            all_maxs = collect(args[offset+6DECK_MaxRows_DDEC:offset+7DECK_MaxRows_DDEC-1])
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
                    "Role" => (i <= 3 ? "Variable" : "Fixed"),
                    "L1" => Sys_Fast.FAST_SafeNum_DDEF(all_l1s[i]),
                    "L2" => Sys_Fast.FAST_SafeNum_DDEF(all_l2s[i]),
                    "L3" => Sys_Fast.FAST_SafeNum_DDEF(all_l3s[i]),
                    "MW" => Sys_Fast.FAST_SafeNum_DDEF(all_mws[i]),
                    "Unit" => isnothing(all_units[i]) ? "" : string(all_units[i]),
                ))
            end

            # 3. Virtual Filler Injection
            processed_rows = filter(r -> get(r, "Role", get(r, :Role, "")) != "Filler", copy(rows))
            
            if !isnothing(stoch_settings)
                f_name = strip(string(get(stoch_settings, "FillerName", get(stoch_settings, :FillerName, ""))))
                f_mw   = Sys_Fast.FAST_SafeNum_DDEF(get(stoch_settings, "FillerMW", get(stoch_settings, :FillerMW, 0.0)))
                if !isempty(f_name) && f_mw > 0.0
                    push!(processed_rows, Dict(
                        "Name" => f_name, "Role" => "Filler", "MW" => f_mw,
                        "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "Min" => 0.0, "Max" => 0.0,
                        "Unit" => "%M", "IsRadioactive" => false, "HalfLife" => 0.0, "HalfLifeUnit" => "Hours"
                    ))
                end
            end

            D = Lib_Mole_PT(processed_rows)
            num_vars = length(D["Idx_Var"])
 num_vars != 3 && return html_div("Protocol requires exactly 3 Variables. Detection: $num_vars", className="fw-bold", style=Dict("color" => "var(--colour-chr0-huered)")), true

            # Generate virtual design for audit
            design_coded = Lib_Core.CORE_GenDesign_DDEF(method, 3)
            configs = [Dict("Levels" => [D["Rows"][i]["L1"], D["Rows"][i]["L2"], D["Rows"][i]["L3"]]) for i in D["Idx_Var"]]
            real_matrix = Lib_Core.CORE_MapLevels_DDEF(design_coded, configs)

            # 1. Mathematical Health
            d_eff = Lib_Core.CORE_D_Efficiency_DDEF(real_matrix)
            metrics = Lib_Core.CORE_CalcDesignMetrics_DDEF(real_matrix)

            # 2. Stoichiometry Feasibility (Full Matrix)
            sv_raw_sci = Sys_Fast.FAST_SafeNum_DDEF(vol)
            sc_raw_sci = Sys_Fast.FAST_SafeNum_DDEF(conc)
            
            if isnan(sv_raw_sci) || sv_raw_sci <= 0 || isnan(sc_raw_sci) || sc_raw_sci <= 0
                return html_div([
                    html_i(className="fas fa-exclamation-triangle me-2"),
                    html_span("Scientific Audit Blocked: Global Volume and Concentration must be defined as positive non-zero values.", className="fw-bold"),
                ], className="h6 mb-3", style=Dict("color" => "var(--colour-chr0-huered)")), true
            end

            sv_calc_sci = sv_raw_sci
            sc_calc_sci = sc_raw_sci

            valid_stoi, stoi_issues = Lib_Mole.MOLE_ValidateDesignFeasibility_DDEF(real_matrix, D["Rows"], sv_calc_sci, sc_calc_sci)

            # 3. Mass Audit (Full Matrix)
            audit_res = Lib_Mole.MOLE_AuditBatch_DDEF(processed_rows, real_matrix, sv_calc_sci, sc_calc_sci)
            masses = audit_res["RunMasses"]
            min_mass = isempty(masses) ? 0.0 : minimum(masses)
            max_mass = isempty(masses) ? 0.0 : maximum(masses)

            # Build UI Report
            return html_div([
 html_h5("DESIGN INTEGRITY REPORT", className="fw-bold mb-3", style=Dict("color" => "var(--colour-chr3-toncya)")),

                # Efficiency Section
                html_div([
 html_div("Mathematical Efficiency", className="small fw-bold mb-1", style=Dict("color" => "var(--colour-val3-darlow)")),
                    dbc_row([
                            dbc_col(Gui_Base.BASE_MiniVitals_DDEF("D-Efficiency", @sprintf("%.1f%%", d_eff * 100), d_eff > 0.6 ? "var(--colour-chr4-tongre)" : "var(--colour-chr5-hueyel)"), xs=6, md=3),
                            dbc_col(Gui_Base.BASE_MiniVitals_DDEF("Condition #", @sprintf("%.1e", metrics["Condition"]), metrics["Condition"] < 1e4 ? "var(--colour-chr4-tongre)" : "var(--colour-chr0-huered)"), xs=6, md=3),
                            dbc_col(Gui_Base.BASE_MiniVitals_DDEF("A-Efficiency", @sprintf("%.2f", metrics["A"]), "var(--colour-chr3-toncya)"), xs=6, md=3),
                            dbc_col(Gui_Base.BASE_MiniVitals_DDEF("G-Efficiency", @sprintf("%.2f", metrics["G"]), "var(--colour-chr3-toncya)"), xs=6, md=3),
                        ], className="mb-3 g-2")
                ]),

                # Stoichiometry Section
                html_div([
 html_div("Chemical Stoichiometry", className="small fw-bold mb-1", style=Dict("color" => "var(--colour-val3-darlow)")),
                    dbc_alert([
                            html_i(className="fas $(valid_stoi ? "fa-check-circle" : "fa-exclamation-triangle") me-2"),
                            html_strong(valid_stoi ? "PHASE FEASIBLE: " : "PHASE VIOLATION: "),
                            valid_stoi ? "All experimental coordinates are physically accessible within the search space." : stoi_issues
                        ], style=Dict("backgroundColor" => valid_stoi ? "var(--colour-chr4-tongre)" : "var(--colour-chr0-huered)", "color" => "var(--colour-val0-purwhi)"), className="py-2 small mb-3")
                ]),

                # Mass Audit Section
                html_div([
 html_div("Mass Inventory (per run)", className="small fw-bold mb-1", style=Dict("color" => "var(--colour-val3-darlow)")),
                    dbc_row([
                            dbc_col(html_div([
 html_span("Min Mass:", className="small", style=Dict("color" => "var(--colour-val4-darhig)")),
                                    html_span(@sprintf("%.4f mg", min_mass), className="fw-bold")
                                ]), xs=6),
                            dbc_col(html_div([
 html_span("Max Mass:", className="small", style=Dict("color" => "var(--colour-val4-darhig)")),
                                    html_span(@sprintf("%.4f mg", max_mass), className="fw-bold")
                                ]), xs=6),
 ], className="p-2 rounded small mb-3", style=Dict("backgroundColor" => "var(--colour-val0-purwhi)"))
                ]), html_div([
                        html_i(className="fas fa-info-circle me-2"),
                        "This audit simulates the full experimental matrix based on your current settings. Passing this check ensures a high probability of successful protocol execution."
 ], className="small italic border-top pt-2", style=Dict("color" => "var(--colour-val3-darlow)"))
            ]), true

        catch e
            bt = sprint(showerror, e, catch_backtrace())
            return html_div("Scientific Audit Failed: $e", className="", style=Dict("color" => "var(--colour-chr0-huered)")), true
        end
    end

    # --- 10. STOICHIOMETRIC COMPONENTS LIST UPDATE ---
    callback!(app,
        Output("deck-stoch-list-display", "children"),
        Input("deck-store-factors", "data"),
        Input("deck-store-stoch-settings", "data"),
        prevent_initial_call=false
    ) do stored, stoch_settings
        isnothing(stored) && return ""
        rows_raw = get(stored, "rows", get(stored, :rows, []))
        
        # Convert to Any[] to avoid JSON3.Object push! MethodError
        stoch_items = Any[]
        
        # Collect items from factors table
        for r in rows_raw
            name = strip(string(get(r, "Name", get(r, :Name, ""))))
            mw   = Sys_Fast.FAST_SafeNum_DDEF(get(r, "MW", get(r, :MW, 0.0)))
            if !isempty(name) && mw > 0.0
                push!(stoch_items, Dict("Name" => name, "MW" => mw, "Role" => get(r, "Role", "Fixed")))
            end
        end
        
        # Add virtual filler from modal
        if !isnothing(stoch_settings)
            f_name = strip(string(get(stoch_settings, "FillerName", get(stoch_settings, :FillerName, ""))))
            f_mw   = Sys_Fast.FAST_SafeNum_DDEF(get(stoch_settings, "FillerMW", get(stoch_settings, :FillerMW, 0.0)))
            if !isempty(f_name) && f_mw > 0.0
                if !any(x -> lowercase(strip(string(get(x, "Name", "")))) == lowercase(f_name), stoch_items)
                    push!(stoch_items, Dict("Name" => f_name, "MW" => f_mw, "Role" => "Filler"))
                end
            end
        end
        
        if isempty(stoch_items)
            return html_div("No stoichiometric components defined.", 
                className="small italic text-center colourtx-v4dh p-3",
                style=Dict("opacity" => "0.6"))
        end
        
        return html_div([
            html_div([
                html_i(className="fas fa-check-circle me-2", style=Dict("fontSize" => "0.7rem", "color" => "var(--colour-chr4-tongre)")),
                html_span(string(get(item, "Name", get(item, :Name, "Unnamed"))), className="fw-bold"),
                (get(item, "Role", "") == "Filler" ? html_span(" [FILLER]", className="ms-2 small colourtx-c1sm", style=Dict("fontSize" => "0.6rem")) : "")
            ], className="mb-2 p-1 border-bottom", style=Dict("borderColor" => "var(--colour-val1-lighig)"))
            for item in stoch_items
        ], className="p-1")
    end

end
end # module
