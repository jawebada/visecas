
Introduction
------------

Visecas is a graphical user interface for Ecasound <http://eca.cx/ecasound>, a
software package written by Kai Vehmanen <k@eca.cx> which is designed for
multitrack audio processing.
It starts Ecasound as a child process and communicates via a pipe using
Ecasound's InterActive Mode (IAM) commands.

Visecas is designed with GNOME's Human Interface Guidelines in mind.

See http://visecas.sourceforge.net for details.


Features
--------

* All arguments are passed on to Ecasound.
  You can start Visecas from the command line as you would start Ecasound.
* This implies that Visecas does not introduce another file format but can read
  and write ecs files (actually Ecasound reads and writes them itself).
* Every chainsetup of an Ecasound session is displayed in one toplevel window.
* Chains can be added, removed, renamed, muted and bypassed.
* Audio objects can be added, removed and connected.
* Chainoperators can be added, removed and controlled by
  dynamically created dialogs.
* The engine status is displayed and can be controlled.
* Ecasound's preferences can be edited.


Other Features (so-called Bugs)
-------------------------------

See TODO.


Installation
------------

Fulfill the following dependencies then see INSTALL.


Dependencies
------------

* Ruby 1.8.x (1.6 untested, may work)
http://www.ruby-lang.org/en
* GTK+ > 2.0
http://www.gtk.org
* A recent version of libglade
http://ftp.gnome.org/pub/GNOME/sources/libglade/2.0/

Make sure you have everything above installed before you move to:

* Ruby-Gnome2 >= 0.8.0
http://ruby-gnome2.sourceforge.jp/
There are different packages:
You will need the ruby-gnome2-all package which includes libglade2 bindings.

And of course last but certainly not least:

* Ecasound >= 2.2.0 (the newer the better)
http://eca.cx/ecasound


Author
------

(C) Copyright 2003 - 2004 Jan Weil <jan.weil@web.de>


Licensing
---------

Visecas is licensed under the terms of the GNU General Public
License (GPL). You should have received a copy of this
license. See COPYING for details.


Mailing list
------------

For now, please join Ecasound's mailing list to discuss this program.

