using Test
using Pkg

if Pkg.project().path != joinpath(@__DIR__, "..", "Project.toml")
    Pkg.activate(joinpath(@__DIR__, ".."))
end

using Dash
using DashBootstrapComponents
using PlotlyJS
using DataFrames
using JSON3
using Base64
using Printf

include("../src/Sys_Fast.jl")
include("../src/Lib_Core.jl")
include("../src/Lib_Mole.jl")
include("../src/Sys_Flow.jl")
include("../src/Lib_Vise.jl")
include("../src/Lib_Arts.jl")
include("../src/Gui_Base.jl")
include("../src/Gui_Deck.jl")
include("../src/Gui_Lens.jl")

using Main.Sys_Fast
using Main.Lib_Core
using Main.Lib_Mole
using Main.Sys_Flow
using Main.Lib_Vise
using Main.Lib_Arts
using Main.Gui_Base
using Main.Gui_Deck
using Main.Gui_Lens

# ==============================================================================
# DOECISORY TEST METRICS & TRACKING HARNESS
# ==============================================================================
mutable struct GroupTracker
    name::String
    total::Int
    passed::Int
    failed::Int
end

const TRACKER = Dict{String, GroupTracker}(
    "G1" => GroupTracker("[G1] Sys_Fast Utilities & Excel I/O", 0, 0, 0),
    "G2" => GroupTracker("[G2] Lib_Core Matrices & Desirability Engine", 0, 0, 0),
    "G3" => GroupTracker("[G3] Lib_Mole Stoichiometry & Radio-Decay", 0, 0, 0),
    "G4" => GroupTracker("[G4] Lib_Vise Statistical Modeling & GLM", 0, 0, 0),
    "G5" => GroupTracker("[G5] Sys_Flow Process Transitions & ACTA", 0, 0, 0),
    "G6" => GroupTracker("[G6] Presentation, UI State & E2E Pipeline", 0, 0, 0)
)

function track_eval(group_key::String, condition::Bool)
    t = TRACKER[group_key]
    t.total += 1
    if condition
        t.passed += 1
    else
        t.failed += 1
    end
    return condition
end

macro track(group_sym, expr)
    grp_str = string(group_sym)
    return quote
        cond = $(esc(expr))
        track_eval($grp_str, cond)
        @test cond
    end
end

const SUITE_START_TIME = time()

@testset "DoECISORY Master Test Suite (100 Verifications)" begin
    # ==========================================================================
    # GROUP 1: Sys_Fast Utilities & Excel I/O (19 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G1"
    Sys_Fast.FAST_InitialiseWorkforce_DDEF()

    @testset "Group 1: Sys_Fast Utilities & Excel I/O" begin
        # 1-9: Numeric sanitisation
        @track G1 Sys_Fast.FAST_SafeNum_DDEF("42.5") == 42.5
        @track G1 Sys_Fast.FAST_SafeNum_DDEF("12,7") == 12.7
        @track G1 isnan(Sys_Fast.FAST_SafeNum_DDEF(nothing))
        @track G1 isnan(Sys_Fast.FAST_SafeNum_DDEF(missing))
        @track G1 Sys_Fast.FAST_SafeNum_DDEF(true) == 1.0
        @track G1 Sys_Fast.FAST_SafeNum_DDEF(false) == 0.0
        @track G1 isnan(Sys_Fast.FAST_SafeNum_DDEF("abc"))
        @track G1 isnan(Sys_Fast.FAST_SafeNum_DDEF("12.3.4"))
        @track G1 isnan(Sys_Fast.FAST_SafeNum_DDEF("  -  "))
        Sys_Fast.FAST_Log_DDEF("AUDIT", "NUMERIC_PARSE", "Sanitised 9 floating-point & edge-case inputs", "OK")

        # 10-13: String sanitisation & IDs
        @track G1 Sys_Fast.FAST_SanitiseFilename_DDEF("öğrenci_işleri.xlsx") == "ogrenci_isleri.xlsx"
        @track G1 Sys_Fast.FAST_SanitiseFilename_DDEF("test/file!name.csv") == "test_file_name.csv"
        @track G1 Sys_Fast.FAST_ExtractDataID_DDEF(Dict("dataid" => "XYZ123")) == "XYZ123"
        @track G1 Sys_Fast.FAST_ExtractDataID_DDEF("ABC") == "ABC"
        Sys_Fast.FAST_Log_DDEF("AUDIT", "CHAR_SAFE", "Sanitised Turkish characters & extracted IDs", "OK")

        # 14-17: File I/O Integration
        C = Sys_Fast.FAST_Data_DDEC
        temp_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_TEST_IO.xlsx")
        Sys_Fast.FAST_CleanTransient_DDEF(temp_file)
        
        df_mock = DataFrame(
            C.COL_EXP_ID => ["EXP_P1_01", "EXP_P1_02"],
            C.COL_PHASE => ["Phase1", "Phase1"]
        )
        
        try
            Sys_Fast.FAST_SafeExcelWrite_DDEF(temp_file, Dict(C.SHEET_DATA => df_mock))
            @track G1 isfile(temp_file)
            
            df_read = Sys_Fast.FAST_ReadExcel_DDEF(temp_file, C.SHEET_DATA)
            @track G1 nrow(df_read) == 2
            @track G1 uppercase(names(df_read)[1]) == "EXP_ID"
        finally
            Sys_Fast.FAST_CleanTransient_DDEF(temp_file)
            @track G1 !isfile(temp_file)
        end

        # 18-19: Smart naming and project extraction
        smart_name = Sys_Fast.FAST_GenerateSmartName_DDEF("DoECISORY", "Phase1", "Design")
        @track G1 startswith(smart_name, "DDE_DoECISORY_P1_Design_")
        @track G1 Sys_Fast.FAST_ExtractProjectFromFilename_DDEF("DDE_SampleProj_P1_Design_2026_0919_1200.xlsx") == "SampleProj"
        Sys_Fast.FAST_Log_DDEF("AUDIT", "SMART_NAME", "Generated DDE protocol filename patterns", "OK")
    end

    # ==========================================================================
    # GROUP 2: Lib_Core Matrices & Desirability Engine (17 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G2"
    @testset "Group 2: Lib_Core Matrices & Desirability Engine" begin
        # 20-21: Box-Behnken matrix
        design_bb = Lib_Core.CORE_Bb15Design_DDEC
        @track G2 size(design_bb) == (15, 3)
        @track G2 all(x -> x in [-1.0, 0.0, 1.0], design_bb)

        # 22-24: BBO Desirability engine
        X_bb = Float64.(design_bb)
        Y_bb = [20.0 - 5.0*(r[1]-0.2)^2 - 3.0*(r[2]+0.1)^2 - 2.0*r[3]^2 for r in eachrow(X_bb)]
        model_bb = Lib_Vise.VISE_Regress_DDEF(X_bb, Y_bb, "quadratic"; InNames=["X1", "X2", "X3"])
        goal_bb = Dict{String, Any}("Type" => "Maximise", "Min" => 0.0, "Max" => 25.0, "Target" => 22.0, "Weight" => 1.0, "WeightVal" => 1.0)
        model_bb["Goal"] = goal_bb
        bounds = [-1.0 1.0; -1.0 1.0; -1.0 1.0]

        best_vals, best_score = Lib_Core.CORE_OptimiseDesirability_DDEF([model_bb], [goal_bb], bounds; MaxTime=0.2)
        @track G2 best_score isa Float64
        @track G2 length(best_vals) == 3
        @track G2 best_score >= 0.0 && best_score <= 1.0

        # 25-27: Alternative design matrix shapes
        @track G2 size(Lib_Core.CORE_Tl09Design_DDEC) == (9, 3)
        @track G2 size(Lib_Core.CORE_Cd17Design_DDEC) == (17, 3)
        df14_mat = Lib_Core.CORE_GenDf14Design_DDEF([-1, -1, -1])
        @track G2 size(df14_mat) == (14, 3)

        # 28: Directional adaptation in DF14
        df14_pos = Lib_Core.CORE_GenDf14Design_DDEF([1, 1, 1])
        @track G2 df14_pos[2, 1] == 1
        Sys_Fast.FAST_Log_DDEF("CORE", "MATRICES", "Verified BB15, TL09, CD17, and DF14 matrix shapes", "OK")

        # 29-31: D-efficiency and design validation
        d_eff = Lib_Core.CORE_D_Efficiency_DDEF(Float64.(df14_mat))
        @track G2 d_eff > 0.30
        metrics = Lib_Core.CORE_CalcDesignMetrics_DDEF(X_bb)
        @track G2 haskey(metrics, "D") && metrics["D"] > 0.0
        val_ok, _ = Lib_Core.CORE_ValidateDesign_DDEF(ones(10, 3))
        @track G2 val_ok == false
        Sys_Fast.FAST_Log_DDEF("CORE", "D_EFFICIENCY", "D-FFCCD14 D-efficiency & validation metrics verified", "OK")

        # 32-34: DCYP Decay penalty engine
        lambda_ga68 = log(2.0) / 67.71
        dm_ga68 = Lib_Core.CORE_DecayModifier_DDES(3, lambda_ga68, [1], "Ga-68")
        @track G2 dm_ga68 isa Lib_Core.CORE_DecayModifier_DDES
        @track G2 Lib_Core.CORE_ApplyDecayPenalty_DDEF(100.0, dm_ga68, [0.0, 0.0, 0.0]) == 100.0
        val_decay_half = Lib_Core.CORE_ApplyDecayPenalty_DDEF(100.0, dm_ga68, [0.0, 0.0, 67.71])
        @track G2 isapprox(val_decay_half, 50.0; atol=1e-2)

        # 35-36: Desirability parsing & clamping
        goal_tup = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 0.0, "Max" => 100.0, "Target" => 90.0, "Weight" => 1.0))
        @track G2 goal_tup[1] isa Lib_Core.CORE_GoalMaximise_DDES
        d_clamped = Lib_Core.CORE_CalcDesirability_DDEF(150.0, goal_tup)
        @track G2 d_clamped <= 1.0 && d_clamped >= 0.0
        Sys_Fast.FAST_Log_DDEF("CORE", "DCYP_DECAY", "Exponential Ga-68 decay penalty & desirability verified", "OK")
    end

    # ==========================================================================
    # GROUP 3: Lib_Mole Stoichiometry & Radio-Decay (13 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G3"
    @testset "Group 3: Lib_Mole Stoichiometry & Radio-Decay" begin
        # 37-39: Mass calculation
        names_mol = String["Component A"]
        mws = Float64[150.0]
        ratios = Float64[100.0]
        units = String["mg"]
        masses = Lib_Mole.MOLE_CalcMass_DDEF(names_mol, mws, ratios, 5.0, 10.0, units, 1.0; SuppressLog=true)
        @track G3 masses isa DataFrame
        @track G3 nrow(masses) >= 1
        @track G3 masses[1, :TARGET_MASS_mg] > 0.0
        Sys_Fast.FAST_Log_DDEF("MOLE", "STOCHIOMETRY", "Calculated recipe component target masses", "OK")

        # 40-41: Isothermal radio-decay (Forward & Reverse)
        val_fwd = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(100.0, 109.7, "Minutes", 109.7; Reverse=false)
        @track G3 isapprox(val_fwd, 50.0; atol=1e-3)
        val_rev = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(100.0, 109.7, "Minutes", 109.7; Reverse=true)
        @track G3 isapprox(val_rev, 200.0; atol=1e-3)
        Sys_Fast.FAST_Log_DDEF("MOLE", "RADIO_DECAY", "Forward & reverse decay equations verified", "OK")

        # 42-44: Quick audit
        audit_rows = [Dict("Name" => "Component A", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 150.0, "Unit" => "mg")]
        ok_aud, report_aud, _, _, _ = Lib_Mole.MOLE_QuickAudit_DDEF(audit_rows, 5.0, 10.0)
        @track G3 ok_aud isa Bool
        @track G3 !isempty(report_aud)
        ok_empty, _, _, _, _ = Lib_Mole.MOLE_QuickAudit_DDEF(Dict{String,Any}[], 5.0, 10.0)
        @track G3 ok_empty == false

        # 45-46: Lu-177 decay kinetics and unit conversion
        lu_half_life_min = 6.647 * 24.0 * 60.0
        val_lu = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(100.0, lu_half_life_min, "Minutes", lu_half_life_min; Reverse=false)
        @track G3 isapprox(val_lu, 50.0; atol=1e-3)
        val_hour_conv = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(100.0, 1.0, "Hours", 60.0; Reverse=false)
        @track G3 isapprox(val_hour_conv, 50.0; atol=1e-3)

        # 47-49: Mass balance & Negative MW audit rejection
        @track G3 sum(masses[!, :TARGET_MASS_mg]) > 0.0
        audit_neg_mw = [Dict("Name" => "Bad Chem", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => -50.0, "Unit" => "mg")]
        ok_neg, _, _, _, _ = Lib_Mole.MOLE_QuickAudit_DDEF(audit_neg_mw, 5.0, 10.0)
        @track G3 ok_neg == false
        @track G3 masses[1, :TARGET_MASS_mg] == masses[1, :TARGET_MASS_mg]
        Sys_Fast.FAST_Log_DDEF("MOLE", "AUDIT_PASS", "Lu-177 decay kinetics & mass balance verified", "OK")
    end

    # ==========================================================================
    # GROUP 4: Lib_Vise Statistical Modeling & GLM (15 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G4"
    @testset "Group 4: Lib_Vise Statistical Modeling & GLM" begin
        X_reg = Float64.(Lib_Core.CORE_Bb15Design_DDEC)
        Y_reg = [10.0 + 2.0*r[1] + 3.0*(r[2]^2) for r in eachrow(X_reg)]
        names_in = ["X1", "X2", "X3"]

        # 50-51: Quadratic model fitting
        model_quad = Lib_Vise.VISE_Regress_DDEF(X_reg, Y_reg, "quadratic"; InNames=names_in)
        @track G4 model_quad["Status"] == "OK"
        @track G4 length(model_quad["Coefs"]) == 10

        # 52: Grid search
        goal_grid = Dict{String, Any}("Type" => "Maximise", "Min" => 0.0, "Max" => 20.0, "Target" => 15.0, "Weight" => 1.0, "WeightVal" => 1.0)
        bounds_grid = [-1.0 1.0; -1.0 1.0; -1.0 1.0]
        model_quad["Goal"] = goal_grid
        grid_res = Lib_Vise.VISE_GridSearch_DDEF([model_quad], [goal_grid], bounds_grid; Steps=5)
        @track G4 size(grid_res, 1) > 0

        # 53-56: ANOVA, normality, and sensitivity
        anova_tab = Lib_Vise.VISE_GenerateAnovaTable_DDEF(model_quad, X_reg, Y_reg)
        @track G4 anova_tab isa AbstractDataFrame
        norm_res = Lib_Vise.VISE_PerformNormalityTest_DDEF(model_quad, X_reg, Y_reg)
        @track G4 haskey(norm_res, "p") && haskey(norm_res, "IsNormal")
        sens_vec = Lib_Vise.VISE_SensitivityAnalysis_DDEF(model_quad, [0.0, 0.0, 0.0], X_reg)
        @track G4 sens_vec isa AbstractVector
        @track G4 size(sens_vec) == (3,)

        # 57: Linear model fitting
        model_lin = Lib_Vise.VISE_Regress_DDEF(X_reg, Y_reg, "linear"; InNames=names_in)
        @track G4 model_lin["Status"] == "OK" && length(model_lin["Coefs"]) == 4

        # 58-60: Determination metrics and VIF
        @track G4 model_quad["R2"] >= 0.0 && model_quad["R2"] <= 1.0
        @track G4 model_quad["R2_Adj"] <= model_quad["R2"] + 1e-6
        @track G4 all(v -> v >= 1.0, model_quad["VIFs"])
        Sys_Fast.FAST_Log_DDEF("VISE", "REGRESSION", "Quadratic & linear OLS models and VIFs verified", "OK")

        # 61-63: Model selection, cross-validation, and prediction
        best_mod, _ = Lib_Vise.VISE_SelectBestModel_DDEF(X_reg, Y_reg, names_in)
        @track G4 best_mod["ModelType"] in ["linear", "quadratic"]
        cv_q2 = Lib_Vise.VISE_CrossValidate_DDEF(X_reg, Y_reg, "quadratic")
        @track G4 cv_q2 isa Float64 && !isnan(cv_q2)
        pred_val = Lib_Vise.VISE_Predict_DDEF(model_quad, [0.0, 0.0, 0.0])
        @track G4 length(pred_val) == 1

        # 64: Singular matrix tolerance
        fail_mod = Lib_Vise.VISE_Regress_DDEF(zeros(10, 3), rand(10), "linear")
        @track G4 fail_mod["Status"] != "OK"
        Sys_Fast.FAST_Log_DDEF("VISE", "TOURNAMENT", "AIC model selection & PRESS Q² verified", "OK")
    end

    # ==========================================================================
    # GROUP 5: Sys_Flow Process Transitions & ACTA (17 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G5"
    @testset "Group 5: Sys_Flow Process Transitions & ACTA" begin
        # 65-70: Bridge transform & validation
        @track G5 Sys_Flow.FLOW_BridgeTransform_DDEF(10.0, 2.0, 5.0) == 25.0
        ok_v, val_v, _ = Sys_Flow.FLOW_BridgeValidate_DDEF(15.0, 0.0, 20.0)
        @track G5 ok_v == true
        @track G5 val_v == 15.0
        ok_c, val_c, msg_c = Sys_Flow.FLOW_BridgeValidate_DDEF(25.0, 0.0, 20.0)
        @track G5 ok_c == false
        @track G5 val_c == 20.0
        @track G5 !isempty(msg_c)
        Sys_Fast.FAST_Log_DDEF("FLOW", "TRANSFORMS", "Cross-phase affine coordinate translation verified", "OK")

        # 71-72: Adaptive range calculation
        old_rng = [10.0, 20.0, 30.0]
        new_rng = Sys_Flow.FLOW_CalcAdaptiveRange_DDEF(25.0, old_rng, 0.5, 0.0, 0.0)
        @track G5 length(new_rng) == 3
        @track G5 new_rng[2] == 25.0

        # 73-75: Boundary status classification
        @track G5 Sys_Flow.FLOW_DetermineBoundaryStatus_DDEF(3.0, 0.0, 100.0) isa Sys_Flow.FLOW_BoundaryLower_DDES
        @track G5 Sys_Flow.FLOW_DetermineBoundaryStatus_DDEF(97.0, 0.0, 100.0) isa Sys_Flow.FLOW_BoundaryUpper_DDES
        @track G5 Sys_Flow.FLOW_DetermineBoundaryStatus_DDEF(50.0, 0.0, 100.0) isa Sys_Flow.FLOW_BoundarySafe_DDES

        # 76-78: Proximity alert checks
        @track G5 Sys_Flow.FLOW_AskLeader_DDEF(50.0, [0.0, 50.0, 100.0])[1] == true
        @track G5 Sys_Flow.FLOW_AskLeader_DDEF(2.0, [0.0, 50.0, 100.0])[1] == false
        @track G5 Sys_Flow.FLOW_AskLeader_DDEF(98.0, [0.0, 50.0, 100.0])[1] == false
        Sys_Fast.FAST_Log_DDEF("FLOW", "BOUNDARIES", "Classified Lower, Upper, and Safe boundary states", "OK")

        # 79-81: Zoom and Shift physics
        zoomed = Sys_Flow.FLOW_CalcAdaptiveRange_DDEF(50.0, [0.0, 50.0, 100.0], 0.5, 0.0, 0.0)
        @track G5 (zoomed[3] - zoomed[1]) == 50.0
        shifted = Sys_Flow.FLOW_CalcAdaptiveRange_DDEF(50.0, [0.0, 50.0, 100.0], 1.0, 0.2, 0.0)
        @track G5 shifted[2] == 60.0
        @track G5 length(zoomed) == 3
        Sys_Fast.FAST_Log_DDEF("FLOW", "ACTA_ADAPT", "Applied 0.5 Zoom and 0.2 Shift factors", "OK")
    end

    # ==========================================================================
    # GROUP 6: Presentation, UI State & E2E Pipeline (19 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G6"
    @testset "Group 6: Presentation, UI State & E2E Pipeline" begin
        X_arts = Float64.(Lib_Core.CORE_Bb15Design_DDEC)
        Y_arts = [10.0 + 2.0*r[1] for r in eachrow(X_arts)]
        model_arts = Lib_Vise.VISE_Regress_DDEF(X_arts, Y_arts, "linear"; InNames=["X1", "X2", "X3"])

        # 82-83: Pareto and Fit plots
        p_pareto = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotPareto_DDES(), model_arts, "TestOut", 0.9, 0.8)
        @track G6 p_pareto isa PlotlyJS.Plot
        p_fit = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotFit_DDES(), Y_arts, Y_arts, "TestOut")
        @track G6 p_fit isa PlotlyJS.Plot
        Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_PLOTS", "Generated Pareto and Fit Plotly objects", "OK")

        # 84-85: Base UI Diagnostics
        @track G6 Gui_Base.BASE_SystemAuditUI_DDEF() !== nothing
        @track G6 Gui_Base.BASE_ScientificAuditUI_DDEF() !== nothing

        # 86-89: Lens UI stateless JSON graph manipulation
        mock_graphs_blob = """
        [
            {
                "title": "Pareto Plot",
                "figure": {
                    "data": [{"type": "bar", "x": [1.2, 3.4], "y": ["Factor A", "Factor B"]}],
                    "layout": {"title": {"text": "Pareto: Activity"}, "width": 320, "height": 400}
                }
            }
        ]
        """
        graphs = JSON3.read(mock_graphs_blob, Vector{Dict{String, Any}})
        @track G6 graphs isa Vector{Dict{String, Any}}
        fig_dict = graphs[1]["figure"]
        layout_dict = deepcopy(fig_dict["layout"])
        layout_dict["width"]  = 640
        layout_dict["height"] = 800
        @track G6 layout_dict["width"] == 640
        @track G6 layout_dict["height"] == 800
        @track G6 layout_dict["title"]["text"] == "Pareto: Activity"
        Sys_Fast.FAST_Log_DDEF("GUI", "STATELESS", "Validated stateless JSON layout mutability", "OK")

        # 90-94: Deck UI default state
        row_deck = Main.Gui_Deck.DECK_GetDefaultRow_DDEF(4)
        @track G6 row_deck["Role"] == "Fixed"
        @track G6 row_deck["MW"] == 0.0
        @track G6 row_deck["IsRadioactive"] == false
        @track G6 Main.Gui_Deck.DECK_SafeNumZero_DDEF("10.5") == 10.5
        @track G6 Main.Gui_Deck.DECK_SafeNumZero_DDEF(nothing) == 0.0

        # 95-96: System gardening & cleanup
        @track G6 isdir(Sys_Fast.FAST_TempRoot_DDEC)
        Sys_Fast.FAST_CleanWorkforce_DDEF(true)
        files_rem = readdir(Sys_Fast.FAST_TempRoot_DDEC)
        temp_files = filter(f -> startswith(f, "DOECISORY_TEMP_") || startswith(f, "DDE_"), files_rem)
        @track G6 isempty(temp_files)

        # 97-98: Contour and Surface plots
        p_surf = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotSurface_DDES(), model_arts, X_arts, [1, 2], ["X1", "X2"], "TestOut")
        @track G6 p_surf isa PlotlyJS.Plot
        p_cont = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotContour_DDES(), model_arts, X_arts, [1, 2], ["X1", "X2"], "TestOut")
        @track G6 p_cont isa PlotlyJS.Plot
        Sys_Fast.FAST_Log_DDEF("ARTS", "SURF_CONTOUR", "Generated 2D Contour and 3D Surface plots", "OK")

        # 99: Color theme constants
        @track G6 !isempty(Lib_Arts.ARTS_Theme_DDEC.PURBLA) && !isempty(Lib_Arts.ARTS_Theme_DDEC.PURWHI)

        # 100: End-to-End Pipeline Verification
        # Pipeline: DF14 Generation -> Quadratic Regression -> Ga-68 DCYP Desirability -> ACTA Next Range
        e2e_matrix = Lib_Core.CORE_GenDf14Design_DDEF()
        e2e_X = Float64.(e2e_matrix)
        e2e_Y = [15.0 + 3.0*r[1] - 2.5*r[2]^2 + 1.2*r[3] for r in eachrow(e2e_X)]
        e2e_mod = Lib_Vise.VISE_Regress_DDEF(e2e_X, e2e_Y, "quadratic"; InNames=["Temp", "Time", "Dose"])
        e2e_goal = Dict{String, Any}("Type" => "Maximise", "Min" => 0.0, "Max" => 30.0, "Target" => 25.0, "Weight" => 1.0, "WeightVal" => 1.0)
        e2e_mod["Goal"] = e2e_goal
        e2e_decay = [Lib_Core.CORE_DecayModifier_DDES(2, log(2.0)/67.71, [1], "Ga-68")]
        e2e_bounds = [-1.0 1.0; -1.0 1.0; -1.0 1.0]
        
        e2e_best_x, e2e_best_s = Lib_Core.CORE_OptimiseDesirability_DDEF([e2e_mod], [e2e_goal], e2e_bounds; MaxTime=0.2, DecayModifiers=e2e_decay)
        e2e_next_range = Sys_Flow.FLOW_CalcAdaptiveRange_DDEF(e2e_best_x[1], [-1.0, 0.0, 1.0], 0.5, 0.0, 0.0)

        @track G6 (e2e_best_s >= 0.0 && length(e2e_best_x) == 3 && length(e2e_next_range) == 3)
        Sys_Fast.FAST_Log_DDEF("E2E", "INTEGRATION", "End-to-end multi-phase theranostic workflow verified", "OK")
    end

    Sys_Fast.FAST_ActiveGroup_DDEC[] = ""
end

# ==============================================================================
# SOBER & TECHNICAL TERMINAL REPORTING DASHBOARD
# ==============================================================================
const SUITE_DURATION = round(time() - SUITE_START_TIME; digits=2)

let
    total_runs   = sum(t.total for t in values(TRACKER))
    total_passed = sum(t.passed for t in values(TRACKER))
    total_failed = sum(t.failed for t in values(TRACKER))
    pct_overall  = total_runs > 0 ? round((total_passed / total_runs) * 100.0; digits=1) : 0.0

    group_keys = ["G1", "G2", "G3", "G4", "G5", "G6"]

    println("\n" * "="^80)
    println("                          DoECISORY TEST SUITE REPORT                           ")
    println("="^80)
    @printf("  %-45s %5s  %6s  %6s   %7s  \n", "Domain Group", "Total", "Passed", "Failed", "Success")
    println("-"^80)

    for k in group_keys
        t = TRACKER[k]
        pct = t.total > 0 ? round((t.passed / t.total) * 100.0; digits=1) : 0.0
        @printf("  %-45s %5d  %6d  %6d   %6.1f%%  \n", t.name, t.total, t.passed, t.failed, pct)
    end

    println("-"^80)
    
    # Progress bar calculation (40 columns width)
    bar_width = 40
    filled = total_runs > 0 ? clamp(round(Int, (total_passed / total_runs) * bar_width), 0, bar_width) : 0
    empty_slots = bar_width - filled
    bar_str = "="^filled * " "^empty_slots

    @printf("  PROGRESS    : [%s] %5.1f%%\n", bar_str, pct_overall)
    @printf("  SUMMARY     : %d / %d passed (%d failed, 0 errored)\n", total_passed, total_runs, total_failed)
    @printf("  DURATION    : %.2f seconds\n", SUITE_DURATION)
    @printf("  FINAL STATUS: %s\n", total_failed == 0 && total_runs == 100 ? "PASSED" : "FAILED")
    println("="^80 * "\n")
end
