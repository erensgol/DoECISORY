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
using LinearAlgebra
using Statistics

using DoECISORY
using DoECISORY.Sys_Fast
using DoECISORY.Lib_Core
using DoECISORY.Lib_Mole
using DoECISORY.Sys_Flow
using DoECISORY.Lib_Vise
using DoECISORY.Lib_Arts
using DoECISORY.Gui_Base
using DoECISORY.Gui_Deck
using DoECISORY.Gui_Lens

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
    "G1" => GroupTracker("[G1] Sys_Fast Utilities, Resilience & Excel I/O", 0, 0, 0),
    "G2" => GroupTracker("[G2] Lib_Core Optimal Matrices, D-A-G-I & Desirability", 0, 0, 0),
    "G3" => GroupTracker("[G3] Lib_Mole Stoichiometry, Mass Invariance & Decay", 0, 0, 0),
    "G4" => GroupTracker("[G4] Lib_Vise Statistical Modeling, OLS & Tournament", 0, 0, 0),
    "G5" => GroupTracker("[G5] Sys_Flow ACTA & IPKT Framework", 0, 0, 0),
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
    line = __source__.line
    return quote
        cond = try
            $(esc(expr))
        catch err
            println("[ERROR in ", $grp_str, " L", $line, "]: ", err)
            false
        end
        track_eval($grp_str, cond)
        if !cond
            println("[FAIL in ", $grp_str, " L", $line, "]: ", $(QuoteNode(expr)))
        end
        @test cond
    end
end

const SUITE_START_TIME = time()

@testset "DoECISORY Master Test Suite (100 Verifications)" begin
    # ==========================================================================
    # GROUP 1: Sys_Fast Utilities, Resilience & Excel I/O (16 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G1"
    Sys_Fast.FAST_InitialiseWorkforce_DDEF()

    @testset "Group 1: Sys_Fast Utilities, Resilience & Excel I/O" begin
        # 1: Scientific, comma, and negative numeric parsing
        @track G1 isapprox(Sys_Fast.FAST_SafeNum_DDEF("1.25e-3"), 0.00125; atol=1e-6) && Sys_Fast.FAST_SafeNum_DDEF("12,7") == 12.7 && Sys_Fast.FAST_SafeNum_DDEF("-0,0035") == -0.0035

        # 2: Degenerate and malformed numeric input handling
        @track G1 all(isnan, [Sys_Fast.FAST_SafeNum_DDEF(nothing), Sys_Fast.FAST_SafeNum_DDEF(missing), Sys_Fast.FAST_SafeNum_DDEF("  -  "), Sys_Fast.FAST_SafeNum_DDEF("abc"), Sys_Fast.FAST_SafeNum_DDEF(""), Sys_Fast.FAST_SafeNum_DDEF("   "), Sys_Fast.FAST_SafeNum_DDEF("1.2.3")])

        # 3: Filename sanitisation, special characters, and path traversal defense
        @track G1 Sys_Fast.FAST_SanitiseFilename_DDEF("öğrenci_işleri.xlsx") == "ogrenci_isleri.xlsx" && Sys_Fast.FAST_SanitiseFilename_DDEF("test/file!name.csv") == "test_file_name.csv" && Sys_Fast.FAST_SanitiseFilename_DDEF("secret/system.xlsx") == "secret_system.xlsx"

        # 4: Universal DataID and Hash extraction
        @track G1 Sys_Fast.FAST_ExtractDataID_DDEF(Dict("dataid" => "HASH_123")) == "HASH_123" && Sys_Fast.FAST_ExtractDataID_DDEF("HASH_456") == "HASH_456"

        # 5: Bidirectional smart protocol filename generation and project extraction
        let name = Sys_Fast.FAST_GenerateSmartName_DDEF("DoECISORY", "Phase1", "Design")
            @track G1 startswith(name, "DDE_DoECISORY_P1_Design_") && Sys_Fast.FAST_ExtractProjectFromFilename_DDEF(name) == "DoECISORY"
        end

        # 6: Condition number formatting and colour tokens
        let c1 = Sys_Fast.FAST_FormatConditionNumber_DDEF(41.25),
            c2 = Sys_Fast.FAST_FormatConditionNumber_DDEF(Inf),
            c3 = Sys_Fast.FAST_FormatConditionNumber_DDEF(NaN)
            @track G1 c1[1] == "41.2" && c1[3] == "var(--colour-chr4-tongre)" && c2[1] == "Singular" && c2[3] == "var(--colour-chr0-huered)" && c3[1] == "N/A" && c3[3] == "var(--colour-val3-darlow)"
        end

        # 7: Configuration read, in-memory cache isolation, and update round-trip
        let cfg_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_CFG_TEST.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(cfg_file)
            df_init = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => [JSON3.write(Dict("Phase" => "Phase1", "Volume" => 10.0))])
            Sys_Fast.FAST_SafeExcelWrite_DDEF(cfg_file, Dict(Sys_Fast.FAST_Data_DDEC.SHEET_CONFIG => df_init))
            cfg1 = Sys_Fast.FAST_ReadConfig_DDEF(cfg_file)
            cfg1["Volume"] = 25.0
            cfg2 = Sys_Fast.FAST_ReadConfig_DDEF(cfg_file)
            upd_ok = Sys_Fast.FAST_UpdateConfig_DDEF(cfg_file, Dict("Phase" => "Phase1", "Volume" => 50.0))
            cfg3 = Sys_Fast.FAST_ReadConfig_DDEF(cfg_file)
            Sys_Fast.FAST_CleanTransient_DDEF(cfg_file)
            @track G1 cfg2["Volume"] == 10.0 && upd_ok && cfg3["Volume"] == 50.0
        end

        # 8: Input parameter sanitisation and anomaly warnings
        let raw_table = [
                Dict("Name" => "Ga-68 Precursor", "Role" => "Variable", "HalfLife" => 67.71, "MW" => 1435.0, "L1" => "10.5"),
                Dict("Name" => "Buffer", "Role" => "Fixed", "MW" => "abc", "L2" => "25.0")
            ],
            (san, warns) = Sys_Fast.FAST_SanitiseInput_DDEF(raw_table)
            @track G1 san[1]["IsRadioactive"] == true && san[1]["L1"] == 10.5 && san[2]["MW"] == 0.0 && length(warns) == 1
        end

        # 9: DataFrame column rounding and numeric precision preservation
        let df_round = DataFrame("A" => [1.234567, 8.910111], "B" => ["keep", "text"], "C" => [100.1, missing])
            Sys_Fast.FAST_RoundCols_DDEF!(df_round)
            @track G1 df_round.A == [1.235, 8.91] && df_round.B == ["keep", "text"] && df_round.C[1] == 100.1
        end

        # 10: Excel workbook generation with multi-sheet dirty user data
        let temp_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_TEST_IO.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(temp_file)
            df_real_dirty = DataFrame(
                Sys_Fast.FAST_Data_DDEC.COL_EXP_ID => ["EXP_P1_01", "EXP_P1_02", "EXP_P1_03"],
                Sys_Fast.FAST_Data_DDEC.COL_PHASE => ["Phase1", "Phase1", "Phase1"],
                "Temp" => [25.0, 50.0, 75.0],
                "Yield" => ["", "", ""],
                "Notes" => ["Initial run", "", "Replicate test"]
            )
            df_cfg = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => ["{\"Variables\": 3}"])
            Sys_Fast.FAST_SafeExcelWrite_DDEF(temp_file, Dict(Sys_Fast.FAST_Data_DDEC.SHEET_DATA => df_real_dirty, Sys_Fast.FAST_Data_DDEC.SHEET_CONFIG => df_cfg))
            @track G1 isfile(temp_file) && filesize(temp_file) > 1000
        end

        # 11: Sheet reading and structural schema validation
        let temp_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_TEST_IO.xlsx"),
            C = Sys_Fast.FAST_Data_DDEC,
            df_read = Sys_Fast.FAST_ReadExcel_DDEF(temp_file, C.SHEET_DATA),
            valid_struct = Sys_Fast.FAST_ValidateSheetStructure_DDEF(df_read, C.SHEET_DATA),
            invalid_struct = Sys_Fast.FAST_ValidateSheetStructure_DDEF(DataFrame("A" => [1], "B" => [2]), "BadSheet")
            @track G1 nrow(df_read) == 3 && valid_struct == true && invalid_struct == false
        end

        # 12: Column name normalisation and case formatting
        @track G1 uppercase.(names(Sys_Fast.FAST_NormaliseCols_DDEF!(DataFrame(" exp_id " => [1], "pHAse" => ["P1"])))) == ["EXP_ID", "PHASE"]

        # 13: Configuration cache invalidation on write
        let temp_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_TEST_IO.xlsx")
            lock(Sys_Fast.FAST_ConfigCacheLock_DDEC) do
                Sys_Fast.FAST_ConfigCache_DDEC[temp_file] = Dict("Cached" => true)
            end
            Sys_Fast.FAST_SafeExcelWrite_DDEF(temp_file, Dict("DATA" => DataFrame("A" => [1])))
            @track G1 !haskey(Sys_Fast.FAST_ConfigCache_DDEC, temp_file)
        end

        # 14: Transient file deletion
        let temp_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_TEST_IO.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(temp_file)
            @track G1 !isfile(temp_file)
        end

        # 15: Transient file path generation and isolation
        let t_path = Sys_Fast.FAST_GetTransientPath_DDEF(),
            res = startswith(abspath(t_path), abspath(Sys_Fast.FAST_TempRoot_DDEC)) && endswith(t_path, ".xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(t_path)
            @track G1 res
        end

        # 16: Transient workspace directory lifecycle management
        let dummy = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_CLEANUP_CHECK.xlsx")
            Sys_Fast.FAST_SafeExcelWrite_DDEF(dummy, Dict("SHEET" => DataFrame("X" => [1])))
            Sys_Fast.FAST_CleanWorkforce_DDEF(true)
            @track G1 !isfile(dummy)
        end
    end

    # ==========================================================================
    # GROUP 2: Lib_Core Optimal Matrices, D-A-G-I & Desirability (18 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G2"
    @testset "Group 2: Lib_Core Optimal Matrices, D-A-G-I & Desirability" begin
        # 17: Box-Behnken and Central Composite matrix dimensions and center points
        @track G2 size(Lib_Core.CORE_Bb15Design_DDEC) == (15, 3) && count(r -> all(==(0), r), eachrow(Lib_Core.CORE_Bb15Design_DDEC)) == 3 && size(Lib_Core.CORE_Cd17Design_DDEC) == (17, 3)

        # 18: Matrix generation factory and invalid design type handling
        let bb = Lib_Core.CORE_GenDesign_DDEF("BB15"),
            cd = Lib_Core.CORE_GenDesign_DDEF("CD17"),
            tl = Lib_Core.CORE_GenDesign_DDEF("TL09"),
            err_thrown = false
            try
                Lib_Core.CORE_GenDesign_DDEF("UNKNOWN_TYPE")
            catch e
                err_thrown = (e isa ArgumentError)
            end
            @track G2 size(bb) == (15, 3) && size(cd) == (17, 3) && size(tl) == (9, 3) && err_thrown
        end

        # 19: Directional D-optimal DF14 matrix structure and determinant symmetry
        let df14_neg = Lib_Core.CORE_GenDf14Design_DDEF([-1, -1, -1]),
            df14_pos = Lib_Core.CORE_GenDf14Design_DDEF([1, 1, 1])
            @track G2 size(df14_neg) == (14, 3) && count(r -> all(==(0), r), eachrow(df14_neg)) == 3 && isapprox(det(Float64.(df14_neg)' * Float64.(df14_neg)), det(Float64.(df14_pos)' * Float64.(df14_pos)); atol=1e-3)
        end

        # 20: Physical level mapping from coded coordinates
        let coded = [-1.0 0.0 1.0; 1.0 -1.0 0.0],
            config = [
                Dict("Levels" => [10.0, 20.0, 30.0]),
                Dict("Levels" => [5.0, 10.0, 15.0]),
                Dict("Levels" => [100.0, 200.0, 300.0])
            ],
            mapped = Lib_Core.CORE_MapLevels_DDEF(coded, config)
            @track G2 mapped[1, :] == [10.0, 10.0, 300.0] && mapped[2, :] == [30.0, 5.0, 200.0]
        end

        # 21: Model matrix expansion for Linear and Quadratic forms
        let X = Float64.(Lib_Core.CORE_Bb15Design_DDEC),
            X_lin = Lib_Core.CORE_ExpandModelMatrix_DDEF(X, Lib_Core.CORE_ModelLinear_DDES()),
            X_qua = Lib_Core.CORE_ExpandModelMatrix_DDEF(X, Lib_Core.CORE_ModelQuadratic_DDES())
            @track G2 size(X_lin) == (15, 4) && size(X_qua) == (15, 10) && all(==(1.0), X_qua[:, 1])
        end

        # 22: D-efficiency calculation
        @track G2 Lib_Core.CORE_D_Efficiency_DDEF(Float64.(Lib_Core.CORE_Bb15Design_DDEC)) > 0.35

        # 23: Comprehensive D, A, G, I optimality and condition number calculation
        let m = Lib_Core.CORE_CalcDesignMetrics_DDEF(Float64.(Lib_Core.CORE_Bb15Design_DDEC))
            @track G2 m["D"] > 0.30 && m["A"] > 0.0 && m["G"] > 0.0 && m["I"] > 0.0 && m["Condition"] < 100.0
        end

        # 24: Singular matrix handling and condition number divergence
        let m_sing = Lib_Core.CORE_CalcDesignMetrics_DDEF(ones(15, 3))
            @track G2 m_sing["D"] == 0.0 && (isinf(m_sing["Condition"]) || m_sing["Condition"] > 1e10)
        end

        # 25: Matrix anomaly detection for zero-variance columns
        let (val_ok, val_warns) = Lib_Core.CORE_ValidateDesign_DDEF(ones(10, 3))
            @track G2 val_ok == false && occursin("zero variance", val_warns)
        end

        # 26: Duplicate run detection in design matrix
        let X_dup = [0.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0; 1.0 2.0 3.0],
            (ok, msg) = Lib_Core.CORE_ValidateDesign_DDEF(X_dup)
            @track G2 ok == false && occursin("duplicate rows", msg)
        end

        # 27: Goal definition extraction and boundary defaults
        let g1 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0)),
            g2 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "InvalidType", "Min" => 5.0, "Max" => 10.0))
            @track G2 g1[1] isa Lib_Core.CORE_GoalMaximise_DDES && g1[3] == 50.0 && g2[1] isa Lib_Core.CORE_GoalNominal_DDES
        end

        # 28: Desirability calculations for Maximise, Minimise, and Nominal targets
        let g_max = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0, "Target" => 40.0, "Weight" => 1.0)),
            g_min = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Minimise", "Min" => 0.0, "Max" => 20.0, "Target" => 5.0, "Weight" => 1.0)),
            g_nom = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Nominal", "Min" => 10.0, "Max" => 30.0, "Target" => 20.0, "Weight" => 1.0)),
            d_max = Lib_Core.CORE_CalcDesirability_DDEF(25.0, g_max),
            d_min = Lib_Core.CORE_CalcDesirability_DDEF(2.0, g_min),
            d_nom = Lib_Core.CORE_CalcDesirability_DDEF(20.0, g_nom)
            @track G2 isapprox(d_max, 0.5; atol=1e-3) && d_min == 1.0 && d_nom == 1.0
        end

        # 29: Desirability power weighting curvature
        let g_w1 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 0.0, "Max" => 10.0, "Target" => 10.0, "Weight" => 1.0)),
            g_w2 = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 0.0, "Max" => 10.0, "Target" => 10.0, "Weight" => 2.0)),
            d1 = Lib_Core.CORE_CalcDesirability_DDEF(5.0, g_w1),
            d2 = Lib_Core.CORE_CalcDesirability_DDEF(5.0, g_w2)
            @track G2 isapprox(d1, 0.5; atol=1e-3) && isapprox(d2, 0.25; atol=1e-3)
        end

        # 30: Multi-objective zero-desirability extinction
        let X_bb = Float64.(Lib_Core.CORE_Bb15Design_DDEC),
            mod_ok = Lib_Vise.VISE_Regress_DDEF(X_bb, fill(25.0, 15), "linear"),
            mod_fail = Lib_Vise.VISE_Regress_DDEF(X_bb, fill(0.0, 15), "linear"),
            g_ok = Lib_Core.CORE_ExtractGoal_DDEF(Dict("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0, "Target" => 40.0, "Weight" => 1.0)),
            g_unreach = Dict{String, Any}("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0, "Target" => 40.0, "Weight" => 1.0, "WeightVal" => 1.0),
            (_, score_zero) = Lib_Core.CORE_OptimiseDesirability_DDEF([mod_ok, mod_fail], [g_ok, g_unreach], [-1.0 1.0; -1.0 1.0; -1.0 1.0]; MaxTime=0.1)
            @track G2 score_zero < 1e-4
        end

        # 31: Multi-objective interior Pareto trade-off optimization
        let X_opt = Float64.(Lib_Core.CORE_Bb15Design_DDEC),
            Y_yield = [20.0 + 10.0*r[1] + 5.0*r[2] for r in eachrow(X_opt)],
            Y_imp   = [2.0 + 8.0*r[1] - 3.0*r[2] for r in eachrow(X_opt)],
            m_yield = Lib_Vise.VISE_Regress_DDEF(X_opt, Y_yield, "linear"),
            m_imp   = Lib_Vise.VISE_Regress_DDEF(X_opt, Y_imp, "linear"),
            g_yield = Dict{String,Any}("Type" => "Maximise", "Min" => 10.0, "Max" => 35.0, "Target" => 35.0, "Weight" => 1.0, "WeightVal" => 1.0),
            g_imp   = Dict{String,Any}("Type" => "Minimise", "Min" => 0.0, "Max" => 15.0, "Target" => 0.0, "Weight" => 1.0, "WeightVal" => 1.0),
            bounds  = [-1.0 1.0; -1.0 1.0; -1.0 1.0],
            (best_x, best_s) = Lib_Core.CORE_OptimiseDesirability_DDEF([m_yield, m_imp], [g_yield, g_imp], bounds; MaxTime=0.2)
            @track G2 best_s > 0.3 && length(best_x) == 3
        end

        # 32: Multi-objective desirability weight sensitivity
        let X_opt = Float64.(Lib_Core.CORE_Bb15Design_DDEC),
            Y_yield = [20.0 + 10.0*r[1] for r in eachrow(X_opt)],
            Y_imp   = [2.0 + 10.0*r[1] for r in eachrow(X_opt)],
            m_y = Lib_Vise.VISE_Regress_DDEF(X_opt, Y_yield, "linear"),
            m_i = Lib_Vise.VISE_Regress_DDEF(X_opt, Y_imp, "linear"),
            bounds = [-1.0 1.0; -1.0 1.0; -1.0 1.0],
            g_y_hi = Dict{String,Any}("Type" => "Maximise", "Min" => 10.0, "Max" => 30.0, "Target" => 30.0, "Weight" => 10.0, "WeightVal" => 10.0),
            g_i_lo = Dict{String,Any}("Type" => "Minimise", "Min" => 0.0, "Max" => 15.0, "Target" => 0.0, "Weight" => 1.0, "WeightVal" => 1.0),
            (bx_y, _) = Lib_Core.CORE_OptimiseDesirability_DDEF([m_y, m_i], [g_y_hi, g_i_lo], bounds; MaxTime=0.2),
            g_y_lo = Dict{String,Any}("Type" => "Maximise", "Min" => 10.0, "Max" => 30.0, "Target" => 30.0, "Weight" => 1.0, "WeightVal" => 1.0),
            g_i_hi = Dict{String,Any}("Type" => "Minimise", "Min" => 0.0, "Max" => 15.0, "Target" => 0.0, "Weight" => 10.0, "WeightVal" => 10.0),
            (bx_i, _) = Lib_Core.CORE_OptimiseDesirability_DDEF([m_y, m_i], [g_y_lo, g_i_hi], bounds; MaxTime=0.2)
            @track G2 bx_y[1] > bx_i[1]
        end

        # 33: Radiochemical decay penalty modification
        let dm_ga = Lib_Core.CORE_DecayModifier_DDES(3, log(2.0) / 67.71, [1], "Ga-68"),
            val_decay = Lib_Core.CORE_ApplyDecayPenalty_DDEF(100.0, dm_ga, [0.0, 0.0, 67.71])
            @track G2 isapprox(val_decay, 50.0; atol=1e-2)
        end

        # 34: Decay modifier structure validation
        let dm = Lib_Core.CORE_DecayModifier_DDES(2, log(2.0) / 109.77, [1, 2], "F-18")
            @track G2 dm.TimeIndex == 2 && dm.IsotopeName == "F-18" && length(dm.AffectedOutputs) == 2
        end
    end

    # ==========================================================================
    # GROUP 3: Lib_Mole Stoichiometry, Mass Invariance & Decay (16 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G3"
    @testset "Group 3: Lib_Mole Stoichiometry, Mass Invariance & Decay" begin
        # 35: Recipe component target masses and molar ratio conservation
        let names = ["Precursor", "Buffer"],
            mws = [1435.0, 210.0],
            ratios = [50.0, 50.0],
            df_mass = Lib_Mole.MOLE_CalcMass_DDEF(names, mws, ratios, 5.0, 10.0, ["%", "%"]; SuppressLog=true)
            @track G3 nrow(df_mass) == 2 && df_mass.TARGET_MASS_mg[1] > 0.0 && isapprox(sum(df_mass.Molar_Ratio), 100.0; atol=1e-3)
        end

        # 36: Automatic filler balancing
        let rows_fill = [
                Dict("Name" => "Var A", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 500.0, "Unit" => "%m"),
                Dict("Name" => "Var B", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 400.0, "Unit" => "%m"),
                Dict("Name" => "Var C", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 300.0, "Unit" => "%m"),
                Dict("Name" => "Saline", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 58.44, "Unit" => "%m")
            ],
            (ok, rep, _, _, _) = Lib_Mole.MOLE_QuickAudit_DDEF(rows_fill, 10.0, 1.0)
            @track G3 ok == true && occursin("auto-balanced", rep)
        end

        # 37: Negative filler rejection on budget overflow
        let rows_overflow = [
                Dict("Name" => "Var A", "Role" => "Variable", "L1" => 60.0, "L2" => 60.0, "L3" => 60.0, "MW" => 500.0, "Unit" => "%m"),
                Dict("Name" => "Var B", "Role" => "Variable", "L1" => 50.0, "L2" => 50.0, "L3" => 50.0, "MW" => 400.0, "Unit" => "%m"),
                Dict("Name" => "Var C", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 300.0, "Unit" => "%m"),
                Dict("Name" => "Saline", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 58.44, "Unit" => "%m")
            ],
            (ok, rep, _, _, _) = Lib_Mole.MOLE_QuickAudit_DDEF(rows_overflow, 10.0, 1.0)
            @track G3 ok == false && occursin("Filler balance failed", rep)
        end

        # 38: Table validation rejection on negative molecular weight or non-positive volume
        let rows_neg_mw = [Dict("Name" => "Bad Chem", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => -150.0, "Unit" => "mg")],
            (ok1, _, _, _, _) = Lib_Mole.MOLE_QuickAudit_DDEF(rows_neg_mw, 10.0, 1.0),
            (ok2, _, _, _, _) = Lib_Mole.MOLE_QuickAudit_DDEF(Dict{String,Any}[], 0.0, 1.0)
            @track G3 ok1 == false && ok2 == false
        end

        # 39: Multi-unit percentage equivalence conversion
        let eq_pct = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(15.0, "%m", 100.0, 10.0, 10.0),
            eq_mg  = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "mg", 100.0, 10.0, 10.0),
            eq_mm  = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(5.0, "mM", 100.0, 10.0, 10.0)
            @track G3 eq_pct == 15.0 && isapprox(eq_mg, 100.0; atol=1e-3) && isapprox(eq_mm, 50.0; atol=1e-3)
        end

        # 40: Stoichiometric zero budget handling
        let eq_zero_vol = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "mg", 100.0, 0.0, 10.0),
            eq_zero_mw  = Lib_Mole.MOLE_GetPercentageEquivalent_DDEF(10.0, "mg", 0.0, 10.0, 10.0)
            @track G3 eq_zero_vol == 0.0 && eq_zero_mw == 0.0
        end

        # 41: Design matrix stoichiometric feasibility validation
        let X_feas = Float64.(Lib_Core.CORE_Bb15Design_DDEC),
            meta_overflow = [
                Dict("Name" => "Salt", "Role" => "Variable", "MW" => 58.44, "Unit" => "%m"),
                Dict("Name" => "Acid", "Role" => "Variable", "MW" => 98.0, "Unit" => "%m"),
                Dict("Name" => "Base", "Role" => "Variable", "MW" => 40.0, "Unit" => "%m"),
                Dict("Name" => "Water", "Role" => "Filler", "MW" => 18.01, "Unit" => "%m")
            ],
            (feas_ok, feas_msg) = Lib_Mole.MOLE_ValidateDesignFeasibility_DDEF(X_feas .* 150.0, meta_overflow, 10.0, 1.0)
            @track G3 feas_ok == false && occursin("overflow", feas_msg)
        end

        # 42: Physical recipe matrix generation from experimental design
        let rows_proc = [
                Dict("Name" => "VarA", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 100.0, "Unit" => "%m"),
                Dict("Name" => "VarB", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 120.0, "Unit" => "%m"),
                Dict("Name" => "VarC", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "MW" => 150.0, "Unit" => "%m"),
                Dict("Name" => "Solvent", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 18.0, "Unit" => "%m")
            ],
            df_proc = Lib_Mole.MOLE_ProcessDesign_DDEF(Float64.(Lib_Core.CORE_Bb15Design_DDEC), rows_proc, 10.0, 1.0)
            @track G3 nrow(df_proc) == 15 && "MASS_VarA_mg" in names(df_proc) && "MASS_Solvent_mg" in names(df_proc)
        end

        # 43: Batch design matrix audit
        let rows_fill = [
                Dict("Name" => "Var A", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 500.0, "Unit" => "%m"),
                Dict("Name" => "Saline", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 58.44, "Unit" => "%m")
            ],
            batch_res = Lib_Mole.MOLE_AuditBatch_DDEF(rows_fill, Float64.(Lib_Core.CORE_Bb15Design_DDEC), 10.0, 1.0)
            @track G3 batch_res["IsFeasible"] == true && length(batch_res["RunMasses"]) == 15
        end

        # 44: Mixed-unit stoichiometric recipe validation
        let rows_mixed = [
                Dict("Name" => "Peptide", "Role" => "Variable", "L1" => 5.0, "L2" => 10.0, "L3" => 15.0, "MW" => 1500.0, "Unit" => "mg"),
                Dict("Name" => "Buffer", "Role" => "Variable", "L1" => 1.0, "L2" => 2.0, "L3" => 3.0, "MW" => 120.0, "Unit" => "mM"),
                Dict("Name" => "Additive", "Role" => "Variable", "L1" => 1.0, "L2" => 2.0, "L3" => 3.0, "MW" => 60.0, "Unit" => "%m"),
                Dict("Name" => "Water", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 18.0, "Unit" => "%m")
            ],
            (ok_m, rep_m, _, _, _) = Lib_Mole.MOLE_QuickAudit_DDEF(rows_mixed, 100.0, 10.0)
            @track G3 ok_m == true && occursin("GRAVIMETRIC AUDIT", rep_m)
        end

        # 45: Forward and reverse radioactive decay kinetics
        let fwd = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(100.0, 67.71, "Minutes", 135.42; Reverse=false),
            rev = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(25.0, 67.71, "Minutes", 135.42; Reverse=true),
            fwd_d = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(100.0, 6.647, "Days", 6.647 * 1440.0; Reverse=false)
            @track G3 isapprox(fwd, 25.0; atol=1e-3) && isapprox(rev, 100.0; atol=1e-3) && isapprox(fwd_d, 50.0; atol=1e-3)
        end

        # 46: Radio-decay temporal limit handling
        let d_zero = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(100.0, 60.0, "Minutes", 0.0),
            d_inf  = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(100.0, 1.0, "Minutes", 1e5)
            @track G3 isapprox(d_zero, 100.0; atol=1e-3) && isapprox(d_inf, 0.0; atol=1e-6)
        end

        # 47: Time unit conversion and format validation
        @track G3 Lib_Mole.MOLE_ConvertTimeToMinutes_DDEF(2.0, "Hours") == 120.0 && Lib_Mole.MOLE_ConvertTimeToMinutes_DDEF(1.0, "Days") == 1440.0 && Lib_Mole.MOLE_IsTimeUnit_DDEF("min") && !Lib_Mole.MOLE_IsTimeUnit_DDEF("mg")

        # 48: Physical unit syntax and dimension validation
        let (m_ok, _, _) = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("5.0 mg", "Mass"),
            (c_ok, _, _) = Lib_Mole.MOLE_ValidatePhysicalUnit_DDEF("10.0 mM", "Concentration")
            @track G3 m_ok && c_ok
        end

        # 49: Unit classification and scale factor extraction
        let (u_mg, s_mg) = Lib_Mole.MOLE_GetUnitType_DDEF("mg"),
            (u_mm, s_mm) = Lib_Mole.MOLE_GetUnitType_DDEF("mM"),
            (u_pc, s_pc) = Lib_Mole.MOLE_GetUnitType_DDEF("%m")
            @track G3 u_mg isa Lib_Mole.MOLE_UnitMass_DDES && s_mg == 1.0 && u_mm isa Lib_Mole.MOLE_UnitConcentration_DDES && u_pc isa Lib_Mole.MOLE_UnitMolar_DDES
        end

        # 50: Table ingredient role classification
        let rows_audit = [
                Dict("Name" => "Var A", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 500.0, "Unit" => "%m"),
                Dict("Name" => "Var B", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 400.0, "Unit" => "%m"),
                Dict("Name" => "Var C", "Role" => "Variable", "L1" => 10.0, "L2" => 10.0, "L3" => 10.0, "MW" => 300.0, "Unit" => "%m"),
                Dict("Name" => "Saline", "Role" => "Filler", "L1" => 0.0, "L2" => 0.0, "L3" => 0.0, "MW" => 58.44, "Unit" => "%m")
            ],
            parsed_t = Lib_Mole.MOLE_ParseTable_DDEF(rows_audit)
            @track G3 length(parsed_t["Idx_Var"]) == 3 && length(parsed_t["Idx_Fill"]) == 1
        end
    end

    # ==========================================================================
    # GROUP 4: Lib_Vise Statistical Modeling, OLS & Tournament (18 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G4"
    @testset "Group 4: Lib_Vise Statistical Modeling, OLS & Tournament" begin
        X_quad = Float64.(Lib_Core.CORE_Bb15Design_DDEC)
        Y_quad = [10.0 + 2.0*r[1] - 1.5*r[2] + 0.8*r[3] + 2.5*r[1]^2 - 3.0*r[2]^2 + 1.2*r[1]*r[2] for r in eachrow(X_quad)]
        names_in = ["X1", "X2", "X3"]

        # 51: Quadratic response surface regression fit
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in)
            @track G4 m_q["Status"] == "OK" && length(m_q["Coefs"]) == 10 && m_q["R2"] > 0.999
        end

        # 52: Linear regression fit
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            m_l = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_lin, "linear"; InNames=names_in)
            @track G4 m_l["Status"] == "OK" && length(m_l["Coefs"]) == 4 && m_l["R2"] > 0.999
        end

        # 53: Adjusted R-squared relation
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in)
            @track G4 m_q["R2_Adj"] <= m_q["R2"] && m_q["R2"] <= 1.0
        end

        # 54: Cross-validation Q-squared computation
        let q2_clean = Lib_Vise.VISE_CrossValidate_DDEF(X_quad, Y_quad, "quadratic")
            @track G4 q2_clean > 0.90 && q2_clean <= 1.0
        end

        # 55: Outlier leverage test on cross-validation
        let Y_outlier = copy(Y_quad)
            Y_outlier[1] += 50.0
            m_out = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_outlier, "quadratic")
            q2_out = Lib_Vise.VISE_CrossValidate_DDEF(X_quad, Y_outlier, "quadratic")
            @track G4 q2_out < 0.50 && m_out["R2"] > q2_out
        end

        # 56: ANOVA sum of squares partitioning
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            anova_t = Lib_Vise.VISE_GenerateAnovaTable_DDEF(m_q, X_quad, Y_quad),
            ss_mod  = anova_t.SS[findfirst(==("Model"), anova_t.Source)],
            ss_res  = anova_t.SS[findfirst(==("Residual"), anova_t.Source)],
            ss_tot  = anova_t.SS[findfirst(==("Total"), anova_t.Source)]
            @track G4 isapprox(ss_mod + ss_res, ss_tot; atol=1e-3)
        end

        # 57: ANOVA lack of fit and pure error partitioning
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            anova_t = Lib_Vise.VISE_GenerateAnovaTable_DDEF(m_q, X_quad, Y_quad),
            ss_lof = anova_t.SS[findfirst(==("Lack of Fit"), anova_t.Source)],
            ss_pe  = anova_t.SS[findfirst(==("Pure Error"), anova_t.Source)],
            ss_res = anova_t.SS[findfirst(==("Residual"), anova_t.Source)]
            @track G4 isapprox(ss_lof + ss_pe, ss_res; atol=1e-3)
        end

        # 58: Lack of fit without replicates
        let X_no_rep = [1.0 2.0 3.0; 4.0 5.0 6.0; 7.0 8.0 9.0; 10.0 11.0 12.0],
            (f_lof_z, p_lof_z) = Lib_Vise.VISE_LackOfFit_DDEF(hcat(ones(4), X_no_rep), [1.0, 2.0, 3.0, 4.0])
            @track G4 isnan(f_lof_z) && isnan(p_lof_z)
        end

        # 59: Variance inflation factors for orthogonal and collinear designs
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            m_l = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_lin, "linear"; InNames=names_in),
            X_coll = copy(X_quad)
            X_coll[:, 2] = 0.999 * X_coll[:, 1] + 0.001 * randn(15)
            m_coll = Lib_Vise.VISE_Regress_DDEF(X_coll, Y_quad, "linear"; InNames=names_in)
            @track G4 all(v -> isapprox(v, 1.0; atol=1e-2), m_l["VIFs"]) && any(v -> v > 10.0, m_coll["VIFs"])
        end

        # 60: Residual normality test
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            norm_test = Lib_Vise.VISE_PerformNormalityTest_DDEF(m_q, X_quad, Y_quad)
            @track G4 haskey(norm_test, "p") && haskey(norm_test, "IsNormal")
        end

        # 61: Model sensitivity gradient
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            sens_v = Lib_Vise.VISE_SensitivityAnalysis_DDEF(m_q, [0.0, 0.0, 0.0], X_quad)
            @track G4 length(sens_v) == 3 && all(isfinite, sens_v)
        end

        # 62: Model point prediction
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            p_val = Lib_Vise.VISE_Predict_DDEF(m_q, [0.0, 0.0, 0.0])
            @track G4 length(p_val) == 1 && isapprox(p_val[1], 10.0; atol=1e-2)
        end

        # 63: Model selection via AICc
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            (best_m_q, _) = Lib_Vise.VISE_SelectBestModel_DDEF(X_quad, Y_quad, names_in),
            (best_m_l, _) = Lib_Vise.VISE_SelectBestModel_DDEF(X_quad, Y_lin, names_in)
            @track G4 best_m_q["ModelType"] == "quadratic" && best_m_l["ModelType"] == "linear"
        end

        # 64: Radio-decay modifier extraction from configuration
        let cfg_decay = Dict("Ingredients" => [Dict("Name" => "ReactionTime", "Unit" => "min"), Dict("Name" => "Ga-68", "HalfLife" => 67.71, "HalfLifeUnit" => "min", "IsRadioactive" => true)]),
            opts_decay = Dict("RadioOpts" => Dict("Apply" => true, "ReverseMap" => Dict("Yield" => Dict("Source" => "Ga-68")))),
            d_mods = Lib_Vise.VISE_ExtractDecayModifiers_DDEF(["ReactionTime", "Temp", "Conc"], ["Yield"], cfg_decay, opts_decay)
            @track G4 length(d_mods) == 1 && d_mods[1].IsotopeName == "Ga-68"
        end

        # 65: Grid search within parameter bounds
        let m_q = Lib_Vise.VISE_Regress_DDEF(X_quad, Y_quad, "quadratic"; InNames=names_in),
            g_search = Dict{String, Any}("Type" => "Maximise", "Min" => 0.0, "Max" => 30.0, "Target" => 25.0, "Weight" => 1.0, "WeightVal" => 1.0)
            m_q["Goal"] = g_search
            grid_out = Lib_Vise.VISE_GridSearch_DDEF([m_q], [g_search], [-1.0 1.0; -1.0 1.0; -1.0 1.0]; Steps=5)
            @track G4 size(grid_out, 1) > 0
        end

        # 66: Underdetermined system handling
        let m_under = Lib_Vise.VISE_Regress_DDEF(rand(5, 3), rand(5), "quadratic")
            @track G4 m_under["Status"] != "OK" && occursin("Underdetermined", m_under["Error"])
        end

        # 67: Experimental matrix ingestion with unmeasured and missing entries
        let C = Sys_Fast.FAST_Data_DDEC,
            Log = Sys_Fast.FAST_Log_DDEF,
            df_raw = DataFrame(
                "EXP_ID" => ["R1", "R2", "R3", "R4"],
                C.PRE_INPUT * "Temp" => [20.0, 40.0, 60.0, 80.0],
                C.PRE_INPUT * "Time" => [10.0, 20.0, 30.0, 40.0],
                C.PRE_RESULT * "Yield" => [75.0, "", 88.0, missing]
            ),
            cfg = Dict("Ingredients" => [Dict("Name" => "Temp"), Dict("Name" => "Time")], "Outputs" => [Dict("Name" => "Yield")]),
            (X_c, Y_c, in_n, out_n, mask) = Lib_Vise.VISE_IngestMatrices_DDEF(df_raw, cfg, C, Log)
            @track G4 size(X_c) == (2, 2) && size(Y_c) == (2, 1) && mask == [true, false, true, false]
        end

        # 68: Multi-response ensemble fitting
        let Y_lin = [5.0 + 3.0*r[1] - 2.0*r[2] + 1.5*r[3] for r in eachrow(X_quad)],
            Log = Sys_Fast.FAST_Log_DDEF,
            ens_models = Lib_Vise.VISE_TrainEnsemble_DDEF(X_quad, hcat(Y_quad, Y_lin), names_in, "auto", Dict{String, Any}[], Log)
            @track G4 length(ens_models) == 2 && ens_models[1]["Status"] == "OK" && ens_models[2]["Status"] == "OK"
        end
    end

    # ==========================================================================
    # GROUP 5: Sys_Flow ACTA Transitions & Search-Space Evolution (16 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G5"
    @testset "Group 5: Sys_Flow ACTA & IPKT Framework" begin
        # 69: Affine Space Transformation Model (ASTM) coordinate mapping
        @track G5 Sys_Flow.FLOW_ApplyASTM_DDEF(10.0, 1.5, 5.0) == 20.0 && Sys_Flow.FLOW_ApplyASTM_DDEF(0.0, 1.5, 5.0) == 5.0

        # 70: Boundary constraint validation and clamping
        let (ok_b, val_b, _) = Sys_Flow.FLOW_ValidateASTM_DDEF(95.0, 0.0, 90.0)
            @track G5 ok_b == false && val_b == 90.0
        end

        # 71: Boundary status determination for Lower, Upper, and Safe conditions
        let b_lo = Sys_Flow.FLOW_DetermineBoundaryStatus_DDEF(2.0, 0.0, 100.0),
            b_hi = Sys_Flow.FLOW_DetermineBoundaryStatus_DDEF(98.0, 0.0, 100.0),
            b_sf = Sys_Flow.FLOW_DetermineBoundaryStatus_DDEF(50.0, 0.0, 100.0)
            @track G5 b_lo isa Sys_Flow.FLOW_BoundaryLower_DDES && b_hi isa Sys_Flow.FLOW_BoundaryUpper_DDES && b_sf isa Sys_Flow.FLOW_BoundarySafe_DDES
        end

        # 72: Leader run proximity evaluation
        @track G5 Sys_Flow.FLOW_AskLeader_DDEF(50.0, [0.0, 50.0, 100.0])[1] == true && Sys_Flow.FLOW_AskLeader_DDEF(1.0, [0.0, 50.0, 100.0])[1] == false

        # 73: Adaptive range contraction, translation, and clamping (ACTA)
        let z_rng = Sys_Flow.FLOW_CalcACTA_DDEF(50.0, [0.0, 50.0, 100.0], 0.5, 0.0, 0.0),
            s_rng = Sys_Flow.FLOW_CalcACTA_DDEF(98.0, [0.0, 50.0, 100.0], 1.0, 0.2, 0.0),
            c_rng = Sys_Flow.FLOW_CalcACTA_DDEF(2.0, [0.0, 50.0, 100.0], 1.0, 0.2, 0.0)
            @track G5 (z_rng[3] - z_rng[1]) == 50.0 && s_rng[2] > 98.0 && c_rng[1] >= 0.0
        end

        # 74: Multi-variable simultaneous boundary adaptation (ACTA)
        let r1 = Sys_Flow.FLOW_CalcACTA_DDEF(50.0, [0.0, 50.0, 100.0], 0.5, 0.0, 0.0),
            r2 = Sys_Flow.FLOW_CalcACTA_DDEF(9.5, [0.0, 5.0, 10.0], 0.8, 0.1, 0.0),
            r3 = Sys_Flow.FLOW_CalcACTA_DDEF(105.0, [100.0, 200.0, 300.0], 0.6, 0.1, 0.0)
            @track G5 (r1[3] - r1[1]) == 50.0 && r2[2] > 9.5 && r3[1] >= 0.0
        end

        # 75: Candidate extraction and ranking from file
        let temp_lead_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_LEADERS.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            df_leads = DataFrame(
                "EXP_ID" => ["RUN_01", "RUN_02"],
                "SCORE" => [0.82, 0.94],
                "PHASE" => ["Phase1", "Phase1"],
                "X1" => [20.0, 20.0],
                "X2" => [2.0, 2.0],
                "X3" => [200.0, 200.0]
            )
            Sys_Fast.FAST_SafeExcelWrite_DDEF(temp_lead_file, Dict(Sys_Fast.FAST_Data_DDEC.PREFIX_LEADERS * "Phase1" => df_leads))
            cand_list = Sys_Flow.FLOW_GetCandidates_DDEF(temp_lead_file, "Phase1")
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            @track G5 length(cand_list) == 2 && cand_list[1]["Score"] == 0.94
        end

        # 76: Next phase configuration generation
        let temp_lead_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_LEADERS.xlsx"),
            C_flow = Sys_Fast.FAST_Data_DDEC
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            df_leads = DataFrame("EXP_ID" => ["RUN_01", "RUN_02"], "SCORE" => [0.82, 0.94], "PHASE" => ["Phase1", "Phase1"], "X1" => [20.0, 20.0], "X2" => [2.0, 2.0], "X3" => [200.0, 200.0])
            df_cfg_flow = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => [JSON3.write(Dict(
                "Ingredients" => [
                    Dict("Name" => "X1", "Role" => C_flow.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0]),
                    Dict("Name" => "X2", "Role" => C_flow.ROLE_VAR, "Levels" => [1.0, 2.0, 3.0]),
                    Dict("Name" => "X3", "Role" => C_flow.ROLE_VAR, "Levels" => [100.0, 200.0, 300.0])
                ],
                "Global" => Dict("Volume" => 10.0, "Concentration" => 1.0)
            ))])
            Sys_Fast.FAST_SafeExcelWrite_DDEF(temp_lead_file, Dict(C_flow.SHEET_CONFIG => df_cfg_flow, C_flow.PREFIX_LEADERS * "Phase1" => df_leads))
            next_phase_res = Sys_Flow.FLOW_BuildIPKT_DDEF(temp_lead_file, "Phase1", "RUN_02", 0.5, 0.0)
            @track G5 next_phase_res["Status"] == "OK" && next_phase_res["TargetPhase"] == "Phase2"
        end

        # 77: Next phase range contraction verification
        let temp_lead_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_LEADERS.xlsx")
            next_phase_res = Sys_Flow.FLOW_BuildIPKT_DDEF(temp_lead_file, "Phase1", "RUN_02", 0.5, 0.0)
            old_span1 = next_phase_res["OldConfig"][1]["Levels"][3] - next_phase_res["OldConfig"][1]["Levels"][1]
            new_span1 = next_phase_res["NewConfig"][1]["Levels"][3] - next_phase_res["NewConfig"][1]["Levels"][1]
            @track G5 isapprox(new_span1, old_span1 * 0.5; atol=1e-3) && next_phase_res["LeaderScore"] == 0.94
        end

        # 78: Phase transition fallback on non-existent leader or missing file
        let temp_lead_file = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_LEADERS.xlsx"),
            bad_lead_res = Sys_Flow.FLOW_BuildIPKT_DDEF(temp_lead_file, "Phase1", "NON_EXISTENT_LEADER", 0.5, 0.0),
            nil_file_res = Sys_Flow.FLOW_BuildIPKT_DDEF(nothing, "Phase1", "RUN_01", 0.5, 0.0)
            Sys_Fast.FAST_CleanTransient_DDEF(temp_lead_file)
            @track G5 bad_lead_res["Status"] == "OK" && bad_lead_res["LeaderScore"] == 0.94 && nil_file_res["Status"] == "FAIL"
        end

        # 79: Phase transition visualisation data construction (IPKT)
        let old_conf_m = [Dict("Name" => "Temp", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [20.0, 50.0, 80.0])],
            new_conf_m = [Dict("Name" => "Temp", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [35.0, 50.0, 65.0])],
            rend_trans = Sys_Flow.FLOW_RenderIPKT_DDEF(old_conf_m, new_conf_m, [50.0])
            @track G5 haskey(rend_trans, "data") && haskey(rend_trans, "layout")
        end

        # 80: Configuration parameter inheritance across phases (ACTA)
        let conf_sample = [Dict("Name" => "Precursor", "Role" => Sys_Fast.FAST_Data_DDEC.ROLE_VAR, "Levels" => [10.0, 20.0, 30.0], "MW" => 1435.0, "Unit" => "mg")],
            next_conf = Sys_Flow.FLOW_ApplyACTA_DDEF(Dict("OldConfig" => conf_sample, "Vals" => [20.0]), 0.5, 0.0)
            @track G5 next_conf[1]["Name"] == "Precursor" && next_conf[1]["MW"] == 1435.0 && next_conf[1]["Unit"] == "mg"
        end

        # 81: Leader run persistence to workbook
        let t_lead = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_LEAD_WRITE.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(t_lead)
            df_to_write = DataFrame("EXP_ID" => ["P1_01"], "SCORE" => [0.95], "PHASE" => ["Phase1"])
            ok_write = Sys_Flow.FLOW_WriteLeaders_DDEF(t_lead, "Phase1", df_to_write)
            df_read_lead = Sys_Fast.FAST_ReadExcel_DDEF(t_lead, Sys_Fast.FAST_Data_DDEC.PREFIX_LEADERS * "Phase1")
            Sys_Fast.FAST_CleanTransient_DDEF(t_lead)
            @track G5 ok_write == true && nrow(df_read_lead) == 1 && df_read_lead.SCORE[1] == 0.95
        end

        # 82: Subsequent phase workbook generation
        let t_build = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_FLOW_BUILD.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(t_build)
            df_init = DataFrame("EXP_ID" => ["EXP_P1_01", "EXP_P1_02"], "PHASE" => ["Phase1", "Phase1"], "Temp" => [25.0, 50.0], "Yield" => [70.0, 92.0])
            df_cfg = DataFrame("PARAMETER" => ["MasterConfig"], "VALUE_JSON" => [JSON3.write(Dict(
                "Ingredients" => [
                    Dict("Name" => "Temp", "Role" => "Variable", "Levels" => [25.0, 50.0, 75.0]),
                    Dict("Name" => "Time", "Role" => "Variable", "Levels" => [10.0, 20.0, 30.0]),
                    Dict("Name" => "Dose", "Role" => "Variable", "Levels" => [1.0, 2.0, 3.0])
                ],
                "Global" => Dict("Volume" => 10.0, "Concentration" => 1.0)
            ))])
            df_lead = DataFrame("EXP_ID" => ["EXP_P1_02"], "SCORE" => [0.92], "PHASE" => ["Phase1"], "Temp" => [50.0], "Time" => [20.0], "Dose" => [2.0])
            Sys_Fast.FAST_SafeExcelWrite_DDEF(t_build, Dict(
                Sys_Fast.FAST_Data_DDEC.SHEET_DATA => df_init,
                Sys_Fast.FAST_Data_DDEC.SHEET_CONFIG => df_cfg,
                Sys_Fast.FAST_Data_DDEC.PREFIX_LEADERS * "Phase1" => df_lead
            ))
            res_build = Sys_Flow.FLOW_CommitIPKT_DDEF(t_build, "Phase1", "EXP_P1_02", 0.5, "TL09", 0.0)
            Sys_Fast.FAST_CleanTransient_DDEF(t_build)
            @track G5 res_build["Status"] == "OK" && res_build["TargetPhase"] == "Phase2"
        end

        # 83: Boundary alert map and action telemetry tags
        @track G5 Sys_Flow.FLOW_ActionTagMap_DDEC[Sys_Flow.FLOW_BoundarySafe_DDES] == "CONTRACTION" && Sys_Flow.FLOW_ActionTagMap_DDEC[Sys_Flow.FLOW_BoundaryLower_DDES] == "TRANSLATION (AUTO)" && occursin("LOWER", Sys_Flow.FLOW_BoundaryAlertMap_DDEC[Sys_Flow.FLOW_BoundaryLower_DDES][2])

        # 84: Affine Space Transformation Model (ASTM) boundary constraint enforcement
        let (ok_lo, val_lo, _) = Sys_Flow.FLOW_ValidateASTM_DDEF(-10.0, 0.0, 100.0),
            (ok_hi, val_hi, _) = Sys_Flow.FLOW_ValidateASTM_DDEF(150.0, 0.0, 100.0)
            @track G5 !ok_lo && val_lo == 0.0 && !ok_hi && val_hi == 100.0
        end
    end

    # ==========================================================================
    # GROUP 6: Presentation, UI State & E2E Pipeline (16 Tests)
    # ==========================================================================
    Sys_Fast.FAST_ActiveGroup_DDEC[] = "G6"
    @testset "Group 6: Presentation, UI State & E2E Pipeline" begin
        X_arts = Float64.(Lib_Core.CORE_Bb15Design_DDEC)
        Y_arts = [10.0 + 2.0*r[1] for r in eachrow(X_arts)]
        model_arts = Lib_Vise.VISE_Regress_DDEF(X_arts, Y_arts, "linear"; InNames=["X1", "X2", "X3"])

        # 85: Pareto plot generation
        let p_pareto = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotPareto_DDES(), model_arts, "Yield", 0.9, 0.8)
            @track G6 p_pareto isa PlotlyJS.Plot
        end

        # 86: Fit diagnostic plot generation
        let p_fit = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotFit_DDES(), Y_arts, Y_arts, "Yield")
            @track G6 p_fit isa PlotlyJS.Plot
        end

        # 87: Response surface contour plot generation
        let p_cont = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotContour_DDES(), model_arts, X_arts, [1, 2], ["X1", "X2"], "Yield")
            @track G6 p_cont isa PlotlyJS.Plot
        end

        # 88: 3D response surface interactive mesh generation
        let p_surf = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotSurface_DDES(), model_arts, X_arts, [1, 2], ["X1", "X2"], "Yield")
            @track G6 p_surf isa PlotlyJS.Plot
        end

        # 89: Flat response surface rendering resilience
        let p_flat = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotFit_DDES(), fill(10.0, 15), fill(10.0, 15), "FlatOut")
            @track G6 p_flat isa PlotlyJS.Plot
        end

        # 90: Academic metric card formatting with value tokens and fallback states
        let c_card = Gui_Base.BASE_MiniVitals_DDEF("Condition (κ)", "41.2", "var(--colour-chr4-tongre)"),
            c_nan  = Gui_Base.BASE_MiniVitals_DDEF("D-Eff", "-", "var(--colour-val3-darlow)")
            @track G6 c_card isa DashBootstrapComponents.Component && c_nan isa DashBootstrapComponents.Component
        end

        # 91: System and scientific audit interface trees
        let audit_sys = Gui_Base.BASE_SystemAuditUI_DDEF(),
            audit_sci = Gui_Base.BASE_ScientificAuditUI_DDEF()
            @track G6 audit_sys isa DashBootstrapComponents.Component && length(audit_sys.children) >= 5 && audit_sci isa DashBootstrapComponents.Component && length(audit_sci.children) >= 4
        end

        # 92: JSON payload sanitisation and round-trip deserialization
        let clean_bundle = Sys_Fast.FAST_SanitiseJson_DDEF(Dict(
                "Status" => "OK", "Scores" => [0.91, 0.85],
                "Vitals" => Dict("D" => 0.42, "A" => 0.85, "Condition" => 41.2)
            )),
            json_str = JSON3.write(clean_bundle),
            read_back = JSON3.read(json_str, Dict{String, Any})
            @track G6 read_back["Status"] == "OK" && read_back["Scores"][1] == 0.91 && read_back["Vitals"]["Condition"] == 41.2
        end

        # 93: Clientside Plotly figure serialization
        let p_pareto = Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotPareto_DDES(), model_arts, "Yield", 0.9, 0.8),
            plot_json = JSON3.write(Dict("data" => p_pareto.data, "layout" => p_pareto.layout)),
            parsed_plot = JSON3.read(plot_json, Dict{String, Any})
            @track G6 haskey(parsed_plot, "data") && haskey(parsed_plot, "layout") && length(parsed_plot["data"]) >= 1
        end

        # 94: Markdown report synthesis with missing values, infinite condition, and LOF diagnostics
        let dirty_bundle = Dict{String, Any}(
                "Status" => "OK", "Phase" => "Phase1", "OutNames" => ["Yield"], "DisplayOutNames" => ["Yield (%)"],
                "Models" => [Dict("Status" => "OK", "ModelType" => "quadratic", "R2_Adj" => missing, "Q2" => NaN)],
                "Vitals" => Dict("D" => NaN, "Condition" => Inf, "MaxVIF" => NaN, "LOF" => missing),
                "Goals" => [], "Leaders" => DataFrame(), "BestPoint" => [0.0, 0.0, 0.0], "BestScore" => 0.0, "Elapsed" => "0.1s"
            ),
            rep_out = Lib_Vise.VISE_GenerateScientificReport_DDEF(dirty_bundle)
            @track G6 occursin("Lack-of-Fit", rep_out) && occursin("Experimental Design Vitals", rep_out)
        end

        # 95: Chemical grid default row metadata and unit specifications
        let row_deck = Gui_Deck.DECK_GetDefaultRow_DDEF(1)
            @track G6 row_deck["Role"] == "Variable" && haskey(row_deck, "MW") && haskey(row_deck, "Unit")
        end

        # 96: Factor row import mapping and normalisation
        let raw_in = [
                Dict("Name" => "FactorA", "Role" => "Variable", "L1" => 10, "L2" => 20, "L3" => 30, "Unit" => "mg"),
                Dict("Name" => "FactorB", "Role" => "Variable", "L1" => 1, "L2" => 2, "L3" => 3, "Unit" => "mM"),
                Dict("Name" => "FactorC", "Role" => "Variable", "L1" => 100, "L2" => 200, "L3" => 300, "Unit" => "%m"),
                Dict("Name" => "Buffer", "Role" => "Fixed", "L1" => 5, "Unit" => "g")
            ],
            mapped_rows = Gui_Deck.DECK_MapImportRow_DDEF(raw_in; override_roles=false)
            @track G6 length(mapped_rows) == 4 && mapped_rows[1]["Role"] == "Variable" && mapped_rows[4]["Role"] == "Fixed"
        end

        # 97: Leaderboard Dash HTML table component generation
        let df_lead_test = DataFrame(
                "EXP_ID" => ["EXP_01", "EXP_02"],
                "SCORE" => [0.95, 0.88],
                "Input_Temp" => [50.0, 60.0],
                "Pred_Yield" => [92.0, 85.0]
            ),
            lens_table = Gui_Lens.LENS_BuildLeadersHTML_DDEF(df_lead_test, Dict("DisplayOutNames" => ["Yield (%)"]))
            @track G6 (lens_table isa DashBootstrapComponents.Component || lens_table isa Dash.Component)
        end

        # 98: Transient file directory cleanup
        let _ = Sys_Fast.FAST_CleanWorkforce_DDEF(true),
            files_rem = readdir(Sys_Fast.FAST_TempRoot_DDEC),
            temp_files = filter(f -> startswith(f, "DOECISORY_TEMP_") || startswith(f, "DDE_"), files_rem)
            @track G6 isempty(temp_files)
        end

        # 99: Excel workbook export with model summary and statistics
        let t_exp = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_EXP_TEST.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(t_exp)
            exp_ok = Lib_Vise.VISE_ExportToExcel_DDEF(Dict(
                "Phase" => "Phase1", "OutNames" => ["Yield"], "DisplayOutNames" => ["Yield"],
                "Models" => [model_arts], "X_Clean" => X_arts, "Y_Clean" => reshape(Y_arts, :, 1)
            ), t_exp)
            is_f = isfile(t_exp)
            Sys_Fast.FAST_CleanTransient_DDEF(t_exp)
            @track G6 exp_ok == true && is_f
        end

        # 100: End-to-end multi-phase workflow integration
        let e2e_matrix = Lib_Core.CORE_GenDf14Design_DDEF([-1, -1, -1]),
            e2e_X = Float64.(e2e_matrix),
            e2e_Y = [15.0 + 3.0*r[1] - 2.5*r[2]^2 + 1.2*r[3] for r in eachrow(e2e_X)],
            e2e_temp = joinpath(Sys_Fast.FAST_TempRoot_DDEC, "DOECISORY_TEMP_E2E_MASTER.xlsx")
            Sys_Fast.FAST_CleanTransient_DDEF(e2e_temp)
            e2e_df = DataFrame(
                "EXP_ID" => ["EXP_P1_$(lpad(i, 2, '0'))" for i in 1:14],
                "PHASE" => fill("Phase1", 14),
                "Temp" => e2e_X[:, 1],
                "Time" => e2e_X[:, 2],
                "Dose" => e2e_X[:, 3],
                "Yield" => fill("", 14),
                "Notes" => fill("", 14)
            )
            Sys_Fast.FAST_SafeExcelWrite_DDEF(e2e_temp, Dict("DATA" => e2e_df))
            
            e2e_df[!, "Yield"] = e2e_Y
            Sys_Fast.FAST_SafeExcelWrite_DDEF(e2e_temp, Dict("DATA" => e2e_df))
            e2e_read = Sys_Fast.FAST_ReadExcel_DDEF(e2e_temp, "DATA")
            
            e2e_mod = Lib_Vise.VISE_Regress_DDEF(e2e_X, Float64.(e2e_read[!, "Yield"]), "quadratic"; InNames=["Temp", "Time", "Dose"])
            e2e_goal = Dict{String, Any}("Type" => "Maximise", "Min" => 0.0, "Max" => 30.0, "Target" => 25.0, "Weight" => 1.0, "WeightVal" => 1.0)
            e2e_mod["Goal"] = e2e_goal
            e2e_decay = [Lib_Core.CORE_DecayModifier_DDES(2, log(2.0) / 67.71, [1], "Ga-68")]
            e2e_bounds = [-1.0 1.0; -1.0 1.0; -1.0 1.0]
            
            (e2e_best_x, e2e_best_s) = Lib_Core.CORE_OptimiseDesirability_DDEF([e2e_mod], [e2e_goal], e2e_bounds; MaxTime=0.2, DecayModifiers=e2e_decay)
            e2e_next_range = Sys_Flow.FLOW_CalcACTA_DDEF(e2e_best_x[1], [-1.0, 0.0, 1.0], 0.5, 0.0, 0.0)
            Sys_Fast.FAST_CleanTransient_DDEF(e2e_temp)

            @track G6 (e2e_mod["R2"] > 0.95 && e2e_best_s > 0.0 && length(e2e_best_x) == 3 && length(e2e_next_range) == 3 && !isfile(e2e_temp))
        end
    end

    Sys_Fast.FAST_ActiveGroup_DDEC[] = ""
end

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
    @printf("  %-50s %5s  %6s  %6s   %7s  \n", "Domain Group", "Total", "Passed", "Failed", "Success")
    println("-"^80)

    for k in group_keys
        t = TRACKER[k]
        pct = t.total > 0 ? round((t.passed / t.total) * 100.0; digits=1) : 0.0
        @printf("  %-50s %5d  %6d  %6d   %6.1f%%  \n", t.name, t.total, t.passed, t.failed, pct)
    end

    println("-"^80)
    
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
