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

# this is set by pre-config.rb
PREFIX = ".."

SHARE_DIR = File::join(PREFIX, "share")
GLADE_DIR = File::join(SHARE_DIR, "visecas/glade")

VERSION_MAJOR = 0
VERSION_MINOR = 3
VERSION_MICRO = 1
VERSION = "#{VERSION_MAJOR}.#{VERSION_MINOR}.#{VERSION_MICRO}"

NAME = "Visecas"
HOMEPAGE = "http://visecas.sourceforge.net"
COPYRIGHT = "Copyright (C) 2003 - 2004 Jan Weil <Jan.Weil@web.de>"
DESCRIPTION = <<EOS
A graphical user interface for Ecasound, 
a software package written by Kai Vehmanen <k@eca.cx>
which is designed for multitrack audio processing.
EOS

# how far to rewind/forward (s)
POSITION_STEP = 5.0

# timeout to update position (ms)
POSITION_UPDATE_INTERVAL = 250

# timeout to update engine status (ms)
ENGINE_UPDATE_INTERVAL = 500

# a Gtk::Adjustment always needs an upper border
# this is 'inf'
MAX_BORDER = 1000000.0

# operator controls are arranged in a table
# this determines how many controls are displayed in one column
CONTROLS_PER_COLUMN = 9

end # Visecas::
