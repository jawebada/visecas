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


module Visecas

# these are 'ordered hashes'
SAMPLE_FORMATS= [
    ["u8",      "8 bits"], 
    ["s16_le",  "16 bits (little endian)"], 
    ["s16_be",  "16 bits (big endian)"], 
    ["s24_le",  "24 bits (little endian)"], 
    ["s24_be",  "24 bits (big endian)"], 
    ["s32_le",  "32 bits (little endian)"], 
    ["s32_be",  "32 bits (big endian)"], 
    ["f32_le",  "32 bits (float little endian)"],
    ["f32_be",  "32 bits (float big endian)"]
]
SAMPLE_FORMATS_KEYS = SAMPLE_FORMATS.collect do |ary| ary[0] end
SAMPLE_FORMATS_VALUES = SAMPLE_FORMATS.collect do |ary| ary[1] end

CHANNELS = [
    ["1",       "Mono"],
    ["2",       "Stereo"],
    ["4",       "Quattro"]
]
CHANNELS_KEYS = CHANNELS.collect do |ary| ary[0] end
CHANNELS_VALUES = CHANNELS.collect do |ary| ary[1] end
CHANNELS_REGEX = /#{CHANNELS_VALUES.join("|")}|[0-9]/

SAMPLE_RATE = [
    ["8000",    "Speech quality (8000 Hz)"],
    ["16000",   "Wideband speech quality (16000 Hz)"],
    ["44100",   "CD quality (44100 Hz)"],
    ["48000",   "DAT quality (48000 Hz)"],
    ["96000",   "Studio quality (96000 Hz)"]
]
SAMPLE_RATE_KEYS = SAMPLE_RATE.collect do |ary| ary[0] end
SAMPLE_RATE_VALUES = SAMPLE_RATE.collect do |ary| ary[1] end
SAMPLE_RATE_REGEX = /#{SAMPLE_RATE_VALUES.join("|")}|[0-9]/

class AudioFormatString < String
    def initialize(str, human_readable = false)
        @format = str.split(",")
        raise("unexpected format of AudioFormatString: '#{str}'") if 
            @format.length < 3
    end

    def sample_format()
        @format[0]
    end

    def human_sample_format()
        SAMPLE_FORMATS_VALUES[SAMPLE_FORMATS_KEYS.index(sample_format)]
    end

    def channels()
        @format[1]
    end

    def human_channels()
        CHANNELS_KEYS.include?(channels) ? 
            CHANNELS_VALUES[CHANNELS_KEYS.index(channels)] : 
            "#{channels} channels"
    end
    
    def sample_rate()
        @format[2]
    end

    def human_sample_rate()
        SAMPLE_RATE_KEYS.include?(sample_rate) ? 
            SAMPLE_RATE_VALUES[SAMPLE_RATE_KEYS.index(sample_rate)] :
            "#{sample_rate} Hz"
    end

    def interleaved?()
        return false if @format[3] == "n"
        true
    end

    def human_interleaved()
        return "Interleaved" if interleaved?
        "Non-interleaved"
    end

    def human_readable()
        [   human_sample_rate, 
            human_sample_format, 
            human_channels, 
            human_interleaved
        ].join(", ")
    end
end # AudioFormatString

end # Visecas::
