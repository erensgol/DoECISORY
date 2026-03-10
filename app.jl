# ======================================================================================
# DAISHODOE - MAIN APPLICATION ENTRY
# ======================================================================================
# ======================================================================================
# Version: v1.0 In Dev.
# Author: Ecz. Eren Selim GÖL
# ======================================================================================

# --- Headless & Stability Overrides ---
# Must be set BEFORE loading any graphics libraries
ENV["GKSwstype"] = "100"
ENV["JULIA_WEBIO_NOT_AVAILABLE"] = "1"
ENV["PLOTLY_KALEIDO_NO_SANDBOX"] = "1"

# --- Core Dependencies ---
using Dash
using DashBootstrapComponents
using Pkg
using DataFrames
using PlotlyJS

# --- HuggingFace Spaces Detection ---
const APP_IsHfSpaces_DDEC = haskey(ENV, "SPACE_ID")
const APP_Port_DDEC = if APP_IsHfSpaces_DDEC
    parse(Int, get(ENV, "PORT", "7860"))
else
    8060 # Local standard port
end

# --- Hot Reload Support (Strictly Local Only) ---
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

# --- Module Scope Fix ---
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

# --- Terminal Identity (Official Julia REPL) ---
println("\e[1m               \e[32m_\e[0m")
println("\e[1m   \e[34m_\e[0m       _ \e[31m_\e[32m(_)\e[35m_\e[0m     |  \e[1mDaishoDoE Engine\e[0m v1.0 In Dev.")
println("\e[1m  \e[34m(_)\e[0m     | \e[31m(_)\e[0m \e[35m(_)\e[0m    |")
println("\e[1m   _ _   _| |_  __ _   |  Official Research Software")
println("\e[1m  | | | | | | |/ _` |  |")
println("\e[1m  | | |_| | | | (_| |  |  Developed for Hacettepe University")
println("\e[1m _/ |\\__'_|_|_|\\__'_|  |  System Status: \e[32m[OPTIMAL]\e[0m")
println("\e[1m|__/                   |")

# Performance Status
let (n_threads, _, _) = Sys_Fast.FAST_GetThreadInfo_DDEF()
    status = n_threads > 1 ? "[OPTIMAL]" : "\e[31m[LIMITED]\e[0m"
    println("\n\e[1m  Computing Core: \e[0m\e[32m$n_threads Threads\e[0m $status")
    println("\e[1m  System Wisdom:  \e[0m\e[36m\"$(Sys_Fast.FAST_GetSystemQuote_DDEF())\"\e[0m")
    println()
end

# --------------------------------------------------------------------------------------
# --- MODULE INTEGRATION ---
# --------------------------------------------------------------------------------------

for (label, file) in [
    ("Molecule Engine: Lib_Mole", "src/Lib_Mole.jl"),
    ("Visual Engine: Lib_Arts", "src/Lib_Arts.jl"),
    ("Algorithm Core: Lib_Core", "src/Lib_Core.jl"),
    ("System Flow Bus: Sys_Flow", "src/Sys_Flow.jl"),
    ("Analysis Suite: Lib_Vise", "src/Lib_Vise.jl"),
    ("GUI Base Component: Gui_Base", "src/Gui_Base.jl"),
    ("GUI Design Deck: Gui_Deck", "src/Gui_Deck.jl"),
    ("GUI Analysis Lens: Gui_Lens", "src/Gui_Lens.jl"),
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

# Explicitly bring all modules into the current namespace (even for sub-processes)
using Main.Lib_Arts
using Main.Lib_Core
using Main.Lib_Mole
using Main.Lib_Vise
using Main.Sys_Fast
using Main.Sys_Flow
using Main.Gui_Base
using Main.Gui_Deck
using Main.Gui_Lens

FAST_Log_DDEF("BOOT", "Complete", "Core Libraries Integrated", "OK")

# --------------------------------------------------------------------------------------
# --- TRANSIENT HOUSEKEEPING ---
# --------------------------------------------------------------------------------------
Sys_Fast.FAST_InitialiseWorkforce_DDEF()

# --------------------------------------------------------------------------------------
# --- APP CONFIGURATION ---
# --------------------------------------------------------------------------------------

FAST_Log_DDEF("INIT", "Setup", "Configuring Dash Framework...", "WAIT")
# Pathname prefix handling for HF Spaces
pathname_prefix = get(ENV, "DASH_REQUESTS_PATHNAME_PREFIX", "/")

app = dash(;
    requests_pathname_prefix=pathname_prefix,
    external_stylesheets=[
        DashBootstrapComponents.dbc_themes.BOOTSTRAP,
        "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css",
        "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&display=swap",
    ],
    suppress_callback_exceptions=true,
)

app.title = "DaishoDoE"

app.index_string = """
<!DOCTYPE html>
<html>
    <head>
        {%metas%}
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

# --------------------------------------------------------------------------------------
# --- UI COMPONENTS ---
# --------------------------------------------------------------------------------------

# 1. Navigation Controller (Constant UI)
const APP_Navbar_DDEC = html_div([
        html_div([
                dcc_link(html_div([
                            html_img(src="/assets/favicon.ico", style=Dict("height" => "32px", "marginRight" => "10px", "borderRadius" => "4px")),
                            html_span("DaishoDoE", className="text-dark fw-bold tracking-tight"),
                        ], className="nav-brand"), href="/", style=Dict("textDecoration" => "none")),
            ], style=Dict("flex" => "1")),
        html_div([
                html_a("Design", href="/design", className="nav-item"),
                html_a("Analyse", href="/analysis", className="nav-item"),
            ], className="nav-links d-flex justify-content-center"),
        html_div([
                html_span("v1.0 In Dev.", className="badge opacity-75", style=Dict("backgroundColor" => "var(--colour-val3-darlow)", "color" => "var(--colour-val0-purwhi)")),
            ], className="nav-actions", style=Dict("flex" => "1", "textAlign" => "right")),
    ], className="glass-navbar d-flex align-items-center justify-content-between")

# 2. Page Content Render Area (Constant UI)
const APP_Content_DDEC = html_div(id="page-content", className="app-container")

# 3. Main Application Framework
const APP_SystemReady_DDEC = Threads.Atomic{Bool}(false)

app.layout = html_div([
    dcc_location(id="url", refresh=false),
    APP_Navbar_DDEC,
    APP_Content_DDEC,

    # Global State Architecture
    dcc_store(id="store-session-config", storage_type="session"),
    dcc_store(id="store-master-vault", storage_type="session"),

    # Master Sync Bus
    dcc_store(id="sync-deck-content", storage_type="memory"),
    dcc_store(id="sync-lens-content", storage_type="memory"),
    dcc_store(id="sync-lens-analysis", storage_type="memory"),
    dbc_toast(id="global-toast",
        header="System Notification", is_open=false, dismissable=true,
        duration=4000, icon="danger",
        style=Dict("position" => "fixed", "top" => 60, "right" => 20,
            "width" => 350, "zIndex" => 9999)),

    # Comprehensive Diagnostics Modal
    dbc_modal([
            dbc_modalheader("System Diagnostics & Scientific Integrity"),
            dbc_modalbody([
                dbc_tabs([
                        dbc_tab([
                                html_div(html_pre(id="modal-diagnostics-sys-content", style=Dict("whiteSpace" => "pre-wrap", "fontSize" => "0.85rem")), className="p-3")
                            ], label="System Health", tab_id="tab-sys"),
                        dbc_tab([
                                html_div(dcc_markdown(id="modal-diagnostics-sci-content"), className="p-3")
                            ], label="Scientific Integrity", tab_id="tab-sci"),
                    ], id="modal-diagnostics-tabs", active_tab="tab-sys")
            ]),
            dbc_modalfooter(dbc_button("Close", id="btn-close-diagnostics", className="ms-auto", n_clicks=0))
        ], id="modal-diagnostics", size="xl", is_open=false),

    # System readiness overlay + polling
    dcc_interval(id="sys-ready-poll", interval=2000, max_intervals=-1),
    html_div(id="sys-loading-overlay", children=[
            html_div([
                    html_div(className="spinner-border text-primary mb-3", style=Dict("width" => "3rem", "height" => "3rem")),
                    html_h4("DaishoDoE", className="fw-bold mb-2", style=Dict("color" => "var(--colour-val5-purbla)")),
                    html_p("Synchronising scientific modules...", style=Dict("color" => "var(--colour-val3-darlow)"), id="sys-loading-msg"),
                ], style=Dict(
                    "display" => "flex", "flexDirection" => "column", "alignItems" => "center",
                    "justifyContent" => "center", "height" => "100vh",
                )),
        ], style=Dict(
            "position" => "fixed", "top" => "0", "left" => "0", "width" => "100vw", "height" => "100vh",
            "backgroundColor" => "var(--colour-val2-liglow)", "zIndex" => "99999", "display" => "flex",
            "alignItems" => "center", "justifyContent" => "center",
        )),
])

# --------------------------------------------------------------------------------------
# --- ROUTING & CALLBACK ORCHESTRATION ---
# --------------------------------------------------------------------------------------

# 1. Global State Sync Bus
"""
    APP_SyncVault_DDEF(deck, lens, lens_analysis) -> Any
Orchestrates the synchronisation of data between UI components and the session store.
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
    Output("store-master-vault", "data"),
    Input("sync-deck-content", "data"),
    Input("sync-lens-content", "data"),
    Input("sync-lens-analysis", "data"),
    prevent_initial_call=true
) do deck, lens, lens_analysis
    return APP_SyncVault_DDEF(deck, lens, lens_analysis)
end

# 2. Main Navigation Orchestrator
"""
    APP_RoutePage_DDEF(pathname::String) -> Any
Handles top-level routing and renders the appropriate layout or portal dashboard.
"""
function APP_RoutePage_DDEF(pathname::String)
    if pathname == "/design"
        return DECK_Layout_DDEF()
    elseif pathname == "/analysis"
        return LENS_Layout_DDEF()
    else
        # --- PORTAL DASHBOARD ---
        nt::Int, tstyle::String, tmsg::String = Sys_Fast.FAST_GetThreadInfo_DDEF()
        return html_div([
            # Hero Section
            dbc_container([
                    dbc_row(dbc_col([
                            html_h1("DaishoDoE", className="fw-bold display-4 mb-3", style=Dict("letterSpacing" => "-0.04em", "color" => "var(--colour-val5-purbla)")),
                            html_p("A Decision-Adaptive, Interactive, and Sequential Hybrid Optimisation Environment for Design of Experiments (DoE) Processes",
                                className="lead text-secondary mb-5", style=Dict("maxWidth" => "800px", "margin" => "0 auto")),
                        ], xs=12, className="text-center mt-5 pt-4")),

                    # Action Cards
                    dbc_row([
                            # Design Card
                            dbc_col([
                                    dcc_link(html_div([
                                                html_div(html_i(className="fas fa-flask text-white"),
                                                    style=Dict("width" => "50px", "height" => "50px", "borderRadius" => "12px",
                                                        "background" => "linear-gradient(135deg, var(--colour-chr0-huered) 0%, var(--colour-chr5-hueyel) 100%)",
                                                        "display" => "flex", "alignItems" => "center", "justifyContent" => "center",
                                                        "fontSize" => "1.5rem", "marginBottom" => "1.5rem", "boxShadow" => "0 10px 20px -5px var(--colour-val2-liglow)")),
                                                html_h3("Experimental Design", className="fw-bold mb-2", style=Dict("color" => "var(--colour-val5-purbla)")),
                                                html_p("Synthesise robust test matrices utilising Box-Behnken and Taguchi methodologies. Automatically generate protocol workspaces for 3-factor experimental architectures.",
                                                    className="text-secondary small mb-0", style=Dict("lineHeight" => "1.6")),
                                            ], className="glass-panel h-100 p-4", style=Dict("transition" => "transform 0.2s ease, box-shadow 0.2s ease", "cursor" => "pointer")); href="/design", style=Dict("textDecoration" => "none")),
                                ], xs=12, md=6, className="mb-4"),

                            # Analysis Card
                            dbc_col([
                                    dcc_link(html_div([
                                                html_div(html_i(className="fas fa-chart-line text-white"),
                                                    style=Dict("width" => "50px", "height" => "50px", "borderRadius" => "12px",
                                                        "background" => "linear-gradient(135deg, var(--colour-chr3-toncya) 0%, var(--colour-chr3-toncya) 100%)",
                                                        "display" => "flex", "alignItems" => "center", "justifyContent" => "center",
                                                        "fontSize" => "1.5rem", "marginBottom" => "1.5rem", "boxShadow" => "0 10px 20px -5px var(--colour-val2-liglow)")),
                                                html_h3("Statistical Analysis", className="fw-bold mb-2", style=Dict("color" => "var(--colour-val5-purbla)")),
                                                html_p("Execute rigorous data analysis via GLM regression, dynamically visualise desirability functions, and determine optimal formulations through mathematical modelling.",
                                                    className="text-secondary small mb-0", style=Dict("lineHeight" => "1.6")),
                                            ], className="glass-panel h-100 p-4", style=Dict("transition" => "transform 0.2s ease, box-shadow 0.2s ease", "cursor" => "pointer")); href="/analysis", style=Dict("textDecoration" => "none")),
                                ], xs=12, md=6, className="mb-4"),
                        ], className="g-4 mb-5", style=Dict("maxWidth" => "900px", "margin" => "0 auto")),

                    # System Diagnostics Footer
                    dbc_row(dbc_col(html_div([
                                    html_div([
                                            html_div([html_i(className="fas fa-server me-2", style=Dict("color" => "var(--colour-chr4-tongre)")), html_span("System Online", className="fw-bold", style=Dict("color" => "var(--colour-val3-darlow)"))], className="d-flex align-items-center me-4"),
                                            html_div([html_i(className="fas fa-microchip me-2", style=Dict("color" => "var(--colour-chr3-toncya)")), html_span(tmsg, className="fw-bold", style=Dict("color" => "var(--colour-val3-darlow)"))], className="d-flex align-items-center me-4"),
                                            html_div([
                                                    html_span([html_i(className="fas fa-cog me-1"), "Diagnostics"],
                                                        id="btn-open-sys-audit", className="badge border",
                                                        style=Dict("cursor" => "pointer", "backgroundColor" => "var(--colour-val1-lighig)", "color" => "var(--colour-val5-purbla)"))
                                                ], className="d-flex align-items-center"),
                                        ], className="d-flex justify-content-center align-items-center p-3 rounded-pill",
                                        style=Dict("background" => "var(--colour-val0-purwhi)", "border" => "1px solid var(--colour-val2-liglow)", "boxShadow" => "0 4px 6px -1px var(--colour-val1-lighig)", "display" => "inline-flex", "margin" => "0 auto"))
                                ], className="text-center"), xs=12), style=Dict("maxWidth" => "900px", "margin" => "0 auto")),], fluid=true, className="pb-5 mt-2")
        ])
    end
end

callback!(app, Output("page-content", "children"), Input("url", "pathname")) do pathname
    return APP_RoutePage_DDEF(isnothing(pathname) ? "/" : pathname)
end

callback!(app,
    Output("modal-diagnostics", "is_open"),
    Output("modal-diagnostics-sys-content", "children"),
    Output("modal-diagnostics-sci-content", "children"),
    Input("btn-open-sys-audit", "n_clicks"),
    Input("btn-close-diagnostics", "n_clicks"),
    State("modal-diagnostics", "is_open"),
    prevent_initial_call=true
) do n_open, n_close, is_open
    ctx = callback_context()
    if isempty(ctx.triggered)
        return false, Dash.no_update(), Dash.no_update()
    end

    trig = split(ctx.triggered[1].prop_id, ".")[1]

    if trig == "btn-open-sys-audit"
        if !isnothing(n_open) && n_open > 0
            return true, Sys_Fast.FAST_SystemAudit_DDEF(), Sys_Fast.FAST_ScientificAudit_DDEF()
        end
    elseif trig == "btn-close-diagnostics"
        return false, Dash.no_update(), Dash.no_update()
    end

    return is_open, Dash.no_update(), Dash.no_update()
end

# Loading overlay dismiss callback (polls until warmup completes)
"""
    APP_HandleLoadingOverlay_DDEF(n::Any) -> Tuple{Any, Bool}
Manages the visibility of the initial loading screen based on background JIT warmup status.
"""
function APP_HandleLoadingOverlay_DDEF(n::Any)
    ready::Bool = APP_SystemReady_DDEC[]
    n_val::Int = isnothing(n) ? 0 : Int(n)

    # Only log status if NOT ready, reduce frequency to ~1 min
    if !ready && n_val % 30 == 0
        Sys_Fast.FAST_Log_DDEF("BOOT", "UI_SYNC", "Status Check: Waiting for System Warmup... (Poll #$n_val)", "INFO")
    end

    if ready
        return Dict("display" => "none"), true
    end
    return Dash.no_update(), false
end

callback!(app,
    Output("sys-loading-overlay", "style"),
    Output("sys-ready-poll", "disabled"),
    Input("sys-ready-poll", "n_intervals")
) do n
    return APP_HandleLoadingOverlay_DDEF(n)
end

# Register Child Callbacks
DECK_RegisterCallbacks_DDEF(app)
LENS_RegisterCallbacks_DDEF(app)

# --------------------------------------------------------------------------------------
# --- JIT WARMUP ROUTINE ---
# --------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------
# --- SERVER EXECUTION & WARMUP ---
# --------------------------------------------------------------------------------------

# Lightweight warmup for HF Spaces to avoid startup timeout
"""
    APP_Warmup_DDEF() -> Nothing
Orchestrates JIT pre-compilation. Skips heavy lifting in Local Dev mode.
"""
function APP_Warmup_DDEF()::Nothing
    t0 = time()
    is_dev = get(ENV, "DAISHO_DEV", "false") == "true"

    # HF Spaces or non-dev environments need thorough warmup for production stability
    if APP_IsHfSpaces_DDEC && !is_dev
        FAST_Log_DDEF("BOOT", "Warmup", "Production Environment Detected (HF Spaces).", "WAIT")
        sleep(2)
    elseif is_dev
        FAST_Log_DDEF("BOOT", "Warmup", "Development Mode: Fast Boot triggered.", "INFO")
        Sys_Fast.FAST_SafeNum_DDEF("1.0")
        APP_SystemReady_DDEC[] = true
        return nothing
    end

    FAST_Log_DDEF("BOOT", "Warmup", "Initiating Scientific JIT Pulse...", "WAIT")

    try
        # 1. Type system & Core Logic
        Sys_Fast.FAST_SafeNum_DDEF("42.0")
        dummy_rows = [Dict{String,Any}("Name" => "A", "Role" => "Variable", "L1" => 1, "L2" => 2, "L3" => 3, "MW" => 100, "Unit" => "mg")]
        
        # 2. Physics & Chemistry
        Lib_Mole.MOLE_ParseTable_DDEF(dummy_rows)
        Lib_Mole.MOLE_CalcMass_DDEF(String["A"], Float64[100.0], Float64[100.0], 5.0, 10.0)

        # 3. Analytics (Basic Regress only, no plotting/heavy rendering)
        X_dummy = Float64[1 2; 3 4; 5 6; 7 8]
        Y_dummy = Float64[10, 20, 30, 40]
        Lib_Vise.VISE_Regress_DDEF(X_dummy, Y_dummy, "linear")
        
        # Memory Housekeeping
        GC.gc()
    catch e
        FAST_Log_DDEF("BOOT", "Warmup_Warn", "JIT pulse encountered warnings: $e", "WARN")
    end

    APP_SystemReady_DDEC[] = true
    elapsed = round(time() - t0; digits=2)
    FAST_Log_DDEF("BOOT", "Warmup", "JIT complete ($(elapsed)s) — System Ready.", "OK")
    return nothing
end

# Launch warmup
Threads.@spawn APP_Warmup_DDEF()

try
    env_label = APP_IsHfSpaces_DDEC ? "Cloud (HF Spaces)" : "Local $(Threads.nthreads())T"
    Sys_Fast.FAST_Log_DDEF("SERVER", "Ready",
        "DaishoDoE Engine listening on :$(APP_Port_DDEC) ($env_label)", "OK")

    run_server(app, "0.0.0.0", APP_Port_DDEC; debug=false)
catch e
    println("\n>>> CRITICAL SERVER ERROR: $e")
    rethrow(e)
end
