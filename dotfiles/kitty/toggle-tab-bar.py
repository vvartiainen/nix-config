"""Toggle the tab bar in the current Kitty OS window."""

from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    manager = boss.os_window_map.get(window.os_window_id)
    if manager is None:
        return
    manager.tab_bar_hidden = not manager.tab_bar_hidden
    manager.mark_tab_bar_dirty()
    manager.resize()
