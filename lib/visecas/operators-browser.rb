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

class OperatorsBrowser < Gtk::Dialog
    attr_reader :selected

    RESPONSE_ADD = 1
    RESPONSE_CLOSE = 2

    def initialize(presets = nil, internals = nil, ladspa = nil)
        super()

        self.modal = true
        self.set_default_size(450, 338)
        self.has_separator = false
        self.border_width = 6
        self.vbox.spacing = 12
        self.add_button(Gtk::Stock::ADD, RESPONSE_ADD)
        close = self.add_button(Gtk::Stock::CLOSE, RESPONSE_CLOSE)
        close.can_default = true
        close.grab_default()

        @glade = GladeXML.new(File::join(GLADE_DIR, "operators-browser.glade")) {|handler| method(handler)}
        @glade.get_widget("child").reparent(self.vbox)

        @name_label = @glade.get_widget("name")
        @description_label = @glade.get_widget("description")

        @parameters_store = Gtk::ListStore.new(String)
        @parameters_view = @glade.get_widget("parameters_view")
        @parameters_view.model = @parameters_store
        @parameters_view.insert_column(-1, "Parameter", Gtk::CellRendererText.new(), :text => 0)
        @parameters_view.selection.mode = Gtk::SELECTION_NONE

        @stores = {}
        @views = {}

        self.preset_operators= presets if presets
        self.internal_operators= internals if internals
        self.ladspa_operators= ladspa if ladspa
        
        self.signal_connect("delete_event") {|dlg, id| dlg.hide_on_delete() }
        self.signal_connect("response") {|dlg, id| dlg.hide() if not id == RESPONSE_ADD }
    end

    def preset_operators=(hash)
        prepare_list_store(hash, "preset")
        prepare_view(@glade.get_widget("presets_view"), "preset")
    end

    def internal_operators=(hash)
        prepare_list_store(hash, "internal")
        prepare_view(@glade.get_widget("internal_view"), "internal")
    end

    def ladspa_operators=(hash)
        prepare_list_store(hash, "ladspa")
        prepare_view(@glade.get_widget("ladspa_view"), "ladspa")
    end

    private

    def prepare_list_store(operators, type)
        store = @stores[type] || Gtk::ListStore.new(String, String, Array, String, String)
        operators.each_pair do |id, operator|
            iter = store.append()
            iter[0] = operator["name"]
            desc = operator["description"]
            desc.sub!(/- Author/, "\nAuthor")
            iter[1] = desc
            iter[2] = []
            if not operator["#parameters"] == 0
                operator["parameters"].each {|param| iter[2].push(param["name"])}
            end
            iter[3] = operator["keyword"]
            iter[4] = type
        end
        store.set_sort_column_id(0)
        @stores[type] = store
    end

    def prepare_view(view, type)
        view.model = @stores[type]
        view.insert_column(-1, "Operator", Gtk::CellRendererText.new(), :text => 0)
        view.selection.mode = Gtk::SELECTION_SINGLE
        view.selection.signal_connect("changed") { |sel| selection_changed(sel) }
        view.selection.select_path(Gtk::TreePath.new("0"))
        view.signal_connect("row-activated") do |view, path, column|
            signal_emit("response", RESPONSE_ADD)
        end
        @views[type] = view
    end

    def selection_changed(selection)
        sel = selection.selected
        unless sel.nil?()
            @name_label.markup = "<b>#{sel[0]}</b>"
            @description_label.text = sel[1]
            @parameters_store.clear()
            sel[2].each do |par|
                iter = @parameters_store.append()
                iter[0] = par
            end
            @selected = {"type" => sel[4], "keyword" => sel[3]}
        end
    end

    def page_changed(nb, pg, nr)
        sel = case nr
            when 0
                @views["preset"].selection
            when 1
                @views["internal"].selection
            when 2
                @views["ladspa"].selection
        end
        sel.signal_emit("changed")
    end

end # OperatorsBrowser

end # Visecas::
