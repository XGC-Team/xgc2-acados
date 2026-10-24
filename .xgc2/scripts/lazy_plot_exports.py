#!/usr/bin/env python3
"""Keep upstream acados code generation independent of optional plotting.

Applied to the staged SDK by both CI packaging and source builds. Numerical
and code-generation modules are unchanged; plotting exports forward lazily.
"""
import ast
from pathlib import Path
import sys


def make_plot_exports_lazy(path):
    path = Path(path)
    text = path.read_text()
    lines = text.splitlines(keepends=True)
    for item in ast.parse(text).body:
        if not isinstance(item, ast.ImportFrom) or item.level != 1 or item.module != 'plot_utils':
            continue
        # Upstream uses a single-line import here (Python 3.6 remains supported).
        replacement = ['# Plotting is optional; importing the solver must stay headless.\n']
        for alias in item.names:
            name = alias.asname or alias.name
            replacement.extend([
                'def '+name+'(*args, **kwargs):\n',
                '    from .plot_utils import '+alias.name+' as implementation\n',
                '    return implementation(*args, **kwargs)\n\n',
            ])
        lines[item.lineno-1] = ''.join(replacement)
        path.write_text(''.join(lines))
        return


if __name__ == '__main__':
    make_plot_exports_lazy(sys.argv[1])
