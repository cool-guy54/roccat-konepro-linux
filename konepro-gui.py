#!/usr/bin/env python3

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gio, GLib, Gtk  # noqa: E402


ROOT = Path(__file__).resolve().parent
HELPER = ROOT / "konepro"
SYSTEM_SETTINGS_PATH = Path.home() / ".config" / "konepro-linux" / "settings.json"
POLLING_RATES = (125, 250, 500, 1000)
LED_MODES = (
    ("0", "Off"),
    ("1", "Fully Lit"),
    ("2", "Blinking"),
    ("3", "Breathing"),
    ("4", "Heartbeat"),
    ("9", "AIMO Intelligent"),
    ("10", "Wave"),
)
ACCEL_PROFILES = ("default", "flat", "adaptive")
BUTTONS = (
    ("Left Click", "Left Click"),
    ("Right Click", "Right Click"),
    ("Wheel Click", "Universal Scrolling"),
    ("Scroll Up", "Scroll Up"),
    ("Scroll Down", "Scroll Down"),
    ("Forward", "Browser Forward"),
    ("Back", "Browser Back"),
    ("Profile Button", "Profile Cycle"),
)
BUTTON_FUNCTIONS = (
    "Left Click", "Right Click", "Middle Click", "Scroll Up", "Scroll Down",
    "Browser Forward", "Browser Back", "Double Click", "DPI Up", "DPI Down",
    "DPI Cycle", "Profile Up", "Profile Down", "Profile Cycle", "Easy-Shift+",
    "Play / Pause", "Next Track", "Previous Track", "Stop", "Mute",
    "Volume Up", "Volume Down", "Keyboard Shortcut", "Macro", "Disabled",
)
PAGE_DEFINITIONS = (
    ("sensitivity", "Sensitivity", "preferences-system-symbolic"),
    ("buttons", "Button Assignment", "input-mouse-symbolic"),
    ("lighting", "Illumination", "display-brightness-symbolic"),
    ("advanced", "Advanced", "applications-engineering-symbolic"),
    ("system", "Pointer & Clicks", "org.gnome.Settings-mouse-symbolic"),
    ("profiles", "Profiles & Device", "drive-harddisk-symbolic"),
)


def load_local_settings():
    defaults = {"pointer_speed": 0.0, "scroll_factor": 1.0}
    try:
        data = json.loads(SYSTEM_SETTINGS_PATH.read_text(encoding="utf-8"))
        defaults.update({key: data[key] for key in defaults if key in data})
    except (OSError, ValueError, TypeError):
        pass
    return defaults


def apply_hyprland_settings(settings):
    if not shutil.which("hyprctl"):
        return
    for option, value in (
        ("input:sensitivity", settings["pointer_speed"]),
        ("input:scroll_factor", settings["scroll_factor"]),
    ):
        subprocess.run(
            ["hyprctl", "keyword", option, str(value)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5,
            check=False,
        )

class KoneProWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Kone Pro Settings")
        self.set_default_size(960, 720)
        self.set_size_request(720, 520)
        self.reset_armed = False
        self.mouse_settings = Gio.Settings.new("org.gnome.desktop.peripherals.mouse")
        self.local_settings = load_local_settings()

        self.toast_overlay = Adw.ToastOverlay()
        self.set_content(self.toast_overlay)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.toast_overlay.set_child(root)

        header = Adw.HeaderBar()
        window_title = Adw.WindowTitle(title="Kone Pro Settings", subtitle="ROCCAT Kone Pro")
        header.set_title_widget(window_title)
        root.append(header)

        split = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        split.set_position(230)
        split.set_shrink_start_child(False)
        split.set_resize_start_child(False)
        split.set_vexpand(True)
        root.append(split)

        sidebar = self.build_sidebar()
        split.set_start_child(sidebar)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(160)
        split.set_end_child(self.stack)

        self.build_sensitivity_page()
        self.build_buttons_page()
        self.build_lighting_page()
        self.build_advanced_page()
        self.build_system_page()
        self.build_profiles_page()

        self.sidebar.select_row(self.sidebar.get_row_at_index(0))
        GLib.idle_add(self.refresh)

    def build_sidebar(self):
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        container.set_size_request(220, -1)
        container.add_css_class("navigation-sidebar")

        device = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        device.set_margin_top(18)
        device.set_margin_bottom(8)
        device.set_margin_start(18)
        device.set_margin_end(18)
        icon = Gtk.Image.new_from_icon_name("input-mouse-symbolic")
        icon.set_pixel_size(48)
        device.append(icon)
        name = Gtk.Label(label="Kone Pro")
        name.add_css_class("title-3")
        device.append(name)
        connection = Gtk.Label(label="Wired · Onboard memory")
        connection.add_css_class("dim-label")
        device.append(connection)
        container.append(device)

        self.sidebar = Gtk.ListBox()
        self.sidebar.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.sidebar.add_css_class("navigation-sidebar")
        self.sidebar.connect("row-selected", self.change_page)
        for page_id, label, icon_name in PAGE_DEFINITIONS:
            row = Gtk.ListBoxRow()
            row.page_id = page_id
            content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            content.set_margin_top(9)
            content.set_margin_bottom(9)
            content.set_margin_start(10)
            content.set_margin_end(10)
            content.append(Gtk.Image.new_from_icon_name(icon_name))
            text = Gtk.Label(label=label)
            text.set_xalign(0)
            content.append(text)
            row.set_child(content)
            self.sidebar.append(row)
        container.append(self.sidebar)
        return container

    def change_page(self, _listbox, row):
        if row is not None and hasattr(row, "page_id"):
            self.stack.set_visible_child_name(row.page_id)

    @staticmethod
    def page(title, description=""):
        page = Adw.PreferencesPage(title=title, description=description)
        return page

    @staticmethod
    def group(title, description=""):
        return Adw.PreferencesGroup(title=title, description=description)

    @staticmethod
    def action_row(title, control=None, subtitle=""):
        row = Adw.ActionRow(title=title, subtitle=subtitle)
        if control is not None:
            row.add_suffix(control)
            row.set_activatable_widget(control)
        return row

    @staticmethod
    def spin(minimum, maximum, step, value=0, digits=0):
        control = Gtk.SpinButton.new_with_range(minimum, maximum, step)
        control.set_value(value)
        control.set_digits(digits)
        control.set_numeric(True)
        control.set_valign(Gtk.Align.CENTER)
        return control

    @staticmethod
    def dropdown(labels, selected=0):
        control = Gtk.DropDown.new_from_strings(list(labels))
        control.set_selected(selected)
        control.set_valign(Gtk.Align.CENTER)
        return control

    @staticmethod
    def add_apply_row(group, label, callback, suggested=True):
        button = Gtk.Button(label=label)
        if suggested:
            button.add_css_class("suggested-action")
        button.set_valign(Gtk.Align.CENTER)
        button.connect("clicked", callback)
        row = Adw.ActionRow()
        row.add_suffix(button)
        group.add(row)
        return button

    def add_page(self, page_id, page):
        self.stack.add_named(page, page_id)

    def build_sensitivity_page(self):
        page = self.page("Sensitivity", "DPI and active onboard profile settings")

        profile_group = self.group("Onboard Profile", "Each profile stores its own DPI, polling, buttons, and lighting settings.")
        self.profile = self.dropdown([f"Profile {index + 1}" for index in range(5)])
        self.profile.connect("notify::selected", self.refresh)
        profile_group.add(self.action_row("Profile to edit", self.profile))
        page.add(profile_group)

        dpi_group = self.group("DPI Presets", "Five sensor presets from 50 to 19,000 DPI in steps of 50.")
        self.active_dpi = self.dropdown([f"Preset {index + 1}" for index in range(5)])
        dpi_group.add(self.action_row("Active preset", self.active_dpi))
        self.dpi_values = []
        defaults = (400, 800, 1200, 1600, 3200)
        for index, value in enumerate(defaults):
            control = self.spin(50, 19000, 50, value)
            self.dpi_values.append(control)
            dpi_group.add(self.action_row(f"Preset {index + 1}", control, "DPI"))
        self.add_apply_row(dpi_group, "Apply DPI Settings", self.apply_dpi)
        page.add(dpi_group)
        self.add_page("sensitivity", page)

    def build_buttons_page(self):
        page = self.page("Button Assignment", "Standard functions, Easy-Shift, shortcuts, media controls, and macros")
        notice = self.group(
            "Protocol Support Required",
            "The Kone Pro button report has not been documented by ROCCAT or Linux projects. "
            "Assignments are shown here but remain locked so the app cannot corrupt an onboard profile."
        )
        page.add(notice)

        standard = self.group("Standard Layer")
        easy_shift = self.group("Easy-Shift+ Layer", "Secondary assignments used while an Easy-Shift button is held.")
        self.button_controls = []
        for title, current in BUTTONS:
            control = self.dropdown(BUTTON_FUNCTIONS, BUTTON_FUNCTIONS.index(current) if current in BUTTON_FUNCTIONS else 0)
            control.set_sensitive(False)
            standard.add(self.action_row(title, control))
            self.button_controls.append(control)
            shifted = self.dropdown(BUTTON_FUNCTIONS, BUTTON_FUNCTIONS.index("Disabled"))
            shifted.set_sensitive(False)
            easy_shift.add(self.action_row(title, shifted))
        page.add(standard)
        page.add(easy_shift)
        self.add_page("buttons", page)

    def build_lighting_page(self):
        page = self.page("Illumination", "Configure the two translucent button lighting zones")
        lighting = self.group("AIMO RGB Lighting", "Lighting is stored separately in each onboard profile.")

        left_dialog = Gtk.ColorDialog.new()
        left_dialog.set_title("Left-button lighting color")
        self.left_color = Gtk.ColorDialogButton.new(left_dialog)
        self.left_color.set_valign(Gtk.Align.CENTER)
        lighting.add(self.action_row("Left-button color", self.left_color))

        right_dialog = Gtk.ColorDialog.new()
        right_dialog.set_title("Right-button lighting color")
        self.right_color = Gtk.ColorDialogButton.new(right_dialog)
        self.right_color.set_valign(Gtk.Align.CENTER)
        lighting.add(self.action_row("Right-button color", self.right_color))

        self.led_mode = self.dropdown([label for _value, label in LED_MODES], 1)
        lighting.add(self.action_row("Effect", self.led_mode))
        self.brightness = self.spin(0, 255, 1, 255)
        lighting.add(self.action_row("Brightness", self.brightness, "0–255"))
        self.led_speed = self.spin(1, 11, 1, 6)
        lighting.add(self.action_row("Effect speed", self.led_speed, "1–11"))
        self.add_apply_row(lighting, "Apply Illumination", self.apply_lighting)
        page.add(lighting)
        self.add_page("lighting", page)

    def build_advanced_page(self):
        page = self.page("Advanced", "Polling, debounce, and sensor behavior")

        performance = self.group("Report Rate")
        self.polling = self.dropdown([f"{rate} Hz" for rate in POLLING_RATES], 2)
        performance.add(self.action_row("Polling rate", self.polling))
        self.polling_all = Gtk.Switch(active=True, valign=Gtk.Align.CENTER)
        performance.add(self.action_row("Apply to all profiles", self.polling_all, "Prevents profile changes from restoring another rate"))
        self.add_apply_row(performance, "Apply Polling Rate", self.apply_polling)
        page.add(performance)

        click_group = self.group("Click Response")
        self.debounce = self.spin(0, 10, 1, 0)
        click_group.add(self.action_row("Debounce time", self.debounce, "Milliseconds · global setting"))
        self.add_apply_row(click_group, "Apply Debounce", self.apply_debounce)
        page.add(click_group)

        sensor = self.group(
            "Sensor Calibration",
            "Swarm exposes these controls, but their Kone Pro USB report bytes are not publicly documented. "
            "They remain locked until verified captures are available."
        )
        self.lift_off = self.dropdown(("1 mm", "2 mm", "Surface Calibration"))
        self.lift_off.set_sensitive(False)
        sensor.add(self.action_row("Lift-off distance", self.lift_off))
        self.angle_snapping = Gtk.Switch(sensitive=False, valign=Gtk.Align.CENTER)
        sensor.add(self.action_row("Angle snapping", self.angle_snapping))
        self.surface_calibration = Gtk.Button(label="Calibrate Surface", sensitive=False)
        sensor.add(self.action_row("Surface calibration", self.surface_calibration))
        page.add(sensor)
        self.add_page("advanced", page)

    def build_system_page(self):
        page = self.page("Pointer & Clicks", "Linux equivalents of Swarm's Windows pointer settings")
        group = self.group(
            "Desktop Input",
            "These settings affect the desktop session rather than the mouse's onboard memory."
        )
        self.pointer_speed = self.spin(-1.0, 1.0, 0.05, self.local_settings["pointer_speed"], 2)
        group.add(self.action_row("Pointer speed", self.pointer_speed, "Hyprland sensitivity"))
        self.scroll_factor = self.spin(0.1, 4.0, 0.1, self.local_settings["scroll_factor"], 1)
        group.add(self.action_row("Scroll speed", self.scroll_factor, "Hyprland scroll factor"))
        self.double_click = self.spin(100, 1000, 25, self.mouse_settings.get_int("double-click"))
        group.add(self.action_row("Double-click interval", self.double_click, "Milliseconds"))
        current_accel = self.mouse_settings.get_string("accel-profile")
        accel_index = ACCEL_PROFILES.index(current_accel) if current_accel in ACCEL_PROFILES else 0
        self.accel_profile = self.dropdown(("System Default", "Flat", "Adaptive"), accel_index)
        group.add(self.action_row("Acceleration profile", self.accel_profile))
        self.natural_scroll = Gtk.Switch(active=self.mouse_settings.get_boolean("natural-scroll"), valign=Gtk.Align.CENTER)
        group.add(self.action_row("Natural scrolling", self.natural_scroll))
        self.left_handed = Gtk.Switch(active=self.mouse_settings.get_boolean("left-handed"), valign=Gtk.Align.CENTER)
        group.add(self.action_row("Left-handed primary button", self.left_handed))
        self.middle_emulation = Gtk.Switch(active=self.mouse_settings.get_boolean("middle-click-emulation"), valign=Gtk.Align.CENTER)
        group.add(self.action_row("Middle-click emulation", self.middle_emulation))
        self.add_apply_row(group, "Apply Desktop Settings", self.apply_system)
        page.add(group)
        self.add_page("system", page)

    def build_profiles_page(self):
        page = self.page("Profiles & Device", "Read onboard memory and manage the mouse")
        profiles = self.group(
            "Onboard Profiles",
            "The Kone Pro stores five profiles. Select profiles from the Sensitivity page; all working pages follow that selection."
        )
        refresh = Gtk.Button(label="Read from Mouse")
        refresh.connect("clicked", self.refresh)
        profiles.add(self.action_row("Refresh current profile", refresh))
        page.add(profiles)

        automation = self.group(
            "Application Linking",
            "Automatic per-application profile switching in Swarm depends on its Windows background service. "
            "A Linux profile watcher is not installed, so this option is currently unavailable."
        )
        auto_switch = Gtk.Switch(sensitive=False, valign=Gtk.Align.CENTER)
        automation.add(self.action_row("Switch profiles with applications", auto_switch))
        page.add(automation)

        device = self.group("Device")
        self.reset_button = Gtk.Button(label="Factory Reset")
        self.reset_button.add_css_class("destructive-action")
        self.reset_button.connect("clicked", self.factory_reset)
        device.add(self.action_row("Restore factory settings", self.reset_button, "Erases all five onboard profiles"))
        page.add(device)
        self.add_page("profiles", page)

    def run_helper(self, *arguments):
        if not HELPER.exists():
            raise RuntimeError("Build the helper first with: make")
        result = subprocess.run(
            [str(HELPER), *arguments],
            text=True,
            capture_output=True,
            timeout=20,
            check=False,
        )
        output = (result.stdout + result.stderr).strip()
        if result.returncode != 0:
            raise RuntimeError(output or f"Helper exited with status {result.returncode}")
        return output

    def toast(self, message, error=False):
        toast = Adw.Toast(title=message, timeout=4)
        if error:
            toast.set_button_label("Dismiss")
        self.toast_overlay.add_toast(toast)

    @staticmethod
    def rgb_arguments(button):
        color = button.get_rgba()
        return [str(round(channel * 255)) for channel in (color.red, color.green, color.blue)]

    @staticmethod
    def set_color(button, values):
        color = Gdk.RGBA()
        color.red, color.green, color.blue = (int(value) / 255 for value in values)
        color.alpha = 1.0
        button.set_rgba(color)

    def selected_profile(self):
        return str(self.profile.get_selected())

    def apply_dpi(self, _button):
        try:
            arguments = ["-prf", self.selected_profile(), "-ds", str(self.active_dpi.get_selected())]
            for index, dpi in enumerate(self.dpi_values):
                arguments.extend(["-d", str(dpi.get_value_as_int()), str(index)])
            self.run_helper(*arguments)
            self.toast("DPI settings saved to the selected profile")
        except Exception as error:
            self.toast(f"Could not apply DPI: {error}", True)

    def apply_polling(self, _button):
        try:
            polling = str(self.polling.get_selected())
            if self.polling_all.get_active():
                self.run_helper("-p-all", polling)
                self.toast("Polling rate saved to all five profiles")
            else:
                self.run_helper("-prf", self.selected_profile(), "-p", polling)
                self.toast("Polling rate saved to the selected profile")
        except Exception as error:
            self.toast(f"Could not apply polling rate: {error}", True)

    def apply_lighting(self, _button):
        try:
            arguments = ["-prf", self.selected_profile(), "-l", *self.rgb_arguments(self.left_color)]
            arguments.extend(["-r", *self.rgb_arguments(self.right_color)])
            arguments.extend([
                "-lm", LED_MODES[self.led_mode.get_selected()][0],
                "-lb", str(self.brightness.get_value_as_int()),
                "-ls", str(self.led_speed.get_value_as_int()),
            ])
            self.run_helper(*arguments)
            self.toast("Illumination saved to the selected profile")
        except Exception as error:
            self.toast(f"Could not apply illumination: {error}", True)

    def apply_debounce(self, _button):
        try:
            value = str(self.debounce.get_value_as_int())
            self.run_helper("-dbt", value)
            self.toast(f"Global debounce set to {value} ms")
        except Exception as error:
            self.toast(f"Could not apply debounce: {error}", True)

    def apply_system(self, _button):
        try:
            settings = {
                "pointer_speed": round(self.pointer_speed.get_value(), 2),
                "scroll_factor": round(self.scroll_factor.get_value(), 1),
            }
            SYSTEM_SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
            temporary = SYSTEM_SETTINGS_PATH.with_suffix(".tmp")
            temporary.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
            temporary.replace(SYSTEM_SETTINGS_PATH)
            apply_hyprland_settings(settings)
            self.mouse_settings.set_int("double-click", self.double_click.get_value_as_int())
            self.mouse_settings.set_string("accel-profile", ACCEL_PROFILES[self.accel_profile.get_selected()])
            self.mouse_settings.set_boolean("natural-scroll", self.natural_scroll.get_active())
            self.mouse_settings.set_boolean("left-handed", self.left_handed.get_active())
            self.mouse_settings.set_boolean("middle-click-emulation", self.middle_emulation.get_active())
            self.toast("Desktop pointer and click settings applied")
        except Exception as error:
            self.toast(f"Could not apply desktop settings: {error}", True)

    def refresh(self, *_args):
        try:
            profile = self.selected_profile()
            output = self.run_helper("-list", profile)
            dpi_values = re.findall(r"(\d+)\(Switch \d\)", output)
            active = re.search(r"Active DPI Switch: (\d+)", output)
            left = re.search(r"Left RGB: (\d+) (\d+) (\d+)", output)
            right = re.search(r"Right RGB: (\d+) (\d+) (\d+)", output)
            polling = re.search(r"Polling Rate: (\d+)Hz", output)
            mode = re.search(r"LED Mode: (\d+)", output)
            brightness = re.search(r"LED Brightness: (\d+)", output)
            speed = re.search(r"LED Speed: (\d+)", output)
            debounce = re.search(r"Debounce Time: (\d+) ms", output)

            if len(dpi_values) == 5:
                for control, value in zip(self.dpi_values, dpi_values):
                    control.set_value(max(50, int(value)))
            if active:
                self.active_dpi.set_selected(int(active.group(1)))
            if left:
                self.set_color(self.left_color, left.groups())
            if right:
                self.set_color(self.right_color, right.groups())
            if polling and int(polling.group(1)) in POLLING_RATES:
                self.polling.set_selected(POLLING_RATES.index(int(polling.group(1))))
            if mode:
                values = [value for value, _label in LED_MODES]
                if mode.group(1) in values:
                    self.led_mode.set_selected(values.index(mode.group(1)))
            if brightness:
                self.brightness.set_value(int(brightness.group(1)))
            if speed:
                self.led_speed.set_value(max(1, int(speed.group(1))))
            if debounce:
                self.debounce.set_value(int(debounce.group(1)))
        except Exception as error:
            self.toast(f"Could not read mouse: {error}", True)
        return GLib.SOURCE_REMOVE

    def factory_reset(self, _button):
        if not self.reset_armed:
            self.reset_armed = True
            self.reset_button.set_label("Confirm Factory Reset")
            self.toast("Click Confirm Factory Reset within 8 seconds")
            GLib.timeout_add_seconds(8, self.disarm_reset)
            return
        self.reset_armed = False
        try:
            self.run_helper("-default")
            self.reset_button.set_label("Factory Reset")
            self.toast("Factory reset command sent")
            GLib.timeout_add(600, self.refresh)
        except Exception as error:
            self.toast(f"Could not factory reset: {error}", True)

    def disarm_reset(self):
        self.reset_armed = False
        self.reset_button.set_label("Factory Reset")
        return GLib.SOURCE_REMOVE


class KoneProApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="local.konepro.Settings")

    def do_activate(self):
        Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.FORCE_DARK)
        window = self.props.active_window
        if window is None:
            window = KoneProWindow(self)
        window.present()


if __name__ == "__main__":
    if "--apply-system" in sys.argv:
        apply_hyprland_settings(load_local_settings())
        raise SystemExit(0)
    KoneProApp().run(sys.argv)
