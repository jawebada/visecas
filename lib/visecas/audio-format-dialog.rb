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

require "visecas/audio-format"
require "visecas/config"
require "gtk2"
require "libglade2"

module Visecas

class AudioFormatDialog < Gtk::Dialog
    RESPONSE_CLOSE = 0
    attr_reader :format
    
    def initialize(format_string = nil)
        super()
        @format = nil
        @glade = GladeXML.new(File::join(GLADE_DIR, "audioformat-editor.glade"), "child") do |handler| 
            methode(handler)
        end
        
        self.vbox.add(@glade.get_widget("child"))
        self.add_button(Gtk::Stock::CLOSE, RESPONSE_CLOSE)
        self.has_separator = false
        self.border_width = 6
        self.modal = true
        self.resizable = false

        prepare_dialog()
        @glade.get_widget("sample_rate_combo").popdown_strings = SAMPLE_RATE_VALUES
        @glade.get_widget("channels_combo").popdown_strings = CHANNELS_VALUES
        @sample_format = @glade.get_widget("sample_format")
        @sample_format.history = 0
        @channels_entry = @glade.get_widget("channels_entry")
        @channels_entry.signal_connect("insert-text") do |entry, text, bytes| 
            validate_input(entry, text, CHANNELS_REGEX)
        end
        @sample_rate_entry = @glade.get_widget("sample_rate_entry")
        @sample_rate_entry.signal_connect("insert-text") do |entry, text, bytes| 
            validate_input(entry, text, SAMPLE_RATE_REGEX)
        end
        @interleaved = @glade.get_widget("interleaved")
        self.signal_connect("response") do |dlg, resp| 
            synthesize_format()
        end
        analyse_format(format_string) unless format_string.nil?
    end

    private

    def prepare_dialog()
       size_group = Gtk::SizeGroup.new(1)
       1.upto(3) do |i|
           size_group.add_widget(@glade.get_widget("label" + i.to_s))
       end
    end

    def analyse_format(str)
        format = str.split(",")
        @sample_format.history = SAMPLE_FORMATS_KEYS.index(format[0])
        @channels_entry.text = CHANNELS_KEYS.include?(format[1]) ? 
            CHANNELS_VALUES[CHANNELS_KEYS.index(format[1])] : 
            format[1]
        @sample_rate_entry.text = SAMPLE_RATE_KEYS.include?(format[2]) ?
            SAMPLE_RATE_VALUES[SAMPLE_RATE_KEYS.index(format[2])] :
            format[2]
        if format[3]
            @interleaved.active = format[3] == "i"
        else
            @interleaved.active = true
        end
    end

    def validate_input(entry, txt, regex)
        if not txt =~ regex
            entry.signal_emit_stop("insert-text")
            Gdk::beep()
            return true
        end
    end

    def synthesize_format()
        format = []
        format.push(SAMPLE_FORMATS_KEYS[@sample_format.history])
        if CHANNELS_VALUES.include?(@channels_entry.text)
            format.push(CHANNELS_KEYS[CHANNELS_VALUES.index(@channels_entry.text)])
        else
            format.push(@channels_entry.text)
        end
        if SAMPLE_RATE_VALUES.include?(@sample_rate_entry.text)
            format.push(SAMPLE_RATE_KEYS[SAMPLE_RATE_VALUES.index(@sample_rate_entry.text)])
        else
            format.push(@sample_rate_entry.text)
        end
        format.push(@interleaved.active? ? "i" : "n")
        @format = format.join(",")
    end
end # AudioFormatEditor

end # Visecas::
