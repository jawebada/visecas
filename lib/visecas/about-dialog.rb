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
require "gtk2"
require "libglade2"

module Visecas

class AboutDialog < Gtk::Dialog
    RESPONSE_CLOSE = 1
    def initialize()
        super()
        self.modal = true
        self.border_width = 6
        self.has_separator = false
        self.resizable = false
        name = NAME
        self.title = "About #{name}"
        glade = GladeXML.new(File::join(GLADE_DIR, "about-dialog.glade"), "child") do |h| end
        vbox.add(glade.get_widget("child"))
        self.add_button(Gtk::Stock::CLOSE, RESPONSE_CLOSE)
        glade.get_widget("title_label").markup = "<span size='xx-large' weight='bold'>#{name} #{VERSION.to_s}</span>"
        glade.get_widget("description_label").text = DESCRIPTION + "\n" + COPYRIGHT
        signal_connect("response") { self.destroy() }
    end
end # AboutDialog

end # Visecas::
