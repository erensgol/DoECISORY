# ==============================================================================
# DoECISORY Code Coverage Runner & Summary Reporter
# ==============================================================================
using Pkg
using Printf

const COVERAGE_START_TIME = time()
const COVERAGE_ROOT_DIR = normpath(joinpath(@__DIR__, ".."))

function cleanup_cov_files()
    src_dir = joinpath(COVERAGE_ROOT_DIR, "src")
    isdir(src_dir) || return nothing
    for (root, _, files) in walkdir(src_dir)
        for f in files
            if endswith(f, ".cov")
                rm(joinpath(root, f); force=true)
            end
        end
    end
end

cleanup_cov_files()

println("[INFO] Executing DoECISORY automated test suite with coverage enabled...")
try
    if Pkg.project().name != "DoECISORY"
        Pkg.activate(COVERAGE_ROOT_DIR)
    end
    Pkg.test("DoECISORY"; coverage=true)
catch e
    println("\n[ERROR] Test suite execution failed: ", e)
end

println("\n[INFO] Analysing source coverage metrics...")

struct FileCoverageSummary
    filename::String
    covered::Int
    total::Int
end

function collect_source_coverage(src_dir::String)
    file_map = Dict{String, Vector{Union{Int, Nothing}}}()
    
    for (root, _, files) in walkdir(src_dir)
        for f in files
            if endswith(f, ".cov")
                cov_path = joinpath(root, f)
                orig_name = replace(f, r"\.[0-9]+\.cov$" => "")
                orig_name = replace(orig_name, r"\.cov$" => "")
                
                lines = readlines(cov_path)
                if !haskey(file_map, orig_name)
                    file_map[orig_name] = Vector{Union{Int, Nothing}}(fill(nothing, length(lines)))
                end
                counts = file_map[orig_name]
                if length(lines) > length(counts)
                    append!(counts, fill(nothing, length(lines) - length(counts)))
                end
                
                for (idx, line) in enumerate(lines)
                    if length(line) >= 9
                        cnt_str = strip(line[1:9])
                        if cnt_str != "-" && !isempty(cnt_str)
                            cnt = tryparse(Int, cnt_str)
                            if !isnothing(cnt)
                                curr = counts[idx]
                                counts[idx] = isnothing(curr) ? cnt : (curr + cnt)
                            end
                        end
                    end
                end
            end
        end
    end
    
    results = FileCoverageSummary[]
    for (fname, line_counts) in sort(collect(file_map); by=first)
        tot = count(!isnothing, line_counts)
        cov = count(x -> !isnothing(x) && x > 0, line_counts)
        push!(results, FileCoverageSummary(fname, cov, tot))
    end
    return results
end

cov_results = collect_source_coverage(joinpath(COVERAGE_ROOT_DIR, "src"))

const COVERAGE_DURATION = round(time() - COVERAGE_START_TIME; digits=2)

try
    let
        total_covered = sum(item.covered for item in cov_results; init=0)
        total_lines   = sum(item.total for item in cov_results; init=0)
        total_missed  = total_lines - total_covered
        tot_pct       = total_lines > 0 ? round((total_covered / total_lines) * 100.0; digits=1) : 0.0

        println("\n" * "="^90)
        println(" "^30 * "DoECISORY CODE COVERAGE REPORT" * " "^30)
        println("="^90)
        @printf("  %-56s %5s  %6s  %6s  %8s\n", "Source File", "Total", "Hit", "Missed", "Coverage")
        println("-"^90)

        for item in cov_results
            missed = item.total - item.covered
            pct = item.total > 0 ? round((item.covered / item.total) * 100.0; digits=1) : 0.0
            @printf("  %-56s %5d  %6d  %6d  %7.1f%%\n", item.filename, item.total, item.covered, missed, pct)
        end

        println("-"^90)

        bar_width = 46
        filled = total_lines > 0 ? clamp(round(Int, (total_covered / total_lines) * bar_width), 0, bar_width) : 0
        empty_slots = bar_width - filled
        bar_str = "="^filled * " "^empty_slots

        @printf("  PROGRESS    : [%s] %5.1f%%\n", bar_str, tot_pct)
        @printf("  SUMMARY     : %d / %d lines covered (%d missed, %.2f%%)\n", total_covered, total_lines, total_missed, total_lines > 0 ? (total_covered / total_lines) * 100.0 : 0.0)
        @printf("  DURATION    : %.2f seconds\n", COVERAGE_DURATION)
        @printf("  TOTAL SCORE : %.2f%%\n", total_lines > 0 ? (total_covered / total_lines) * 100.0 : 0.0)
        println("="^90 * "\n")
    end
finally
    cleanup_cov_files()
end
