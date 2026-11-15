// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// Indices remain native model rows; reversal changes only their presentation.
function reversed(direction, vertical, rtl) {
    return direction === 2 || (direction !== 1 && !vertical && rtl);
}
function boundary(pinned) {
    if (pinned.length < 2 || !pinned[0]) return -1;
    let index = 0;
    while (index < pinned.length && pinned[index]) ++index;
    // Never draw an outside or misleading separator for an interleaved model.
    for (let i = index; i < pinned.length; ++i) if (pinned[i]) return -1;
    return index === pinned.length ? -1 : index;
}
function cycle(model, row, direction, skipMinimized, roles) {
    const parent = model.makeModelIndex(row);
    if (!parent.valid) return false;
    const count = model.rowCount(parent);
    if (!count) return false;
    const candidates = [];
    let active = -1;
    for (let i = 0; i < count; ++i) {
        const child = model.makeModelIndex(row, i);
        if (model.data(child, roles.active)) active = i;
        if (!skipMinimized || !model.data(child, roles.minimized)) candidates.push(i);
    }
    if (!candidates.length) return false;
    let selected = direction > 0 ? candidates[0] : candidates[candidates.length - 1];
    const position = candidates.indexOf(active);
    if (position >= 0) selected = candidates[(position + direction + candidates.length) % candidates.length];
    model.requestActivate(model.makeModelIndex(row, selected));
    return true;
}
function primary(model, row, minimizeActive, roles) {
    const index = model.makeModelIndex(row);
    if (!index.valid) return;
    if (minimizeActive && model.data(index, roles.active) && model.data(index, roles.minimizable))
        model.requestToggleMinimized(index);
    else model.requestActivate(index);
}
function middle(model, row, action, roles) {
    const index = model.makeModelIndex(row);
    if (!index.valid) return;
    if (action === 1) model.requestNewInstance(index);
    else if (action === 2 && model.data(index, roles.closable)) model.requestClose(index);
    else if (action === 3 && model.data(index, roles.minimizable)) model.requestToggleMinimized(index);
}

// Discrete wheel events select one window regardless of configured wheel speed.
// Only continuous pixel scrolling needs accumulation to avoid rapid cycling.
function wheelCycle(angle, pixels, remainder) {
    if (!pixels) return {direction: angle === 0 ? 0 : (angle > 0 ? -1 : 1), remainder: 0};
    const total = (remainder * pixels < 0 ? 0 : remainder) + pixels;
    return Math.abs(total) >= 40
        ? {direction: total > 0 ? -1 : 1, remainder: total % 40}
        : {direction: 0, remainder: total};
}
