from builtin.io import _fdopen
from builtin.file_descriptor import FileDescriptor
from sys import _libc as libc
from sys.ffi import OpaquePointer, external_call, DLHandle
from memory.unsafe_pointer import UnsafePointer
from collections.string import StringSlice
from collections.inline_list import InlineList
from sys.info import os_is_macos

alias BREAK = ord("\033")
alias OB = ord("[")
alias A = ord("A")
alias B = ord("B")
alias C = ord("C")
alias D = ord("D")

alias SHORT_MASK = SIMD[DType.bool, 4](1, 0, 0, 0)
alias DIR_MASK = SIMD[DType.bool, 4](1, 1, 1, 0)
alias ZERO = SIMD[DType.uint8, 4](0)

alias ESC = SIMD[DType.uint8, 4](BREAK, 0, 0, 0)

alias UP = SIMD[DType.uint8, 4](BREAK, OB, A, 0)
alias DOWN = SIMD[DType.uint8, 4](BREAK, OB, B, 0)
alias RIGHT = SIMD[DType.uint8, 4](BREAK, OB, C, 0)
alias LEFT = SIMD[DType.uint8, 4](BREAK, OB, D, 0)

alias KEY_ESC = 27
alias KEY_UP = 1000
alias KEY_DOWN = 1001
alias KEY_RIGHT = 1003
alias KEY_LEFT = 1002


fn read_once(handle: DLHandle) -> (SIMD[DType.uint8, 4], Int):
    buf = SIMD[DType.uint8, 4](0)
    # Use libc read function
    # read(int fd, void *buf, size_t count)
    bytes_read = handle.call["read", Int32](0, UnsafePointer.address_of(buf), 4)
    # print(buf, bytes_read)
    return buf, Int(bytes_read)


fn get_key(handle: DLHandle) -> (Int, SIMD[DType.uint8, 4], Int, Int):
    # Read a single byte from stdin without buffering
    buf, bytes_read = read_once(handle)
    dir = DIR_MASK.select(buf, ZERO)
    esc = SHORT_MASK.select(buf, ZERO)
    # print("non get_key functions:\n")
    if all(dir == UP):
        # print("is up")
        return KEY_UP, buf, 3, bytes_read - 3
    if all(dir == DOWN):
        # print("is down")
        return KEY_DOWN, buf, 3, bytes_read - 3
    if all(dir == RIGHT):
        # print("is right")
        return KEY_RIGHT, buf, 3, bytes_read - 3
    if all(dir == LEFT):
        # print("is left")
        return KEY_LEFT, buf, 3, bytes_read - 3
    if all(esc == ESC):
        # print("is esc")
        return KEY_ESC, buf, 1, bytes_read - 1

    # print("is another")
    return -1, buf, 1, bytes_read - 1  # Means another key.


struct InputManager:
    alias SIMDBuf = SIMD[DType.uint32, 8]
    var key_buffer: Self.SIMDBuf
    var frst_empty_idx: Int
    var is_running: Bool
    var handle: DLHandle

    fn __init__(out self, handle: DLHandle):
        self.handle = handle
        self.key_buffer = Self.SIMDBuf(0)
        self.is_running = True
        self.frst_empty_idx = 0

    fn pop_front(mut self) -> Int:
        val = self.key_buffer[0]
        self.key_buffer = self.key_buffer.shift_left[1]()
        self.frst_empty_idx -= 1
        return Int(val)

    fn process_input(mut self):
        key, buf, items_used, items_left = get_key(self.handle)
        if items_used == 0:  # Nothing readed
            return

        key = key if key != -1 else Int(buf[0])
        self.key_buffer[self.frst_empty_idx] = key
        self.frst_empty_idx += 1

        for left in range(items_left):
            self.key_buffer[self.frst_empty_idx + left] = buf[
                items_used + left
            ].cast[DType.uint32]()

        self.frst_empty_idx += items_left

        if key == ord("q"):
            self.is_running = False

    fn has_key(self) -> Bool:
        return self.key_buffer.reduce_add() > 0

    fn get_next_key(mut self) -> Int:
        if self.has_key():
            key = self.pop_front()
            return Int(key)

        return -1


fn enable_mouse_tracking():
    # Enable mouse tracking for modern terminals
    print("\033[?1000h\033[?1003h", end="")


fn disable_mouse_tracking():
    # Disable mouse tracking
    print("\033[?1000l\033[?1003l", end="")
