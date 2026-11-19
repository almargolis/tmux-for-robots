# The Problem

Since the earliest days of UNIX, processes were born as interactive programs attached to a terminal, reading the keyboard as stdin and writing to the screen as stdout.

As a user, the lowest level of UNIX-derived systems seems to be the terminal command line. That is an illusion. The command line interface (CLI) is just another program called a shell. When you use the CLI to launch a program, the shell asks the kernel, the real core of the operating system, to start a new process using its stdin and stdout. The shell seems to go away but is actually still running in the background. When the new program terminates, the shell continues where you last saw it.

Connection to a terminal device is essential for these processes. If the terminal is somehow disconnected, the processes that were attached to it terminate. If your terminal device is a laptop connected to the computer via an Ethernet cable, unplugging the cable causes all the processes that were running to terminate immediately.

Sometimes you don't want a process tethered to a terminal. This includes things like web and mail servers that you want to run automatically in the background. UNIX-based systems have a capability for programs to detach from the terminal and keep running. These types of programs are often called daemons.

When your server boots up, it may launch a web server that quickly detaches from the terminal and keeps running. That is great until you want to change the server's operation or it crashes and terminates with no stdout (or stderr) onto which to write an error message. Because of this, daemons require a lot of complexity to get all operating instructions from configuration files, robustly log operations and handle every circumstance the world may throw at it. The only way for the system operator to talk to the daemon is through the signal system, which provides almost no details, generally just a nudge telling it that something has changed in the configuration files. The mechanics of detaching from the terminal and handling signals are a bit complex and hard to code properly. Developing a robust daemon process is a high-skill effort.

What if you don't want to be absolutely tethered to a terminal but don't have the skill or time needed to turn your program into a finished daemon? The screen program was developed to solve this and other problems in more complex operating environments. Screen launches as a detached process with virtualized stdin and stdout. Once launched, it keeps running until it finishes its job. If the program is printing status and error messages, they are held in a scrollback buffer to be viewed if the process is re-attached to a terminal. If it needs keyboard input, it waits for a terminal.

Screen is useful as a simplified way to develop daemon-like processes with less structure and generally easier debugging. In robotics it keeps things running even when movement causes terminal connection problems. It is common for robots to have multiple running processes that need to be monitored at times, but which present a confusing flood of terminal tabs or windows. Screen provides the capability to hide working processes by detaching while keeping the ability to attach as needed for monitoring or debugging.

The default function of screen is to terminate when the running process terminates. When developing a new system that may not be desirable because you want to see messages that were on the screen when a program crashes. Screen has an easily enabled feature to have it keep the shell alive so you can look at the output and investigate the problem and even restart the programs at the CLI.

tmux and herdr are descendants of screen that keep its fundamental capabilities but add more modern UI features and AI Agent control.
