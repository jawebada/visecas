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
require "visecas/audio-format"
require "visecas/position-string"
require "visecas/operators-browser"
require "visecas/operator-control-dialog"
require "visecas/about-dialog"
require "libglade2"
require "gtk2"

module Visecas

class MainWindow < Gtk::Window
    attr_reader :chainsetup

    def initialize(application, chainsetup)
        super()
        @application = application
        @chainsetup = chainsetup
        @engine = application.engine
        @operator_dialogs = {}
        @glade = GladeXML.new(File::join(GLADE_DIR, "main.glade"), "child") do |handler| 
            if private_methods.include?(handler)
                method(handler) 
            else
                puts "signal handler '#{handler}' missing!"
            end
        end
        self.add(w("child"))
        self.set_default_size(800, 600)
        prepare_treeviews()
        setup_signal_handlers()
        self.signal_connect("delete_event") {action_close(); true}
    end

    def sync()
        action_sync()
    end

    def close()
        action_close()
    end

    private

    ###############################################
    # widget access
    ###############################################
    def w(string)
        @glade.get_widget(string) or raise "widget #{string} not found"
    end

    ###############################################
    # init
    ###############################################
    def prepare_treeviews()
        # audio objects
        @audio_objects_treeview = w("audio_objects_treeview")
        @audio_objects_treeview.selection.mode = Gtk::SELECTION_MULTIPLE
        @audio_objects_treeview.model = @chainsetup.audio_objects

        columns = ["I/O", "Path", "Type", "Position", "Length", "Format"]
        columns.each_index do |i|
            tvc = Gtk::TreeViewColumn.new(columns[i], Gtk::CellRendererText.new(), :text => i)
            tvc.resizable = true if i == 1 or i == 5
            @audio_objects_treeview.append_column(tvc)
        end
        
        # chains
        @chains_treeview = w("chains_treeview")
        @chains_treeview.model = @chainsetup.chains
        @chains_treeview.selection.mode = Gtk::SELECTION_MULTIPLE

        columns = ["Name", "Muted", "Bypassed", "Op.", "Input", "Output"]
        columns.each_index do |i|
            case i
                when 0
                    r = Gtk::CellRendererText.new()
                    r.editable = true
                    r.signal_connect("edited") do |crt, path, new_text|
                        if not @chainsetup.connected
                            iter = @chains_treeview.model.get_iter(path)
                            @chainsetup.chain_rename(iter[0], new_text)
                        else
                            puts "chain cannot be renamed when it's chainsetup is connected"
                            Gdk.beep()
                        end
                    end
                    key = "markup"
                when 1
                    r = Gtk::CellRendererToggle.new()
                    r.activatable = true
                    r.signal_connect("toggled") do |crt, path|
                        iter = @chains_treeview.model.get_iter(path)
                        @chainsetup.chains_toggle_muting([iter[0]])
                    end
                    key = "active"
                when 2
                    r = Gtk::CellRendererToggle.new()
                    r.activatable = true
                    r.signal_connect("toggled") do |crt, path|
                        iter = @chains_treeview.model.get_iter(path)
                        @chainsetup.chains_toggle_bypass([iter[0]])
                    end
                    key = "active"
                else
                    r = Gtk::CellRendererText.new()
                    key = "markup"
            end
            tvc = Gtk::TreeViewColumn.new(columns[i], r, key => i)
            tvc.resizable = true if i == 4 or i == 5
            @chains_treeview.append_column(tvc)
        end

        # operators
        @operators_treeview = w("operators_treeview")
        @operators_treeview.selection.mode = Gtk::SELECTION_MULTIPLE

        columns = ["Control", "Name", "Description", "Parameters"]
        columns.each_index do |i|
            if i == 0
                r = Gtk::CellRendererToggle.new()
                r.activatable = true
                r.signal_connect("toggled") do |crt, path|
                    iter = @operators_treeview.model.get_iter(path)
                    op_id = Integer(path.to_str) + 1
                    if iter[0]
                        @chainsetup.chain_hide_operator_control(@currently_selected_chain, op_id)
                    else
                        @chainsetup.chain_show_operator_control(@currently_selected_chain, op_id)
                    end
                end
                tvc = Gtk::TreeViewColumn.new(columns[i], r, :active => i)
            else
                tvc = Gtk::TreeViewColumn.new(columns[i], Gtk::CellRendererText.new(), :text => i)
            end
            tvc.resizable = true if i == 2
            @operators_treeview.append_column(tvc)
        end

        @operators_treeview.signal_connect("row-activated") do |view, path, column|
            op_id = Integer(path.to_str) + 1
            @chainsetup.chain_show_operator_control(@currently_selected_chain, op_id)
            @operator_dialogs[@currently_selected_chain][op_id].present()
        end
    end

    def setup_signal_handlers()
        @handlers = {}
        @handlers[@application] = []
        @handlers[@engine] = []

        ###############################################
        # preferences are shown/hidden
        ###############################################
        @handlers[@application].push(
            @application.signal_connect("notify::prefsvisible") do |app, pspec|
                w("menu_edit_preferences").sensitive = ! @application.prefsvisible
            end
        )
        
        ###############################################
        # connect toggled
        ###############################################
        @connect_togglebutton_handler = w("connect_togglebutton").signal_connect("toggled") do |widget|
            if widget.active?
                action_connect()
            else
                action_disconnect()
            end
        end

        ###############################################
        # launch toggled
        ###############################################
        @launch_togglebutton_handler = w("launch_togglebutton").signal_connect("toggled") do |widget|
            if widget.active?
                @engine.launch()
            else
                @engine.halt()
            end
        end

        ###############################################
        # loop toggled
        ###############################################
        @loop_togglebutton_handler = w("loop_togglebutton").signal_connect("toggled") do |widget|
            if widget.active?
                action_loop()
            else
                action_unloop()
            end
        end

        ###############################################
        # chainsetup's loop status changed
        ###############################################
        @chainsetup.signal_connect("notify::looped") do |chainsetup, pspec|
            looped = @chainsetup.looped
            w("loop_togglebutton").signal_handler_block(@loop_togglebutton_handler)
            w("loop_togglebutton").active = looped
            w("loop_togglebutton").signal_handler_unblock(@loop_togglebutton_handler)
            w("menu_edit_loop").sensitive = ! looped
            w("menu_edit_unloop").sensitive = looped
        end

        ###############################################
        # chainsetup got dirty/saved
        ###############################################
        @chainsetup.signal_connect("notify::dirty") do |chainsetup, pspec|
            w("save_button").sensitive = w("menu_file_save").sensitive = @chainsetup.dirty
        end

        ###############################################
        # chainsetup's name changed
        ###############################################
        @chainsetup.signal_connect("notify::name") do |chainsetup, pspec|
            self.title = @chainsetup.name
        end

        ###############################################
        # chainsetup got valid/invalid
        ###############################################
        @chainsetup.signal_connect("notify::valid") do |chainsetup, pspec|
            w("connect_togglebutton").signal_handler_block(@connect_togglebutton_handler)
            w("connect_togglebutton").sensitive = @chainsetup.valid
            w("connect_togglebutton").signal_handler_unblock(@connect_togglebutton_handler)
            
            if @chainsetup.valid
                w("menu_edit_connect").sensitive = true
                w("menu_edit_disconnect").sensitive = false
                self.chainsetup_status = "valid"
            else
                w("menu_edit_connect").sensitive = w("menu_edit_disconnect").sensitive = false
                self.chainsetup_status = "invalid"
            end
        end

        ###############################################
        # chainsetup was connected/disconnected
        ###############################################
        @chainsetup.signal_connect("notify::connected") do |chainsetup, pspec|
            connected = @chainsetup.connected
            valid = @chainsetup.valid
            
            w("connect_togglebutton").signal_handler_block(@connect_togglebutton_handler)
            w("connect_togglebutton").active = connected
            w("connect_togglebutton").signal_handler_unblock(@connect_togglebutton_handler)

            if connected
                # menu items
                # edit
                w("menu_edit_connect").sensitive = false
                w("menu_edit_disconnect").sensitive = true && valid
                w("menu_edit_unloop").sensitive =
                w("menu_edit_loop").sensitive = false
                w("menu_edit_forward").sensitive =
                w("menu_edit_rewind").sensitive =
                w("menu_edit_go_to_start").sensitive =
                w("menu_edit_set_position").sensitive = true
                # chains
                w("menu_chains_add").sensitive =
                w("menu_chains_remove").sensitive = false
                # audio objects
                w("menu_io_add").sensitive =
                w("menu_io_remove").sensitive =
                w("menu_io_attach").sensitive =
                w("menu_io_set_position").sensitive = false

                # main toolbar
                w("attach_button").sensitive = false

                # chains buttonbar
                w("add_chain_button").sensitive =
                w("remove_chains_button").sensitive = false

                # audio objects buttonbar
                w("add_audio_objects_button").sensitive =
                w("remove_audio_objects_button").sensitive =
                w("audio_objects_position_button").sensitive = false

                # control toolbar
                w("launch_togglebutton").sensitive = true
                
                w("reset_button").sensitive = 
                w("rewind_button").sensitive =
                w("forward_button").sensitive = true

                w("loop_togglebutton").sensitive = false
                
                w("position_button").sensitive =
                w("position_hscale").sensitive = true
            else
                # menu items
                # edit
                w("menu_edit_connect").sensitive = true && valid
                w("menu_edit_disconnect").sensitive = false
                w("menu_edit_forward").sensitive =
                w("menu_edit_rewind").sensitive =
                w("menu_edit_go_to_start").sensitive =
                w("menu_edit_set_position").sensitive = false
                # chains
                w("menu_chains_add").sensitive = true
                # audio objects
                w("menu_io_add").sensitive = true

                # chains buttonbar
                w("add_chain_button").sensitive = true

                # audio objects buttonbar
                w("add_audio_objects_button").sensitive = true

                # control toolbar
                w("launch_togglebutton").sensitive = false
                
                w("reset_button").sensitive =
                w("rewind_button").sensitive =
                w("start_button").sensitive =
                w("stop_button").sensitive =
                w("forward_button").sensitive = false

                w("loop_togglebutton").sensitive = true
                @chainsetup.notify("looped")

                w("position_button").sensitive =
                w("position_hscale").sensitive = false

                @chains_treeview.selection.signal_emit("changed")
                @audio_objects_treeview.selection.signal_emit("changed")
            end

            @engine.notify("status")
        end
        
        ###############################################
        # chainsetup's length changed
        ###############################################
        @chainsetup.signal_connect("notify::length") do |chainsetup, pspec| 
            w("position_hscale").adjustment =
                Gtk::Adjustment.new(@chainsetup.position, 0.0, @chainsetup.length, 1.0, POSITION_STEP, 0.0)
            update_position()
        end
        
        ###############################################
        # chainsetup's position changed
        ###############################################
        @chainsetup.signal_connect("notify::position") do |chainsetup, pspec| 
            update_position()
        end
        
        ###############################################
        # positon_hscale drawn
        ###############################################
        @set_position_handler = w("position_hscale").signal_connect("value-changed") do |widget, event|
            @chainsetup.position =  w("position_hscale").value
        end
        
        ###############################################
        # engine status changed
        ###############################################
        @handlers[@engine].push(
            @engine.signal_connect("notify::status") do |engine, pspec|
                connected = @chainsetup.connected
                case engine.status
                    when "running"
                        w("menu_edit_go_to_start").sensitive =
                        w("menu_edit_rewind").sensitive =
                        w("menu_edit_forward").sensitive =
                        w("menu_edit_set_position").sensitive =
                        w("menu_engine_stop").sensitive =
                        w("reset_button").sensitive =
                        w("rewind_button").sensitive =
                        w("forward_button").sensitive = 
                        w("position_button").sensitive =
                        w("stop_button").sensitive = true

                        w("start_button").sensitive =
                        w("menu_engine_start").sensitive = false

                        w("position_hscale").sensitive = false
                    else
                        w("menu_edit_go_to_start").sensitive =
                        w("menu_edit_rewind").sensitive =
                        w("menu_edit_forward").sensitive =
                        w("menu_edit_set_position").sensitive =
                        w("menu_engine_start").sensitive =
                        w("reset_button").sensitive =
                        w("rewind_button").sensitive =
                        w("forward_button").sensitive = 
                        w("position_button").sensitive =
                        w("position_hscale").sensitive =
                        w("start_button").sensitive = true && connected

                        w("menu_engine_stop").sensitive =
                        w("stop_button").sensitive = false
                end

                w("launch_togglebutton").signal_handler_block(@launch_togglebutton_handler)
                case engine.status
                    when "not started"
                        w("menu_engine_launch").sensitive = true && connected
                        w("menu_engine_halt").sensitive = false

                        w("launch_togglebutton").active = false
                    else
                        w("menu_engine_launch").sensitive = false
                        w("menu_engine_halt").sensitive = true && connected

                        w("launch_togglebutton").active = true
                end
                w("launch_togglebutton").signal_handler_unblock(@launch_togglebutton_handler)

                self.engine_status = engine.status
            end
        )

        ###############################################
        # chains selection changed
        ###############################################
        @chains_treeview.selection.signal_connect("changed") do |sel|
            connected = @chainsetup.connected
            count = 0
            sel.selected_each do |model, path, iter| 
                count += 1
                @currently_selected_chain = iter[0]
            end
            w("menu_chains_remove").sensitive =
            w("remove_chains_button").sensitive = count != 0 && ! connected
            w("menu_chains_toggle_muting").sensitive =
            w("menu_chains_toggle_bypass").sensitive =
            w("mute_chains_button").sensitive =
            w("bypass_chains_button").sensitive = count != 0 
            if count == 1
                w("menu_chains_add_operators").sensitive =
                w("add_operators_button").sensitive =
                w("operators_vbox").sensitive = true
                w("operators_label").markup = "<b>Operators (#{@currently_selected_chain})</b>"
                @operators_treeview.model = @chainsetup.operators_lists[@currently_selected_chain]

                ###############################################
                # operators selection changed
                ###############################################
                @operators_treeview.selection.signal_connect("changed") do |sel|
                    count = 0
                    sel.selected_each do |model, path, iter| 
                        count += 1
                    end
                    w("menu_chains_remove_operators").sensitive =
                    w("menu_chains_show_operators_control").sensitive =
                    w("remove_operators_button").sensitive =
                    w("operators_show_control_button").sensitive = count == 0 ? false : true
                end
                @operators_treeview.selection.signal_emit("changed")
            else
                w("menu_chains_add_operators").sensitive =
                w("menu_chains_remove_operators").sensitive =
                w("menu_chains_show_operators_control").sensitive =
                w("add_operators_button").sensitive =
                w("remove_operators_button").sensitive =
                w("operators_show_control_button").sensitive =
                w("operators_vbox").sensitive = false
                w("operators_label").text = "Select a chain to edit it's operators."
                @operators_treeview.model = nil
            end
        end

        ###############################################
        # audio objects selection changed
        ###############################################
        @audio_objects_treeview.selection.signal_connect("changed") do |sel|
            connected = @chainsetup.connected
            input_count = 0
            output_count = 0
            sel.selected_each do |model, path, iter| 
                if iter[0] == "input"
                    input_count += 1
                else
                    output_count += 1
                end
            end
            w("menu_io_remove").sensitive =
            w("menu_io_set_position").sensitive =
            w("remove_audio_objects_button").sensitive =
            w("audio_objects_position_button").sensitive = input_count + output_count > 0 && ! connected
            w("menu_io_attach").sensitive =
            w("attach_button").sensitive = input_count <= 1 && 
                output_count <= 1 && input_count + output_count >= 1 && ! connected
        end

        @chainsetup.signal_connect("operator_visibility_changed") do |cs, chain, op_id, show|
            if @operator_dialogs[chain].nil?
                @operator_dialogs[chain] = {}
            end
            if show
                hash = @application.chainoperators[@chainsetup.chain_get_operators(chain)[op_id - 1]]
                @operator_dialogs[chain][op_id] = d = OperatorControlDialog.new(@chainsetup, chain, op_id, hash)
                d.signal_connect("response") do |dlg, id|
                    @chainsetup.chain_hide_operator_control(dlg.chain, dlg.operator_id)
                end
            else
                d = @operator_dialogs[chain][op_id]
                @operator_dialogs[chain].delete(op_id)
                d.destroy()
            end
        end

        @chainsetup.signal_connect("chain_renamed") do |cs, old_name, new_name|
            @operator_dialogs[new_name] = @operator_dialogs[old_name]
            @operator_dialogs.delete(old_name)
            @chains_treeview.selection.selected_each do |model, path, iter|
                @currently_selected_chain = iter[0]
            end
        end

        # make sure that those signal handlers which are connected to objects
        # which will stay consistent after a destroy are disconnected
        signal_connect("destroy") do
            @handlers.each_pair do |object, handlers|
                handlers.each do |h|
                    object.signal_handler_disconnect(h)
                end
            end
        end

        # init
        @application.notify("prefsvisible")
        action_sync()
    end

    ###############################################
    # actions
    ###############################################
    # file
    def action_new()
        @application.new_chainsetup()
    end

    def action_open()
        fs = @application.fileselection
        fs.title = "Open a Chainsetup..."
        fs.select_multiple = true
        fs.transient_for = self
        # fs.complete(".ecs")
        if fs.run() == Gtk::Dialog::RESPONSE_OK
            @application.open_chainsetups(fs.selections)
        end
    end

    def action_save()
        if @chainsetup.filename
            @chainsetup.save_as(@chainsetup.filename)
            return true
        else
            return action_save_as()
        end
    end

    def action_save_as()
        fs = @application.fileselection
        fs.title = "Save #{@chainsetup.name}..."
        fs.transient_for = self
        if fs.run() == Gtk::Dialog::RESPONSE_OK
            @chainsetup.save_as(fs.filename)
            return true
        else
            return false
        end
    end

    def action_show_properties()
        puts "action_show_properties"
        # TODO
    end

    def action_sync()
        @chainsetup.sync()
        @chains_treeview.selection.signal_emit("changed")
        @audio_objects_treeview.selection.signal_emit("changed")
        @operators_treeview.selection.signal_emit("changed")
    end

    def action_close()
        if @chainsetup.dirty
            d = Gtk::MessageDialog.new(
                self,
                Gtk::Dialog::MODAL|Gtk::Dialog::DESTROY_WITH_PARENT,
                Gtk::MessageDialog::QUESTION,
                Gtk::MessageDialog::BUTTONS_YES_NO,
                "The chainsetup '#{@chainsetup.name}' contains unsaved changes.\nSave them now?"
                )
            d.has_separator = false
            d.resizable = false
            # yes is default
            d.action_area.children[0].grab_default()
            # suppose if it's not yes then it's no
            if d.run() == Gtk::Dialog::RESPONSE_YES
                d.destroy()
                if action_save()
                    @application.close_chainsetup(@chainsetup)
                    return true
                else
                    return false
                end
            else
                d.destroy()
            end
        end
        @application.close_chainsetup(@chainsetup)
        true
    end

    def action_quit()
        @application.quit()
    end

    # edit
    def action_connect()
        @chainsetup.connected = true
    end

    def action_disconnect()
        @chainsetup.connected = false
    end

    def action_loop()
        @chainsetup.looped = true
    end

    def action_unloop()
        @chainsetup.looped = false
    end

    def action_go_to_start()
        @chainsetup.position = 0.0
    end

    def action_forward()
        @chainsetup.forward(POSITION_STEP)
    end
    
    def action_rewind()
        @chainsetup.rewind(POSITION_STEP)
    end

    def action_set_position()
        puts "action_set_position"
        puts "coming soon ;)"
        # TODO
    end

    def action_show_preferences()
        @application.show_preferences()
    end

    # audio objects
    def action_add_audio_objects()
        d = @application.audio_objects_dialog
        d.title = "Add Audio Objects to #{@chainsetup.name}..."
        d.modal = true
        d.transient_for = self
        d.audio_format = @chainsetup.audio_format
        handler = d.signal_connect("response") do |dlg, id|
            case id
                when AudioObjectsDialog::RESPONSE_ADD_INPUT
                    @chainsetup.audio_format = dlg.audio_format
                    @chainsetup.add_audio_input(dlg.audio_object_string)
                when AudioObjectsDialog::RESPONSE_ADD_OUTPUT
                    @chainsetup.audio_format = dlg.audio_format
                    @chainsetup.add_audio_output(dlg.audio_object_string)
                else
                    dlg.signal_handler_disconnect(handler)
            end
        end
        d.show_all()
    end

    def action_remove_selected_audio_objects()
        inputs_to_remove = []
        outputs_to_remove = []
        @audio_objects_treeview.selection.selected_each do |model, path, iter|
            if iter[0] == "input"
                inputs_to_remove.push(iter[1])
            else
                outputs_to_remove.push(iter[1])
            end
        end
        inputs_to_remove.each {|ai| @chainsetup.remove_audio_input(ai)}
        outputs_to_remove.each {|ao| @chainsetup.remove_audio_output(ao)}
    end

    def action_selected_audio_objects_set_position()
        puts "action_selected_audio_objects_set_position"
        puts "coming soon ;)"
        # TODO
    end

    # chains
    def action_add_chain()
        @chainsetup.add_chain()
    end

    def action_remove_selected_chains()
        chains_to_remove = []
        @chains_treeview.selection.selected_each do |model, path, iter|
            chains_to_remove.push(iter[0])
        end
        @chainsetup.remove_chains(chains_to_remove)
    end

    def action_attach()
        target_chains = []
        @chains_treeview.selection.selected_each do |model, path, iter|
            target_chains.push(iter[0])
        end
        @audio_objects_treeview.selection.selected_each do |model, path, iter|
            # puts "attaching #{target_chains.join(",")} to #{iter[1]}"
            if iter[0] == "input"
                @chainsetup.attach_input(target_chains, iter[1])
            else
                @chainsetup.attach_output(target_chains, iter[1])
            end
        end
    end

    def action_selected_chains_toggle_muting()
        chains_to_toggle = []
        @chains_treeview.selection.selected_each do |model, path, iter|
            chains_to_toggle.push(iter[0])
        end
        @chainsetup.chains_toggle_muting(chains_to_toggle)
    end
    
    def action_selected_chains_toggle_bypass()
        chains_to_toggle = []
        @chains_treeview.selection.selected_each do |model, path, iter|
            chains_to_toggle.push(iter[0])
        end
        @chainsetup.chains_toggle_bypass(chains_to_toggle)
    end
    
    def action_add_operators()
        b = @application.operators_browser
        b.title = "Add Operators to #{chainsetup.name}:#{@currently_selected_chain}"
        b.set_transient_for(self)
        handler = b.signal_connect("response") do |dlg, id|
            if id == OperatorsBrowser::RESPONSE_ADD
                type = dlg.selected["type"]
                keyword = dlg.selected["keyword"]
                if type == "ladspa" and @application.ladspa_plugins[keyword]["name"] =~ /_/
                    puts "LADSPA plugin's name appears to contain a ',', Ecasound cannot handle this"
                    d = Gtk::MessageDialog.new(
                        dlg, 
                        Gtk::Dialog::MODAL|Gtk::Dialog::DESTROY_WITH_PARENT,
                        Gtk::MessageDialog::ERROR,
                        Gtk::MessageDialog::BUTTONS_OK,
                        "The name of this LADSPA plugin appears to contain a ','.\nEcasound currently cannot handle this correctly"
                        )
                    d.run()
                    d.destroy()
                else
                    @chainsetup.chain_add_operator(@currently_selected_chain, type, keyword) 
                end
            else
                dlg.signal_handler_disconnect(handler)
            end
        end
        b.show_all()
    end

    def action_remove_selected_operators()
        cops_to_remove = []
        @operators_treeview.selection.selected_each do |model, path, iter|
            cops_to_remove.push(Integer(path.to_str)+1)
        end
        @chainsetup.chain_remove_operators(@currently_selected_chain, cops_to_remove)
    end
    
    def action_selected_operators_control()
        ops_to_activate = []
        @operators_treeview.selection.selected_each do |model, path, iter|
            op_id = Integer(path.to_str) + 1
            if not iter[0]
                ops_to_activate.push(op_id)
            end
        end
        if ops_to_activate.size > 0
            ops_to_activate.each {|op_id| @chainsetup.chain_show_operator_control(@currently_selected_chain, op_id)}
        else
            1.upto(@chainsetup.chain_get_operators(@currently_selected_chain).size) do |op_id|
                @chainsetup.chain_hide_operator_control(@currently_selected_chain, op_id)
            end
        end
    end

    def action_show_all_controls()
        @chainsetup.chains.each do |model, path, iter|
            chain = iter[0]
            ops = @chainsetup.chain_get_operators(chain)
            if ops.size > 0
                1.upto(ops.size) do |op_id|
                    @chainsetup.chain_show_operator_control(chain, op_id)
                end
            end
        end
    end
    
    # engine
    def action_launch()
        @engine.launch()
    end

    def action_halt()
        @engine.halt()
    end

    def action_start()
        @engine.start()
    end

    def action_stop()
        @engine.stop()
    end

    def action_show_user_guide()
        puts "action_show_user_guide"
        # TODO
    end

    def action_show_about()
        Visecas::AboutDialog.new().show_all()
    end

    ###############################################
    # misc
    ###############################################
    def update_position()
        markup = "<span size='xx-large' weight='bold'>" + PositionString.new(@chainsetup.position) + "</span>\n"
        markup += "<b>" + PositionString.new(@chainsetup.length) + "\n"
        markup += "#{@chainsetup.position_samples} / #{@chainsetup.length_samples}</b>"
        w("position_label").markup = markup

        w("position_hscale").signal_handler_block(@set_position_handler)
        w("position_hscale").value = @chainsetup.position
        w("position_hscale").signal_handler_unblock(@set_position_handler)
    end

    def engine_status=(status)
        if @engine_status_context.nil?
            @engine_statusbar = w("engine_statusbar")
            @engine_status_context = @engine_statusbar.get_context_id("engine_status")
            @engine_statusbar.push(@engine_status_context, "Engine is " + status)
        else
            @engine_statusbar.pop(@engine_status_context)
            @engine_statusbar.push(@engine_status_context, "Engine is " + status)
        end
    end

    def chainsetup_status=(status)
        if @chainsetup_status_context.nil?
            @chainsetup_statusbar = w("chainsetup_statusbar")
            @chainsetup_status_context = @chainsetup_statusbar.get_context_id("chainsetup_status")
            @chainsetup_statusbar.push(@chainsetup_status_context, "Chainsetup is " + status)
        else
            @chainsetup_statusbar.pop(@chainsetup_status_context)
            @chainsetup_statusbar.push(@chainsetup_status_context, "Chainsetup is " + status)
        end
    end
end # MainWindow

end # Visecas::
