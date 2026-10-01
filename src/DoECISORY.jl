"""
    DoECISORY

A scientific computation library for classical and adaptive Design of Experiments (DoE),
stoichiometric formulation balancing, multi-response statistical modelling, and visual
analytics in chemical and radiopharmaceutical research.

# Submodules
- `Lib_Core`: Algorithmic matrix generation (BB15, CD17, TL09, DF14), optimality metrics (D, A, G, I), and desirability optimisation.
- `Lib_Mole`: Stoichiometric mass conservation, unit conversions, and radiochemical decay kinetics.
- `Lib_Vise`: Ordinary least-squares regression, AIC model selection, ANOVA diagnostics, and scientific report generation.
- `Lib_Arts`: Visualisation routines built upon PlotlyJS with the Viridis colour palette.
- `Sys_Flow`: Adaptive Continuous Transition Algorithm (ACTA) and iterative experimental space navigation.
- `Sys_Fast`: Multi-threaded Excel data exchange, session caching, and workspace file management.
- `Gui_Base`, `Gui_Deck`, `Gui_Lens`: Interactive Dash web application components and page layouts.

# Entry Points
- [`run_app`](@ref): Launch the interactive web user interface in the local browser.
"""
module DoECISORY

# ==============================================================================
# DOECISORY - ROOT PACKAGE ENTRY POINT
# ==============================================================================
# Description: Package root for DoECISORY.jl. Integrates submodules, exports 
#              public APIs, and provides the application launcher.
# ==============================================================================

# ==============================================================================
# PART A: SUBMODULE COMPONENT INTEGRATION & PUBLIC API
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: SUBMODULE COMPONENT INTEGRATION
# ------------------------------------------------------------------------------

include("Sys_Fast.jl")
using .Sys_Fast

include("Lib_Core.jl")
using .Lib_Core

include("Lib_Mole.jl")
using .Lib_Mole

include("Sys_Flow.jl")
using .Sys_Flow

include("Lib_Vise.jl")
using .Lib_Vise

include("Lib_Arts.jl")
using .Lib_Arts

include("Gui_Base.jl")
using .Gui_Base

include("Gui_Deck.jl")
using .Gui_Deck

include("Gui_Lens.jl")
using .Gui_Lens

# ------------------------------------------------------------------------------
# SECTION 2: PUBLIC INTERFACE EXPORTS
# ------------------------------------------------------------------------------

# Submodule Accessors
export Sys_Fast, Lib_Core, Lib_Mole, Sys_Flow, Lib_Vise, Lib_Arts,
       Gui_Base, Gui_Deck, Gui_Lens

# Sys_Fast: Excel Data Exchange & Logging
export FAST_ReadExcel_DDEF, FAST_SafeExcelWrite_DDEF,
       FAST_InitialiseMaster_DDEF, FAST_GenerateSmartName_DDEF,
       FAST_SafeNum_DDEF, FAST_Log_DDEF, FAST_Data_DDEC

# Lib_Core: Experimental Design Generation, Optimality & Desirability
export CORE_GenDesign_DDEF, CORE_GenerateMatrix_DDEF,
       CORE_MapLevels_DDEF, CORE_CodeMatrix_DDEF,
       CORE_ExpandModelMatrix_DDEF, CORE_D_Efficiency_DDEF,
       CORE_CalcDesignMetrics_DDEF, CORE_OptimiseDesirability_DDEF,
       CORE_CalcDesirability_DDEF, CORE_ExtractGoal_DDEF,
       CORE_ValidateDesign_DDEF, CORE_ExtractLeader_DDEF,
       CORE_ModifierDCYP_DDES, CORE_ApplyDCYP_DDEF

# Lib_Mole: Stoichiometric Mass Balance & Radiochemical Kinetics
export MOLE_ParseTable_DDEF, MOLE_QuickAudit_DDEF, MOLE_CalcMass_DDEF,
       MOLE_ApproxEq_DDEF, MOLE_ValidatePhysicalUnit_DDEF,
       MOLE_AuditMatrix_DDEF, MOLE_AuditBatch_DDEF,
       MOLE_ValidateDesignFeasibility_DDEF, MOLE_CalcRadioDecay_DDEF,
       MOLE_ProcessDesign_DDEF, MOLE_GetPercentageEquivalent_DDEF,
       MOLE_IsTimeUnit_DDEF, MOLE_ConvertTimeToMinutes_DDEF

# Sys_Flow: Phase Transition & Iterative Space Exploration (ACTA / ASTM)
export FLOW_ApplyACTA_DDEF, FLOW_CalcACTA_DDEF,
       FLOW_ApplyASTM_DDEF, FLOW_ValidateASTM_DDEF,
       FLOW_AskLeader_DDEF, FLOW_BuildIPKT_DDEF, FLOW_CommitIPKT_DDEF,
       FLOW_GetCandidates_DDEF, FLOW_WriteLeaders_DDEF, FLOW_RenderIPKT_DDEF

# Lib_Vise: Statistical Modelling, ANOVA & Scientific Reporting
export VISE_Regress_DDEF, VISE_SelectBestModel_DDEF, VISE_Predict_DDEF,
       VISE_CrossValidate_DDEF, VISE_CalcMetrics_DDEF,
       VISE_GenerateAnovaTable_DDEF, VISE_LackOfFit_DDEF, VISE_CalcVIF_DDEF,
       VISE_PerformNormalityTest_DDEF, VISE_GridSearch_DDEF, VISE_SensitivityAnalysis_DDEF,
       VISE_GenerateScientificReport_DDEF, VISE_ExportToExcel_DDEF,
       VISE_ApplyForwReveDecay_DDEF, VISE_ExtractDCYP_DDEF, VISE_Execute_DDEF,
       VISE_GetTermNames_DDEF, VISE_ExpandDesign_DDEF

# Lib_Arts: Plotly Visualisation Suite
export ARTS_RenderSurface_DDEF, ARTS_RenderContour_DDEF, ARTS_RenderSlice_DDEF,
       ARTS_RenderTrend_DDEF, ARTS_RenderPareto_DDEF, ARTS_RenderFit_DDEF,
       ARTS_RenderQQPlot_DDEF, ARTS_RenderResidualsVsPred_DDEF,
       ARTS_RenderSensitivityPlot_DDEF, ARTS_RenderSpace_DDEF,
       ARTS_RenderOptimalZone_DDEF, ARTS_RenderCandidates_DDEF,
       ARTS_RenderInteractionMatrix_DDEF, ARTS_Render_DDEF

# ==============================================================================
# PART B: APPLICATION RUNTIME LAUNCHER
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 3: APPLICATION RUNTIME LAUNCHER
# ------------------------------------------------------------------------------

export APP_Launch_DDEF, run_app

"""
    APP_Launch_DDEF(; host="0.0.0.0", port=nothing, debug=false, open_browser=true, wait=false)

Launch the DoECISORY interactive web application.

Spawns a multi-threaded Julia process hosting the Dash web server and initialises
the experimental formulation workspace (Deck) alongside the response surface analysis dashboard (Lens).

# Arguments
- `host::String`: Host interface address to bind (default: `"0.0.0.0"`).
- `port::Union{Int, Nothing}`: Network port to bind. If `nothing`, defaults to 8060 (or 7860 on Hugging Face Spaces).
- `debug::Bool`: Enables Dash developer hot-reloading and debug tools (default: `false`).
- `open_browser::Bool`: Automatically launches the default web browser upon startup (default: `true`).
- `wait::Bool`: Blocks the calling process until the web server is terminated (default: `false`).

# Returns
- `nothing`

# Examples
```julia
using DoECISORY
run_app()
```
"""
function APP_Launch_DDEF(; host::String="0.0.0.0", port::Union{Int, Nothing}=nothing, debug::Bool=false, open_browser::Bool=true, wait::Bool=false)
    app_path  = joinpath(dirname(@__DIR__), "app.jl")
    proj_path = dirname(@__DIR__)
    if isfile(app_path)
        env_vars = copy(ENV)
        if port !== nothing
            env_vars["PORT"] = string(port)
        end
        if !open_browser
            env_vars["DOECISORY_NO_BROWSER"] = "true"
        end
        target_port = something(port, 8060)
        println("DoECISORY web application launching with multi-threading at http://127.0.0.1:$target_port...")
        cmd = setenv(`$(Base.julia_cmd()) --threads=auto --project=$proj_path $app_path`, env_vars)
        run(cmd; wait=wait)
        return nothing
    else
        error("DoECISORY entry point app.jl not found at: $app_path")
    end
end

"""
    run_app(; host="0.0.0.0", port=nothing, debug=false, open_browser=true, wait=false)

Convenient alias for [`APP_Launch_DDEF`](@ref).
"""
const run_app = APP_Launch_DDEF

end
