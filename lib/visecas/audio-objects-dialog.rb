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

class AudioObjectsDialog < Gtk::FileSelection
    attr_reader     :audio_object_string

    RESPONSE_CLOSE = 0
    RESPONSE_ADD_INPUT = 1
    RESPONSE_ADD_OUTPUT = 2

    def initialize()
        super()
        
        self.show_fileops = 
        self.has_separator = false
        self.border_width = 0

        vbox.spacing = 12

        # this produces warnings
        ok_button.destroy()
        cancel_button.destroy()

        add_button(Gtk::Stock::CLOSE, RESPONSE_CLOSE)
        add_button("Add as Input", RESPONSE_ADD_INPUT)
        add_button("Add as Output", RESPONSE_ADD_OUTPUT)

        @notebook = Gtk::Notebook.new()
        # @notebook.homogeneous = true
        prepare_file_page()
        vbox.pack_start(@notebook)
        prepare_others_page()
        prepare_audio_format_box()

        signal_connect("response") do |dlg, id|
            if @notebook.page == 0
                @audio_object_string = self.filename
            else
                @audio_object_string = get_other_audio_object_string()
            end
        end

        @notebook.prev_page()
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
        @glade.get_widget(str)
    end

    def prepare_file_page()
        box = Gtk::VBox.new()
        l = Gtk::Label.new()
        l.markup = "<b>File</b>"
        @notebook.append_page(box, l)
        box.border_width = 6
        i = 0
        # put everything but the button box into first notebook page
        loop do
            c = self.vbox.children[0]
            break if c.class == Gtk::HButtonBox
            h = Gtk::HBox.new()
            c.reparent(h)
            if i == 1
                box.pack_start(h, true, true)
            else
                box.pack_start(h, false, false)
            end
            i += 1
        end
    end

    def prepare_others_page()
        @glade = GladeXML.new(File::join(GLADE_DIR, "audio-objects-dialog.glade"), "others_vbox") {|h| method(h)}
        
        size_group = Gtk::SizeGroup.new(1)
        [   "oss_radiobutton", 
            "alsa_device_radiobutton", 
            "alsa_hardware_radiobutton", 
            "alsa_plugin_radiobutton",
            "jack_alsa_radiobutton",
            "jack_client_radiobutton",
            "jack_generic_radiobutton",
            "loopback_radiobutton",
            "generic_radiobutton"
        ].each do |str|
            size_group.add_widget(w(str))
        end

        menu = Gtk::Menu.new()
        @oss_devices = []

        Dir["/dev/dsp*"].each do |dev|
            @oss_devices.push(dev)
            menu.append(Gtk::MenuItem.new(dev))
        end

        w("oss_optionmenu").menu = menu

        if @oss_devices.size == 0
            w("oss_vbox").sensitive = false
        end

        l = Gtk::Label.new()
        l.markup = "<b>Others</b>"
        box = w("others_vbox")
        box.border_width = 12
        @notebook.append_page(box, l)
    end

    def prepare_audio_format_box()
        glade = GladeXML.new(File::join(GLADE_DIR, "audio-objects-dialog.glade"), "audioformat_vbox") {|h| method(h)}
        @sample_rate_label = glade.get_widget("sample_rate_label")
        @sample_resolution_label = glade.get_widget("sample_resolution_label")
        @channels_label = glade.get_widget("channels_label")
        @interleaved_label = glade.get_widget("interleaved_label")
        vbox.pack_start(glade.get_widget("audioformat_vbox"), false, false)
    end

    def configure_audio_format()
        d = AudioFormatDialog.new(@format)
        d.title = "Configure Audio Format"
        d.transient_for = self
        d.run()
        @format = d.format
        d.destroy()
        display_audio_format()
    end

    def display_audio_format()
        string = AudioFormatString.new(@format)
        @sample_rate_label.text = string.human_sample_rate
        @sample_resolution_label.text = string.human_sample_format
        @channels_label.text = string.human_channels
        @interleaved_label.text = string.interleaved? ? "Yes" : "No"
    end

    def get_other_audio_object_string()
        if w("oss_radiobutton").active?
            @audio_object_string = @oss_devices[w("oss_optionmenu").history]
        elsif w("alsa_device_radiobutton").active?
            @audio_object_string = "alsa," + w("alsa_dev_entry").text
        elsif w("alsa_hardware_radiobutton").active?
            @audio_object_string = "alsahw," + 
                Integer(w("alsa_hw_card_spinbutton").value).to_s + "," +
                Integer(w("alsa_hw_dev_spinbutton").value).to_s + "," +
                Integer(w("alsa_hw_subdev_spinbutton").value).to_s
        elsif w("alsa_plugin_radiobutton").active?
            @audio_object_string = "alsaplugin," +
                Integer(w("alsa_plug_card_spinbutton").value).to_s + "," +
                Integer(w("alsa_plug_dev_spinbutton").value).to_s + "," +
                Integer(w("alsa_plug_subdev_spinbutton").value).to_s
        elsif w("jack_alsa_radiobutton").active?
            @audio_object_string = "jack_alsa"
        elsif w("jack_client_radiobutton").active?
            @audio_object_string = "jack_auto," + w("jack_client_entry").text
        elsif w("jack_generic_radiobutton").active?
            @audio_object_string = w("jack_generic_entry").text == "" ?
                "jack" : "jack_generic," + w("jack_generic_entry").text
        elsif w("loopback_radiobutton").active?
            @audio_object_string = "loop," + Integer(w("loop_id_spinbutton").value).to_s
        else
            @audio_object_string = w("generic_entry").text
        end
    end
end # AudioObjectsDialog

end # Visecas::
