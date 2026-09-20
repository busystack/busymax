#!/usr/bin/gjs

// Development-only native reference for the libadwaita generation pinned in
// docs/linux_button_reference.md. It intentionally uses real Gtk.Button
// controls and native CSS states; no BusyMax styling is applied here.
imports.gi.versions.Gtk = '4.0';
imports.gi.versions.Adw = '1';

const { Adw, Gdk, GLib, Gsk, Gtk } = imports.gi;

if (ARGV.length !== 1) {
    printerr('usage: native_libadwaita_button_reference.js OUTPUT.png');
    imports.system.exit(2);
}

const output = ARGV[0];
const app = new Adw.Application({
    application_id: 'com.busymax.LibadwaitaButtonReference',
});

function addLabel(grid, text, column, row, align = Gtk.Align.CENTER) {
    const label = new Gtk.Label({ label: text, halign: align });
    grid.attach(label, column, row, 1, 1);
}

function addButton(grid, label, column, row, { suggested, focused }) {
    const button = new Gtk.Button({ label, hexpand: true });
    if (suggested) {
        button.add_css_class('suggested-action');
    }
    if (focused) {
        button.set_state_flags(
            Gtk.StateFlags.FOCUSED | Gtk.StateFlags.FOCUS_VISIBLE,
            false,
        );
    }
    grid.attach(button, column, row, 1, 1);
}

app.connect('activate', () => {
    const window = new Adw.ApplicationWindow({
        application: app,
        title: 'Native libadwaita button reference',
        default_width: 760,
        default_height: 390,
    });
    const grid = new Gtk.Grid({
        row_spacing: 18,
        column_spacing: 28,
        halign: Gtk.Align.CENTER,
        valign: Gtk.Align.CENTER,
        margin_top: 48,
        margin_bottom: 48,
        margin_start: 48,
        margin_end: 48,
    });

    addLabel(grid, 'State', 0, 0);
    addLabel(grid, 'Standard', 1, 0);
    addLabel(grid, 'Suggested', 2, 0);
    addLabel(grid, 'Resting', 0, 1, Gtk.Align.START);
    addButton(grid, 'Action', 1, 1, { suggested: false, focused: false });
    addButton(grid, 'Action', 2, 1, { suggested: true, focused: false });
    addLabel(grid, 'Keyboard-focused', 0, 2, Gtk.Align.START);
    addButton(grid, 'Action', 1, 2, { suggested: false, focused: true });
    addButton(grid, 'Action', 2, 2, { suggested: true, focused: true });

    window.set_content(grid);
    window.present();

    const settings = Gtk.Settings.get_default();
    print(
        `theme=${settings.gtk_theme_name} ` +
        `font=${settings.gtk_font_name} ` +
        `scale=${window.get_scale_factor()}`,
    );

    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
        const paintable = new Gtk.WidgetPaintable({ widget: window });
        const width = paintable.get_intrinsic_width();
        const height = paintable.get_intrinsic_height();
        const snapshot = new Gtk.Snapshot();
        paintable.snapshot(snapshot, width, height);
        const node = snapshot.to_node();
        const renderer = new Gsk.CairoRenderer();
        renderer.realize_for_display(Gdk.Display.get_default());
        const texture = renderer.render_texture(node, null);
        texture.save_to_png(output);
        renderer.unrealize();
        app.quit();
        return GLib.SOURCE_REMOVE;
    });
});

app.run([]);
