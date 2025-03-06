from subprocess import run
from collections.string import StringSlice
from os import abort


struct TerminalModeManager:
    var original_settings: Optional[String]

    fn __init__(out self):
        self.original_settings = None
        try:
            mode = run("stty -g").strip()
            self.original_settings = String(mode)
            _ = run("stty raw -echo")
        except:
            abort("Failed to get original setting and do raw terminal")

    fn restore(self):
        cmd = String("stty", self.original_settings.value(), sep=" ")
        try:
            _ = run(cmd)
        except:
            abort("Failed to restore..")
