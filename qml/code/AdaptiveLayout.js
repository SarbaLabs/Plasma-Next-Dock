// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// Bound the sum of squared falloff weights, including a fractional pointer.
function zoomBudget(radius) {
    if (radius === 0) return 1;
    let weight = 1;
    for (let i = 1; i <= radius; ++i) weight += 2 * Math.pow(1 - i / (radius + 0.4), 2);
    return Math.max(2, weight);
}
function hoverWeight(distance, radius) {
    const factor = Math.max(0, 1 - Math.abs(distance) / (radius === 0 ? 0.5 : radius + 0.4));
    return factor * factor;
}
// Reserve the same zoom budget in the canvas and in animated delegates.
// The renderer caps animation tails to this same fixed budget.
// Sizing depends only on count/settings/output, never on animated row geometry.
function metrics(count, preferred, zoom, available, crossAvailable, gap, iconSpacing = 10, endPadding = 12, crossPadding = 10, blastRadius = 2, hoverLift = 0, separatorSpan = 0, bounceHeight = 0) {
    available = Math.max(1, available);
    crossAvailable = Math.max(1, crossAvailable);
    gap = Math.min(Math.max(0, gap), Math.max(0, crossAvailable - 1));
    const resting = count * preferred + Math.max(0, count - 1) * iconSpacing + 2 * endPadding + separatorSpan;
    const zoomReserve = Math.min(count, zoomBudget(blastRadius)) * preferred * (zoom - 1);
    const natural = Math.max(200, resting + zoomReserve);
    const crossScale = Math.min(1, (crossAvailable - gap) / (preferred * zoom + hoverLift + bounceHeight + 2 * crossPadding + 4));
    const minimumScale = Math.min(1, 24 / preferred, crossScale);
    const scale = Math.min(crossScale, Math.max(minimumScale, Math.min(1, available / natural)));
    return { scale: scale, base: preferred * scale, restingLength: resting * scale,
        length: Math.min(available, natural * scale),
        depth: (preferred * zoom + hoverLift + bounceHeight + 2 * crossPadding + 4) * scale + gap,
        gap: gap };
}
function scrollPosition(position, delta, content, viewport) {
    return Math.max(0, Math.min(Math.max(0, content - viewport), position + delta));
}
