// SPDX-License-Identifier: GPL-2.0-or-later
// Executed by Plasma's workspace scripting API. Inputs are JSON literals
// supplied by the dock. Only instances of our relay are added or removed.
(function(outputs, providers) {
    var relay = "org.sarbalabs.nextdock.launcherrelay";
    var wanted = outputs.map(name => screenForConnector(name)).filter(id => id >= 0);
    var current = desktopsForActivity(currentActivity());
    if (outputs.length && (!current.length || wanted.length !== outputs.length)) print("pending");
    var occupied = panels().concat(current).filter(c =>
        providers.indexOf(c.type) >= 0 || c.widgets().some(w => providers.indexOf(w.type) >= 0)
    ).map(c => c.screen);
    desktops().forEach(d => {
        var keep = wanted.indexOf(d.screen) >= 0 && occupied.indexOf(d.screen) < 0
            && current.some(c => c.id === d.id);
        d.widgets().filter(w => w.type === relay).forEach(w => {
            if (keep) keep = false;
            else w.remove();
        });
        if (keep) d.addWidget(relay);
    });
})(OUTPUT_NAMES, LAUNCHER_PROVIDERS)
