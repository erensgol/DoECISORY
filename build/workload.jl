# ==============================================================================
# DoECISORY Precompilation Workload
# ==============================================================================
# Executed during sysimage creation to pre-compile critical code paths.
# This file is not a runtime script — it is consumed by PackageCompiler.
# ==============================================================================

using Pkg
const _PROJECT_ROOT = abspath(joinpath(@__DIR__, ".."))
if Pkg.project().path != joinpath(_PROJECT_ROOT, "Project.toml")
    Pkg.activate(_PROJECT_ROOT)
end

# Environment configuration (mirrors app.jl Section 1)
let
    base_tmp = tempdir()
    wf_path  = endswith(rstrip(base_tmp, ['/', '\\']), "DoECISORY_Workforce") ? base_tmp : joinpath(base_tmp, "DoECISORY_Workforce")
    if !isdir(wf_path); mkpath(wf_path) end
    ENV["TMP"]    = wf_path
    ENV["TEMP"]   = wf_path
    ENV["TMPDIR"] = wf_path
    ENV["CHROME_USER_DATA_DIR"]   = wf_path
    ENV["CHROME_CRASH_DUMPS_DIR"] = wf_path
end
ENV["GKSwstype"]                 = "100"
ENV["JULIA_WEBIO_NOT_AVAILABLE"] = "1"
ENV["PLOTLY_KALEIDO_NO_SANDBOX"] = "1"

# --- Package Loading (mirrors app.jl Section 1) ---
using Logging
Logging.disable_logging(Logging.Warn)
using Dash
using DashBootstrapComponents
Logging.disable_logging(Logging.BelowMinLevel)

using DataFrames
using LoggingExtras
# NOTE: PlotlyJS loaded via Lib_Arts include (not in sysimage packages)

# --- Module Loading (mirrors app.jl Section 3-5) ---

include(joinpath(_PROJECT_ROOT, "src", "Sys_Fast.jl"))
using Main.Sys_Fast
Sys_Fast.FAST_InitialiseWorkforce_DDEF()

for (_, file) in [
    ("Lib_Core",  joinpath(_PROJECT_ROOT, "src", "Lib_Core.jl")),
    ("Lib_Mole",  joinpath(_PROJECT_ROOT, "src", "Lib_Mole.jl")),
    ("Sys_Flow",  joinpath(_PROJECT_ROOT, "src", "Sys_Flow.jl")),
    ("Lib_Vise",  joinpath(_PROJECT_ROOT, "src", "Lib_Vise.jl")),
    ("Lib_Arts",  joinpath(_PROJECT_ROOT, "src", "Lib_Arts.jl")),
    ("Gui_Base",  joinpath(_PROJECT_ROOT, "src", "Gui_Base.jl")),
    ("Gui_Deck",  joinpath(_PROJECT_ROOT, "src", "Gui_Deck.jl")),
    ("Gui_Lens",  joinpath(_PROJECT_ROOT, "src", "Gui_Lens.jl")),
]
    include(file)
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

# ==============================================================================
# WORKLOAD: Exercise every hot code path so PackageCompiler records the traces.
# ==============================================================================

println("[SYSIMAGE] Executing precompilation workload...")

# 1. Numeric utilities
Sys_Fast.FAST_SafeNum_DDEF("42.0")
Sys_Fast.FAST_SafeNum_DDEF(42)
Sys_Fast.FAST_SafeNum_DDEF(42.0)
Sys_Fast.FAST_SafeNum_DDEF(nothing)
Sys_Fast.FAST_SafeNum_DDEF("1,5")
Sys_Fast.FAST_SanitiseFilename_DDEF("Test_Project_Café_Naïve")
Sys_Fast.FAST_FormatDuration_DDEF(123.456)

# 2. JSON sanitisation
Sys_Fast.FAST_SanitiseJson_DDEF(Dict("a" => 1.0, "b" => NaN, "c" => [1, 2, 3]))
Sys_Fast.FAST_SanitiseJson_DDEF(DataFrame(A=[1,2], B=[3.0, NaN]))

# 3. Stoichiometry engine
names_mock  = String["A"]
mw_mock     = Float64[100.0]
ratios_mock = Float64[100.0]
units_mock  = String["%M"]
Lib_Mole.MOLE_CalcMass_DDEF(names_mock, mw_mock, ratios_mock, 5.0, 10.0, units_mock, 1.0; SuppressLog=true)

table_mock = [
    Dict("Name"=>"A", "MW"=>100.0, "Unit"=>"%M", "Type"=>"Variable", "Min"=>0.0, "Max"=>50.0, "Mid"=>25.0, "Rows"=>[[Dict("Unit"=>"%M")]]),
    Dict("Name"=>"W", "MW"=>18.0, "Unit"=>"%", "Type"=>"Filler", "Min"=>0.0, "Max"=>100.0, "Mid"=>50.0),
]
design_mock = fill(20.0, 5, 1)
Lib_Mole.MOLE_AuditBatch_DDEF(table_mock, design_mock, 5.0, 10.0)

# 4. Design matrix generation
X_dummy = Float64.(Lib_Core.CORE_Bb15Design_DDEC)
Y_dummy = [50 + 10*r[1] + 5*r[2] - 2*r[3] + 8*r[1]^2 + 6*r[2]^2 + 4*r[3]^2 for r in eachrow(X_dummy)]

Lib_Core.CORE_GenDesign_DDEF("BB15", 3)
Lib_Core.CORE_GenDesign_DDEF("TL09", 3)
Lib_Core.CORE_GenDesign_DDEF("CD17", 3)
Lib_Core.CORE_GenDesign_DDEF("DF14", 3, [-1, -1, -1])

configs_bench = [Dict("Levels" => [-1.0, 0.0, 1.0]) for _ in 1:3]
Lib_Core.CORE_MapLevels_DDEF(X_dummy, configs_bench)
Lib_Core.CORE_D_Efficiency_DDEF(X_dummy)

# 5. Linear regression
names_in = ["X1", "X2", "X3"]
mod_lin = Lib_Vise.VISE_Regress_DDEF(X_dummy, vec(Y_dummy), "linear"; InNames=names_in)

# 6. Quadratic regression
mod_quad = Lib_Vise.VISE_Regress_DDEF(X_dummy, vec(Y_dummy), "quadratic"; InNames=names_in)

# 7. Grid search
bounds_dummy = [-1.0 1.0; -1.0 1.0; -1.0 1.0]
goal_dummy = Dict{String, Any}("Type"=>"Maximise", "Min"=>0.0, "Max"=>20.0, "Target"=>15.0, "Weight"=>1.0, "WeightVal" => 1.0)
mod_lin["Goal"]  = goal_dummy
mod_quad["Goal"] = goal_dummy

Lib_Vise.VISE_GridSearch_DDEF([mod_lin],  [goal_dummy], bounds_dummy; Steps=11)
Lib_Vise.VISE_GridSearch_DDEF([mod_quad], [goal_dummy], bounds_dummy; Steps=11)

# 8. BlackBoxOptim
Lib_Core.CORE_OptimiseDesirability_DDEF([mod_lin],  [goal_dummy], bounds_dummy; MaxTime=0.1)
Lib_Core.CORE_OptimiseDesirability_DDEF([mod_quad], [goal_dummy], bounds_dummy; MaxTime=0.1)

# 9. Statistical diagnostics
Lib_Vise.VISE_GenerateAnovaTable_DDEF(mod_quad, X_dummy, vec(Y_dummy))
Lib_Vise.VISE_PerformNormalityTest_DDEF(mod_quad, X_dummy, vec(Y_dummy))
Lib_Vise.VISE_SensitivityAnalysis_DDEF(mod_quad, [0.5, 0.5, 0.5], X_dummy)
Lib_Vise.VISE_CrossValidate_DDEF(X_dummy, vec(Y_dummy), "quadratic")
Lib_Vise.VISE_CrossValidate_DDEF(X_dummy, vec(Y_dummy), "linear")

# 10. Visualisation suite
try
    Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotSurface_DDES(), mod_quad, X_dummy, [1, 2], ["X1", "X2"], "PC")
    Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotContour_DDES(), mod_quad, X_dummy, [1, 2], ["X1", "X2"], "PC")
    Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotTrend_DDES(),   mod_quad, X_dummy, vec(Y_dummy), [1], ["X1"], "PC")
    Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotSlice_DDES(),   mod_quad, X_dummy, [1, 2], ["X1", "X2"], "PC")
    Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotPareto_DDES(),  mod_quad, "PC", 0.9, 0.8)
    Lib_Arts.ARTS_Draw_DDEF(Lib_Arts.ARTS_PlotQQ_DDES(),      rand(15), "PC")
catch e
    println("[SYSIMAGE] Visualisation warmup skipped (PlotlyJS conflict): ", e)
end

# 11. Analytical pipeline
pfx_in  = Main.Sys_Fast.FAST_Data_DDEC.PRE_INPUT
pfx_out = Main.Sys_Fast.FAST_Data_DDEC.PRE_RESULT
df_mock = DataFrame()
df_mock[!, "$(pfx_in)X1"]  = X_dummy[:, 1]
df_mock[!, "$(pfx_in)X2"]  = X_dummy[:, 2]
df_mock[!, "$(pfx_in)X3"]  = X_dummy[:, 3]
df_mock[!, "$(pfx_out)Y1"] = Y_dummy

config_mock = Dict{String, Any}(
    "Ingredients" => [Dict("Name" => "X1"), Dict("Name" => "X2"), Dict("Name" => "X3")],
    "Outputs"     => [Dict("Name" => "Y1")],
    "Global"      => Dict("Volume" => 5.0, "Conc" => 10.0),
)
w_opts = Dict{String, Any}("MaxTime" => 0.1, "GridSteps" => 11)

try
    Lib_Vise.VISE_ExecuteCore_DDEF(df_mock, config_mock, "PC_Lin", [goal_dummy], "linear";
        t_start=time(), Opts=w_opts, RenderMode=:Full)
    Lib_Vise.VISE_ExecuteCore_DDEF(df_mock, config_mock, "PC_Quad", [goal_dummy], "quadratic";
        t_start=time(), Opts=w_opts, RenderMode=:Full)
catch e
    println("[SYSIMAGE] ExecuteCore warmup partial (PlotlyJS may be unavailable): ", e)
end

# 12. Dash layout generation
try
    app_pc = dash(; suppress_callback_exceptions=true)
    app_pc.layout = html_div("precompile")
    Gui_Deck.DECK_Layout_DDEF()
    Gui_Lens.LENS_Layout_DDEF()
    Gui_Deck.DECK_RegisterCallbacks_DDEF(app_pc)
    Gui_Lens.LENS_RegisterCallbacks_DDEF(app_pc)
catch e
    println("[SYSIMAGE] UI Callback warmup partial: ", e)
end

# 13. Design metrics and validation
Lib_Core.CORE_CalcDesignMetrics_DDEF(Lib_Vise.VISE_ExpandDesign_DDEF(Lib_Core.CORE_CodeMatrix_DDEF(X_dummy), "quadratic"))

# 14. Excel I/O paths
tmp_path = joinpath(tempdir(), "PC_test.xlsx")
try
    test_df = DataFrame(A=[1,2,3], B=[4.0, 5.0, 6.0])
    Sys_Fast.FAST_SafeExcelWrite_DDEF(tmp_path, Dict("Sheet1" => test_df))
    Sys_Fast.FAST_ReadExcel_DDEF(tmp_path, "Sheet1")
    rm(tmp_path; force=true)
catch
end

# 15. Mole processing for design generation path
rows_mock = [
    Dict("Name"=>"Lipid",  "Role"=>"Variable", "MW"=>760.0, "Unit"=>"mg", "L1"=>10.0, "L2"=>20.0, "L3"=>30.0, "Min"=>0.0, "Max"=>50.0, "IsRadioactive"=>false, "HalfLife"=>0.0, "HalfLifeUnit"=>"Hours"),
    Dict("Name"=>"Chol",   "Role"=>"Variable", "MW"=>386.0, "Unit"=>"mg", "L1"=>1.0,  "L2"=>5.0,  "L3"=>9.0,  "Min"=>0.0, "Max"=>15.0, "IsRadioactive"=>false, "HalfLife"=>0.0, "HalfLifeUnit"=>"Hours"),
    Dict("Name"=>"PEG",    "Role"=>"Variable", "MW"=>2800.0,"Unit"=>"mg", "L1"=>4.0,  "L2"=>7.0,  "L3"=>10.0, "Min"=>0.0, "Max"=>14.0, "IsRadioactive"=>false, "HalfLife"=>0.0, "HalfLifeUnit"=>"Hours"),
]
try
    parsed = Lib_Mole.MOLE_ParseTable_DDEF(rows_mock)
    real_mat = Lib_Core.CORE_MapLevels_DDEF(X_dummy, [Dict("Levels"=>[rows_mock[i]["L1"], rows_mock[i]["L2"], rows_mock[i]["L3"]]) for i in 1:3])
    Lib_Mole.MOLE_ProcessDesign_DDEF(real_mat, rows_mock, 5.0, 10.0)
catch
end

# 16. Scientific report generation
try
    Lib_Vise.VISE_GenerateScientificReport_DDEF(Dict(
        "Vitals"       => Dict("D"=>0.95, "Condition"=>12.0, "LOF"=>0.35),
        "Models"       => [mod_quad],
        "OutNames"     => ["Y1"],
        "DisplayOutNames" => ["Y1"],
        "InNames"      => names_in,
        "DisplayInNames" => names_in,
        "BestPoint"    => [0.5, 0.5, 0.5],
        "BestScore"    => 0.95,
        "Sensitivities"=> [[0.4, 0.35, 0.25]],
    ))
catch
end

GC.gc()
println("[SYSIMAGE] Precompilation workload complete.")
