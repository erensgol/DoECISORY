module Gui_Base

# ======================================================================================
# DAISHODOE - GUI BASE (SHARED COMPONENTS)
# ======================================================================================
# Purpose: Foundational UI definitions, shared styles, and common helper functions.
# Module Tag: BASE
# ======================================================================================

using Dash
using DashBootstrapComponents

export BASE_STYLE_CELL, BASE_STYLE_INPUT, BASE_STYLE_INPUT_CENTER
export BASE_STYLE_HEADER, BASE_STYLE_DATATABLE_CELL, BASE_STYLE_INLINE_HEADER, BASE_STYLE_HR, BASE_EMPTY_FIGURE
export BASE_safe_rows, BASE_get_trigger
export BASE_PageHeader, BASE_RayPanel, BASE_DataTable, BASE_Modal, BASE_ConvertTheme_PlotlyWhite!

# --------------------------------------------------------------------------------------
# SECTION 1: SHARED STYLE CONSTANTS
# --------------------------------------------------------------------------------------

const BASE_STYLE_CELL = Dict(
    "backgroundColor" => "#FFFFFF",
    "border" => "1px solid #DCDCDC",
    "verticalAlign" => "middle",
    "padding" => "0px",
)

const BASE_STYLE_INPUT = Dict(
    "backgroundColor" => "transparent",
    "border" => "none",
    "color" => "#000000",
    "fontSize" => "10px",
    "width" => "100%",
    "outline" => "none",
    "fontFamily" => "Inter",
)

const BASE_STYLE_INPUT_CENTER = merge(BASE_STYLE_INPUT, Dict("textAlign" => "center"))

const BASE_STYLE_HEADER = Dict(
    "backgroundColor" => "#FFFFFF", "color" => "#666666",
    "borderBottom" => "2px solid #DCDCDC",
    "fontSize" => "0.70rem", "padding" => "6px 5px",
    "fontWeight" => "600",
)

const BASE_STYLE_DATATABLE_CELL = Dict(
    "backgroundColor" => "#FFFFFF", "color" => "#000000",
    "border" => "none",
    "borderBottom" => "none",
    "fontFamily" => "Inter", "fontSize" => "10px", "padding" => "6px 5px",
)

const BASE_STYLE_INLINE_HEADER = Dict(
    "backgroundColor" => "#FFFFFF",
    "color" => "#666666",
    "fontWeight" => "600",
    "fontSize" => "0.65rem",
    "textTransform" => "uppercase",
    "letterSpacing" => "0.05em",
    "border" => "none",
    "borderBottom" => "none",
)

const BASE_STYLE_HR = Dict("borderColor" => "#DCDCDC", "margin" => "6px 0")

const BASE_EMPTY_FIGURE = Dict(
    "data" => [],
    "layout" => Dict(
        "paper_bgcolor" => "#FFFFFF",
        "plot_bgcolor" => "#DCDCDC",
        "xaxis" => Dict("visible" => false, "showgrid" => false, "zeroline" => false),
        "yaxis" => Dict("visible" => false, "showgrid" => false, "zeroline" => false),
        "margin" => Dict("l" => 0, "r" => 0, "t" => 0, "b" => 0),
        "annotations" => [Dict(
            "text" => "<b>No Visualization Data</b><br><span style='font-size:12px'>Run analysis to generate plots</span>",
            "showarrow" => false,
            "xref" => "paper", "yref" => "paper", "x" => 0.5, "y" => 0.5,
            "font" => Dict("color" => "#666666", "size" => 16, "family" => "Inter"),
        )],
    ),
)


# --------------------------------------------------------------------------------------
# SECTION 2: UI WIDGET BUILDERS
# --------------------------------------------------------------------------------------

"""
    BASE_PageHeader(title::String, subtitle::String)
Standardized page header layout.
"""
function BASE_PageHeader(title::String, subtitle::String)
    return dbc_row(dbc_col([
                html_h3(title, className="mb-1"),
                html_p(subtitle, className="text-secondary small"),
            ], xs=12), className="mb-3")
end

"""
    BASE_RayPanel(title::String, content; right_node, panel_class, content_class)
Standardized 'ray-panel' component with header and body.
"""
function BASE_RayPanel(title::String, content; right_node=nothing, panel_class="h-100", content_class="ray-content p-2 p-md-3", overflow="hidden")
    header_content = Any[html_span(title, className="ray-caption")]
    !isnothing(right_node) && push!(header_content, right_node)

    return html_div([
            html_div(header_content, className="ray-header d-flex justify-content-between align-items-center mb-2"),
            html_div(content, className=content_class)
        ], className="ray-panel $panel_class", style=Dict("overflow" => overflow))
end

"""
    BASE_DataTable(id::String, columns::Vector, data; kwargs...)
Dash DataTable wrapper enforcing DaishoDoE CSS consistency and responsive rules.
"""
function BASE_DataTable(id::String, columns::Vector, data; kwargs...)
    return dash_datatable(;
        id=id, columns=columns, data=data,
        style_table=Dict("overflowX" => "auto", "overflowY" => "visible", "borderCollapse" => "collapse", "width" => "100%"),
        style_header=BASE_STYLE_HEADER,
        style_cell=BASE_STYLE_DATATABLE_CELL,
        css=[
            Dict("selector" => ".dash-spreadsheet-container .dash-spreadsheet-inner th", "rule" => "padding: 0.25rem; font-size: 0.70rem; text-transform: uppercase; letter-spacing: 0.05em;"),
            Dict("selector" => ".dash-spreadsheet-container .dash-spreadsheet-inner td", "rule" => "padding: 0.25rem; font-size: 10px;")
        ],
        kwargs...
    )
end

"""
    BASE_Modal(id::String, title::String, body, footer; size="lg", is_open=false, centered=true, close_button=true)
Standardized modal constructor.
"""
function BASE_Modal(id::String, title::String, body, footer; size="lg", is_open=false, centered=true, close_button=true)
    return dbc_modal([
            dbc_modalheader(dbc_modaltitle(title); close_button=close_button),
            dbc_modalbody(body),
            dbc_modalfooter(footer)
        ]; id=id, is_open=is_open, size=size, centered=centered)
end

# --------------------------------------------------------------------------------------
# SECTION 3: SHARED HELPER FUNCTIONS
# --------------------------------------------------------------------------------------

"""
    BASE_safe_rows(d) -> Vector{Dict{String,Any}}
Convert raw callback data to a clean vector of string-keyed dicts.
"""
BASE_safe_rows(d) = isnothing(d) ? Dict{String,Any}[] :
                    [Dict{String,Any}(string(k) => v for (k, v) in r) for r in d]

"""
    BASE_get_trigger(ctx) -> String
Extracts the ID of the component that triggered the Dash callback.
"""
function BASE_get_trigger(ctx)
    isempty(ctx.triggered) && return ""
    return ctx.triggered[1].prop_id |> x -> split(x, ".")[1]
end

"""
    BASE_ConvertTheme_PlotlyWhite(fig_dict)
Mutates a PlotlyJS JSON representation into a flat white theme for high-res reporting.
"""
function BASE_ConvertTheme_PlotlyWhite!(fig_dict)
    if haskey(fig_dict, "layout")
        lay = fig_dict["layout"]
        lay["template"] = "plotly_white"
        lay["paper_bgcolor"] = "#FFFFFF"
        lay["plot_bgcolor"] = "#FFFFFF"
        lay["font"] = Dict("color" => "#000000", "family" => "Arial", "size" => 16)

        if haskey(lay, "scene")
            lay["scene"]["bgcolor"] = "#FFFFFF"
            for ax in ("xaxis", "yaxis", "zaxis")
                if haskey(lay["scene"], ax)
                    lay["scene"][ax]["color"] = "#000000"
                    lay["scene"][ax]["gridcolor"] = "#E6E6E6"
                    lay["scene"][ax]["zerolinecolor"] = "#E6E6E6"
                    lay["scene"][ax]["backgroundcolor"] = "#FFFFFF"
                end
            end
        end

        for ax in ("xaxis", "yaxis")
            if haskey(lay, ax)
                lay[ax]["color"] = "#000000"
                lay[ax]["gridcolor"] = "#E6E6E6"
                lay[ax]["zerolinecolor"] = "#E6E6E6"
            end
        end
    end
    return fig_dict
end

end # module
