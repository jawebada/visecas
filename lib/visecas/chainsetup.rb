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
require "visecas/audio-format"
require "visecas/position-string"
require "glib2"

module Visecas 

class Chainsetup < Gtk::Object
    include DestroyableGtkObject

    attr_reader     :name, 
                    :dirty,
                    :chains, 
                    :audio_objects,
                    :operators_lists
    attr_accessor   :filename

    type_register("Chainsetup")

    ###############################################
    # properties
    ###############################################

    install_property(GLib::Param::String.new(
        "name",
        "Name",
        "the chainsetup's name",
        "ERROR, YOU SHOULD NOT SEE THIS",
        GLib::Param::READABLE |
        GLib::Param::WRITABLE
    ))

    def name=(str)
        @name = str
        command("cs-option -n:#{str}")
        notify("name")
    end

    install_property(GLib::Param::Boolean.new(
        "update_mode",
        "Update mode",
        "true if audio objects are opened for updating",
        false,
        GLib::Param::READABLE |
        GLib::Param::WRITABLE
    ))

    def update_mode()
        status()["options"] =~ /\-X/ ? true : false
    end

    def update_mode=(b)
        if b
            command("cs-option -X")
        else
            command("cs-option -x")
        end
    end

    install_property(GLib::Param::Boolean.new(
        "xruns",
        "Xruns",
        "true if processing is stopped when an xrun occurs",
        false,
        GLib::Param::READABLE |
        GLib::Param::WRITABLE
    ))

    def xruns()
        status()["options"] =~ /z:xruns/ ? true : false
    end

    def xruns=(b)
        if b
            command("cs-option -z:xruns")
        else
            command("cs-option -z:noxruns")
        end
    end

    install_property(GLib::Param::Boolean.new(
        "dirty",
        "Dirty",
        "true if the chainsetup needs to be saved",
        false,
        GLib::Param::READABLE
    ))

    install_property(GLib::Param::Boolean.new(
        "valid",
        "Valid",
        "true if the chainsetup is valid",
        false,
        GLib::Param::READABLE
    ))

    def valid()
        command("cs-is-valid") == 1 ? true : false
    end

    install_property(GLib::Param::Boolean.new(
        "connected",
        "Connected",
        "true if the chainsetup is connected",
        false,
        GLib::Param::READABLE |
        GLib::Param::WRITABLE
    ))

    def connected()
        @application.command("cs-connected") == @name ? true : false
    end
    
    def connected=(b)
        if b
            old_length = length
            @application.connect_chainsetup(self)
            notify("length") if old_length != length
        else
            command("cs-disconnect")
        end
        notify("connected")
    end

    install_property(GLib::Param::Boolean.new(
        "looped",
        "Looped",
        "true if the chainsetup is looped",
        false,
        GLib::Param::READABLE |
        GLib::Param::WRITABLE
    ))

    def looped()
        status["options"] =~ /-tl/
    end

    def looped=(b)
        command("cs-toggle-loop") if looped() != b
        notify("looped")
        self.dirty = true
    end

    install_property(GLib::Param::Float.new(
        "length",
        "Length",
        "the chainsetup's length",
        0.0,
        31536000.0, # one year, I hope that's enough :)
        0.0,
        GLib::Param::READABLE |
        GLib::Param::WRITABLE
    ))

    def length()
        command("cs-get-length")
    end

    def length=(l)
        case l.kindof?
            when Integer
                command("cs-set-length-samples #{l}")
            when Float
                command("cs-set-length #{l}")
            else
                raise("length must be Integer (samples) or Float (seconds)")
        end
        notify("length")
    end

    def length_samples()
        command("cs-get-length-samples")
    end

    install_property(GLib::Param::Float.new(
        "position",
        "Position",
        "the chainsetup's position",
        0.0,
        31536000.0, # one year, I hope that's enough :)
        0.0,
        GLib::Param::READABLE |
        GLib::Param::WRITABLE
    ))

    def position()
        command("cs-get-position")
    end

    def position=(value)
        if value.kind_of?(Float)
            command(sprintf("cs-set-position %.3f", value))
        elsif value.kind_of?(Integer)
            command("cs-set-position-samples #{value}")
        end
        notify("position")
    end

    def position_samples()
        command("cs-get-position-samples")
    end

    signal_new(
        "chain_renamed",
        GLib::Signal::RUN_FIRST,
        nil,
        GLib::Type["void"],
        GLib::Type["gchararray"], GLib::Type["gchararray"]
    )

    def signal_do_chain_renamed(old_name, new_name)
        #puts "chain #{old_name} is now #{new_name}"
        @operators_lists[new_name] = @operators_lists[old_name]
        @operators_lists.delete(old_name)
        @visible_operators[new_name] = @visible_operators[old_name]
        @visible_operators.delete(old_name)
        update_chains([new_name])
    end

    signal_new(
        "operator_visibility_changed",
        GLib::Signal::RUN_FIRST,
        nil,
        GLib::Type["void"],
        GLib::Type["gchararray"], GLib::Type["gint"], GLib::Type["gboolean"]
    )

    def signal_do_operator_visibility_changed(chain, op_id, b)
        @visible_operators[chain][op_id] =
        @operators_lists[chain].get_iter(String(op_id - 1))[0] = b
        chain_update_operators(chain)
    end

    ###############################################
    # chainsetup methods
    ###############################################

    def initialize(application, name)
        super()
        
        @application = application
        @engine = application.engine
        
        if @application.command("cs-connected") == name
            @application.command("cs-select #{name}")
            @application.command("cs-disconnect")
        end

        self.name = name
        
        @operators_lists = {}
        @visible_operators = {}
        @chains = Gtk::ListStore.new(String, TrueClass, TrueClass, Integer, String, String)
        @audio_objects = Gtk::ListStore.new(String, String, String, String, String, String)
        setup_signal_handlers()
        sync()
    end

    def select()
        @application.command("cs-select #{@name}")
    end

    def command(str)
        select()
        @application.command(str)
    end

    def sync()
        @visible_operators.each_key do |chain|
            if @visible_operators[chain]
                @visible_operators[chain].each_key do |op_id|
                    chain_hide_operator_control(chain, op_id)
                end
            end
        end
        @operators_lists.clear()
        @chains.clear()
        command("c-list").each { |c| append_chain(c) }
        @audio_objects.clear()
        command("ai-list").each { |ai| append_audio_object("input", ai) }
        command("ao-list").each { |ao| append_audio_object("output", ao) }
        notify("name")
        notify("dirty")
        notify("valid")
        notify("connected")
        notify("length")
        notify("looped")
        @engine.notify("status")
    end

    def remove()
        self.connected = false if connected
        command("cs-remove")
    end

    def save_as(filename)
        command("cs-save-as #{filename}")
        self.filename = filename
        self.dirty = false
    end

    def attach_input(chains, input)
        chains_status().each_pair do |name, status|
            chains.push(name) if status["input"] == input
        end
        chains.uniq!
        old_valid = valid
        old_length = length
        command("c-select #{chains.join(',')}")
        command("ai-select #{input}")
        command("ai-attach")
        update_chains(chains)
        notify("valid") if old_valid != valid
        notify("length") if old_length != length
    end

    def attach_output(chains, output)
        chains_status().each_pair do |name, status|
            chains.push(name) if status["output"] == output
        end
        chains.uniq!
        old_valid = valid
        old_length = length
        command("c-select #{chains.join(',')}")
        command("ao-select #{output}")
        command("ao-attach")
        update_chains(chains)
        notify("valid") if old_valid != valid
        notify("length") if old_length != length
    end

    def forward(secs)
        command("cs-forward #{secs}")
        notify("position")
    end

    def rewind(secs)
        command("cs-rewind #{secs}")
        notify("position")
    end

    def audio_format()
        random = ""
        loop do
            random = rand().to_s + ".wav"
            random.sub!(/\./, "_")
            break if not command("ao-list").include?(random)
        end
        command("ao-add #{random}")
        command("ao-select #{random}")
        format = command("ao-get-format")
        command("ao-remove #{random}")
        format
    end

    def audio_format=(audio_format_string)
        command("cs-set-audio-format #{audio_format_string}")
    end

    ###############################################
    # chains methods
    ###############################################

    def add_chain(chain = nil)
        old_valid = valid
        if chain.nil?
            i = command("c-list").size + 1
            loop do
                chain = "chain" + i.to_s
                i += 1
                break if not command("c-list").include?(chain)
            end
        end
        command("c-add #{chain}")
        append_chain(chain)
        notify("valid") if old_valid != valid
        self.dirty = true
    end

    def remove_chains(list)
        old_valid = valid
        list.each do |chain|
            @visible_operators[chain].each_key do |op_id|
                chain_hide_operator_control(chain, op_id)
            end
            @chains.remove(@chains.get_iter(command("c-list").index(chain).to_s))
            command("c-select #{chain}")
            command("c-remove")
            @operators_lists.delete(chain)
            @visible_operators.delete(chain)
        end
        notify("valid") if old_valid != valid
        self.dirty = true
    end

    def chain_rename(old_name, new_name)
        command("c-select #{old_name}")
        command("c-rename #{new_name}")
        signal_emit("chain_renamed", old_name, new_name)
        self.dirty = true
    end

    def chains_toggle_muting(list)
        status = chains_status()
        toggle = true
        list.each do |chain|
            if not status[chain]["muted"]
                command("c-select #{chain}")
                command("c-muting")
                toggle = false
            end
        end
        if toggle
            chains = list.join(",")
            command("c-select #{chains}")
            command("c-muting")
        end
        # ecaound bug?
        # if chainsetup is connected c-status is sometimes wrong
        update_chains(list)
        update_chains(list)
    end

    def chains_toggle_bypass(list)
        status = chains_status()
        toggle = true
        list.each do |chain|
            if not status[chain]["bypassed"]
                command("c-select #{chain}")
                command("c-bypass")
                toggle = false
            end
        end
        if toggle
            chains = list.join(",")
            command("c-select #{chains}")
            command("c-bypass")
        end
        # ecaound bug?
        # if chainsetup is connected c-status is sometimes wrong
        update_chains(list)
        update_chains(list)
    end

    def chain_add_operator(chain, type, id_string)
        case type
            when "preset"
                cop = @application.operator_presets[id_string]
                command_string = "-pn:#{id_string}"
            when "internal"
                cop = @application.internal_operators[id_string]
                command_string = "-#{id_string}"
            when "ladspa"
                cop = @application.ladspa_plugins[id_string]
                command_string = "-el:#{id_string}"
        end
        if cop["#parameters"] != 0
            defaults = []
            cop["parameters"].each {|hash| defaults.push(hash["defaultvalue"])}
            if type == "internal"
                command_string += ":" + defaults.join(",")
            else
                command_string += "," + defaults.join(",")
            end
        end
        command("c-select #{chain}")
        #puts "cop-add #{command_string}"
        command("cop-add #{command_string}")
        chain_update_operators(chain)
        update_chains([chain])
        self.dirty = true
        # return id
        command("cop-list").size
    end

    def chain_remove_operators(chain, op_id_ary)
        command("c-select #{chain}")
        op_id_ary.reverse_each do |id| 
            #puts "removing op #{id} from #{chain}"
            command("cop-select #{id}")
            command("cop-remove")
            treeview = @operators_lists[chain]
            treeview.remove(treeview.get_iter(String(id-1)))
        end
        chain_update_operators(chain)
        update_chains([chain])
        self.dirty = true
    end

    def chain_get_operators(chain)
        command("c-select #{chain}")
        command("cop-list")
    end

    def chain_show_operator_control(chain, op_id)
        if not @visible_operators[chain][op_id]
            signal_emit("operator_visibility_changed", chain, op_id, true)
        end
    end

    def chain_hide_operator_control(chain, op_id)
        if @visible_operators[chain][op_id]
            signal_emit("operator_visibility_changed", chain, op_id, false)
        end
    end

    def chain_get_operator_parameter(chain, op_id, param_id)
        command("c-select #{chain}")
        command("cop-select #{op_id}")
        command("copp-select #{param_id}")
        value = command("copp-get")
        #puts "value of #{chain}(#{op_id},#{param_id}) = #{value}"
        value
    end

    def chain_set_operator_parameter(chain, op_id, param_id, value)
        command("c-select #{chain}")
        command("cop-select #{op_id}")
        command("copp-select #{param_id}")
        command("copp-set #{value}")
        self.dirty = true
        #puts "setting value of #{chain}(#{op_id},#{param_id}) to #{value}"
        #puts "result: #{command('copp-get')}"
    end

    ###############################################
    # audio inputs methods
    ###############################################

    def add_audio_input(path)
        old_valid = valid
        command("c-deselect #{command("c-list").join(",")}")
        command("ai-add #{path}")
        name = command("ai-list")[-1]
        append_audio_object("input", name)
        notify("valid") if old_valid != valid
        self.dirty = true
    end

    def remove_audio_input(path)
        old_valid = valid
        aio_status = audio_objects_status()
        @audio_objects.remove(@audio_objects.get_iter(command("ai-list").index(path).to_s))
        command("ai-select #{path}")
        command("ai-remove")
        update_chains(aio_status["input" + path]["chains"])
        notify("valid") if old_valid != valid
        self.dirty = true
    end

    def audio_input_format(path)
        command("ai-select #{path}")
        command("ai-get-format")
    end

    def audio_input_position(path)
        command("ai-select #{path}")
        command("ai-get-position")
    end

    def audio_input_length(path)
        command("ai-select #{path}")
        command("ai-get-length")
    end

    ###############################################
    # audio outputs methods
    ###############################################

    def add_audio_output(path)
        old_valid = valid
        command("c-deselect #{command("c-list").join(",")}")
        command("ao-add #{path}")
        name = command("ao-list")[-1]
        append_audio_object("output", name)
        notify("valid") if old_valid != valid
        self.dirty = true
    end

    def remove_audio_output(path)
        old_valid = valid
        aio_status = audio_objects_status()
        id = command("ai-list").length + command("ao-list").index(path)
        command("ao-select #{path}")
        command("ao-remove")
        @audio_objects.remove(@audio_objects.get_iter(id.to_s))
        update_chains(aio_status["output" + path]["chains"])
        notify("valid") if old_valid != valid
        self.dirty = true
    end

    def audio_output_format(path)
        command("ao-select #{path}")
        command("ao-get-format")
    end

    def audio_output_position(path)
        command("ao-select #{path}")
        command("ao-get-position")
    end

    def audio_output_length(path)
        command("ao-select #{path}")
        command("ao-get-length")
    end

    ###############################################
    # private methods
    ###############################################

    private

    def setup_signal_handlers()
        destroyable_signal_connect(@application, "connected_chainsetup_changed") do |app, connected_name|
            notify("connected")
        end

        # engine status changed
        destroyable_signal_connect(@engine, "notify::status") do |engine, pspec|
            case engine.status
                when "running"
                    #@running_idle_loop = Gtk.idle_add() do
                    @running_idle_loop = Gtk.timeout_add(POSITION_UPDATE_INTERVAL) do
                        notify("position")
                    end
                else
                    #Gtk.idle_remove(@running_idle_loop) if @running_idle_loop
                    Gtk.timeout_remove(@running_idle_loop) if @running_idle_loop
                    @running_idle_loop = nil
                    notify("position")
            end if connected
        end

        # chainsetup was dis-/connected
        signal_connect("notify::connected") do |cs, pspec|
            @audio_objects.each do |model, path, iter|
                update_audio_object_format(iter[0], iter[1])
            end
        end
        # position changed
        signal_connect("notify::position") do |cs, pspec|
            @audio_objects.each do |model, path, iter|
                update_audio_object_position(iter[0], iter[1])
            end
        end
    end

    def status()
        @application.chainsetups_status[name]
    end

    def dirty=(b)
        @dirty = b ? true : false
        notify("dirty")
    end

    def append_chain(chain)
        iter = @chains.append()
        iter[0] = chain
        update_chains([chain])
        @operators_lists[chain] = Gtk::ListStore.new(TrueClass, String, String, Integer)
        @visible_operators[chain] = {}
        chain_update_operators(chain)
    end

    def chain_update_operators(chain)
        list = @operators_lists[chain]
        list.clear()
        command("c-select #{chain}")
        cop_list = command("cop-list")
        cop_list.each_index do |idx|
            cop_name = cop_list[idx]
            cop = @application.chainoperators[cop_name] or raise "failed to lookup chainoperator hash"
            iter = list.append()
            iter[0] = @visible_operators[chain][idx+1]
            iter[1] = cop_name
            iter[2] = cop["description"]
            iter[3] = cop["parameters"].size
        end
    end

    def update_chains(list)
        status = chains_status()
        list.each do |chain|
            iter = @chains.get_iter(command("c-list").index(chain).to_s)
            iter[0] = chain
            iter[1] = status[chain]["muted"]
            iter[2] = status[chain]["bypassed"]
            command("c-select #{chain}")
            iter[3] = command("cop-list").size
            iter[4] = status[chain]["input"]
            iter[5] = status[chain]["output"]
        end
    end

    def chains_status()
        aio_status = audio_objects_status()
        c_status = command("c-status")
        lines = c_status.split("\n")
        lines.delete_at(0)
        ret = {}
        lines.each do |line|
            line =~ /Chain "(\w+)"/
            chain = $1
            ret[chain] = {}
            ret[chain]["muted"] = line =~ /\[muted\]/ ? true : false
            ret[chain]["bypassed"] = line =~ /\[bypassed\]/ ? true : false
            ret[chain]["input"] = ret[chain]["output"] = "<b>None</b>"
            aio_status.each_pair do |key, value|
                if value["chains"].include?(chain)
                    ret[chain][value["io"]] = value["path"]
                end
            end
        end
        ret
    end

    def append_audio_object(io, name)
        return false if not name
        iter =  io == "input" ? 
            @audio_objects.insert(command("ai-list").size - 1) :
            @audio_objects.append()
        iter[0] = io
        iter[1] = name
        status = audio_objects_status()[io+name] || {}
        iter[2] = status["type"] || "unknown"
        iter[3] = PositionString.new(0)
        iter[4] = PositionString.new(0)
        update_audio_object_format(io, name)
        update_audio_object_position(io, name)
    end

    def update_audio_object_position(io, name)
        if io == "input"
            iter = @audio_objects.get_iter(command("ai-list").index(name).to_s)
            iter[3] = PositionString.new(audio_input_position(name))
            iter[4] = PositionString.new(audio_input_length(name))
        else
            iter = @audio_objects.get_iter((command("ai-list").length + command("ao-list").index(name)).to_s)
            iter[3] = PositionString.new(audio_output_position(name))
            iter[4] = PositionString.new(audio_output_length(name))
        end
    end

    def update_audio_object_format(io, name)
        iter = io == "input" ? 
            @audio_objects.get_iter(command("ai-list").index(name).to_s) :
            @audio_objects.get_iter((command("ai-list").length + command("ao-list").index(name)).to_s)
        format = io == "input" ? 
            audio_input_format(name) :
            audio_output_format(name)
        iter[5] = AudioFormatString.new(format).human_readable
    end
    
    def audio_objects_status()
        status = command("aio-status")
        # puts status
        lines = status.split("\n")
        lines.delete_at(0)
        ret = {}
        (lines.size/3).times do |i|
            off = i * 3
            string = lines[off..off+2].join(" ") 
            # HMMMM :(
            string =~ /(Input|Output) \((\d+)\): "(\S+)" \- \[([-\s\w_.=>]+)\]/
            io = $1.downcase!
            id = $2
            type = $4
            name = $3.split(",")[0]
            #puts "io " + io
            #puts "id " + id
            #puts "name " + name
            #puts "type " + type
            string =~ /connected to chains "(\S*)":/
            chains = $1.split(",") or []
            #puts "chains" + chains.to_s
            #puts
            ret[io+name] = {"io" => io, "path" => name, "id" => id, "type" => type, "chains" => chains}
        end
        ret
    end
end # Chainsetup

end # Visecas::
