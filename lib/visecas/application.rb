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
require "visecas/engine"
require "visecas/audio-objects-dialog"
require "visecas/operators-browser"
require "visecas/chainsetup"
require "visecas/main-window"
require "visecas/preferences"
require "visecas/preferences-dialog"
require "visecas/ecasound"
require "gtk2"
require "glib2"

module Visecas

if ARGV.include?("--verbose")
    VERBOSE_COMMANDS = true
    ARGV.delete("--verbose")
else
    VERBOSE_COMMANDS = false
end

class Application < GLib::Object
    attr_reader :engine, 
                :chainoperators,
                :fileselection,
                :audio_objects_dialog,
                :operators_browser

    type_register("Application")

    signal_new(
        "connected_chainsetup_changed",
        GLib::Signal::RUN_FIRST,
        nil,
        GLib::Type["void"],
        GLib::Type["gchararray"]
    )

    def signal_do_connected_chainsetup_changed(name)
        # ?
    end

    install_property(GLib::Param::Boolean.new(
        "prefsvisible",
        "Prefsvisible",
        "true if the preferences dialog is visible",
        false,
        GLib::Param::READABLE
    ))

    def prefsvisible
        @prefs_shown
    end

    def prefsvisible=(b)
        @prefs_shown = b
        notify("prefsvisible")
    end

    def initialize(argv = [])
        super()

        @eci = Ecasound::ControlInterface.new()
        
        if argv.include?("-h") or argv.include?("--help")
            puts "#{NAME}'s arguments are passed on to Ecasound.\nEcasound's options are:"
            puts `ecasound --help`
            exit
        end

        puts "scanning presets..."
        @cops_presets = parse_operator_descriptions(command("map-preset-list"))
        puts "scanning internal operators..."
        @cops_internal = parse_operator_descriptions(command("map-cop-list"))
        puts "scanning ladspa plugins..."
        @cops_ladspa = parse_operator_descriptions(command("map-ladspa-list"))
        
        @chainoperators = {}
        [@cops_presets, @cops_internal, @cops_ladspa].each do |hash|
            to_hide = []
            hash.each_pair do |key, value| 
                if @chainoperators[value["name"]]
                    puts "WARNING: chainoperator name '#{value['name']}' not unique"
                    puts "WARNING: it is already used by '#{@chainoperators[value['name']]['keyword']}'"
                    puts "WARNING: chainoperator '#{key}' will not be available"
                    to_hide.push(key)
                else
                    @chainoperators[value["name"]] = value
                end
            end
            to_hide.each {|key| hash.delete(key)}
        end
        
        @fileselection = Gtk::FileSelection.new()
        @fileselection.modal = true
        @fileselection.signal_connect("response") do |dlg, id|
            dlg.hide()
        end

        @engine = Engine.new(self)

        @operators_browser = Visecas::OperatorsBrowser.new(self)
        @operators_browser.signal_connect("response") do |dlg, id|
            dlg.hide() if id != OperatorsBrowser::RESPONSE_ADD
        end
        
        @audio_objects_dialog = AudioObjectsDialog.new()
        @audio_objects_dialog.signal_connect("response") do |dlg, id|
            dlg.hide() if id != AudioObjectsDialog::RESPONSE_ADD_INPUT and
                id != AudioObjectsDialog::RESPONSE_ADD_OUTPUT
        end

        @eci.cleanup()
        @eci = Ecasound::ControlInterface.new(argv.join(" "))
        
        @cs_windows = {}
        command("cs-list").each {|cs| push_chainsetup(cs)}

        @engine.start_timeout()
    end

    def command(arg)
        begin
            ret = eci_command(arg)
        rescue Ecasound::EcasoundCommandError
            message =<<EOS
An ecasound (iam) command caused an error!
The command was: '#{$!.command}'
The error was: '#{$!.error}'

#{NAME} is going to be resynced to correctly show Ecasound's state.
If you can reproduce this error message please consider filing a bug report.
(See #{HOMEPAGE})
EOS
            d = Gtk::MessageDialog.new(
                nil, 
                Gtk::Dialog::MODAL|Gtk::Dialog::DESTROY_WITH_PARENT,
                Gtk::MessageDialog::ERROR,
                Gtk::MessageDialog::BUTTONS_OK,
                message
                )
            d.has_separator = false
            d.resizable = false
            d.signal_connect("response") {|dlg, id| dlg.destroy()}
            d.show_all()
            @cs_windows.each_value {|w| w.sync() }
        end
        ret
    end

    def new_chainsetup(name = nil)
        if name.nil?
            i = command("cs-list").size + 1
            loop do
                name = "chainsetup" + i.to_s
                i += 1
                break if not command("cs-list").include?(name)
            end
        end
        command("cs-add #{name}")
        push_chainsetup(name)
    end

    def open_chainsetups(paths)
        paths.each do |p|
            old_size = command("cs-list").size
            command("cs-load #{p}")
            if command("cs-list").size == old_size + 1
                cs = push_chainsetup(command("cs-list")[-1])
                cs.filename = p
            else
                puts "failed to open chainsetup #{p}"
                puts "probably there is already a chainsetup with the same name"
            end
        end
    end

    def connect_chainsetup(cs)
        cs.select()
        command("cs-connect")
        signal_emit("connected_chainsetup_changed", cs.name)
    end

    def close_chainsetup(cs)
        cs.remove()
        w = @cs_windows[cs]
        w.destroy()
        @cs_windows.delete(cs)
        Gtk.main_quit() if @cs_windows.size == 0
    end

    def quit()
        @cs_windows.each_pair do |cs, w|
            break if not w.close()
        end
    end

    def internal_operators()
        @cops_internal
    end

    def operator_presets()
        @cops_presets
    end

    def ladspa_plugins()
        @cops_ladspa
    end

    def show_preferences()
        prefs_file = File::join(`cd; pwd`.chomp, ".ecasound/ecasoundrc")
        if test(?e, prefs_file)
            prefs = Preferences.new(prefs_file)
            pd = PreferencesDialog.new(prefs)
            pd.title = "Preferences #{NAME}"
            pd.signal_connect("response") do |dlg, id|
                if id == PreferencesDialog::RESPONSE_SAVE
                    # prefs.each_pair do |key, value| puts "#{key}: #{value}" end
                    prefs.write()
                end
                pd.destroy()
                self.prefsvisible = false
            end
            pd.show_all()
            self.prefsvisible = true
        else
            d = Gtk::MessageDialog.new(
                nil, 
                Gtk::Dialog::MODAL|Gtk::Dialog::DESTROY_WITH_PARENT,
                Gtk::MessageDialog::WARNING,
                Gtk::MessageDialog::BUTTONS_OK,
                "The file '#{prefs_file}' does not exist.\nPlease copy the default preferences file which comes with Ecasound to this location."
                )
            d.has_separator = false
            d.resizable = false
            d.signal_connect("response") {|dlg, id| dlg.destroy()}
            d.show_all()
        end
    end

    def chainsetups_status()
        lines = command("cs-status").split("\n")
        lines.delete_at(0)
        ret = {}
        (lines.size/4).times do |i|
            off = i * 4
            string = lines[off..off+3].join(" ")
            string =~ /^Chainsetup \(\d+\) "(\S+)"/
            name = $1
            string =~ /Options: (.*)$/
            options = $1
            ret[name] = {"options" => options}
        end
        ret
    end

    private

    if VERBOSE_COMMANDS
        def eci_command(str)
            puts "command: " + str
            result = @eci.command(str)
            puts "result: " + result.to_s
            puts
            result
        end
    else
        def eci_command(str)
            @eci.command(str)
        end
    end

    def push_chainsetup(name)
        puts "opening '#{name}'..."
        cs = Chainsetup.new(self, name)
        w = MainWindow.new(self, cs)
        w.signal_connect("delete_event") do |window, event|
            window.chainsetup.remove
            @cs_windows.delete(window)
            window.destroy
            Gtk.main_quit() if @cs_windows.size == 0
            true
        end
        @cs_windows[cs] = w
        w.show_all()
        cs
    end

    def parse_operator_descriptions(str)
        hash = {}
        descriptions = str.split("\n")
        descriptions.each do |s|
            d = s.split(",")
            tmp = {}
            tmp["keyword"] = d[0]
            tmp["name"] = d[1]
            tmp["description"] = d[2]
            tmp["#parameters"] = nrof_params = d[3].to_i()
            next if nrof_params == 0
            tmp["parameters"] = []
            #puts
            #puts tmp["name"]
            1.upto(nrof_params) do |i|
                offset = 4 + (i-1) * 11
                param = {}
                param["name"] = d[offset]
                param["description"] = d[offset+1]
                param["defaultvalue"] = d[offset+2].to_f()
                d[offset+3] =~ /above=(\d+)/
                if $1.to_i == 1
                    d[offset+4] =~ /upper=(-*\d+.\d+)/
                    param["upper_border"] = $1.to_f()
                end
                d[offset+5] =~ /below=(\d+)/
                if $1.to_i == 1
                    d[offset+6] =~ /lower=(-*\d+.\d+)/
                    param["lower_border"] = $1.to_f()
                end
                param["toggled_flag"] = true if d[offset+7].to_i() == 1
                param["integer_flag"] = true if d[offset+8].to_i() == 1
                param["logarithmic_flag"] = true if d[offset+9].to_i() == 1
                param["output_flag"] = true if d[offset+10] =~ /output=1/
                tmp["parameters"].push(param)
                #puts param["name"]
                #puts "lower: #{param['lower_border']}"
                #puts "upper: #{param['upper_border']}"
            end
            hash[tmp["keyword"]] = tmp
        end
        return hash
    end
end

end # Visecas::
