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
        read(file) if file
    end

    def read(file)
        @file = file
        lines = IO.readlines(file)
        lines.each_index do |i|
            next if lines[i] =~ /^#/
            lines[i] =~ /(\S+)\s*( |=)\s*(\S.+)/
            key = $~[1]
            value = $~[3]
            self[key] = value
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
