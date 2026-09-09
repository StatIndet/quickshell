/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/.
*
* Adapted from Zen Browser, commit 412731f37e567223097101d9fae9f9d364708b6b.
* See licenses/README.md for source mapping and modification details.
* Alternatively, the contents of this file may be used under the terms
* of the GNU General Public License Version 3 or (at your option) later.
* This file is free software: you may copy, redistribute and/or modify it
* under those terms as published by the Free Software Foundation.
* This file is distributed WITHOUT ANY WARRANTY; without even the implied
* warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
* You should have received a copy of the GNU General Public License along
* with this program. If not, see https://www.gnu.org/licenses/.
*/
import QtQuick
import Clavis.Runtime
import qs.Services
import "../../Common/functions/ZenPalette.js" as Zen

ShaderEffect {
    id: root
    required property var paletteState
    readonly property var safePalette: paletteState || Zen.initial()
    readonly property var rgb: Zen.colors(safePalette)
    property vector2d resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
    property color firstColor: Zen.hex(rgb[0])
    property color secondColor: Zen.hex(rgb[Math.min(1, rgb.length - 1)])
    property color thirdColor: Zen.hex(rgb[Math.min(2, rgb.length - 1)])
    // Zen derives its composition base from the window scheme, not palette data.
    property color baseColor: UiPreferences.darkMode ? "#17171a" : "#f0f0f4"
    property real colorCount: safePalette.count
    property real paletteOpacity: safePalette.opacity
    property real grain: safePalette.grain
    fragmentShader: "qrc:/clavis/shaders/zen-palette.frag.qsb"
}
