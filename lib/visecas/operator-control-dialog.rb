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
require "visecas/destroyable-gtk-object"
require "gtk2"

module Visecas

class OperatorControlDialog < Gtk::Dialog
    include DestroyableGtkObject

    RESPONSE_CLOSE = 1

    attr_accessor   :chain, 
                    :operator_id

    def initialize(chainsetup, chain, operator_id, operator_hash)
        super()
        @chainsetup = chainsetup
        @chain = chain
        @operator_id = operator_id
        @operator_hash = operator_hash
        
        self.border_width = 6
        self.has_separator = false
        self.add_button(Gtk::Stock::CLOSE, RESPONSE_CLOSE)
        self.resizable = false
        self.window_position = Gtk::Window::POS_CENTER_ALWAYS
        self.type_hint = Gdk::Window::TYPE_HINT_NORMAL
        vbox.spacing = 6
        
        @title_label = Gtk::Label.new()
        @title_label.xalign = 0.0
        vbox.pack_start(@title_label, false, false)
        
        set_title()

        if @operator_hash["description"] != @operator_hash["name"]
            l = Gtk::Label.new(@operator_hash["description"].capitalize)
            l.wrap = true
            l.xalign = 0.0
            vbox.pack_start(l, false, false)
        end

        destroyable_signal_connect(@chainsetup, "notify::name") {set_title()}
        destroyable_signal_connect(@chainsetup, "chain_renamed") do |cs, old_name, new_name|
            if @chain == old_name
                @chain = new_name
                set_title()
            end
        end

        table = Gtk::Table.new(1, 1)
        table.row_spacings = 3
        table.column_spacings = 6
        table.homogeneous = false

        controls = []
        params = @operator_hash["parameters"]
        params.each_index do |i|
            controls.push(render_control(params[i], i+1))
        end

        case controls.size
            when 1..CONTROLS_PER_COLUMN
                table.resize(controls.size, 1)
            when CONTROLS_PER_COLUMN..2*CONTROLS_PER_COLUMN
                table.resize(controls.size/2 + controls.size%2, 2)
            else
                table.resize(CONTROLS_PER_COLUMN, 
                    (controls.size / CONTROLS_PER_COLUMN + 
                        controls.size % CONTROLS_PER_COLUMN > 0 ? 1 : 0) + 1)
        end

        n_rows = table.n_rows

        labels_size_group = nil
        spin_button_size_group = nil
        range_labels_size_group = nil
        
        controls.each_index do |i|
            if i % n_rows == 0
                labels_size_group = Gtk::SizeGroup.new(1)
                spin_button_size_group = Gtk::SizeGroup.new(1)
                range_labels_size_group = Gtk::SizeGroup.new(1)
            end
            control = controls[i]
            left = i / n_rows
            top = i % n_rows
            table.attach_defaults(control["widget"], left, left + 1, top, top + 1)
            if control["label"]
                labels_size_group.add_widget(control["label"])
            end
            if control["spin_button"]
                spin_button_size_group.add_widget(control["spin_button"]) 
            end
            if control["range_label"]
                range_labels_size_group.add_widget(control["range_label"]) 
            end
        end

        scw = nil
        vp = nil

        if table.n_columns <= 2
            vbox.pack_start(table, true, true)
        else
            table.homogeneous = true
            scw = Gtk::ScrolledWindow.new()
            scw.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
            vp = Gtk::Viewport.new(nil, nil)
            vp.shadow_type = Gtk::SHADOW_NONE
            vp.add(table)
            scw.add(vp)
            vbox.pack_start(scw, true, true)
        end

        self.show_all()

        if scw
            width, height = table.size_request
            col_width = width / table.n_columns
            scw.set_size_request(col_width, height + 20)
            self.queue_resize()
            # XXX this does not what I thought it would do
            # how do I make the scw scroll in tab columns width?
            #scw.hadjustment = vp.hadjustment = Gtk::Adjustment.new(0, 0, width, col_width, col_width, 0)
            scw.hadjustment.step_increment = 
            scw.hadjustment.page_increment = col_width
        elsif @has_hscale
            # make window width resizable up to 600 px (vscale)
            width, height = self.size
            geometry = Gdk::Geometry.new()
            geometry.min_height = geometry.max_height = height
            geometry.min_width = width
            geometry.max_width = 600
            self.set_geometry_hints(vbox, geometry, Gdk::Window::HINT_MIN_SIZE | Gdk::Window::HINT_MAX_SIZE)
        end
    end

    private

    def set_title()
        self.title = "#{@operator_hash['name']} (#{operator_id}) #{@chainsetup.name}:#{@chain}"
        @title_label.markup = "<b>#{@operator_hash['name']} (#{operator_id}) </b>\nChainsetup: #{@chainsetup.name}\nChain: #{@chain}"
    end

    def render_control(param, param_id)
        box = Gtk::VBox.new()
        box.spacing = 3
        value = @chainsetup.chain_get_operator_parameter(@chain, @operator_id, param_id)
        ret = {}
        if param["toggled_flag"]
            w = Gtk::CheckButton.new(param["name"].capitalize)
            w.signal_connect("toggled") do |w|
                value = w.active? ? 1 : 0
                @chainsetup.chain_set_operator_parameter(@chain, @operator_id, param_id, value)
            end
        else
            upper_border = param["upper_border"] ? param["upper_border"] : MAX_BORDER
            lower_border = param["lower_border"] ? param["lower_border"] : - MAX_BORDER
            hbox = Gtk::HBox.new()
            hbox.spacing = 6

            l = Gtk::Label.new(param["name"].capitalize + ":")
            l.xalign = 0.0
            l.yalign = 0.5
            hbox.pack_start(l, false, false)
            ret["label"] = l
            
            if param["integer_flag"]
                step = 1.0
            elsif upper_border != MAX_BORDER and lower_border != -MAX_BORDER
                step = (upper_border - lower_border) / 20.0
            elsif param["defaultvalue"] != 0.0
                step = param["defaultvalue"] / 20.0
            else
                step = 10.0
            end

            adj = Gtk::Adjustment.new(value, lower_border, upper_border, step, step * 10.0, 0)
            adj.signal_connect("value-changed") do |adj|
                @chainsetup.chain_set_operator_parameter(@chain, @operator_id, param_id, adj.value)
            end

            sb = Gtk::SpinButton.new()
            sb.adjustment = adj
            sb.digits = param["integer_flag"] ? 0 : 3
            hbox.pack_start(sb, false, false)
            
            if lower_border == -MAX_BORDER
                lower = "-inf"
            elsif param["integer_flag"]
                lower = Integer(lower_border).to_s
            else
                lower = lower_border.to_s
            end
            if upper_border == MAX_BORDER
                upper = "inf"
            elsif param["integer_flag"]
                upper = Integer(upper_border).to_s
            else
                upper = upper_border.to_s
            end
            l = Gtk::Label.new("[#{lower} - #{upper}]")
            l.xalign = 1.0
            l.yalign = 0.5
            hbox.pack_start(l, false, false)
            ret["range_label"] = l
            
            ret["spin_button"] = sb

            w = hbox

            if upper_border != MAX_BORDER and lower_border != -MAX_BORDER
                scale_box = Gtk::VBox.new()
                scale_box.spacing = 1
                scale_box.pack_start(hbox, true, true)
                vscale = Gtk::HScale.new(adj)
                vscale.draw_value = false
                scale_box.pack_start(vscale, true, true)
                w = scale_box
                @has_hscale = true
            end
        end
        box.pack_start(w)
        if not param["description"].empty? and param["description"] != param["name"]
            l = Gtk::Label.new(param["description"].capitalize)
            l.xalign = 0.0
            box.pack_start(l) 
        end
        ret["widget"] = box
        ret
    end
end # OperatorControlWindow

end # Visecas::
