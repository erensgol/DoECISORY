# API Reference

This page documents the public API functions, constants, and types exported by `DoECISORY.jl`.

---

## Application Launcher

```@docs
APP_Launch_DDEF
run_app
```

---

## Experimental Design & Optimality (`Lib_Core`)

```@docs
CORE_GenDesign_DDEF
CORE_GenerateMatrix_DDEF
CORE_MapLevels_DDEF
CORE_CodeMatrix_DDEF
CORE_ExpandModelMatrix_DDEF
CORE_D_Efficiency_DDEF
CORE_CalcDesignMetrics_DDEF
CORE_OptimiseDesirability_DDEF
CORE_CalcDesirability_DDEF
CORE_ExtractGoal_DDEF
CORE_ValidateDesign_DDEF
CORE_ExtractLeader_DDEF
CORE_ModifierDCYP_DDES
CORE_ApplyDCYP_DDEF
```

---

## Stoichiometry & Mass Conservation (`Lib_Mole`)

```@docs
MOLE_ParseTable_DDEF
MOLE_QuickAudit_DDEF
MOLE_CalcMass_DDEF
MOLE_ApproxEq_DDEF
MOLE_ValidatePhysicalUnit_DDEF
MOLE_AuditMatrix_DDEF
MOLE_AuditBatch_DDEF
MOLE_ValidateDesignFeasibility_DDEF
MOLE_CalcRadioDecay_DDEF
MOLE_ProcessDesign_DDEF
MOLE_GetPercentageEquivalent_DDEF
MOLE_IsTimeUnit_DDEF
MOLE_ConvertTimeToMinutes_DDEF
```

---

## Statistical Modelling & ANOVA (`Lib_Vise`)

```@docs
VISE_Regress_DDEF
VISE_SelectBestModel_DDEF
VISE_Predict_DDEF
VISE_CrossValidate_DDEF
VISE_CalcMetrics_DDEF
VISE_GenerateAnovaTable_DDEF
VISE_LackOfFit_DDEF
VISE_CalcVIF_DDEF
VISE_PerformNormalityTest_DDEF
VISE_GridSearch_DDEF
VISE_SensitivityAnalysis_DDEF
VISE_GenerateScientificReport_DDEF
VISE_ExportToExcel_DDEF
VISE_ApplyForwReveDecay_DDEF
VISE_ExtractDCYP_DDEF
VISE_Execute_DDEF
VISE_GetTermNames_DDEF
VISE_ExpandDesign_DDEF
```

---

## Response Surface Visualisation (`Lib_Arts`)

```@docs
ARTS_RenderSurface_DDEF
ARTS_RenderContour_DDEF
ARTS_RenderSlice_DDEF
ARTS_RenderTrend_DDEF
ARTS_RenderPareto_DDEF
ARTS_RenderFit_DDEF
ARTS_RenderQQPlot_DDEF
ARTS_RenderResidualsVsPred_DDEF
ARTS_RenderSensitivityPlot_DDEF
ARTS_RenderSpace_DDEF
ARTS_RenderOptimalZone_DDEF
ARTS_RenderCandidates_DDEF
ARTS_RenderInteractionMatrix_DDEF
ARTS_Render_DDEF
```

---

## Workflow Transitions (`Sys_Flow`)

```@docs
FLOW_ApplyACTA_DDEF
FLOW_CalcACTA_DDEF
FLOW_ApplyASTM_DDEF
FLOW_ValidateASTM_DDEF
FLOW_AskLeader_DDEF
FLOW_BuildIPKT_DDEF
FLOW_CommitIPKT_DDEF
FLOW_GetCandidates_DDEF
FLOW_WriteLeaders_DDEF
FLOW_RenderIPKT_DDEF
```

---

## File Exchange & System Utilities (`Sys_Fast`)

```@docs
FAST_ReadExcel_DDEF
FAST_SafeExcelWrite_DDEF
FAST_InitialiseMaster_DDEF
FAST_GenerateSmartName_DDEF
FAST_SafeNum_DDEF
FAST_Log_DDEF
FAST_Data_DDEC
```
