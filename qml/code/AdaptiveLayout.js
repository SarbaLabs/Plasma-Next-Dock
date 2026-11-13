// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// The local squared falloff uses less than two full-icon zoom equivalents.
// The renderer caps animation tails to this same fixed budget.
// Sizing depends only on count/settings/output, never on animated row geometry.
function metrics(count, preferred, zoom, available, crossAvailable, gap) {
    available = Math.max(1, available);
    crossAvailable = Math.max(1, crossAvailable);
    gap = Math.min(Math.max(0, gap), Math.max(0, crossAvailable - 1));
    const resting = count * preferred + Math.max(0, count - 1) * 10 + 24;
    const zoomReserve = Math.min(count, 2) * preferred * (zoom - 1);
    const natural = Math.max(200, resting + zoomReserve);
    const crossScale = Math.min(1, (crossAvailable - gap) / (preferred * zoom + 24));
    const minimumScale = Math.min(1, 24 / preferred, crossScale);
    const scale = Math.min(crossScale, Math.max(minimumScale, Math.min(1, available / natural)));
    return { scale: scale, base: preferred * scale,
        length: Math.min(available, natural * scale),
        depth: (preferred * zoom + 24) * scale + gap,
        gap: gap };
}
function scrollPosition(position, delta, content, viewport) {
    return Math.max(0, Math.min(Math.max(0, content - viewport), position + delta));
}
