#!/usr/bin/env python3
"""Drive visible X11 fixture controls; never dispatch application commands."""
import argparse
import ctypes
import time

parser = argparse.ArgumentParser()
parser.add_argument('keys', nargs='*')
args = parser.parse_args()
x11 = ctypes.CDLL('libX11.so.6')
xtst = ctypes.CDLL('libXtst.so.6')
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
x11.XStringToKeysym.restype = ctypes.c_ulong
x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x11.XKeysymToKeycode.restype = ctypes.c_uint
x11.XFlush.argtypes = [ctypes.c_void_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
display = x11.XOpenDisplay(None)
if not display:
    raise SystemExit('An X11 fixture session is required')
try:
    for key in args.keys:
        code = x11.XKeysymToKeycode(display, x11.XStringToKeysym(key.encode('ascii')))
        if not code:
            raise ValueError(f'Unknown X11 key: {key}')
        xtst.XTestFakeKeyEvent(display, code, 1, 0)
        xtst.XTestFakeKeyEvent(display, code, 0, 0)
        x11.XFlush(display)
        time.sleep(.15)
finally:
    x11.XCloseDisplay(display)
