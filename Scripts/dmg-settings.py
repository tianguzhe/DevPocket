"""Finder layout, generated without launching or scripting Finder."""

from pathlib import Path
import ctypes
import os
import struct

app = Path(defines["app"])
files = [(str(app), "DevPocket.app")]
symlinks = {"Applications": "/Applications"}
icon = str(app / "Contents" / "Resources" / "AppIcon.icns")
background = defines["background"]

format = "UDZO"
filesystem = "HFS+"
compression_level = 9
# Leave room for Finder's title bar and the user's optional path/status bars.
window_rect = ((180, 140), (720, 520))
default_view = "icon-view"
include_icon_view_settings = True
include_list_view_settings = False
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
icon_size = 96
text_size = 12
label_pos = "bottom"
show_icon_preview = False
show_item_info = False
# Setting Finder's hidden-extension flag adds FinderInfo to the signed bundle,
# which fails strict codesign verification. Finder already treats .app as a bundle.
hide_extensions = []
icon_locations = {"DevPocket.app": (192, 246), "Applications": (528, 246)}


def create_hook(mount_point, options):
    # HFS+ Finder info word 2 identifies the folder to open on mount. Set only
    # that word to the HFS+ root catalog ID (2), preserving the volume UUID and
    # all other Finder info. Unlike bless --openfolder, this works on arm64.
    # ATTR_VOL_INFO selects this image's volume metadata, not a file's flags.
    attributes = ctypes.create_string_buffer(struct.pack("=HHIIIII", 5, 0, 0x4000, 0x80000000, 0, 0, 0))
    library = ctypes.CDLL("/usr/lib/libSystem.B.dylib", use_errno=True)
    signature = [ctypes.c_char_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint]
    path = os.fsencode(mount_point)
    finder_info = ctypes.create_string_buffer(36)
    library.getattrlist.argtypes = signature
    library.getattrlist.restype = ctypes.c_int
    if library.getattrlist(path, attributes, finder_info, 36, 0):
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), mount_point)
    if struct.unpack_from("=I", finder_info.raw)[0] != 36:
        raise RuntimeError("Unexpected HFS+ volume Finder info size")
    updated = bytearray(finder_info.raw[4:36])
    struct.pack_into(">I", updated, 8, 2)
    payload = ctypes.create_string_buffer(bytes(updated), 32)
    library.setattrlist.argtypes = signature
    library.setattrlist.restype = ctypes.c_int
    if library.setattrlist(path, attributes, payload, 32, 0):
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), mount_point)
