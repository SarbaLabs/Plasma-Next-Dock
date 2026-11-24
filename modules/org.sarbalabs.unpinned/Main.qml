// SPDX-License-Identifier: GPL-2.0-or-later
import org.sarbalabs.nextdock.modules 1.0

TaskModule {
    // A task reference keeps native window actions and group children attached
    // to the same KDE model index when this list is sorted or a window closes.
    entries: {
        const list = candidates.slice();
        const order = configuration.sort || "name";
        list.sort((a, b) => {
            if (order === "recent" && a.lastActivated !== b.lastActivated)
                return b.lastActivated - a.lastActivated;
            if (order === "desktop" && a.desktop !== b.desktop)
                return a.desktop - b.desktop;
            if (order === "activity") {
                const difference = a.activity.localeCompare(b.activity);
                if (difference) return difference;
            }
            return a.name.localeCompare(b.name) || a.title.localeCompare(b.title);
        });
        return list.map(task => ({id: task.id, taskRef: task.id, name: task.name, icon: task.icon}));
    }
}
