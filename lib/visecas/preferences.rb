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

module Visecas

class Preferences < Hash
    def initialize(file = nil)
        self["midi-device"] = "rawmidi,/dev/midi"
        self["default-output"] = "/dev/dsp"
        self["default-audio-format"] = "s16_le,2,44100,i"
        self["default-to-precise-sample-rates"] = "false"
        self["default-to-interactive-mode"] = "false"
        self["bmode-defaults-nonrt"] = "1024,false,50,false,100000,true"
        self["bmode-defaults-rt"] = "1024,true,50,true,100000,true"
        self["bmode-defaults-rtlowlatency"] = "256,true,50,true,100000,false"
        self["resource-directory"] = "/usr/local/share/ecasound"
        self["resource-file-genosc-envelopes"] = "generic_oscillators"
        self["resource-file-effect-presets"] = "effect_presets"
        self["ladspa-plugin-directory"] = "/usr/local/lib/ladspa"
        self["ext-cmd-text-editor"] = "pico"
        self["ext-cmd-text-editor-use-getenv"] = "true"
        self["ext-cmd-wave-editor"] = "ecawave"
        self["ext-cmd-mp3-input"] = "mpg123 --stereo -r %s -b 0 -q -s -k %o %f"
        self["ext-cmd-mp3-output"] = "lame -b %B -s %S -x -S - %f"
        self["ext-cmd-ogg-input"] = "ogg123 -d raw --file=- %f"
        self["ext-cmd-ogg-output"] = "oggenc -b %B --raw --raw-bits=%b --raw-chan=%c --raw-rate=%s --output=%f -"
        self["ext-cmd-mikmod"] = "mikmod -d stdout -o 16s -q -f %s -p 0 --noloops %f"
        self["ext-cmd-timidity"] = "timidity -Or1S -id -s %s -o - %f"
        @file = file
        read(file) if file
    end

    def read(file)
        @file = file
        return if not test(?e @file)
        lines = IO.readlines(file)
        lines.each_index do |i|
            next if lines[i] =~ /^#/
            lines[i] =~ /(\S+)\s*( |=)\s*(\S.+)/
            self[$1] = $3
        end
    end

    def write(file = nil)
        file = file.nil? ? @file : file
        fd = File.new(file, "w")
        self.each_pair { |key, value| fd.write("#{key} = #{value}\n") }
        fd.close()
    end
end # Preferences

end # Visecas::
