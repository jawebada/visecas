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

require "gtk2"

module Visecas 

module DestroyableGtkObject
    # make sure that a signal handler which is connected to an object which
    # possibly stays alife after self is destroyed is disconnected on
    # "destroy"
    def destroyable_signal_connect(obj, signal, after = false, &block)
        @signals_connected_to_destroyables = {} if not 
            @signals_connected_to_destroyables
        @signals_connected_to_destroyables[obj] = [] if not 
            @signals_connected_to_destroyables[obj]

        @signals_connected_to_destroyables[obj].push(
            after ?
                obj.signal_connect_after(signal, block) :
                obj.signal_connect(signal, block)
        )

        @destroyable_destroy_handle = 
            self.signal_connect("destroy") do |o|
                @signals_connected_to_destroyables.each_pair do |obj, handlers|
                    handlers.each do |h|
                        # puts "disconnecting #{h} from #{obj}..."
                        obj.signal_handler_disconnect(h)
                    end
                end
            end if not @destroyable_destroy_handle
    end
end # DestroyableGtkObject::

end # Visecas::
