"""Save this Kitty instance and reopen it after its process exits (Kitty 0.50+)."""

import os
from pathlib import Path
import subprocess

from kittens.tui.handler import result_handler
from kitty.constants import kitty_exe
from kitty.fast_data_types import (
    IMPERATIVE_CLOSE_REQUESTED,
    current_application_quit_request,
    get_options,
)
from kitty.session import default_save_as_session_opts


def main(args):
    pass


def restart(confirmed, boss):
    if not confirmed:
        return
    waiter = None
    try:
        helper = Path(__file__).with_name("restart.sh")
        if not helper.is_file():
            raise FileNotFoundError(f"Restart helper is missing: {helper}")
        state = Path.home() / ".local/state/kitty"
        state.mkdir(mode=0o700, parents=True, exist_ok=True)
        snapshot = state / f"restart-{os.getpid()}.kitty-session"
        opts = default_save_as_session_opts()
        opts.os_window_geometry = True
        # Fresh shells, rather than replaying whatever happened to be running.
        session = "\n".join(boss.serialize_state_as_session(str(snapshot), opts))
        with open(snapshot, "w", opener=lambda path, flags: os.open(path, flags, 0o600)) as f:
            f.write(session)

        command = [
            "/bin/sh", str(helper),
            str(os.getpid()), kitty_exe(), str(snapshot),
        ]
        config = get_options()
        for path in config.config_paths:
            command.extend(("--config", path))
        for override in config.config_overrides:
            command.extend(("--override", override))
        with (state / "restart.log").open("w") as log:
            waiter = subprocess.Popen(
                command, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                start_new_session=True,
            )
        # The confirmation above replaces the normal quit dialog. Keep quit
        # watchers and Kitty's ordinary shutdown path, including their veto.
        boss.handle_quit_confirmation(True)
        if current_application_quit_request() != IMPERATIVE_CLOSE_REQUESTED:
            waiter.terminate()
    except Exception as error:
        if waiter is not None:
            waiter.terminate()
        boss.show_error("Kitty restart failed", str(error))


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    boss.confirm(
        "Restart Kitty and restore its windows? Running programs will close; "
        "scrollback and live process state will not be restored.",
        restart, boss, window=boss.window_id_map.get(target_window_id),
        title="Restart Kitty?",
    )
