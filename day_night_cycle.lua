--[[
##################################################
#### maxxiemax9
#### Copyright (c) 2025 maxxiemax9. All Rights Reserved.
##################################################
--]]

-- Script para ServerScriptService.
-- Ciclo continuo de 24h de juego en 10 minutos reales.
-- Además ajusta efectos visuales en la noche para un look más cinematográfico.

local Lighting = game:GetService("Lighting")

local DAY_LENGTH = 600 -- 10 minutos reales = 24h del juego

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- NightFactor: 0 en pleno día (~12:00), 1 en plena noche (~00:00).
local function getNightFactor(clockTime)
	local distanceToNoon = math.abs(clockTime - 12)
	if distanceToNoon > 12 then
		distanceToNoon = 24 - distanceToNoon
	end

	local raw = distanceToNoon / 12
	-- Suavizado para evitar cambios bruscos visuales.
	return raw * raw * (3 - 2 * raw)
end

-- Busca primero por nombre de tu setup y luego por clase como fallback.
local blur = Lighting:FindFirstChild("Blur [Realism Mod]") or Lighting:FindFirstChildOfClass("BlurEffect")
local colorCorrection = Lighting:FindFirstChild("ColorCorrection [Realism Mod]") or Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local depthOfField = Lighting:FindFirstChild("DepthOfField [Realism Mod]") or Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
local sunRays = Lighting:FindFirstChild("SunRays [Realism Mod]") or Lighting:FindFirstChildOfClass("SunRaysEffect")

-- Guardamos base para no pisar permanentemente tu configuración inicial.
local baseLightingBrightness = Lighting.Brightness
local baseBlurSize = blur and blur.Size or 0

local baseCC = colorCorrection and {
	Brightness = colorCorrection.Brightness,
	Contrast = colorCorrection.Contrast,
	Saturation = colorCorrection.Saturation,
	TintColor = colorCorrection.TintColor,
} or nil

local baseDOF = depthOfField and {
	FarIntensity = depthOfField.FarIntensity,
} or nil

local baseSunRaysIntensity = sunRays and sunRays.Intensity or 0

local function applyVisualProfile(nightFactor)
	-- Brillo general un poco más bajo de noche.
	Lighting.Brightness = lerp(baseLightingBrightness, baseLightingBrightness * 0.72, nightFactor)

	if blur then
		-- Noche: un poco más de blur para look de realismo.
		blur.Size = lerp(baseBlurSize, baseBlurSize + 6, nightFactor)
	end

	if colorCorrection and baseCC then
		-- Noche: menos brillo, más contraste y tono más frío.
		colorCorrection.Brightness = lerp(baseCC.Brightness, baseCC.Brightness - 0.08, nightFactor)
		colorCorrection.Contrast = lerp(baseCC.Contrast, baseCC.Contrast + 0.12, nightFactor)
		colorCorrection.Saturation = lerp(baseCC.Saturation, baseCC.Saturation - 0.1, nightFactor)
		colorCorrection.TintColor = baseCC.TintColor:Lerp(Color3.fromRGB(175, 195, 255), 0.25 * nightFactor)
	end

	if depthOfField and baseDOF then
		depthOfField.FarIntensity = lerp(baseDOF.FarIntensity, baseDOF.FarIntensity + 0.08, nightFactor)
	end

	if sunRays then
		-- Noche: rayos solares más suaves.
		sunRays.Intensity = lerp(baseSunRaysIntensity, baseSunRaysIntensity * 0.25, nightFactor)
	end
end

while true do
	local delta = task.wait()
	Lighting.ClockTime = (Lighting.ClockTime + (24 / DAY_LENGTH) * delta) % 24

	local nightFactor = getNightFactor(Lighting.ClockTime)
	applyVisualProfile(nightFactor)
end
