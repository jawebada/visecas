# Visecas is a graphical user interface for Ecasound
# Copyright (C) 2003 - 2004  Jan Weil <jan.weil@web.de>
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# ---------------------------------------------------------------------------

require "visecas/config"
require "visecas/audio-format-dialog"
require "gtk2"
require "libglade2"

module Visecas

class PreferencesDialog < Gtk::Dialog
    RESPONSE_CANCEL = 0
    RESPONSE_SAVE = 1
    BUFFER_SIZES = [32, 64, 128, 256, 512, 1024, 2048, 4096, 8129]
    BUFFERING_MODES = ["bmode-defaults-nonrt", "bmode-defaults-rt", "bmode-defaults-rtlowlatency"]

    def initialize(preferences)
        super()
        @preferences = preferences
        self.title = "Preferences #{NAME}"
        self.add_button(Gtk::Stock::CANCEL, RESPONSE_CANCEL)
        self.add_button(Gtk::Stock::SAVE, RESPONSE_SAVE)
        @glade = GladeXML.new(File::join(GLADE_DIR, "preferences.glade"), "child") {|handler| method(handler)}
        self.border_width = 6
        self.vbox.spacing = 12
        self.has_separator = false
        self.vbox.add(w("child"))
        self.modal = false
        setup_size_group("label_devices", 3)
        setup_size_group("label_buffering", 2)
        setup_size_group("label_commands", 8)
        display_preferences()
    end

    private

    # widget access
    def w(str)
        @glade.get_widget(str)
    end

    def setup_size_group(str, up)
        size_group = Gtk::SizeGroup.new(1)
        1.upto(up) {|i| size_group.add_widget(w(str + i.to_s())) }
    end

    def display_preferences()
        # default audio format
        display_audio_format()
        # buffering mode
        w("buffering_mode").signal_emit("changed")
        # everything else
        @preferences.each_pair do |key, value|
            widget = w(key)
            if widget.kind_of?(Gtk::Entry)
                widget.text = value
                widget.signal_connect("changed") do |entry|
                    @preferences[key] = entry.text
                end
            elsif widget.kind_of?(Gtk::CheckButton)
                widget.active = value == "true"
                widget.signal_connect("toggled") do |button|
                    @preferences[key] = button.active?
                end
            end
        end
    end

    def display_audio_format()
        format_string = AudioFormatString.new(@preferences["default-audio-format"])
        w("sample_rate_label").text = format_string.human_sample_rate
        w("sample_format_label").text = format_string.human_sample_format
        w("channels_label").text = format_string.human_channels
        w("interleaved_label").text = format_string.human_interleaved =~ /(N|n)on/ ? "No" : "Yes"
    end

    def configure_audio_format(*args)
        d = AudioFormatDialog.new(@preferences["default-audio-format"])
        d.title = "Configure Default Audioformat"
        d.transient_for = @self
        d.signal_connect("response") do |dlg, id|
            @preferences["default-audio-format"] = dlg.format
            display_audio_format()
            dlg.destroy()
        end
        d.show_all()
    end

    def buffering_mode_changed(menu)
        @selected_bmode = BUFFERING_MODES[menu.history]
        b_mode = @preferences[@selected_bmode]
        b_mode = b_mode.split(",")
        w("buffersize").history = BUFFER_SIZES.index(b_mode[0].to_i())
        w("scheduling_priority").value = b_mode[2].to_f()
        w("enable_realtime_scheduling").active = b_mode[1] == "true"
        w("double_buffer_size").value = b_mode[4].to_f()
        w("enable_double_buffering").active = b_mode[3] == "true"
        w("enable_internal_buffering").active = b_mode[5] == "true"
    end

    def set_buffer_mode(id, value)
        #puts @selected_bmode
        #puts id
        b_mode = @preferences[@selected_bmode].split(",")
        b_mode[id] = value
        @preferences[@selected_bmode] = b_mode.join(",")
        #puts @preferences[@selected_bmode]
    end

    def buffersize_changed(menu)
        set_buffer_mode(0, BUFFER_SIZES[menu.history])
    end

    def realtime_scheduling_toggled(button)
        w("label_buffering1").sensitive = 
        w("scheduling_priority").sensitive = button.active?
        set_buffer_mode(1, button.active? ? "true" : "false")
    end

    def scheduling_priority_changed(spin_button)
        set_buffer_mode(2, spin_button.value)
    end

    def double_buffering_toggled(button)
        w("label_buffering2").sensitive =
        w("double_buffer_size").sensitive =
        w("label_buffering3").sensitive = button.active?
        set_buffer_mode(3, button.active? ? "true" : "false")
    end

    def double_buffer_size_changed(spin_button)
        set_buffer_mode(4, spin_button.value)
    end

    def enable_internal_buffering_toggled(button)
        set_buffer_mode(5, button.active? ? "true" : "false")
    end

    # XXX UGLY!
    def browse_resource_directory()
        filesel = Gtk::FileSelection.new()
        filesel.filename = @preferences["resource-directory"] + "/"
        filesel.title = "Browse Resources Directory..."
        filesel.signal_connect("response") do |dlg, id|
            if id == Gtk::Dialog::RESPONSE_OK
                f = filesel.filename
                dir = test(?d, f) ? f : File.dirname(f)
                @preferences["resource-directory"] = 
                w("resource-directory").text = dir.chomp("/")
            end
            filesel.destroy()
        end
        filesel.show_all()
    end

    def browse_ladspa_directory()
        filesel = Gtk::FileSelection.new()
        filesel.filename = @preferences["ladspa-plugin-directory"] + "/"
        filesel.title = "Browse LADSPA Plugin Directory..."
        filesel.signal_connect("response") do |dlg, id|
            if id == Gtk::Dialog::RESPONSE_OK
                f = filesel.filename
                dir = test(?d, f) ? f : File.dirname(f)
                @preferences["ladspa-plugin-directory"] = 
                w("ladspa-plugin-directory").text = dir.chomp("/")
            end
            filesel.destroy()
        end
        filesel.show_all()
    end
end # PreferencesDialog

end # Visecas::
