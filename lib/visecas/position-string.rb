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

class PositionString
    def initialize(pos)
        super()
        self.position = pos
    end

    def position=(pos)
        @h = (pos / 3600.0).to_i()
        @m = ((pos - 3600.0 * @h) / 60.0).to_i()
        @s = (pos - (3600.0 * @h + 60.0 * @m)).to_i()
        @ms = ((pos - pos.floor()) * 1000).to_i()
    end

    def to_str()
        sprintf("%02d:%02d:%02d.%03d", @h, @m, @s, @ms)
    end
end # Class

end # Visecas::
