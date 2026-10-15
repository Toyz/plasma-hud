import QtQuick

// Area names for workspaces, in the spirit of The World's three-keyword gates:
// a server glyph plus three words, picked deterministically from the desktop id
// (and a salt, so "reroll" gives a workspace a fresh name).
QtObject {
    readonly property string glyphs: "ΔΘΛΣΩΦΨΞΠΓ"

    readonly property var first: [
        "Hidden", "Silent", "Bursting", "Lonely", "Ancient", "Shining", "Frozen", "Endless",
        "Twilight", "Fallen", "Sleeping", "Crimson", "Distant", "Whispering", "Broken", "Gilded",
        "Drowned", "Hollow", "Radiant", "Forgotten", "Wandering", "Sunken", "Veiled", "Burning"
    ]
    readonly property var second: [
        "Forbidden", "Plentiful", "Pulsing", "Eternal", "Sacred", "Cursed", "Bitter", "Rusted",
        "Hymning", "Glass", "Iron", "Mirrored", "Starless", "Quiet", "Ruined", "Blooming",
        "Thundering", "Unseen", "Merciful", "Restless", "Fleeting", "Lost", "Pale", "Distorted"
    ]
    readonly property var third: [
        "Holy Ground", "Lake", "Sea", "Fortress", "Cathedral", "Archive", "Garden", "Labyrinth",
        "Spire", "Plateau", "Abyss", "Tower", "Ruins", "Shrine", "Gate", "Canyon",
        "Field", "Citadel", "Grotto", "Harbor", "Sanctum", "Wasteland", "Observatory", "Mire"
    ]

    function hash(s) {
        let h = 2166136261;
        for (let i = 0; i < s.length; i++) {
            h ^= s.charCodeAt(i);
            h = Math.imul(h, 16777619) >>> 0;
        }
        return h >>> 0;
    }

    function glyph(index) { return glyphs.charAt(index % glyphs.length); }

    function words(id, salt) {
        const h = hash(String(id) + "#" + (salt || 0));
        return first[h % first.length] + " " + second[(h >>> 8) % second.length] + " " + third[(h >>> 16) % third.length];
    }

    function name(index, id, salt) { return glyph(index) + " " + words(id, salt); }

    // KWin's default names ("Desktop 2") get replaced; anything the user typed is kept.
    function isGeneric(n) { return /^(Desktop|Workspace)\s*\d+$/i.test(String(n || "").trim()); }
}
