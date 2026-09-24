module DoECISORY

# ==============================================================================
# DOECISORY - ROOT PACKAGE ENTRY POINT
# ==============================================================================
# Description: Package root for DoECISORY.jl. Integrates submodules, exports 
#              public APIs, and provides the application launcher.
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
# Exports
# ------------------------------------------------------------------------------

export Sys_Fast
export FAST_Log_DDEF, FAST_ReadExcel_DDEF, FAST_Constants_DDES,
       FAST_SafeNum_DDEF, FAST_GetLabDefaults_DDEF, FAST_InitialiseMaster_DDEF,
       FAST_NormaliseCols_DDEF!, FAST_SanitiseJson_DDEF, FAST_PrepareDownload_DDEF,
       FAST_GenerateSmartName_DDEF, FAST_ExtractProjectFromFilename_DDEF,
       FAST_GetTransientPath_DDEF, FAST_ReadToStore_DDEF, FAST_UpdateConfig_DDEF,
       FAST_GetThreadInfo_DDEF, FAST_ClearConfigCache_DDEF, FAST_SanitiseInput_DDEF,
       FAST_AcquireLock_DDEF, FAST_ReleaseLock_DDEF, FAST_ForceReleaseAll_DDEF,
       FAST_CacheRead_DDEF, FAST_CacheWrite_DDEF, FAST_CacheEvict_DDEF,
       FAST_VaultWrite_DDEF, FAST_VaultRead_DDEF, FAST_GetComputeThreads_DDEF,
       FAST_SafeExcelWrite_DDEF, FAST_CleanTransient_DDEF, FAST_FormatDuration_DDEF,
       FAST_SortColumns_DDEF

export Lib_Core
export CORE_GenDesign_DDEF, CORE_MapLevels_DDEF, CORE_ExtractLeader_DDEF,
       CORE_GenDf14Design_DDEF, CORE_ExpandModelMatrix_DDEF,
       CORE_OptimiseDesirability_DDEF, CORE_ValidateDesign_DDEF,
       CORE_D_Efficiency_DDEF, CORE_CalcDesignMetrics_DDEF, CORE_CodeMatrix_DDEF,
       CORE_CalcDesirability_DDEF, CORE_ExtractGoal_DDEF, CORE_GetModelType_DDEF,
       CORE_ModifierDCYP_DDES, CORE_ApplyDCYP_DDEF,
       CORE_AbstractDesignMethod_DDET, CORE_MethodBB15_DDES, CORE_MethodTL09_DDES,
       CORE_MethodCD17_DDES, CORE_MethodDF14_DDES

export Lib_Mole
export MOLE_ParseTable_DDEF, MOLE_QuickAudit_DDEF, MOLE_CalcMass_DDEF,
       MOLE_ApproxEq_DDEF, MOLE_ValidatePhysicalUnit_DDEF, MOLE_AuditMatrix_DDEF,
       MOLE_AuditBatch_DDEF, MOLE_ValidateDesignFeasibility_DDEF,
       MOLE_CalcRadioDecay_DDEF, MOLE_ProcessDesign_DDEF,
       MOLE_GetPercentageEquivalent_DDEF, MOLE_IsTimeUnit_DDEF,
       MOLE_ConvertTimeToMinutes_DDEF

export Sys_Flow
export FLOW_AskLeader_DDEF, FLOW_BuildIPKT_DDEF, FLOW_GetCandidates_DDEF,
       FLOW_CommitIPKT_DDEF, FLOW_ApplyACTA_DDEF, FLOW_WriteLeaders_DDEF,
       FLOW_CalcACTA_DDEF, FLOW_RenderIPKT_DDEF,
       FLOW_ApplyASTM_DDEF, FLOW_ValidateASTM_DDEF

export Lib_Vise
export VISE_Regress_DDEF, VISE_GridSearch_DDEF, VISE_ExpandDesign_DDEF,
       VISE_Predict_DDEF, VISE_Execute_DDEF, VISE_CrossValidate_DDEF,
       VISE_GetTermNames_DDEF, VISE_ClampIndex_DDEF, VISE_SelectBestModel_DDEF,
       VISE_CalcMetrics_DDEF, VISE_SensitivityAnalysis_DDEF,
       VISE_GenerateScientificReport_DDEF, VISE_CalcVIF_DDEF, VISE_LackOfFit_DDEF,
       VISE_ExportToExcel_DDEF, VISE_ExtractDCYP_DDEF, VISE_ApplyForwReveDecay_DDEF,
       VISE_WidenColumnFloat_DDEF!

export Lib_Arts
export ARTS_RenderPareto_DDEF, ARTS_RenderFit_DDEF, ARTS_RenderSurface_DDEF,
       ARTS_RenderContour_DDEF, ARTS_RenderSlice_DDEF, ARTS_RenderTrend_DDEF,
       ARTS_RenderSpace_DDEF, ARTS_RenderCandidates_DDEF, ARTS_Render_DDEF,
       ARTS_Downsample_DDEF, ARTS_RenderOptimalZone_DDEF,
       ARTS_RenderInteractionMatrix_DDEF, ARTS_BaseLayout_DDEF,
       ARTS_Predict_DDEF, ARTS_BuildGrid_DDEF, ARTS_AdaptiveGridN_DDEF,
       ARTS_RenderSpaceImpl_DDEF, ARTS_GetDynamicN_DDEF,
       ARTS_PlotPareto_DDES, ARTS_PlotFit_DDES, ARTS_PlotInteractionMatrix_DDES,
       ARTS_PlotQQ_DDES, ARTS_PlotResiduals_DDES, ARTS_PlotSensitivity_DDES,
       ARTS_PlotSurface_DDES, ARTS_PlotContour_DDES, ARTS_PlotSlice_DDES,
       ARTS_PlotTrend_DDES, ARTS_PlotOptimalZone_DDES, ARTS_PlotDesignSpace_DDES,
       ARTS_PlotCandidates_DDES

# GUI modules
export Gui_Base, Gui_Deck, Gui_Lens
export BASE_StyleCell_DDEC, BASE_StyleInput_DDEC, BASE_StyleInputCentre_DDEC,
       BASE_StyleHeader_DDEC, BASE_StyleDatatableCell_DDEC, BASE_StyleInlineHeader_DDEC,
       BASE_StyleHr_DDEC, BASE_EmptyFigure_DDEC, BASE_SafeRows_DDEF, BASE_GetTrigger_DDEF,
       BASE_PageHeader_DDEF, BASE_GlassPanel_DDEF, BASE_DataTable_DDEF, BASE_Modal_DDEF,
       BASE_ConvertThemePlotlyWhite!_DDEF, BASE_MiniVitals_DDEF, BASE_Loading_DDEF,
       BASE_SystemAuditUI_DDEF, BASE_ScientificAuditUI_DDEF, BASE_StatusIcon_DDEF,
       BASE_IconButton_DDEF, BASE_TableHeader_DDEF, BASE_ControlGroup_DDEF,
       BASE_ActionButton_DDEF, BASE_Separator_DDEF, BASE_SidebarHeader_DDEF,
       BASE_Upload_DDEF, BASE_NextButton_DDEF, BASE_BuildIdRow_DDEF, BASE_BuildLevelRow_DDEF,
       BASE_BuildLimitsRow_DDEF, BASE_BuildGoalRow_DDEF,
       DECK_Layout_DDEF, DECK_RegisterCallbacks_DDEF,
       LENS_Layout_DDEF, LENS_RegisterCallbacks_DDEF

# ------------------------------------------------------------------------------
# Application Launcher
# ------------------------------------------------------------------------------

export APP_Launch_DDEF, run_app

"""
    run_app(; host="0.0.0.0", port=nothing, debug=false, open_browser=true)

Launch the DoECISORY web application.
"""
function APP_Launch_DDEF(; host::String="0.0.0.0", port::Union{Int, Nothing}=nothing, debug::Bool=false, open_browser::Bool=true)
    app_path = joinpath(dirname(@__DIR__), "app.jl")
    if isfile(app_path)
        if port !== nothing
            ENV["PORT"] = string(port)
        end
        if !open_browser
            ENV["DOECISORY_NO_BROWSER"] = "true"
        end
        include(app_path)
    else
        error("DoECISORY entry point app.jl not found at: $app_path")
    end
end

const run_app = APP_Launch_DDEF

end
