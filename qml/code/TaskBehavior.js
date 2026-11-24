// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

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

// Window selection is a discrete action, not distance-based scrolling. Some
// input paths provide both deltas; neither should impose a multi-event threshold.
function wheelCycle(angle, pixels) {
    const amount = angle || pixels;
    return amount === 0 ? 0 : (amount > 0 ? -1 : 1);
}
