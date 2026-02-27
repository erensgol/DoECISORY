# ======================================================================================
# DAISHODOE - MAIN APPLICATION ENTRY
# ======================================================================================
# Version: 1.0.0
# Author: Ecz. Eren Selim GÖL
# ======================================================================================

using Dash
using DashBootstrapComponents
using Pkg
using DataFrames

include("src/Sys_Fast.jl")
using .Sys_Fast

# --- Terminal Identity (Official Julia REPL) ---
println("\e[1m               \e[32m_\e[0m")
println("\e[1m   \e[34m_\e[0m       _ \e[31m_\e[32m(_)\e[35m_\e[0m     |  \e[1mDaishoDoE Engine\e[0m v1.0 (2026)")
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
    println()
end

# --------------------------------------------------------------------------------------
# MODULE INTEGRATION
# --------------------------------------------------------------------------------------

for (label, file) in [
    ("Visual Engine: Lib_Arts", "src/Lib_Arts.jl"),
    ("Algorithm Core: Lib_Core", "src/Lib_Core.jl"),
    ("Molecule Engine: Lib_Mole", "src/Lib_Mole.jl"),
    ("Analysis Suite: Lib_Vise", "src/Lib_Vise.jl"),
    ("System Flow Bus: Sys_Flow", "src/Sys_Flow.jl"),
    ("GUI Base Component: Gui_Base", "src/Gui_Base.jl"),
    ("GUI Design Deck: Gui_Deck", "src/Gui_Deck.jl"),
    ("GUI Analysis Lens: Gui_Lens", "src/Gui_Lens.jl"),
]
    FAST_Log_DDEF("BOOT", "Loading", label, "INFO")
    include(file)
end

using .Sys_Fast
using .Sys_Flow
using .Gui_Base
using .Gui_Deck
using .Gui_Lens

FAST_Log_DDEF("BOOT", "Complete", "Core Libraries Integrated", "OK")

# --------------------------------------------------------------------------------------
# APP CONFIGURATION
# --------------------------------------------------------------------------------------

FAST_Log_DDEF("INIT", "Setup", "Configuring Dash Framework...", "WAIT")
app = dash(;
    external_stylesheets=[
        DashBootstrapComponents.dbc_themes.BOOTSTRAP,
        "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css",
        "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&display=swap",
    ],
    suppress_callback_exceptions=true,
)

app.title = "DaishoDoE"

# --------------------------------------------------------------------------------------
# UI COMPONENTS
# --------------------------------------------------------------------------------------

# 1. Navigation Controller
navbar = html_div([
        html_div([
                dcc_link(html_div([
                            html_i(className="fas fa-layer-group text-dark me-2"),
                            html_span("DaishoDoE", className="text-dark fw-bold tracking-tight"),
                        ], className="nav-brand"), href="/", style=Dict("textDecoration" => "none")),
            ], style=Dict("flex" => "1")),
        html_div([
                dcc_link("Design", href="/design", className="nav-item"),
                dcc_link("Analyse", href="/analysis", className="nav-item"),
            ], className="nav-links d-flex justify-content-center"),
        html_div([
                html_span("v1.0 In Dev.", className="badge bg-secondary text-white small opacity-50"),
            ], className="nav-actions", style=Dict("flex" => "1", "textAlign" => "right")),
    ], className="ray-navbar d-flex align-items-center justify-content-between")

# 2. Page Content Render Area
content = html_div(id="page-content", className="app-container")

# 3. Main Application Framework
const _SYSTEM_READY = Ref(false)

app.layout = html_div([
    dcc_location(id="url"),
    navbar,
    content,

    # Global State Architecture
    dcc_store(id="store-session-config", storage_type="session"),
    dcc_store(id="store-master-file-content", storage_type="session"),

    # Master Sync Bus
    dcc_store(id="sync-deck-content", storage_type="memory"),
    dcc_store(id="sync-lens-content", storage_type="memory"),
    dcc_store(id="sync-lens-analysis", storage_type="memory"),
    dbc_toast(id="global-toast",
        header="System Notification", is_open=false, dismissable=true,
        duration=4000, icon="danger",
        style=Dict("position" => "fixed", "top" => 60, "right" => 20,
            "width" => 350, "zIndex" => 9999)),

    # System readiness overlay + polling
    dcc_interval(id="sys-ready-poll", interval=800, max_intervals=-1),
    html_div(id="sys-loading-overlay", children=[
            html_div([
                    html_div(className="spinner-border text-dark mb-3", style=Dict("width" => "3rem", "height" => "3rem")),
                    html_h4("DaishoDoE Engine", className="fw-bold mb-2", style=Dict("color" => "#000000")),
                    html_p("Compiling scientific modules...", className="text-secondary", id="sys-loading-msg"),
                ], style=Dict(
                    "display" => "flex", "flexDirection" => "column", "alignItems" => "center",
                    "justifyContent" => "center", "height" => "100vh",
                )),
        ], style=Dict(
            "position" => "fixed", "top" => "0", "left" => "0", "width" => "100vw", "height" => "100vh",
            "backgroundColor" => "#DCDCDC", "zIndex" => "99999", "display" => "flex",
            "alignItems" => "center", "justifyContent" => "center",
        )),
])

# --------------------------------------------------------------------------------------
# ROUTING & CALLBACK ORCHESTRATION
# --------------------------------------------------------------------------------------

# 1. Global State Sync Bus
callback!(app,
    Output("store-master-file-content", "data"),
    Input("sync-deck-content", "data"),
    Input("sync-lens-content", "data"),
    Input("sync-lens-analysis", "data")
) do deck, lens, lens_analysis
    ctx = callback_context()
    isempty(ctx.triggered) && return Dash.no_update()
    trig = split(ctx.triggered[1].prop_id, ".")[1]

    if trig == "sync-deck-content"
        return deck
    elseif trig == "sync-lens-content"
        return lens
    else
        return lens_analysis
    end
end

# 2. Main Navigation Orchestrator
callback!(app, Output("page-content", "children"), Input("url", "pathname")) do pathname
    if pathname == "/design"
        return DECK_Layout_DDEF()
    elseif pathname == "/analysis"
        return LENS_Layout_DDEF()
    else
        # --- PORTAL DASHBOARD ---
        nt, tstyle, tmsg = Sys_Fast.FAST_GetThreadInfo_DDEF()
        return html_div([
            # Hero Section
            dbc_container([
                    dbc_row(dbc_col([
                            html_h1("DaishoDoE Engine", className="fw-bold display-4 mb-3", style=Dict("letterSpacing" => "-0.04em", "color" => "#000000")),
                            html_p("A Decision-Adaptive Interactive Sequential Hybrid Optimization Environment for Design of Experiments",
                                className="lead text-secondary mb-5", style=Dict("maxWidth" => "600px", "margin" => "0 auto")),
                        ], xs=12, className="text-center mt-5 pt-4")),

                    # Action Cards
                    dbc_row([
                            # Design Card
                            dbc_col([
                                    dcc_link(html_div([
                                                html_div(html_i(className="fas fa-flask text-white"),
                                                    style=Dict("width" => "50px", "height" => "50px", "borderRadius" => "12px",
                                                        "background" => "linear-gradient(135deg, #FF0000 0%, #FDE725 100%)",
                                                        "display" => "flex", "alignItems" => "center", "justifyContent" => "center",
                                                        "fontSize" => "1.5rem", "marginBottom" => "1.5rem", "boxShadow" => "0 10px 20px -5px rgba(255, 0, 0, 0.4)")),
                                                html_h3("Experimental Design", className="fw-bold mb-2", style=Dict("color" => "#000000")),
                                                html_p("Synthesise robust testing matrices using Box-Behnken and Taguchi methodologies. Automatically generate protocol workspaces.",
                                                    className="text-secondary small mb-0", style=Dict("lineHeight" => "1.6")),
                                            ], className="ray-panel h-100 p-4", style=Dict("transition" => "transform 0.2s ease, box-shadow 0.2s ease", "cursor" => "pointer")); href="/design", style=Dict("textDecoration" => "none")),
                                ], xs=12, md=6, className="mb-4"),

                            # Analysis Card
                            dbc_col([
                                    dcc_link(html_div([
                                                html_div(html_i(className="fas fa-chart-line text-white"),
                                                    style=Dict("width" => "50px", "height" => "50px", "borderRadius" => "12px",
                                                        "background" => "linear-gradient(135deg, #3B528B 0%, #21918C 100%)",
                                                        "display" => "flex", "alignItems" => "center", "justifyContent" => "center",
                                                        "fontSize" => "1.5rem", "marginBottom" => "1.5rem", "boxShadow" => "0 10px 20px -5px rgba(33, 145, 140, 0.4)")),
                                                html_h3("Statistical Analysis", className="fw-bold mb-2", style=Dict("color" => "#000000")),
                                                html_p("Extract insights via GLM regression, visualise desirability functions, and identify optimal formulation candidates using robust grid search algorithms.",
                                                    className="text-secondary small mb-0", style=Dict("lineHeight" => "1.6")),
                                            ], className="ray-panel h-100 p-4", style=Dict("transition" => "transform 0.2s ease, box-shadow 0.2s ease", "cursor" => "pointer")); href="/analysis", style=Dict("textDecoration" => "none")),
                                ], xs=12, md=6, className="mb-4"),
                        ], className="g-4 mb-5", style=Dict("maxWidth" => "900px", "margin" => "0 auto")),

                    # System Diagnostics Footer
                    dbc_row(dbc_col(html_div([
                                html_div([
                                        html_div([html_i(className="fas fa-server text-success me-2"), html_span("System Online", className="text-secondary fw-bold")], className="d-flex align-items-center me-4"),
                                        html_div([html_i(className="fas fa-microchip text-$tstyle me-2"), html_span(tmsg, className="text-secondary fw-bold")], className="d-flex align-items-center"),
                                    ], className="d-flex justify-content-center align-items-center p-3 rounded-pill",
                                    style=Dict("background" => "#FFFFFF", "border" => "1px solid #DCDCDC", "boxShadow" => "0 4px 6px -1px rgba(0,0,0,0.05)", "display" => "inline-flex", "margin" => "0 auto"))
                            ], className="text-center"), xs=12)),], fluid=true, className="pb-5 mt-2")
        ])
    end
end

# Loading overlay dismiss callback (polls until warmup completes)
callback!(app,
    Output("sys-loading-overlay", "style"),
    Output("sys-ready-poll", "disabled"),
    Input("sys-ready-poll", "n_intervals")
) do n
    if _SYSTEM_READY[]
        return Dict("display" => "none"), true  # Hide overlay, stop polling
    end
    return Dash.no_update(), false
end

# Register Child Callbacks
DECK_RegisterCallbacks_DDEF(app)
LENS_RegisterCallbacks_DDEF(app)

# --------------------------------------------------------------------------------------
# JIT WARMUP ROUTINE
# --------------------------------------------------------------------------------------

function _daisho_warmup!()
    t0 = time()
    FAST_Log_DDEF("BOOT", "Warmup", "JIT pre-compilation starting (background)...", "WAIT")

    try
        # 1. Sys_Fast: Type coercion pipeline
        Sys_Fast.FAST_SafeNum_DDEF("3.14")
        Sys_Fast.FAST_SafeNum_DDEF(42)
        Sys_Fast.FAST_SafeNum_DDEF(missing)
        Sys_Fast.FAST_SafeNum_DDEF(nothing)
        dummy_rows = [
            Dict("Name" => "A", "Role" => "Variable", "L1" => 1, "L2" => 2, "L3" => 3, "MW" => 100, "Unit" => "mg"),
            Dict("Name" => "B", "Role" => "Variable", "L1" => "4", "L2" => "5", "L3" => "6", "MW" => 200.0, "Unit" => "mM"),
            Dict("Name" => "C", "Role" => "Filler", "L1" => 0, "L2" => 0, "L3" => 0, "MW" => 300, "Unit" => "MR"),
        ]
        Sys_Fast.FAST_SanitizeInput_DDEF(dummy_rows)

        # 2. Lib_Mole: Stoichiometry engine
        Lib_Mole.MOLE_ParseTable_DDEF(dummy_rows)
        Lib_Mole.MOLE_CalcMass_DDEF(
            ["A", "B", "C"], [100.0, 200.0, 300.0], [30.0, 30.0, 40.0], 5.0, 10.0
        )
        Lib_Mole.MOLE_ApproxEq_DDEF(1.0, 1.0 + 1e-12)

        # 3. Lib_Vise: Regression + GridSearch (core hot path)
        X_dummy = Float64[1 2 3; 4 5 6; 7 8 9; 2 4 6; 3 6 9; 5 3 1; 8 2 4; 6 7 5;
            1 5 9; 4 8 2; 7 1 5; 3 9 6]
        Y_dummy = Float64[10, 20, 30, 15, 25, 12, 28, 22, 18, 24, 14, 26]

        mod = Lib_Vise.VISE_Regress_DDEF(X_dummy, Y_dummy, "quadratic";
            InNames=["Var1", "Var2", "Var3"])
        Lib_Vise.VISE_CrossValidate_DDEF(X_dummy, Y_dummy, "quadratic")
        Lib_Vise.VISE_ClampIndex_DDEF(5, 10)

        if mod["Status"] == "OK"
            bounds = hcat([1.0, 2.0, 1.0], [8.0, 9.0, 9.0])
            goals = [Dict("Type" => "Nominal", "Min" => 10.0, "Max" => 30.0, "Target" => 20.0)]
            mod["Goal"] = goals[1]
            Lib_Vise.VISE_GridSearch_DDEF([mod], goals, bounds; Steps=5)
        end

        # 4. Lib_Arts: Rendering pipeline
        if mod["Status"] == "OK"
            Lib_Arts.ARTS_RenderPareto_DDEF(mod, "Dummy", 0.95, 0.90)
            Y_pred = Lib_Vise.VISE_Predict_DDEF(mod, X_dummy)
            Lib_Arts.ARTS_RenderFit_DDEF(Y_dummy, Y_pred, "Dummy")
            Lib_Arts.ARTS_CalcDesirability_DDEF(20.0,
                Dict("Type" => "Nominal", "Min" => 10.0, "Max" => 30.0, "Target" => 20.0))
        end

        # 5. Subsystem warm-up
        Sys_Fast.FAST_CacheWrite_DDEF("_warmup_test", DataFrames.DataFrame(x=[1, 2, 3]))
        Sys_Fast.FAST_CacheRead_DDEF("_warmup_test")
        Sys_Fast.FAST_CacheEvict_DDEF("_warmup_test")
        Sys_Fast.FAST_AcquireLock_DDEF("_warmup")
        Sys_Fast.FAST_ReleaseLock_DDEF("_warmup")

    catch e
        FAST_Log_DDEF("BOOT", "Warmup_Warn", "Non-critical warmup error: $e", "WARN")
    end

    _SYSTEM_READY[] = true  # Signal the loading overlay to dismiss
    elapsed = round(time() - t0; digits=2)
    FAST_Log_DDEF("BOOT", "Warmup", "JIT pre-compilation complete ($(elapsed)s) — System READY", "OK")
end

# --------------------------------------------------------------------------------------
# SERVER EXECUTION
# --------------------------------------------------------------------------------------

# HuggingFace Spaces detection
const _IS_HF_SPACES = haskey(ENV, "SPACE_ID")
const PORT = _IS_HF_SPACES ? 7860 : 8060

# Spawn warmup in BACKGROUND so server starts instantly
Threads.@spawn _daisho_warmup!()

try
    # Browser Auto-Launch (skip on HuggingFace Spaces)
    if !_IS_HF_SPACES
        @async begin
            sleep(0.5)  # Just enough for server socket to bind
            url = "http://127.0.0.1:$PORT"
            Sys_Fast.FAST_Log_DDEF("SYSTEM", "Launch", "Opening browser: $url", "OK")
            try
                if Sys.iswindows()
                    run(`cmd /c start $url`)
                elseif Sys.isapple()
                    run(`open $url`)
                elseif Sys.islinux()
                    run(`xdg-open $url`)
                end
            catch e
                Sys_Fast.FAST_Log_DDEF("SYSTEM", "Error", "Browser launch error: $e", "FAIL")
            end
        end
    end

    env_label = _IS_HF_SPACES ? "HuggingFace Spaces" : "Local $(Threads.nthreads())T"
    Sys_Fast.FAST_Log_DDEF("SERVER", "Ready",
        "DaishoDoE Engine listening on :$PORT ($env_label)", "OK")
    run_server(app, "0.0.0.0", PORT)
catch e
    if isa(e, Base.IOError) && e.code == -4091
        println("\n>>> CRITICAL WARNING: Port $PORT occupied. Please terminate existing sessions.\n")
    else
        rethrow(e)
    end
end
