-- The annotation keybindings send commands to a running WayScriber daemon.
if o.cmd_present("wayscriber") then
  o.launch_on_start("wayscriber --daemon")
end
