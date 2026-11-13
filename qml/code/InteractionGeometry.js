// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// Coordinates are local to the dock root, never to a rotated task or screen.
function menuPosition(edge, bar, click, size, gap) {
    if (edge === 2) return {x: bar.x + bar.width + gap, y: click.y - size.height / 2};
    if (edge === 3) return {x: bar.x - size.width - gap, y: click.y - size.height / 2};
    if (edge === 1) return {x: click.x - size.width / 2, y: bar.y + bar.height + gap};
    return {x: click.x - size.width / 2, y: bar.y - size.height - gap};
}
