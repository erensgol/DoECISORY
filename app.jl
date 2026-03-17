# ==============================================================================
# DAISHODOE PROJECT - APP MAIN
# ==============================================================================
# Description: Primary application entry point, routing orchestrator, and UI layout definition.
# Author:      Ecz. Eren Selim GÖL
# Version:     v1.0-dev
# Module Tag:  APP
# ==============================================================================

# ==============================================================================
# PART A: SYSTEM ARCHITECTURE & INITIALISATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: ENVIRONMENT & STABILITY CONFIGURATIONS
# ------------------------------------------------------------------------------

ENV["GKSwstype"]               = "100"
ENV["JULIA_WEBIO_NOT_AVAILABLE"] = "1"
ENV["PLOTLY_KALEIDO_NO_SANDBOX"] = "1"

using Dash
using DashBootstrapComponents
using Pkg
using DataFrames
using PlotlyJS
using Logging
using LoggingExtras

# ------------------------------------------------------------------------------
# SECTION 2: INFRASTRUCTURE DETECTION
# ------------------------------------------------------------------------------

const APP_IsHfSpaces_DDEC = haskey(ENV, "SPACE_ID")
const APP_Port_DDEC       = if APP_IsHfSpaces_DDEC
    parse(Int, get(ENV, "PORT", "7860"))
else
    8060 
end

const APP_HasRevise_DDEC = if APP_IsHfSpaces_DDEC
    false
else
    try
        using Revise
        true
    catch
        false
    end
end

# ------------------------------------------------------------------------------
# SECTION 3: BOOTSTRAP INCLUDES & MODULE SCOPE
# ------------------------------------------------------------------------------

try
    if APP_HasRevise_DDEC && !haskey(ENV, "DASH_DEBUG")
        Revise.includet("src/Sys_Fast.jl")
    else
        include("src/Sys_Fast.jl")
    end
catch e
    println("CRITICAL ERROR: Failed to load Sys_Fast.jl: $e")
    rethrow(e)
end
using Main.Sys_Fast
Sys_Fast.FAST_InitialiseWorkforce_DDEF()

# ------------------------------------------------------------------------------
# SECTION 4: TERMINAL IDENTITY & SYSTEM REPORTING
# ------------------------------------------------------------------------------

println("\e[1m               \e[32m_\e[0m")
println("\e[1m   \e[34m_\e[0m       _ \e[31m_\e[32m(_)\e[35m_\e[0m     |")
println("\e[1m  \e[34m(_)\e[0m     | \e[31m(_)\e[0m \e[35m(_)\e[0m    |  System Status: \e[32m[OPTIMAL]\e[0m")
println("\e[1m   _ _   _| |_  __ _   |  \e[1mDaishoDoE Software\e[0m v1.0-dev")
println("\e[1m  | | | | | | |/ _` |  |  Author: E.S. GÖL, Pharmacist  ")
println("\e[1m  | | |_| | | | (_| |  |  Department of Radiopharmacy")
println("\e[1m _/ |\\__'_|_|_|\\__'_|  |  Hacettepe University. 2026.")
println("\e[1m|__/                   |")

let (n_threads, _, _) = Sys_Fast.FAST_GetThreadInfo_DDEF()
    status = n_threads > 1 ? "[OPTIMAL]" : "\e[31m[LIMITED]\e[0m"
    println("\n\e[1m  Computing Core: \e[0m\e[32m$n_threads Threads\e[0m $status")
    println("\e[1m  System Wisdom:  \e[0m\e[36m\"$(Sys_Fast.FAST_GetSystemQuote_DDEF())\"\e[0m\n")
end

# ------------------------------------------------------------------------------
# SECTION 5: MODULE INTEGRATION BUS
# ------------------------------------------------------------------------------

for (label, file) in [
    ("Molecule Engine: Lib_Mole",   "src/Lib_Mole.jl"),
    ("Visual Engine: Lib_Arts",     "src/Lib_Arts.jl"),
    ("Algorithm Core: Lib_Core",     "src/Lib_Core.jl"),
    ("System Flow Bus: Sys_Flow",     "src/Sys_Flow.jl"),
    ("Analysis Suite: Lib_Vise",      "src/Lib_Vise.jl"),
    ("GUI Base Component: Gui_Base", "src/Gui_Base.jl"),
    ("GUI Design Deck: Gui_Deck",    "src/Gui_Deck.jl"),
    ("GUI Analysis Lens: Gui_Lens",  "src/Gui_Lens.jl"),
]
    !APP_IsHfSpaces_DDEC && FAST_Log_DDEF("BOOT", "Loading", label, "INFO")
    try
        if APP_HasRevise_DDEC && !haskey(ENV, "DASH_DEBUG")
            Revise.includet(file)
        else
            include(file)
        end
    catch e
        println("CRITICAL ERROR: Failed to load $label ($file): $e")
        rethrow(e)
    end
end

using Main.Lib_Arts
using Main.Lib_Core
using Main.Lib_Mole
using Main.Lib_Vise
using Main.Sys_Fast
using Main.Sys_Flow
using Main.Gui_Base
using Main.Gui_Deck
using Main.Gui_Lens

FAST_Log_DDEF("BOOT", "Complete", "All Modules Integrated", "OK")

Sys_Fast.FAST_InitialiseWorkforce_DDEF()

# ==============================================================================
# PART B: UI FRAMEWORK & DASH LAYOUT
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 6: DASH APP INITIALISATION
# ------------------------------------------------------------------------------

FAST_Log_DDEF("INIT", "Setup", "Configuring Dash Framework...", "WAIT")
pathname_prefix = get(ENV, "DASH_REQUESTS_PATHNAME_PREFIX", "/")

app = dash(;
    requests_pathname_prefix     = pathname_prefix,
    external_stylesheets         = [
        DashBootstrapComponents.dbc_themes.BOOTSTRAP,
        "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css",
        "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&display=swap",
    ],
    suppress_callback_exceptions = true,
)

app.title = "DaishoDoE"

app.index_string = """
<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{%title%}</title>
        {%favicon%}
        {%css%}
    </head>
    <body class="dash-template">
        {%app_entry%}
        <footer>
            {%config%}
            {%scripts%}
            {%renderer%}
        </footer>
        <script>
            /* Navigation guards removed for seamless page transitions */
        </script>
    </body>
</html>
"""

# ------------------------------------------------------------------------------
# SECTION 7: GLOBAL UI COMPONENTS
# ------------------------------------------------------------------------------

const APP_Navbar_DDEC = html_div([
    html_div([
        dcc_link(html_div([
            html_img(src="/assets/favicon.ico", style=Dict("height" => "32px", "marginRight" => "10px", "borderRadius" => "4px")),
            html_span("DaishoDoE", className="fw-bold tracking-tight", style=Dict("color" => "var(--colour-val5-purbla)")),
        ], className="nav-brand"), href="/", style=Dict("textDecoration" => "none")),
    ], style=Dict("flex" => "1")),

    html_div([
        html_a("Design",  href="/design",   className="nav-item"),
        html_a("Analyse", href="/analysis", className="nav-item"),
    ], className="nav-links d-flex justify-content-center"),

    html_div([
        html_span("v1.0-dev", 
            className="badge opacity-75", 
            style=Dict("backgroundColor" => "var(--colour-val3-darlow)", "color" => "var(--colour-val0-purwhi)")
        ),
    ], className="nav-actions", style=Dict("flex" => "1", "textAlign" => "right")),
], className="glass-navbar d-flex align-items-center justify-content-between")

const APP_Content_DDEC = html_div(id="page-content", className="app-container")

# ------------------------------------------------------------------------------
# SECTION 8: APPLICATION PERSISTENCE STORES
# ------------------------------------------------------------------------------

const APP_SystemReady_DDEC = Threads.Atomic{Bool}(false)

app.layout = html_div([
    dcc_location(id="url", refresh=false),
    APP_Navbar_DDEC,
    APP_Content_DDEC,

    dcc_store(id="store-session-config", storage_type="memory"),
    dcc_store(id="store-master-vault",   storage_type="memory"),
    dcc_store(id="sync-deck-content",  storage_type="memory"),
    dcc_store(id="sync-lens-content",  storage_type="memory"),
    dcc_store(id="sync-lens-analysis", storage_type="memory"),
    dcc_store(id="lens-store-diag-force", data=0, storage_type="memory"),

    dbc_toast(id="global-toast",
        header="System Notification", is_open=false, dismissable=true,
        duration=4000, icon="danger",
        style=Dict(
            "position" => "fixed", "top" => 60, "right" => 20,
            "width"    => 350, "zIndex" => 9999
        )
    ),

# ------------------------------------------------------------------------------
# SECTION 9: DIAGNOSTICS MODAL ARCHITECTURE
# ------------------------------------------------------------------------------

    dbc_modal([
        dbc_modalheader("System Diagnostics & Scientific Integrity"),
        dbc_modalbody([
            dbc_tabs([
                dbc_tab([
                    html_div(id="modal-diagnostics-sys-content", className="p-3 d-flex flex-column justify-content-center")
                ], label="System Health", tab_id="tab-sys"),
                dbc_tab([
                    html_div(id="modal-diagnostics-sci-content", className="p-3 d-flex flex-column justify-content-center")
                ], label="Scientific Integrity", tab_id="tab-sci"),
            ], id="modal-diagnostics-tabs", active_tab="tab-sys")
        ]),
        dbc_modalfooter(dbc_button("Close", id="btn-close-diagnostics", className="ms-auto colourgl-c0hr", n_clicks=0, outline=false))
    ], id="modal-diagnostics", size="xl", is_open=false),

# ------------------------------------------------------------------------------
# SECTION 10: SYSTEM READINESS OVERLAY
# ------------------------------------------------------------------------------

    dcc_interval(id="sys-ready-poll", interval=500, max_intervals=-1),
    html_div(id="sys-loading-overlay", children=[
        html_div([
            html_div(className="sys-spinner"),
            html_h4("DaishoDoE", className="fw-bold mb-2 text-center", style=Dict("color" => "var(--colour-val5-purbla)")),
            html_p("Synchronising scientific modules...", className="text-center",
                style=Dict("color" => "var(--colour-val3-darlow)", "margin" => "0"), id="sys-loading-msg"),
        ], style=Dict(
            "position"      => "relative",
            "display"       => "flex", 
            "flexDirection" => "column", 
            "alignItems"    => "center",
            "justifyContent"=> "center", 
        )),
    ], style=Dict(
        "position"        => "fixed", 
        "top"             => "0", 
        "left"            => "0", 
        "width"           => "100vw", 
        "height"          => "100vh",
        "backgroundColor" => "var(--colour-val2-liglow)", 
        "zIndex"          => "99999", 
        "display"         => "flex",
        "alignItems"      => "center", 
        "justifyContent"  => "center",
    )),
])

# ==============================================================================
# PART C: ORCHESTRATION & CALLBACK BUS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 11: GLOBAL STATE SYNC CALLBACKS
# ------------------------------------------------------------------------------

"""
    APP_SyncVault_DDEF(deck, lens, lens_analysis) -> Any
Synchronises session data between the UI components and the master repository.
"""
function APP_SyncVault_DDEF(deck::Any, lens::Any, lens_analysis::Any)
    ctx = callback_context()
    isempty(ctx.triggered) && return Dash.no_update()
    
    trig::String = split(ctx.triggered[1].prop_id, ".")[1]

    if trig == "sync-deck-content"
        return deck
    elseif trig == "sync-lens-content"
        return lens
    else
        return lens_analysis
    end
end

callback!(app,
    Output("store-master-vault",  "data"),
    Input("sync-deck-content",    "data"),
    Input("sync-lens-content",    "data"),
    Input("sync-lens-analysis",   "data"),
    prevent_initial_call = true
) do deck, lens, lens_analysis
    return APP_SyncVault_DDEF(deck, lens, lens_analysis)
end

# ------------------------------------------------------------------------------
# SECTION 12: TOP-LEVEL ROUTING & NAVIGATION
# ------------------------------------------------------------------------------

"""
    APP_RoutePage_DDEF(pathname::String) -> Any
Top-level routing orchestrator for navigating between experimental and analytical modules.
"""
function APP_RoutePage_DDEF(pathname::String)
    if pathname == "/design"
        return DECK_Layout_DDEF()
    elseif pathname == "/analysis"
        return LENS_Layout_DDEF()
    else
        # Central application portal dashboard interface.
        nt::Int, tstyle::String, tmsg::String = Sys_Fast.FAST_GetThreadInfo_DDEF()
        
        return html_div([
            # Visual brand identity and scientific mission statement.
            dbc_container([
                dbc_row(dbc_col([
                    html_h1("DaishoDoE", 
                        className = "fw-bold display-4 mb-3", 
                        style     = Dict("letterSpacing" => "-0.04em", "color" => "var(--colour-val5-purbla)")
                    ),
                    html_p("A Decision-Adaptive, Interactive, and Sequential Hybrid Optimisation Environment for Design of Experiments (DoE) Processes",
                        className = "lead mb-2", 
                        style     = Dict("color" => "var(--colour-val4-darhig)", "maxWidth" => "800px", "margin" => "0 auto")
                    ),
                    html_p("Under active system development. No liability is assumed for the accuracy of results or computations during this phase.",
                        className = "small opacity-75 mb-5",
                        style     = Dict("color" => "var(--colour-val3-darlow)", "fontStyle" => "italic")
                    ),
                ], xs=12, className="text-center mt-5 pt-4")),

                dbc_row([
                    dbc_col([
                        dcc_link(html_div([
                            html_div(html_i(className="fas fa-flask", style=Dict("color" => "var(--colour-val0-purwhi)")),
                                style=Dict(
                                    "width"        => "50px", "height" => "50px", "borderRadius" => "12px",
                                    "background"   => "linear-gradient(135deg, var(--colour-chr0-huered) 0%, var(--colour-chr5-hueyel) 100%)",
                                    "display"      => "flex", "alignItems" => "center", "justifyContent" => "center",
                                    "fontSize"     => "1.5rem", "marginBottom" => "1.5rem", 
                                    "boxShadow"    => "0 10px 20px -5px var(--colour-val2-liglow)"
                                )
                            ),
                            html_h3("Experimental Design", className="fw-bold mb-2", style=Dict("color" => "var(--colour-val5-purbla)")),
                            html_p("Synthesise robust test matrices utilising Box-Behnken and Taguchi methodologies. Automatically generate protocol workspaces for 3-factor experimental architectures.",
                                className="small mb-0", style=Dict("color" => "var(--colour-val4-darhig)", "lineHeight" => "1.6")),
                        ], className="glass-panel h-100 p-4", style=Dict("transition" => "transform 0.2s ease, box-shadow 0.2s ease", "cursor" => "pointer")), href="/design", style=Dict("textDecoration" => "none")),
                    ], xs=12, md=6, className="mb-4"),

                    dbc_col([
                        dcc_link(html_div([
                            html_div(html_i(className="fas fa-chart-line", style=Dict("color" => "var(--colour-val0-purwhi)")),
                                style=Dict(
                                    "width"        => "50px", "height" => "50px", "borderRadius" => "12px",
                                    "background"   => "linear-gradient(135deg, var(--colour-chr1-shamag) 0%, var(--colour-val4-darhig) 100%)",
                                    "display"      => "flex", "alignItems" => "center", "justifyContent" => "center",
                                    "fontSize"     => "1.5rem", "marginBottom" => "1.5rem", 
                                    "boxShadow"    => "0 10px 20px -5px var(--colour-val3-darlow)"
                                )
                            ),
                            html_h3("Statistical Analysis", className="fw-bold mb-2", style=Dict("color" => "var(--colour-val5-purbla)")),
                            html_p("Execute rigorous data analysis via GLM regression, dynamically visualise desirability functions, and determine optimal formulations through mathematical modelling.",
                                className="small mb-0", style=Dict("color" => "var(--colour-val4-darhig)", "lineHeight" => "1.6")),
                        ], className="glass-panel h-100 p-4", style=Dict("transition" => "transform 0.2s ease, box-shadow 0.2s ease", "cursor" => "pointer")), href="/analysis", style=Dict("textDecoration" => "none")),
                    ], xs=12, md=6, className="mb-4"),
                ], className="g-4 mb-5", style=Dict("maxWidth" => "900px", "margin" => "0 auto")),

                dbc_row(dbc_col(html_div([
                    html_div([
                        html_div([
                            html_i(className="fas fa-server me-2", style=Dict("color" => "var(--colour-chr1-shamag)")), 
                            html_span("System Online", className="fw-bold", style=Dict("color" => "var(--colour-val3-darlow)"))
                        ], className="d-flex align-items-center me-4"),
                        html_div([
                            html_i(className="fas fa-microchip me-2", style=Dict("color" => "var(--colour-chr4-tongre)")), 
                            html_span(tmsg, className="fw-bold", style=Dict("color" => "var(--colour-val3-darlow)"))
                        ], className="d-flex align-items-center me-4"),
                        html_div([
                            html_span([html_i(className="fas fa-cog me-1"), "Diagnostics"],
                                id="btn-open-sys-audit", className="badge border", n_clicks=0,
                                style=Dict("cursor" => "pointer", "backgroundColor" => "var(--colour-val1-lighig)", "color" => "var(--colour-val5-purbla)"))
                        ], className="d-flex align-items-center"),
                    ], className="d-flex justify-content-center align-items-center p-3 rounded-pill",
                    style=Dict(
                        "background" => "var(--colour-val0-purwhi)", 
                        "border"     => "1px solid var(--colour-val2-liglow)", 
                        "boxShadow"  => "0 4px 6px -1px var(--colour-val1-lighig)", 
                        "display"    => "inline-flex", 
                        "margin"     => "0 auto"
                    ))
                ], className="text-center"), xs=12), style=Dict("maxWidth" => "900px", "margin" => "0 auto")),
            ], fluid=true, className="pb-5 mt-2")
        ])
    end
end

callback!(app, Output("page-content", "children"), Input("url", "pathname")) do pathname
    return APP_RoutePage_DDEF(isnothing(pathname) ? "/" : pathname)
end

# ------------------------------------------------------------------------------
# SECTION 13: DIAGNOSTICS ORCHESTRATOR
# ------------------------------------------------------------------------------

callback!(app,
    Output("modal-diagnostics",             "is_open"),
    Output("modal-diagnostics-sys-content", "children"),
    Output("modal-diagnostics-sci-content", "children"),
    Input("btn-open-sys-audit",             "n_clicks"),
    Input("btn-close-diagnostics",          "n_clicks"),
    State("modal-diagnostics",              "is_open"),
    prevent_initial_call = true
) do n_open, n_close, is_open
    ctx = callback_context()
    isempty(ctx.triggered) && return false, Dash.no_update(), Dash.no_update()

    trig = split(ctx.triggered[1].prop_id, ".")[1]

    if trig == "btn-open-sys-audit"
        if !isnothing(n_open) && n_open > 0
            return true, Gui_Base.BASE_SystemAuditUI_DDEF(), Gui_Base.BASE_ScientificAuditUI_DDEF()
        end
    elseif trig == "btn-close-diagnostics"
        return false, Dash.no_update(), Dash.no_update()
    end

    return is_open, Dash.no_update(), Dash.no_update()
end

# ------------------------------------------------------------------------------
# SECTION 14: EMERGENCY RECOVERY & LOCK RELEASE BUS
# ------------------------------------------------------------------------------

callback!(app,
    Output("lens-store-diag-force", "data"),
    Output("diag-global-output",    "children"),
    Input("btn-diag-force-unlock",  "n_clicks"),
    Input("btn-diag-clear-temp",    "n_clicks"),
    prevent_initial_call=true
) do n_lock, n_temp
    ctx = callback_context()
    isempty(ctx.triggered) && return Dash.no_update(), Dash.no_update()
    
    trig = split(ctx.triggered[1].prop_id, ".")[1]
    
    if trig == "btn-diag-force-unlock"
        (isnothing(n_lock) || n_lock == 0) && return Dash.no_update(), Dash.no_update()
        # Reset system-wide backend reentrant synchronisation locks.
        Sys_Fast.FAST_ForceReleaseAll_DDEF()
        
        # Emit frontend synchronisation signal via system timestamp.
        new_force = Int(round(time()))
        
        msg = html_div([
            html_span("✅ Force Open Lock: SUCCESS", className="fw-bold colourtx-c4tg d-block"),
            html_span("Backend locks cleared. System control guards reset.", className="x-small colourtx-v4dh")
        ], className="mt-2 text-center")
        
        return new_force, msg
        
    elseif trig == "btn-diag-clear-temp"
        (isnothing(n_temp) || n_temp == 0) && return Dash.no_update(), Dash.no_update()
        # Execute comprehensive purge of the backend workforce transient storage.
        Sys_Fast.FAST_CleanWorkforce_DDEF(true)
        
        msg = html_div([
            html_span("✅ Clear Temporary Files: SUCCESS", className="fw-bold colourtx-c4tg d-block text-center"),
            html_span("Transient storage directory successfully cleared and reset.", className="x-small colourtx-v4dh d-block text-center")
        ], className="mt-2")
        
        return Dash.no_update(), msg
    end
    
    return Dash.no_update(), Dash.no_update()
end

# ------------------------------------------------------------------------------
# SECTION 15: UI LOADING POLISH
# ------------------------------------------------------------------------------

"""
    APP_HandleLoadingOverlay_DDEF(n::Any) -> Tuple{Any, Bool}
Manages the visibility of the initial loading screen based on background JIT pre-compilation status.
"""
function APP_HandleLoadingOverlay_DDEF(n::Any)
    ready::Bool = APP_SystemReady_DDEC[]
    n_val::Int  = isnothing(n) ? 0 : Int(n)

    # Status check logging active during pre-operation phase with regulated polling frequency.
    if !ready && n_val % 30 == 0
        Sys_Fast.FAST_Log_DDEF("BOOT", "UI_SYNC", "Status Check: Waiting for System Pre-compilation... (Poll #$n_val)", "INFO")
    end

    if ready
        return Dict("display" => "none"), true
    end
    
    return Dash.no_update(), false
end

callback!(app,
    Output("sys-loading-overlay", "style"),
    Output("sys-ready-poll",      "disabled"),
    Input("sys-ready-poll",       "n_intervals")
) do n
    return APP_HandleLoadingOverlay_DDEF(n)
end

# ==============================================================================
# PART D: JIT PULSE & BOOTSTRAP
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 16: CHILD CALLBACK REGISTRATION & JIT WARMUP ROUTINE
# ------------------------------------------------------------------------------

DECK_RegisterCallbacks_DDEF(app)
LENS_RegisterCallbacks_DDEF(app)

# Accelerated warmup sequence configured for cloud deployment stability.
"""
    APP_Warmup_DDEF() -> Nothing
Orchestrates Just-In-Time (JIT) pre-compilation. Prioritises speed in local development environments.
"""
function APP_Warmup_DDEF()::Nothing
    t0     = time()
    is_dev = get(ENV, "DAISHO_DEV", "false") == "true"

    # Production environment integrity ensured through comprehensive scientific warmup.
    if APP_IsHfSpaces_DDEC && !is_dev
        FAST_Log_DDEF("BOOT", "Warmup", "Production Environment Detected (HF Spaces).", "WAIT")
        sleep(2)
    elseif is_dev
        FAST_Log_DDEF("BOOT", "Warmup", "Development Mode: Fast Boot triggered.", "INFO")
        Sys_Fast.FAST_SafeNum_DDEF("1.0")
        APP_SystemReady_DDEC[] = true
        return nothing
    end

    FAST_Log_DDEF("BOOT", "Pre-compilation", "Initiating Scientific JIT Pulse...", "WAIT")

    try
        Sys_Fast.FAST_SafeNum_DDEF("42.0")
        
        # Simulation mass data balanced to stoichiometric unity via relative mass units.
        names_mock  = String["A"]
        mw_mock     = Float64[100.0]
        ratios_mock = Float64[100.0]
        units_mock  = String["%M"]
        Lib_Mole.MOLE_CalcMass_DDEF(names_mock, mw_mock, ratios_mock, 5.0, 10.0, units_mock, 1.0; SuppressLog=true)
        
        # Synthesised audit batch parameters including auto-balancing filler components.
        table_mock = [Dict("Name"=>"A", "MW"=>100.0, "Unit"=>"%M", "Type"=>"Variable", "Min"=>0.0, "Max"=>50.0, "Mid"=>25.0, "Rows"=>[[Dict("Unit"=>"%M")]]),
                     Dict("Name"=>"W", "MW"=>18.0, "Unit"=>"%", "Type"=>"Filler", "Min"=>0.0, "Max"=>100.0, "Mid"=>50.0)]
        # Safe stochiometric configuration with proportional filler balance.
        design_mock = fill(20.0, 5, 1) 

        Lib_Mole.MOLE_AuditBatch_DDEF(table_mock, design_mock, 5.0, 10.0)

        X_dummy = rand(11, 3) 
        Y_dummy = rand(11, 1)
        names_in = ["X1", "X2", "X3"]
        mod_dummy = Lib_Vise.VISE_Regress_DDEF(X_dummy, vec(Y_dummy), "linear"; InNames=names_in)
        
        goals_dummy = [Dict("Type"=>"Maximise", "Weight"=>1.0)]
        mod_dummy["Goal"] = goals_dummy[1]
        
        bounds_dummy = [0.0 1.0; 0.0 1.0; 0.0 1.0]
        Lib_Vise.VISE_GridSearch_DDEF([mod_dummy], goals_dummy, bounds_dummy)
        
        GC.gc()
    catch e
        FAST_Log_DDEF("BOOT", "Warmup_Warn", "JIT pulse encountered warnings: $e", "WARN")
    end

    APP_SystemReady_DDEC[] = true
    elapsed                = round(time() - t0; digits=2)
    
    FAST_Log_DDEF("BOOT", "Pre-compilation", "JIT complete ($(elapsed)s) — System Ready.", "OK")
    return nothing
end

# ------------------------------------------------------------------------------
# SECTION 17: SERVER BOOTSTRAP & ASYNC LAUNCH
# ------------------------------------------------------------------------------

Threads.@spawn APP_Warmup_DDEF()

try
    env_label = APP_IsHfSpaces_DDEC ? "Cloud (HF Spaces)" : "Local $(Threads.nthreads())T"
    
    Sys_Fast.FAST_Log_DDEF("SERVER", "Ready", "DaishoDoE Engine listening on :$(APP_Port_DDEC) ($env_label)", "OK")
    custom_logger = EarlyFilteredLogger(current_logger()) do log
        if log.level == Logging.Error && contains(string(log.message), "operation canceled")
            Sys_Fast.FAST_Log_DDEF("SERVER", "DISCONNECT", "Connection reset by browser (ECANCELED)", "INFO")
            return false
        end
        return true
    end

    with_logger(custom_logger) do
        run_server(app, "0.0.0.0", APP_Port_DDEC; debug=false)
    end
catch e
    println("\n>>> CRITICAL SERVER BOOT ERROR: $e")
    rethrow(e)
end