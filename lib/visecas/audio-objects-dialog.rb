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

class AudioObjectsDialog < Gtk::Dialog
    attr_reader     :audio_object_string

    RESPONSE_CLOSE = 0
    RESPONSE_ADD_INPUT = 1
    RESPONSE_ADD_OUTPUT = 2

    def initialize()
        super()
        
        self.resizable = false
        self.has_separator = false
        self.border_width = 6

        @glade = GladeXML.new(File::join(GLADE_DIR, "audio-objects-dialog.glade"), "child") {|h| method(h)}

        vbox.spacing = 12
        vbox.add(w("child"))

        add_button(Gtk::Stock::CLOSE, RESPONSE_CLOSE)
        add_button("Add as Input", RESPONSE_ADD_INPUT)
        add_button("Add as Output", RESPONSE_ADD_OUTPUT)

        prepare_file_page()
        prepare_devices_page()
        prepare_jack_page()
        prepare_misc_page()

        geometry = Gdk::Geometry.new()
        geometry.max_height = 800
        geometry.max_width = 0
        self.set_geometry_hints(vbox, geometry, Gdk::Window::HINT_MAX_SIZE)

        signal_connect("response") do |dlg, id|
            if [RESPONSE_ADD_INPUT, RESPONSE_ADD_OUTPUT].include?(id)
                @audio_object_string = get_audio_object_string()
            end
        end

        # Ecasound 'bug' loopback name contains an ','
        w("loopback_vbox").sensitive = false
    end

    def audio_format=(format)
        @format = format
        display_audio_format()
    end

    def audio_format()
        @format
    end

    private

    def w(str)
        @glade.get_widget(str) || raise("glade: #{str} not found")
    end

    def prepare_file_page()
        @dir_view = w("dir_treeview")
        sel = @dir_view.selection
        sel.mode = Gtk::SELECTION_SINGLE
        sel.signal_connect("changed") do |sel|
            if sel.selected
                entry = sel.selected[1]
                w("file_entry").text = entry if test(?f, File.join(@dir, entry))
            else
                w("file_entry").text = ""
            end
        end
        @dir_menu = w("dir_optionmenu")
        @dir_view.append_column(Gtk::TreeViewColumn.new("Path", Gtk::CellRendererText.new(), :text => 1))
        @dir_store = Gtk::ListStore.new(String, String)
        @dir_store.set_sort_func(0) do |e1, e2|
            if test(?d, e1[0])
                if test(?d, e2[0])
                    ret = e1[0] <=> e2[0]
                else
                    ret = -1
                end
            else
                if test(?d, e2[0])
                    ret = 1
                else
                    ret = e1[0] <=> e2[0]
                end
            end
            ret
        end
        @dir_store.set_sort_column_id(0)
        @dir_view.model = @dir_store
        @dir_menu_handler = @dir_menu.signal_connect("changed") do |optm| 
            display_directory(@parent_dirs[optm.history])
        end
        @dir_view.signal_connect("row-activated") do |view, path, column|
            entry = view.model.get_iter(path)[0]
            if test(?d, entry)
                display_directory(entry)
            elsif test(?f, entry)
                signal_emit("response", RESPONSE_ADD_INPUT)
            end
        end
        display_directory(`pwd`.chomp)
    end

    def prepare_devices_page()
        size_group = Gtk::SizeGroup.new(1)
        [   "alsa_device_radiobutton", 
            "alsa_hardware_radiobutton", 
            "oss_radiobutton", 
            "alsa_plugin_radiobutton"
        ].each do |str|
            size_group.add_widget(w(str))
        end

        menu = Gtk::Menu.new()
        @oss_devices = []
        Dir["/dev/dsp*"].each do |dev|
            @oss_devices.push(dev)
            menu.append(Gtk::MenuItem.new(dev))
        end
        menu.show_all()
        w("oss_optionmenu").menu = menu
        if @oss_devices.size == 0
            w("oss_vbox").sensitive = false
        end
    end

    def prepare_jack_page()
        size_group = Gtk::SizeGroup.new(1)
        [   "jack_alsa_radiobutton", 
            "jack_client_radiobutton",
            "jack_generic_radiobutton"
        ].each do |str|
            size_group.add_widget(w(str))
        end
    end

    def prepare_misc_page()
        size_group = Gtk::SizeGroup.new(1)
        [   "misc_loopback_radiobutton", 
            "misc_generic_radiobutton"
        ].each do |str|
            size_group.add_widget(w(str))
        end
    end

    def display_directory(dir)
        @dir_store.clear()
        @dir = File.expand_path(dir)
        d = Dir.new(@dir)
        d.each do |entry|
            next if entry =~ /^\./ and not entry == ".."
            path = File.expand_path(File.join(@dir, entry))
            iter = @dir_store.append()
            iter[0] = path
            entry += "/" if File.stat(path).directory? and entry != ".."
            iter[1] = entry
        end
        @dir_menu.signal_handler_block(@dir_menu_handler)
        menu = Gtk::Menu.new()
        path = ""
        i = -1
        @parent_dirs = []
        @dir.split("/").each do |p|
            path += p + "/"
            @parent_dirs.push(path)
            menu.append(Gtk::MenuItem.new(path))
            i += 1
        end
        menu.show_all()
        @dir_menu.menu = menu
        @dir_menu.history = i
        @dir_menu.signal_handler_unblock(@dir_menu_handler)
    end

    def configure_audio_format()
        d = AudioFormatDialog.new(@format)
        d.title = "Configure Audioformat"
        d.transient_for = self
        d.run()
        @format = d.format
        d.destroy()
        display_audio_format()
    end

    def display_audio_format()
        string = AudioFormatString.new(@format)
        w("sample_rate_label").text = string.human_sample_rate
        w("sample_format_label").text = string.human_sample_format
        w("channels_label").text = string.human_channels
        w("interleaved_label").text = string.interleaved? ? "Yes" : "No"
    end

    def get_audio_object_string()
        case w("notebook").page
            when 0
                ret = File.join(@dir, w("file_entry").text)
            when 1
                if w("alsa_device_radiobutton").active?
                    ret = "alsa," + w("alsa_device_entry").text
                elsif w("alsa_hardware_radiobutton").active?
                    ret = "alsahw," + 
                        Integer(w("alsa_hardware_card_spinbutton").value).to_s + "," +
                        Integer(w("alsa_hardware_device_spinbutton").value).to_s + "," +
                        Integer(w("alsa_hardware_subdevice_spinbutton").value).to_s
                elsif w("alsa_plugin_radiobutton").active?
                    ret = "alsaplugin," + 
                        Integer(w("alsa_plugin_card_spinbutton").value).to_s + "," +
                        Integer(w("alsa_plugin_device_spinbutton").value).to_s + "," +
                        Integer(w("alsa_plugin_subdevice_spinbutton").value).to_s
                elsif w("oss_radiobutton").active?
                    ret = @oss_devices[w("oss_optionmenu").history]
                end
            when 2
                if w("jack_alsa_radiobutton").active?
                    ret = "jack_alsa"
                elsif w("jack_client_radiobutton").active?
                    ret = "jack_auto," + w("jack_client_entry").text
                elsif w("jack_generic_radiobutton").active?
                    ret = w("jack_generic_entry").text == "" ?
                        "jack" : "jack_generic," + w("jack_generic_entry").text
                end
            when 3
                if w("misc_loopback_radiobutton").active?
                    ret = "loop," + Integer(w("misc_loopback_spinbutton").value).to_s
                elsif w("misc_generic_radiobutton").active?
                    ret = w("misc_generic_entry").text
                end
        end
        ret
    end
end # AudioObjectsDialog

end # Visecas::
