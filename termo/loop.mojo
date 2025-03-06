from terminal_mode_manager import TerminalModeManager
from canvas import TerminalCanvas, term_size, Terminal
from input_capture import InputManager, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT
from sys.ffi import DLHandle, os_is_macos
from time import sleep

alias Handle = "libc.dylib" if os_is_macos() else "libc.so.6"


fn main():
    var mode_manager = TerminalModeManager()

    handle = DLHandle(Handle)
    var canvas = TerminalCanvas(handle)
    var input_manager = InputManager(handle)
    var drawing_char = Codepoint(ord("*"))
    var is_drawing = False
    canvas.temp_clear()
    canvas.draw_rectangle((0, 0), (canvas.width, canvas.height), drawing_char)

    while input_manager.is_running:
        canvas.render()

        if not input_manager.has_key():
            input_manager.process_input()  # Blocking on input
            # FOR SURE, IT WILL HAVE INPUT AFTER THIS

        var key = input_manager.get_next_key()

        x, y = canvas.pos
        if key in [KEY_UP, ord("k")] and y > 0:
            y -= 1
        elif key in [KEY_DOWN, ord("j")] and y < canvas.height - 1:
            y += 1
        elif key in [KEY_LEFT, ord("h")] and x > 0:
            x -= 1
        elif key in [KEY_RIGHT, ord("l")] and x < canvas.width - 1:
            x += 1

        elif key == ord(" "):
            is_drawing ^= True

        # Move to the new position
        canvas.set_cursor((x, y))
        if is_drawing:
            canvas.set_pixel((x, y), Codepoint(key))

    # finally:
    mode_manager.restore()

    handle.close()
    print("\033[2J\033[H", end="")
