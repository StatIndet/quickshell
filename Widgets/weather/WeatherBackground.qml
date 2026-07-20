import QtQuick

Item {
    id: root

    property int weatherCode: -1
    property string iconName: "cloud"
    property bool night: false
    property real windSpeedMs: 0
    property real windGustsMs: 0
    property real scrollProgress: 0
    property bool animate: visible
    property bool fullCardParticleBounds: false
    property string weatherType: "overcast"
    property bool windy: false
    property bool componentReady: false

    property real pointerX: width * 0.5
    property real pointerY: height * 0.28
    property real parallaxX: width > 0 ? (pointerX / width - 0.5) * 18 : 0
    property real parallaxY: height > 0 ? (pointerY / height - 0.35) * 14 : 0
    property real rainBounceY: height
    property var cloudBands: []
    property var rainLayers: [[], [], []]
    property var splashes: []
    property var lightningStrikes: []
    property var meteors: []
    property real lightningCooldown: 0
    property real cloudMaskOpacity: 0.18
    property real frameBaseDt: 33 / 1000.0
    property int windLeafTargetCount: 3
    property int nextLeafId: 0
    property int snowflakeTargetCount: 24
    property var snowflakes: []

    function classifyWeatherType() {
        const name = (root.iconName || "").toLowerCase()
        if (root.weatherCode >= 95 || name.indexOf("thunder") >= 0)
            return "storm"
        if ((root.weatherCode >= 71 && root.weatherCode <= 77) || root.weatherCode === 85 || root.weatherCode === 86 || name.indexOf("snow") >= 0)
            return "snow"
        if ((root.weatherCode >= 51 && root.weatherCode <= 67) || (root.weatherCode >= 80 && root.weatherCode <= 82)
                || name.indexOf("rain") >= 0 || name.indexOf("drizzle") >= 0
                || name.indexOf("shower") >= 0 || name.indexOf("sleet") >= 0)
            return "rain"
        if (root.weatherCode === 0 || name.indexOf("clear") >= 0 || name.indexOf("sunny") >= 0 || name.indexOf("sun") >= 0)
            return "clear"
        if (root.weatherCode === 1 || root.weatherCode === 2 || name.indexOf("partly") >= 0 || name.indexOf("mostly") >= 0)
            return "partly"
        if (root.weatherCode === 45 || root.weatherCode === 48 || root.weatherCode === 3 || name.indexOf("fog") >= 0
                || name.indexOf("overcast") >= 0 || name.indexOf("cloud") >= 0)
            return "overcast"
        return "overcast"
    }

    function classifyWindy(type) {
        const sustained = isNaN(root.windSpeedMs) ? 0 : root.windSpeedMs
        const gusts = isNaN(root.windGustsMs) ? 0 : root.windGustsMs
        const strength = Math.max(sustained, gusts)
        return strength >= 8.0 && (type === "clear" || type === "partly" || type === "overcast")
    }

    function updateWeatherClassification() {
        const nextType = root.classifyWeatherType()
        const nextWindy = root.classifyWindy(nextType)
        const sceneChanged = nextType !== root.weatherType || nextWindy !== root.windy

        root.weatherType = nextType
        root.windy = nextWindy
        if (root.componentReady && sceneChanged)
            root.resetVisualScenes()
    }

    function resetVisualScenes() {
        root.initCloudBands()
        root.resetRainScene()
        root.resetLightningScene()
        root.resetMeteorScene()
        root.resetSnowScene()
        root.resetLeafScene()
    }

    function palette() {
        switch (visualWeatherType() + (night ? "_night" : "_day")) {
        case "clear_day":
            return {
                top: "#7fc5e5",
                mid: "#dde7ec",
                bottom: "#f7fbfd",
                glow: "#fff6cd",
                cloud1: "#f0efed",
                cloud2: "#e0dfdd",
                cloud3: "#cecdcb",
                particle: "#fff2c0",
                accent: "#ffd96d"
            }
        case "clear_night":
            return {
                top: "#45578f",
                mid: "#8ca0d8",
                bottom: "#c0cbef",
                glow: "#e8edff",
                cloud1: "#eef2fb",
                cloud2: "#d7dce8",
                cloud3: "#c4cad8",
                particle: "#eef2ff",
                accent: "#d9e5ff"
            }
        case "partly_day":
            return {
                top: "#7fc5e5",
                mid: "#dde7ec",
                bottom: "#f7fbfd",
                glow: "#fff6cd",
                cloud1: "#f0efed",
                cloud2: "#e0dfdd",
                cloud3: "#cecdcb",
                particle: "#fff2c0",
                accent: "#ffd96d"
            }
        case "partly_night":
            return {
                top: "#45578f",
                mid: "#8ca0d8",
                bottom: "#c0cbef",
                glow: "#e8edff",
                cloud1: "#eef2fb",
                cloud2: "#d7dce8",
                cloud3: "#c4cad8",
                particle: "#eef2ff",
                accent: "#d9e5ff"
            }
        case "overcast_day":
            return {
                top: "#9aadb9",
                mid: "#c8d2d8",
                bottom: "#eef3f5",
                glow: "#f7fafb",
                cloud1: "#ecebea",
                cloud2: "#dddcd9",
                cloud3: "#cbc9c6",
                particle: "#eaf0f5",
                accent: "#dce7ef"
            }
        case "overcast_night":
            return {
                top: "#53657a",
                mid: "#8a9bad",
                bottom: "#c1ccd4",
                glow: "#e7edf1",
                cloud1: "#dde2eb",
                cloud2: "#c3c8d2",
                cloud3: "#aeb4c0",
                particle: "#dae6f4",
                accent: "#c2d2e5"
            }
        case "rain_day":
            return {
                top: "#a5b7d2",
                mid: "#ced8e4",
                bottom: "#edf2f7",
                glow: "#f6f9fd",
                cloud1: "#ecebea",
                cloud2: "#dddcd9",
                cloud3: "#cbc9c6",
                particle: "#d8ecff",
                accent: "#cce0f6"
            }
        case "rain_night":
            return {
                top: "#4a617d",
                mid: "#879cb7",
                bottom: "#bcc9d9",
                glow: "#e3ebf4",
                cloud1: "#dde2eb",
                cloud2: "#c3c8d2",
                cloud3: "#aeb4c0",
                particle: "#cee5ff",
                accent: "#aac6e7"
            }
        case "snow_day":
            return {
                top: "#a5bdd5",
                mid: "#d1dfe9",
                bottom: "#f7fbfd",
                glow: "#ffffff",
                cloud1: "#f2f2f1",
                cloud2: "#e4e3e1",
                cloud3: "#d3d2d0",
                particle: "#ffffff",
                accent: "#f5fbff"
            }
        case "snow_night":
            return {
                top: "#566d91",
                mid: "#9ab0cb",
                bottom: "#d1dce8",
                glow: "#f0f5fa",
                cloud1: "#edf1f8",
                cloud2: "#d5dae4",
                cloud3: "#c4ccd8",
                particle: "#ffffff",
                accent: "#e7f1ff"
            }
        case "storm_day":
            return {
                top: "#78879a",
                mid: "#adb8c9",
                bottom: "#dbe1ea",
                glow: "#f5f7fc",
                cloud1: "#9fa4ad",
                cloud2: "#8b8e98",
                cloud3: "#7b7988",
                particle: "#d7e8ff",
                accent: "#f0d48f"
            }
        case "storm_night":
            return {
                top: "#49516f",
                mid: "#8790b0",
                bottom: "#c0c6da",
                glow: "#e9ecf8",
                cloud1: "#8f949d",
                cloud2: "#7d8089",
                cloud3: "#6d6c79",
                particle: "#d3dfff",
                accent: "#f6dea6"
            }
        default:
            return {
                top: "#86a0b5",
                mid: "#bccad5",
                bottom: "#e4ebf1",
                glow: "#f6f9fb",
                cloud1: "#f0efed",
                cloud2: "#e0dfdd",
                cloud3: "#cecdcb",
                particle: "#eef3f8",
                accent: "#dae3ec"
            }
        }
    }

    function alphaColor(hex, alpha) {
        const value = hex.replace("#", "")
        const r = parseInt(value.slice(0, 2), 16)
        const g = parseInt(value.slice(2, 4), 16)
        const b = parseInt(value.slice(4, 6), 16)
        return "rgba(" + r + "," + g + "," + b + "," + alpha + ")"
    }

    function makeEmptyRainLayers() {
        return [[], [], []]
    }

    function resetRainScene() {
        rainLayers = makeEmptyRainLayers()
        splashes = []
        canvas.requestPaint()
    }

    function randomLightningDelay() {
        return Math.max(0.08, Math.random() * 6.0)
    }

    function resetLightningScene() {
        lightningStrikes = []
        lightningCooldown = randomLightningDelay()
        canvas.requestPaint()
    }

    function visualWeatherType() {
        if (windy && (weatherType === "clear" || weatherType === "partly" || weatherType === "overcast"))
            return "overcast"
        return weatherType
    }

    function hasMeteorScene() {
        return night && visualWeatherType() === "clear"
    }

    function meteorSlotCount() {
        return 3
    }

    function meteorRespawnDelay(firstSpawn) {
        return (firstSpawn ? 1.0 : 5.0) + Math.random() * (firstSpawn ? 6.0 : 12.0)
    }

    function meteorColors() {
        return [
            "#d2f7ff",
            "#d0e9ff",
            "#afd0ec",
            "#a4c2dc",
            "#ecead5",
            "#f0dc97"
        ]
    }

    function makeMeteorState(delaySeconds) {
        const colors = meteorColors()
        const scale = 0.45 + Math.random() * 0.55
        const size = Math.max(1, Math.min(width, height))
        const angle = (108 + Math.random() * 18) * Math.PI / 180.0
        return {
            active: false,
            delay: delaySeconds,
            progress: 0,
            startX: width * (0.22 + Math.random() * 0.96),
            startY: height * (-0.30 + Math.random() * 0.42),
            dx: Math.cos(angle),
            dy: Math.sin(angle),
            travel: size * (0.50 + Math.random() * 0.26),
            len: size * (0.24 + Math.random() * 0.14) * scale,
            strokeWidth: 1.5 + scale * 1.5,
            color: colors[Math.floor(Math.random() * colors.length)]
        }
    }

    function hasLeafScene() {
        return windy && (weatherType === "clear" || weatherType === "partly" || weatherType === "overcast")
    }

    function leafTargetCount() {
        return hasLeafScene() ? windLeafTargetCount : 0
    }

    function leafColors() {
        return ["#76993E", "#4A5E23", "#6D632F"]
    }

    function leafFlightBounds() {
        const top = 0
        const bottom = Math.max(120, leafLayer.height)
        return {
            top: top,
            bottom: bottom,
            span: Math.max(48, bottom - top)
        }
    }

    function nextLeafSpawnInterval() {
        return 260 + Math.random() * 420
    }

    // Match the reference leaf generator, but keep everything inside one clipped sidebar layer.
    function makeLeafState() {
        const colors = leafColors()
        const scale = 0.5 + Math.random() * 0.5
        const bounds = leafFlightBounds()
        const areaY = bounds.span / 2
        const startY = areaY + Math.random() * areaY
        const endY = startY - ((Math.random() * (areaY * 2)) - areaY)
        const controlY = Math.random() * endY + endY / 3
        return {
            leafId: ++nextLeafId,
            scale: scale,
            color: colors[Math.floor(Math.random() * colors.length)],
            startRotation: Math.random() * 180,
            endRotation: Math.random() * 360,
            x0: -100,
            y0: startY,
            x1: leafLayer.width / 2,
            y1: controlY,
            x2: leafLayer.width + 50,
            y2: endY
        }
    }

    function spawnLeaf() {
        if (!hasLeafScene() || leafModel.count >= leafTargetCount())
            return
        if (leafLayer.width <= 0 || leafLayer.height <= 0)
            return

        leafModel.append(makeLeafState())
    }

    function scheduleLeafSpawn(delayMs) {
        if (!hasLeafScene() || !animate || leafModel.count >= leafTargetCount()) {
            leafSpawnTimer.stop()
            return
        }

        leafSpawnTimer.interval = delayMs === undefined ? nextLeafSpawnInterval() : delayMs
        leafSpawnTimer.restart()
    }

    function ensureLeafPopulation() {
        if (!hasLeafScene()) {
            leafSpawnTimer.stop()
            return
        }

        if (leafModel.count < leafTargetCount()) {
            spawnLeaf()
            if (leafModel.count < leafTargetCount())
                scheduleLeafSpawn()
        } else {
            leafSpawnTimer.stop()
        }
    }

    function removeLeaf(leafId) {
        for (let i = 0; i < leafModel.count; ++i) {
            if (leafModel.get(i).leafId === leafId) {
                leafModel.remove(i)
                break
            }
        }
        if (hasLeafScene() && animate)
            scheduleLeafSpawn()
    }

    function resetLeafScene() {
        leafSpawnTimer.stop()
        leafModel.clear()
        if (hasLeafScene() && animate)
            scheduleLeafSpawn(0)
    }

    function hasSnowScene() {
        return weatherType === "snow"
    }

    function activeSnowflakeTargetCount() {
        return hasSnowScene() ? snowflakeTargetCount : 0
    }

    function snowFloorY(radius) {
        const margin = radius === undefined ? 0 : radius
        if (fullCardParticleBounds)
            return height + margin * 2
        return Math.max(margin, Math.min(height, rainBounceY - margin))
    }

    function configureSnowflake(flake, ageOverride) {
        const scale = 0.5 + Math.random() * 0.5
        const fallDuration = 3.0 + Math.random() * 5.0
        const radiusBase = 5 * scale
        flake.age = ageOverride === undefined ? 0 : ageOverride
        flake.x = 20 + Math.random() * Math.max(0, width - 40)
        flake.y = -10
        flake.endY = snowFloorY(radiusBase)
        flake.swayTarget = (Math.random() * 150) - 75
        flake.swayFactor = Math.PI / 3.0
        flake.fallDuration = fallDuration
        flake.fallInverse = 1.0 / fallDuration
        flake.radiusBase = radiusBase
        flake.alphaBase = 0.34 + scale * 0.42
    }

    function makeSnowflake(ageOverride) {
        const flake = {}
        configureSnowflake(flake, ageOverride)
        return flake
    }

    function resetSnowScene() {
        snowflakes = []
        if (!hasSnowScene() || width <= 40 || height <= 0)
            return

        const next = []
        const target = activeSnowflakeTargetCount()
        for (let i = 0; i < target; ++i) {
            const flake = makeSnowflake()
            flake.age = Math.random() * flake.fallDuration
            next.push(flake)
        }
        snowflakes = next
    }

    function updateSnow(dt) {
        if (!hasSnowScene()) {
            if (snowflakes.length > 0)
                snowflakes = []
            return
        }

        const target = activeSnowflakeTargetCount()
        for (let i = 0; i < snowflakes.length; ++i) {
            const flake = snowflakes[i]
            flake.age += dt
            if (flake.age >= flake.fallDuration)
                configureSnowflake(flake, 0)
        }

        while (snowflakes.length < target)
            snowflakes.push(makeSnowflake())
        while (snowflakes.length > target)
            snowflakes.pop()
    }

    function resetMeteorScene() {
        meteors = []
        if (hasMeteorScene()) {
            const slots = []
            const count = meteorSlotCount()
            for (let i = 0; i < count; ++i)
                slots.push(makeMeteorState(meteorRespawnDelay(true)))
            meteors = slots
        }
        canvas.requestPaint()
    }

    function updateMeteors(dt) {
        if (!hasMeteorScene()) {
            if (meteors.length > 0)
                meteors = []
            return
        }

        let next = meteors.slice(0, meteorSlotCount())
        while (next.length < meteorSlotCount())
            next.push(makeMeteorState(meteorRespawnDelay(true)))

        for (let i = 0; i < next.length; ++i) {
            const meteor = next[i]
            if (!meteor.active) {
                meteor.delay -= dt
                if (meteor.delay <= 0) {
                    meteor.active = true
                    meteor.progress = 0
                }
                continue
            }

            meteor.progress += dt * meteor.travel * 1.85
            if (meteor.progress >= meteor.travel) {
                next[i] = makeMeteorState(meteorRespawnDelay(false))
            }
        }

        meteors = next
    }

    function isRainScene() {
        return weatherType === "rain" || weatherType === "storm"
    }

    function cloudBandCount() {
        const type = visualWeatherType()
        if (type === "clear")
            return 0
        if (type === "partly")
            return 2
        return 3
    }

    function hasCloudBands() {
        return cloudBandCount() > 0
    }

    function rainStrokeColor() {
        return weatherType === "storm" ? "#d7deec" : "#0000ff"
    }

    function rainTargetCount() {
        return weatherType === "storm" ? 60 : 20
    }

    function cloudSpeedFactor(index) {
        const factors = [1.0, 0.72, 0.48]
        return factors[Math.max(0, Math.min(index, factors.length - 1))]
    }

    // Match the reference card: each strike is a temporary jagged polyline
    // that spans the card height and quickly fades out.
    function makeLightningStrike() {
        if (width <= 0 || height <= 0)
            return

        const steps = 20
        const horizontalMargin = Math.min(width * 0.25, Math.max(24, width * 0.10))
        const horizontalJitter = Math.max(20, width * 0.07)
        const pathX = horizontalMargin + Math.random() * Math.max(1, width - horizontalMargin * 2)
        const points = [{ x: pathX, y: 0 }]

        for (let i = 0; i < steps; ++i) {
            const x = pathX + (Math.random() * horizontalJitter - horizontalJitter * 0.5)
            const y = (height / steps) * (i + 1)
            points.push({ x: x, y: y })
        }

        lightningStrikes = lightningStrikes.concat([{
            points: points,
            age: 0,
            duration: 1.0,
            strokeWidth: 2.8 + Math.random() * 1.2
        }])
    }

    function updateLightning(dt) {
        if (weatherType !== "storm") {
            if (lightningStrikes.length > 0)
                lightningStrikes = []
            return
        }

        for (let i = lightningStrikes.length - 1; i >= 0; --i) {
            const strike = lightningStrikes[i]
            strike.age += dt
            if (strike.age >= strike.duration)
                lightningStrikes.splice(i, 1)
        }

        lightningCooldown -= dt
        while (lightningCooldown <= 0) {
            makeLightningStrike()
            lightningCooldown += randomLightningDelay()
        }
    }

    function cloudProfile(index) {
        const wide = Math.max(width, 1)
        const configs = [
            {
                height: wide * 0.255,
                archBase: wide * 0.124,
                archVariance: wide * 0.124,
                speed: cloudSpeedFactor(0)
            },
            {
                height: wide * 0.335,
                archBase: wide * 0.124,
                archVariance: wide * 0.124,
                speed: cloudSpeedFactor(1)
            },
            {
                height: wide * 0.405,
                archBase: wide * 0.124,
                archVariance: wide * 0.124,
                speed: cloudSpeedFactor(2)
            }
        ]
        const config = configs[Math.max(0, Math.min(index, configs.length - 1))]
        return {
            y: 0,
            h: config.height,
            arch: config.height + config.archBase + Math.random() * config.archVariance,
            speed: config.speed
        }
    }

    function cloudSourceIndex(slotIndex) {
        return visualWeatherType() === "clear" ? slotIndex + 1 : slotIndex
    }

    function initCloudBands() {
        const bands = []
        const count = cloudBandCount()
        for (let i = 0; i < count; ++i) {
            const sourceIndex = cloudSourceIndex(i)
            const profile = cloudProfile(sourceIndex)
            bands.push({
                offset: Math.random() * Math.max(width, 1),
                height: profile.h,
                arch: profile.arch,
                speed: profile.speed,
                toneIndex: sourceIndex
            })
        }
        cloudBands = bands
        canvas.requestPaint()
    }

    function driftBaseSpeed() {
        if (!hasCloudBands())
            return 0
        return windy ? 3.05 : 1.05
    }

    function makeRainDrop() {
        const lineWidth = Math.random() * 3
        const lineLength = weatherType === "storm" ? 35 : 14
        const layerIndex = Math.max(0, Math.min(2, 2 - Math.floor(lineWidth)))
        rainLayers[layerIndex].push({
            x: 20 + Math.random() * Math.max(1, width - 40),
            width: lineWidth,
            len: lineLength,
            age: 0,
            delay: Math.random(),
            duration: 1
        })
    }

    function makeSplash(x, stroke) {
        const splashLength = weatherType === "storm" ? 30 : 20
        const splashBounce = weatherType === "storm" ? 120 : 100
        const splashDistance = 80
        const randomX = (Math.random() * splashDistance) - (splashDistance / 2)
        const curve = makeQuadraticSamples(0, 0,
                                           randomX, -(Math.random() * splashBounce),
                                           randomX * 2, splashDistance)
        splashes.push({
            x: x,
            y: Math.max(0, Math.min(height, rainBounceY)),
            segmentLength: splashLength,
            duration: weatherType === "storm" ? 0.7 : 0.5,
            age: 0,
            color: stroke,
            samples: curve.points,
            totalLength: curve.totalLength
        })
    }

    function updateRain(dt) {
        for (let layerIndex = 0; layerIndex < rainLayers.length; ++layerIndex) {
            const layer = rainLayers[layerIndex]
            for (let i = layer.length - 1; i >= 0; --i) {
                const drop = layer[i]
                drop.age += dt
                if (drop.age >= drop.delay + drop.duration) {
                    if (drop.width > 2)
                        makeSplash(drop.x, rainStrokeColor())
                    layer.splice(i, 1)
                }
            }
        }

        let dropCount = 0
        for (let layerIndex = 0; layerIndex < rainLayers.length; ++layerIndex)
            dropCount += rainLayers[layerIndex].length

        while (dropCount < rainTargetCount()) {
            makeRainDrop()
            ++dropCount
        }
    }

    function updateSplashes(dt) {
        for (let i = splashes.length - 1; i >= 0; --i) {
            const splash = splashes[i]
            splash.age += dt
            if (splash.age >= splash.duration)
                splashes.splice(i, 1)
        }
    }

    function quadraticPoint(startX, startY, controlX, controlY, endX, endY, t) {
        const inverse = 1 - t
        return {
            x: inverse * inverse * startX + 2 * inverse * t * controlX + t * t * endX,
            y: inverse * inverse * startY + 2 * inverse * t * controlY + t * t * endY
        }
    }

    function makeQuadraticSamples(startX, startY, controlX, controlY, endX, endY) {
        const steps = 20
        const points = [{ x: startX, y: startY, len: 0 }]
        let previous = { x: startX, y: startY }
        let totalLength = 0
        for (let i = 1; i <= steps; ++i) {
            const point = quadraticPoint(startX, startY, controlX, controlY, endX, endY, i / steps)
            const dx = point.x - previous.x
            const dy = point.y - previous.y
            totalLength += Math.sqrt(dx * dx + dy * dy)
            points.push({
                x: point.x,
                y: point.y,
                len: totalLength
            })
            previous = point
        }
        return {
            points: points,
            totalLength: totalLength
        }
    }

    function sampleAtLength(samples, targetLength) {
        if (samples.length === 0)
            return { x: 0, y: 0 }
        if (targetLength <= 0)
            return { x: samples[0].x, y: samples[0].y }

        const endSample = samples[samples.length - 1]
        if (targetLength >= endSample.len)
            return { x: endSample.x, y: endSample.y }

        for (let i = 1; i < samples.length; ++i) {
            const current = samples[i]
            if (targetLength <= current.len) {
                const previous = samples[i - 1]
                const span = Math.max(0.0001, current.len - previous.len)
                const ratio = (targetLength - previous.len) / span
                return {
                    x: previous.x + (current.x - previous.x) * ratio,
                    y: previous.y + (current.y - previous.y) * ratio
                }
            }
        }

        return { x: endSample.x, y: endSample.y }
    }

    function rainDropTop(drop, bounceY) {
        if (drop.age <= drop.delay)
            return -drop.len
        const progress = Math.min(1, (drop.age - drop.delay) / drop.duration)
        return -drop.len + (bounceY + drop.len) * progress * progress
    }

    function drawCloudBandShape(ctx, offset, bandHeight, archHeight) {
        const w = Math.max(width, 1)
        const startX = -w + offset
        ctx.beginPath()
        ctx.moveTo(startX, 0)
        ctx.lineTo(startX + w * 2.0, 0)
        ctx.quadraticCurveTo(startX + w * 3.0, bandHeight * 0.5, startX + w * 2.0, bandHeight)
        ctx.quadraticCurveTo(startX + w * 1.5, archHeight, startX + w, bandHeight)
        ctx.quadraticCurveTo(startX + w * 0.5, archHeight, startX, bandHeight)
        ctx.quadraticCurveTo(startX - w, bandHeight * 0.5, startX - w, 0)
        ctx.closePath()
    }

    function drawCloudBand(ctx, offset, bandHeight, archHeight, fillColor) {
        ctx.fillStyle = fillColor
        drawCloudBandShape(ctx, offset, bandHeight, archHeight)
        ctx.fill()

        ctx.fillStyle = alphaColor("#6a7078", cloudMaskOpacity)
        drawCloudBandShape(ctx, offset, bandHeight, archHeight)
        ctx.fill()
    }

    function cloudFillColor(index, palette) {
        if (index === 0) return palette.cloud1
        if (index === 1) return palette.cloud2
        return palette.cloud3
    }

    function drawMeteors(ctx, fade) {
        ctx.lineCap = "round"
        for (let i = 0; i < meteors.length; ++i) {
            const meteor = meteors[i]
            if (!meteor.active)
                continue

            const progress = Math.max(0, Math.min(1, meteor.progress / meteor.travel))
            const opacity = Math.sin(progress * Math.PI) * 0.92 * fade
            if (opacity <= 0.02)
                continue

            const headX = meteor.startX + meteor.dx * meteor.progress
            const headY = meteor.startY + meteor.dy * meteor.progress
            const tailX = headX - meteor.dx * meteor.len
            const tailY = headY - meteor.dy * meteor.len

            ctx.strokeStyle = alphaColor(meteor.color, opacity * 0.16)
            ctx.lineWidth = meteor.strokeWidth * 2.4
            ctx.beginPath()
            ctx.moveTo(tailX, tailY)
            ctx.lineTo(headX, headY)
            ctx.stroke()

            const segments = 7
            for (let segmentIndex = 0; segmentIndex < segments; ++segmentIndex) {
                const startRatio = segmentIndex / segments
                const endRatio = (segmentIndex + 1) / segments
                const segmentStartX = tailX + (headX - tailX) * startRatio
                const segmentStartY = tailY + (headY - tailY) * startRatio
                const segmentEndX = tailX + (headX - tailX) * endRatio
                const segmentEndY = tailY + (headY - tailY) * endRatio
                const segmentAlpha = opacity * (0.10 + 0.90 * Math.pow(endRatio, 1.7))
                const segmentWidth = meteor.strokeWidth * (0.30 + 0.70 * endRatio)
                ctx.strokeStyle = alphaColor(meteor.color, segmentAlpha)
                ctx.lineWidth = segmentWidth
                ctx.beginPath()
                ctx.moveTo(segmentStartX, segmentStartY)
                ctx.lineTo(segmentEndX, segmentEndY)
                ctx.stroke()
            }

            ctx.fillStyle = alphaColor("#ffffff", Math.min(1, opacity * 0.95))
            ctx.beginPath()
            ctx.arc(headX, headY, meteor.strokeWidth * 0.45, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    function drawStars(ctx, fade, palette) {
        for (let i = 0; i < 34; ++i) {
            const twinkle = 0.4 + 0.6 * (0.5 + 0.5 * Math.sin(canvas.phase * (0.5 + (i % 4) * 0.09) + i * 1.3))
            const x = (i * 43 + (i % 3) * 29) % Math.max(width, 1)
            const y = (i * 27 + (i % 6) * 15) % Math.max(80, height * 0.48)
            const r = 0.9 + (i % 3) * 0.35
            ctx.fillStyle = alphaColor(palette.particle, twinkle * 0.56 * fade)
            ctx.beginPath()
            ctx.arc(x, y, r, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    function drawRainLayer(ctx, fade, layerIndex) {
        const layer = rainLayers[layerIndex]
        const bounceY = Math.max(0, Math.min(height, rainBounceY))
        ctx.lineCap = "butt"
        ctx.strokeStyle = alphaColor(rainStrokeColor(), fade)
        for (let i = 0; i < layer.length; ++i) {
            const drop = layer[i]
            if (drop.age < drop.delay)
                continue
            const dropTop = rainDropTop(drop, bounceY)
            ctx.lineWidth = drop.width
            ctx.beginPath()
            ctx.moveTo(drop.x, dropTop)
            ctx.lineTo(drop.x, dropTop + drop.len)
            ctx.stroke()
        }
    }

    function drawSplashes(ctx, fade) {
        ctx.lineCap = "butt"
        for (let i = 0; i < splashes.length; ++i) {
            const splash = splashes[i]
            const progress = splash.age / splash.duration
            const strokeWidth = 2 * (1 - progress)
            const startLength = progress * splash.totalLength
            const endLength = Math.min(splash.totalLength, startLength + splash.segmentLength)
            if (strokeWidth <= 0.02 || endLength <= startLength)
                continue

            // Approximate Snap's animated dash by drawing only the visible curve segment.
            const startPoint = sampleAtLength(splash.samples, startLength)
            const endPoint = sampleAtLength(splash.samples, endLength)
            ctx.strokeStyle = alphaColor(splash.color, fade)
            ctx.lineWidth = strokeWidth
            ctx.beginPath()
            ctx.moveTo(splash.x + startPoint.x, splash.y + startPoint.y)
            for (let sampleIndex = 1; sampleIndex < splash.samples.length - 1; ++sampleIndex) {
                const sample = splash.samples[sampleIndex]
                if (sample.len <= startLength || sample.len >= endLength)
                    continue
                ctx.lineTo(splash.x + sample.x, splash.y + sample.y)
            }
            ctx.lineTo(splash.x + endPoint.x, splash.y + endPoint.y)
            ctx.stroke()
        }
    }

    function drawSnow(ctx, fade, palette) {
        if (fade <= 0 || snowflakes.length === 0)
            return

        ctx.fillStyle = palette.particle
        for (let i = 0; i < snowflakes.length; ++i) {
            const flake = snowflakes[i]
            const fallProgress = Math.max(0, Math.min(1, flake.age * flake.fallInverse))
            const growProgress = Math.max(0, Math.min(1, flake.age))
            const growEase = 0.5 - 0.5 * Math.cos(growProgress * Math.PI)
            const sway = flake.swayTarget * 0.5 * (1 - Math.cos(flake.age * flake.swayFactor))
            const x = flake.x + sway
            const y = flake.y + (flake.endY - flake.y) * fallProgress
            const radius = flake.radiusBase * growEase
            if (radius <= 0.05)
                continue

            ctx.globalAlpha = flake.alphaBase * fade
            ctx.beginPath()
            ctx.arc(x, y, radius, 0, Math.PI * 2)
            ctx.fill()
        }
        ctx.globalAlpha = 1
    }

    function drawLightning(ctx, fade) {
        let flashOpacity = 0
        for (let i = 0; i < lightningStrikes.length; ++i) {
            const strike = lightningStrikes[i]
            const progress = Math.max(0, Math.min(1, strike.age / strike.duration))
            flashOpacity = Math.max(flashOpacity, Math.pow(1 - progress, 10) * 0.22 * fade)
        }

        if (flashOpacity > 0.01) {
            ctx.fillStyle = "rgba(255,255,255," + flashOpacity + ")"
            ctx.fillRect(0, 0, width, height)
        }

        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        for (let i = 0; i < lightningStrikes.length; ++i) {
            const strike = lightningStrikes[i]
            const progress = Math.max(0, Math.min(1, strike.age / strike.duration))
            const opacity = Math.pow(1 - progress, 4) * fade
            if (opacity <= 0.01 || strike.points.length === 0)
                continue

            ctx.strokeStyle = "rgba(255,255,255," + opacity + ")"
            ctx.lineWidth = strike.strokeWidth
            ctx.beginPath()
            ctx.moveTo(strike.points[0].x, strike.points[0].y)
            for (let pointIndex = 1; pointIndex < strike.points.length; ++pointIndex) {
                const point = strike.points[pointIndex]
                ctx.lineTo(point.x, point.y)
            }
            ctx.stroke()
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0.46, 0.96 - root.scrollProgress * 0.28)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.palette().top }
            GradientStop { position: 0.54; color: root.palette().mid }
            GradientStop { position: 1.0; color: root.palette().bottom }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0, 0.20 - root.scrollProgress * 0.08)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.alphaColor(root.palette().glow, 0.18) }
            GradientStop { position: 0.44; color: root.alphaColor(root.palette().glow, 0.04) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    ListModel {
        id: leafModel
    }

    Timer {
        id: leafSpawnTimer
        repeat: false
        onTriggered: root.ensureLeafPopulation()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        opacity: Math.max(0, 0.92 - root.scrollProgress * 0.34)

        property real phase: 0

        onPaint: {
            const ctx = getContext("2d")
            const fade = Math.max(0, 1 - root.scrollProgress)
            const colors = root.palette()

            ctx.clearRect(0, 0, width, height)

            if (root.night)
                root.drawStars(ctx, fade, colors)

            if (root.hasMeteorScene())
                root.drawMeteors(ctx, fade)

            if (root.hasCloudBands()) {
                for (let i = root.cloudBands.length - 1; i >= 0; --i) {
                    if (root.isRainScene())
                        root.drawRainLayer(ctx, fade, i)
                    if (root.weatherType === "storm" && i === 0)
                        root.drawLightning(ctx, fade)
                    const band = root.cloudBands[i]
                    root.drawCloudBand(ctx,
                                       band.offset,
                                       band.height,
                                       band.arch,
                                       root.cloudFillColor(band.toneIndex, colors))
                }
            }

            if (root.isRainScene())
                root.drawSplashes(ctx, fade)

            if (root.hasSnowScene())
                root.drawSnow(ctx, fade, colors)
        }
    }

    Item {
        id: leafLayer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.fullCardParticleBounds
            ? parent.height
            : Math.max(150,
                       Math.min(parent.height * 0.56,
                                rainBounceY > 0 ? rainBounceY - 18 : parent.height * 0.56))
        clip: true
        opacity: Math.max(0, 0.90 - root.scrollProgress * 0.34)
        visible: root.hasLeafScene() || leafModel.count > 0

        Repeater {
            model: leafModel

            delegate: LeafItem {
                leafId: model.leafId
                leafColor: model.color
                leafScale: model.scale
                x0: model.x0
                y0: model.y0
                x1: model.x1
                y1: model.y1
                x2: model.x2
                y2: model.y2
                startRotation: model.startRotation
                endRotation: model.endRotation
                onFinished: root.removeLeaf(leafId)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0, 0.18 - root.scrollProgress * 0.08)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.62; color: "transparent" }
            GradientStop { position: 1.0; color: root.alphaColor("#0d1220", root.night ? 0.12 : 0.09) }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onPositionChanged: function(mouse) {
            root.pointerX = mouse.x
            root.pointerY = mouse.y
        }

        onExited: {
            root.pointerX = root.width * 0.5
            root.pointerY = root.height * 0.28
        }
    }

    Behavior on pointerX {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Behavior on pointerY {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        interval: 16
        running: root.animate
        repeat: true

        property double lastTickMs: 0

        onRunningChanged: {
            if (!running)
                lastTickMs = 0
        }

        onTriggered: {
            const now = Date.now()
            const dt = lastTickMs > 0 ? Math.min(0.05, (now - lastTickMs) / 1000.0) : interval / 1000.0
            const stepScale = dt / root.frameBaseDt
            lastTickMs = now
            const base = root.driftBaseSpeed()
            const nextBands = []
            for (let i = 0; i < root.cloudBands.length; ++i) {
                const band = root.cloudBands[i]
                let wrappedOffset = band.offset
                if (base > 0) {
                    const nextOffset = band.offset + base * band.speed * stepScale
                    wrappedOffset = nextOffset
                    if (wrappedOffset > root.width)
                        wrappedOffset = wrappedOffset - root.width
                }
                nextBands.push({
                    offset: wrappedOffset,
                    height: band.height,
                    arch: band.arch,
                    speed: band.speed,
                    toneIndex: band.toneIndex
                })
            }
            root.cloudBands = nextBands
            if (root.isRainScene()) {
                root.updateRain(dt)
                root.updateSplashes(dt)
            } else {
                root.rainLayers = root.makeEmptyRainLayers()
                root.splashes = []
            }
            root.updateSnow(dt)
            root.updateLightning(dt)
            root.updateMeteors(dt)
            canvas.phase += 0.04 * stepScale
            canvas.requestPaint()
        }
    }

    Component.onCompleted: {
        updateWeatherClassification()
        componentReady = true
        resetVisualScenes()
    }
    onWidthChanged: {
        initCloudBands()
        resetRainScene()
        resetLightningScene()
        resetMeteorScene()
        resetSnowScene()
        resetLeafScene()
    }
    onHeightChanged: {
        initCloudBands()
        resetRainScene()
        resetLightningScene()
        resetMeteorScene()
        resetSnowScene()
        resetLeafScene()
    }
    onWeatherCodeChanged: updateWeatherClassification()
    onIconNameChanged: updateWeatherClassification()
    onWindSpeedMsChanged: updateWeatherClassification()
    onWindGustsMsChanged: updateWeatherClassification()
    onNightChanged: {
        resetMeteorScene()
        canvas.requestPaint()
    }
    onAnimateChanged: {
        if (animate) {
            ensureLeafPopulation()
        } else {
            leafSpawnTimer.stop()
        }
    }
    onRainBounceYChanged: {
        if (hasSnowScene())
            resetSnowScene()
        if (hasLeafScene())
            resetLeafScene()
    }
    onFullCardParticleBoundsChanged: {
        if (hasSnowScene())
            resetSnowScene()
        if (hasLeafScene())
            resetLeafScene()
    }
    onScrollProgressChanged: canvas.requestPaint()
}
