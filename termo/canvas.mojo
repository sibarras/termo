import time
from sys.ffi import DLHandle
from memory.unsafe_pointer import UnsafePointer


@always_inline("nodebug")
fn in_bounds(x: Int, y: Int, width: Int, height: Int) -> Bool:
    return x >= 0 and x < width and y >= 0 and y < height


struct WinSize:
    var ws_row: UInt16
    var ws_col: UInt16
    var ws_xpixel: UInt16
    var ws_ypixel: UInt16

    fn __init__(out self):
        self.ws_row = 0
        self.ws_col = 0
        self.ws_xpixel = 0
        self.ws_ypixel = 0


alias TIOCGWINSZ = 0x5413
alias STDOUT_FILENO = 1


fn term_size(handle: DLHandle) -> (Int, Int):
    """Returns Width (cols) and Height (rows)."""
    var ws = WinSize()
    ptr = UnsafePointer.address_of(ws)

    res = handle.call["ioctl", Int32](STDOUT_FILENO, TIOCGWINSZ, ptr)

    if res < 0:
        print("Failed to get terminal size. Using default.")
        return (24, 80)

    return Int(ws.ws_col), Int(ws.ws_row)


@value
struct TerminalCanvas:
    var width: Int
    var height: Int
    var pos: (Int, Int)
    """Position array based."""
    var buffer: List[String]
    # var buf: Span[UInt8, MutableAnyOrigin]

    fn __init__(out self, handle: DLHandle):
        w, h = term_size(handle)
        self = Self(w, h)

    fn __init__(out self, width: Int, height: Int):
        self.width = width
        self.height = height
        self.buffer = List[String]()
        self.pos = (0, 0)

        for _ in range(self.height):
            self.buffer.append(" " * self.width)

    fn set_pixel(mut self, pos: (Int, Int), char: Codepoint):
        x, y = pos
        pr = self.buffer[y]
        self.buffer[y] = pr[:x] + String(char) + pr[x + 1 :]

    fn set_string(mut self, pos: (Int, Int), str: String):
        x, y = pos
        pr = self.buffer[y]
        new_row = pr[:x] + str + pr[x + len(str) :]
        self.buffer[y] = new_row[: self.width]

    fn draw_rectangle(
        mut self, pos: (Int, Int), pos2: (Int, Int), char: Codepoint
    ):
        x, y = pos
        width, height = pos2
        # Draw horizontal lines
        for i in range(width):
            self.set_pixel((x + i, y), char)
            self.set_pixel((x + i, y + height - 1), char)

        # Draw vertical lines
        for i in range(height):
            self.set_pixel((x, y + i), char)
            self.set_pixel((x + width - 1, y + i), char)

    fn render(self):
        v = "".join(self.buffer)
        self.temp_write((0, 0), v)

    fn set_cursor(mut self, pos: (Int, Int)):
        self.pos = pos
        Terminal.set_cursor(pos)

    fn temp_write[s: Writable](self, pos: (Int, Int), value: s):
        Terminal.write_into(self.pos, pos, value)

    @always_inline("nodebug")
    fn temp_clear(self):
        Terminal.clear_screen()


struct Terminal:
    @staticmethod
    @always_inline("nodebug")
    fn clear_screen():
        print("\033[2J", end="")

    @staticmethod
    fn set_cursor(pos: (Int, Int)):
        """Needs to move +1 because in Terminal, we have 1 based indexing."""
        x, y = pos
        print("\033[", y + 1, ";", x + 1, "H", sep="", end="")

    @staticmethod
    fn write_into[s: Writable](prev_pos: (Int, Int), pos: (Int, Int), w: s):
        Self.set_cursor(pos)
        print(w, end="")
        Self.set_cursor(prev_pos)
