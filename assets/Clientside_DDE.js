/**
 * DaishoDoE - Clientside Acceleration Bridge
 * Extends Dash functionality with high-speed JS callbacks for instant graph navigation.
 * Architecture: Graphs live server-side in a Ref. Only metadata (count + timestamp)
 * travels through dcc_store. render_graph is server-side (single figure per request).
 */

window.dash_clientside = Object.assign({}, window.dash_clientside, {
    clientside: {
        /**
         * Logic to update the plot index based on navigation buttons or direct input.
         * Runs instantly in the browser.
         * Input 1: meta  = {count: N, ts: T} from lens-store-graph-meta
         * Input 2: n_nxt = lens-btn-next.n_clicks
         * Input 3: n_prv = lens-btn-prev.n_clicks
         * Input 4: val_inp = lens-graph-input.value
         * State 1: current_i = lens-store-index.data
         */
        update_index: function(meta, n_nxt, n_prv, val_inp, current_i) {
            const context = window.dash_clientside.callback_context;
            const trigger = context.triggered.length > 0 ? context.triggered[0].prop_id : "";
            const tot = (meta && meta.count) ? meta.count : 0;
            console.log("[DAISHO] Graph Meta Count:", tot, "| Trigger:", trigger);

            // Data arrival or growth (6 -> 70)
            if (trigger.includes('lens-store-graph-meta.data')) {
                if (tot === 0) return [0, 1, 1];
                let idx = (current_i === null || current_i === undefined) ? 0 : current_i;
                // Preserve current index if valid, otherwise clamp
                idx = Math.min(idx, tot - 1);
                return [idx, idx + 1, Math.max(1, tot)];
            }
            if (tot === 0) return [0, 1, 1];

            let idx = (current_i === null || current_i === undefined) ? 0 : current_i;

            if (trigger.includes('lens-btn-next.n_clicks')) {
                idx = (idx + 1) % tot;
            } else if (trigger.includes('lens-btn-prev.n_clicks')) {
                idx = (idx - 1 + tot) % tot;
            } else if (trigger.includes('lens-graph-input.value')) {
                if (val_inp === null || val_inp === undefined || isNaN(val_inp)) {
                     return window.dash_clientside.no_update;
                }
                if (val_inp >= 1 && val_inp <= tot) {
                    idx = val_inp - 1;
                } else {
                    idx = val_inp < 1 ? 0 : tot - 1;
                }
            }

            // Ensure index is valid
            idx = Math.max(0, Math.min(idx, tot - 1));

            return [idx, idx + 1, Math.max(1, tot)];
        }
    }
});
