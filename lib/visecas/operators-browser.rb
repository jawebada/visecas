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

    def initialize(application)
        super()
        @application = application
        self.modal = true
        self.add_button(Gtk::Stock::ADD, RESPONSE_ADD)
        close = self.add_button(Gtk::Stock::CLOSE, RESPONSE_CLOSE)
        close.can_default = true
        close.grab_default()
        self.set_default_size(450, 338)
        self.has_separator = false
        self.border_width = 6
        self.vbox.spacing = 12
        @glade = GladeXML.new(File::join(GLADE_DIR, "operators-browser.glade")) {|handler| method(handler)}
        @glade.get_widget("child").reparent(self.vbox)
        @name = @glade.get_widget("name")
        @description = @glade.get_widget("description")

        prepare_listviews()
        
        self.signal_connect("delete_event") {|dlg, id| dlg.hide_on_delete() }
        self.signal_connect("response") {|dlg, id| dlg.hide() if not id == RESPONSE_ADD }
    end

    private

    def prepare_listviews()
        @parameters_store = Gtk::ListStore.new(String)
        @parameters_view = @glade.get_widget("parameters_view")
        @parameters_view.model = @parameters_store
        @parameters_view.insert_column(-1, "Parameter", Gtk::CellRendererText.new(), :text => 0)
        @parameters_view.selection.mode = Gtk::SELECTION_NONE
        
        @internal_store = prepare_list_store(@application.internal_operators, "internal")
        @presets_store = prepare_list_store(@application.operator_presets, "preset")
        @ladspa_store = prepare_list_store(@application.ladspa_plugins, "ladspa")
        
        @ladspa_view = prepare_view(@glade.get_widget("ladspa_view"), @ladspa_store)
        @internal_view = prepare_view(@glade.get_widget("internal_view"), @internal_store)
        @presets_view = prepare_view(@glade.get_widget("presets_view"), @presets_store)

        @ladspa_view.signal_connect("row-activated") do |view, path, column|
            signal_emit("response", RESPONSE_ADD)
        end
        @internal_view.signal_connect("row-activated") do |view, path, column|
            signal_emit("response", RESPONSE_ADD)
        end
        @presets_view.signal_connect("row-activated") do |view, path, column|
            signal_emit("response", RESPONSE_ADD)
        end

        @presets_view.grab_focus()
    end

    def prepare_list_store(operators, type)
        store = Gtk::ListStore.new(String, String, Array, String, String)
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
        return store
    end

    def prepare_view(view, model)
        view.model = model
        view.insert_column(-1, "Operator", Gtk::CellRendererText.new(), :text => 0)
        view.selection.mode = Gtk::SELECTION_SINGLE
        view.selection.signal_connect("changed") { |sel| selection_changed(sel) }
        view.selection.select_path(Gtk::TreePath.new("0"))
        return view
    end

    def selection_changed(selection)
        sel = selection.selected
        unless sel.nil?()
            @name.markup = "<b>#{sel[0]}</b>"
            @description.text = sel[1]
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
                @presets_view.selection
            when 1
                @internal_view.selection
            when 2
                @ladspa_view.selection
        end
        sel.signal_emit("changed")
    end

end # OperatorsBrowser

end # Visecas::
