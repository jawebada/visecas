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


require "visecas/application"
require "visecas/config"
require "gtk2"
require "libglade2"

module Visecas 

class Engine < GLib::Object
    type_register("Engine")

    def initialize(application)
        super()
        @application = application
        @current = status()
    end

    install_property(GLib::Param::String.new(
        "status",
        "Status",
        "the status of ecasound's engine",
        nil,
        GLib::Param::READABLE
    ))

    def start_timeout()
        Gtk.timeout_add(ENGINE_UPDATE_INTERVAL) do 
            now = status()
            if @current != now
                @current = now
                notify("status")
            end
            true
        end
    end

    def status()
        @application.command("engine-status")
    end

    def start()
        @application.command("start")
    end

    def stop()
        @application.command("stop")
    end

    def halt()
        @application.command("engine-halt")
    end

    def launch()
        @application.command("engine-launch")
    end
end # Engine

end # Visecas::
