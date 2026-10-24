# Hints kitten processor: mark absolute (or ~) paths that exist, with an
# optional :line suffix, and open the selected one in an nvim overlay.
import os
import re

PATTERN = re.compile(r'(?<![\w.@+~/:-])(?P<path>~?/[\w.@+/-]*[\w@+-])(?::(?P<line>\d+))?')


def mark(text, args, Mark, extra_cli_args, *a):
    idx = 0
    for m in PATTERN.finditer(text):
        path = os.path.expanduser(m['path'])
        if not os.path.exists(path):
            continue
        start, end = m.span()
        yield Mark(idx, start, end, text[start:end], {'path': path, 'line': m['line']})
        idx += 1


def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    for m, g in zip(data['match'], data['groupdicts']):
        if m:
            cmd = ['launch', '--type=overlay', 'nvim']
            if g['line']:
                cmd.append(f'+{g["line"]}')
            cmd.append(g['path'])
            boss.call_remote_control(boss.window_id_map.get(target_window_id), tuple(cmd))
            return
