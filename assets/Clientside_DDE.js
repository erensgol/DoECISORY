/**
 * DaishoDoE - Clientside Acceleration Bridge
 * Extends Dash functionality with high-speed JS callbacks for instant graph navigation.
 */

window.dash_clientside = Object.assign({}, window.dash_clientside, {
    clientside: {
        /**
         * Logic to update the plot index based on navigation buttons or direct input.
         * Runs instantly in the browser.
         */
        update_index: function(g, n_nxt, n_prv, val_inp, current_i) {
            const context = window.dash_clientside.callback_context;
            const trigger = context.triggered.length > 0 ? context.triggered[0].prop_id : "";
            const tot = (g && Array.isArray(g)) ? g.length : 0;

            // Initial state or data reset
            if (trigger.includes('lens-store-graphs.data') || tot === 0) {
                return [0, 1, Math.max(1, tot)];
            }

            let idx = (current_i === null || current_i === undefined) ? 0 : current_i;

            if (trigger.includes('lens-btn-next.n_clicks')) {
                idx = (idx + 1) % tot;
            } else if (trigger.includes('lens-btn-prev.n_clicks')) {
                idx = (idx - 1 + tot) % tot;
            } else if (trigger.includes('lens-graph-input.value')) {
                // If the user clears the input or it's invalid, don't jump to index 0
                if (val_inp === null || val_inp === undefined || isNaN(val_inp)) {
                     return window.dash_clientside.no_update;
                }
                if (val_inp >= 1 && val_inp <= tot) {
                    idx = val_inp - 1;
                } else {
                    // Out of bounds: clamp it
                    idx = val_inp < 1 ? 0 : tot - 1;
                }
            }

            // Ensure index is valid
            idx = Math.max(0, Math.min(idx, tot - 1));

            return [idx, idx + 1, Math.max(1, tot)];
        },

        /**
         * Renders the active graph instantly from the local store.
         */
        render_graph: function(i, g) {
            if (!g || !Array.isArray(g) || g.length === 0) {
                return [{}, "No Visualisation Data", "/ 0"];
            }

            // Sanitise index: loop around if needed
            const idx = Math.max(0, i % g.length);
            const item = g[idx];

            if (!item || !item.figure) {
                return [{}, "Corrupted Data", "/ " + g.length];
            }

            return [
                item.figure,
                item.title || "Untitled Plot",
                "/ " + g.length
            ];
        }
    }
});
