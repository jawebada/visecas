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
# pre-setup.rb
#

config_file = "config.rb"

lines = open(config_file).readlines()
lines.each_index do |i|
    if lines[i] =~ /^PREFIX =/
        lines[i] = "PREFIX = \"#{config('prefix')}\"\n"
        break
    end
end
f = open(config_file, "w")
f << lines.join("")

