-- PE BG TEST v1.0 - isolated photo-pipeline tester
-- One button, results shown ON SCREEN as image tiles + text log.

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local URL_JPG = "https://raw.githubusercontent.com/blegbot1/PrisonESP/main/pe_bg.jpg"
local URL_PNG = "https://raw.githubusercontent.com/blegbot1/PrisonESP/main/pe_bg.png"
local DECAL_ID = "rbxassetid://93512518437052" -- user decal
local CONTROL = "rbxasset://textures/ui/GuiImagePlaceholder.png" -- always loads

local gui = Instance.new("ScreenGui")
gui.Name = "PE_BG_TEST"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100000
pcall(function()
	gui.Parent = LP:FindFirstChildOfClass("PlayerGui")
		or LP:WaitForChild("PlayerGui", 3)
end)
if not gui.Parent then
	pcall(function() gui.Parent = game:GetService("CoreGui") end)
end

local root = Instance.new("Frame")
root.Size = UDim2.new(0, 620, 0, 520)
root.Position = UDim2.new(0.5, -310, 0.5, -260)
root.BackgroundColor3 = Color3.fromRGB(17, 11, 28)
root.BorderSizePixel = 0
root.Parent = gui
local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0, 12)
rc.Parent = root
local rs = Instance.new("UIStroke")
rs.Color = Color3.fromRGB(90, 60, 150)
rs.Parent = root

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 36)
title.Position = UDim2.new(0, 14, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.Nunito
title.TextSize = 17
title.TextColor3 = Color3.fromRGB(212, 188, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "BG PHOTO TEST - 4 tiles: control / your decal / jpg / png"
title.Parent = root

-- 4 test tiles on the right side
local tiles = {}
local tileNames = { "CONTROL", "DECAL", "JPG", "PNG" }
local tileImages = { CONTROL, DECAL_ID, "", "" }
for i = 1, 4 do
	local t = Instance.new("ImageLabel")
	t.Name = "Tile" .. i
	t.Size = UDim2.new(0, 130, 0, 170)
	t.Position = UDim2.new(0, 480, 0, 10 + (i - 1) * 125)
	t.BackgroundColor3 = Color3.fromRGB(205, 196, 232)
	t.BackgroundTransparency = 0.5
	t.BorderSizePixel = 0
	t.Image = tileImages[i]
	t.ScaleType = Enum.ScaleType.Fit
	t.Parent = root
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 8)
	tc.Parent = t
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 0, 16)
	tl.Position = UDim2.new(0, 0, 1, -16)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.Nunito
	tl.TextSize = 12
	tl.TextColor3 = Color3.fromRGB(212, 188, 255)
	tl.Text = tileNames[i]
	tl.Parent = t
	tiles[i] = t
end

local log = Instance.new("TextLabel")
log.Name = "Log"
log.Size = UDim2.new(0, 450, 1, -110)
log.Position = UDim2.new(0, 14, 0, 50)
log.BackgroundTransparency = 1
log.Font = Enum.Font.Code
log.TextSize = 12
log.TextColor3 = Color3.fromRGB(180, 255, 180)
log.TextXAlignment = Enum.TextXAlignment.Left
log.TextYAlignment = Enum.TextYAlignment.Top
log.TextWrapped = true
log.Text = "Press RUN TEST."
log.Parent = root

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 220, 0, 40)
btn.Position = UDim2.new(0, 14, 1, -52)
btn.BackgroundColor3 = Color3.fromRGB(167, 120, 255)
btn.Font = Enum.Font.Nunito
btn.TextSize = 16
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Text = "RUN TEST"
btn.Parent = root
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = btn

local testing = false
btn.MouseButton1Click:Connect(function()
	if testing then return end
	testing = true
	log.Text = ""
	local function L(s)
		log.Text = log.Text .. "\n" .. tostring(s)
		print("[BGTEST] " .. tostring(s))
	end

	-- 0) environment
	L("executor fns:")
	L(" isfile=" .. tostring(type(isfile) == "function")
		.. " writefile=" .. tostring(type(writefile) == "function")
		.. " readfile=" .. tostring(type(readfile) == "function")
		.. " getcustomasset=" .. tostring(type(getcustomasset) == "function"))
	L(" request=" .. tostring(type(request) == "function")
		.. " http_request=" .. tostring(type(http_request) == "function"))

	-- 1) download BOTH images via request/http_request (raw Body)
	local function dl(url, file)
		local okD, data = pcall(function()
			if type(http_request) == "function" then
				return http_request({ Url = url, Method = "GET" })
			end
			return request({ Url = url, Method = "GET" })
		end)
		if not okD or not data or not data.Body then
			L(" dl " .. file .. " FAILED: " .. tostring(data))
			return nil
		end
		L(" dl " .. file .. ": " .. #data.Body .. " bytes, status "
			.. tostring(data.StatusCode))
		if #data.Body < 500 then
			L("  too small - corrupted/404?")
			return nil
		end
		local okW = pcall(function() writefile(file, data.Body) end)
		L("  writefile " .. file .. ": " .. tostring(okW))
		-- verify: read back and compare sizes
		local okR, back = pcall(function() return readfile(file) end)
		if okR and type(back) == "string" then
			L("  readback " .. #back .. " bytes"
				.. (back == data.Body and " (identical)" or " (DIFFERS!)"))
		end
		return file
	end
	local jpgFile = dl(URL_JPG, "pe_t_jpg.jpg")
	local pngFile = dl(URL_PNG, "pe_t_png.png")

	-- 2) also download via game:HttpGet for comparison
	local okH, hBody = pcall(function()
		return game:HttpGet(URL_JPG, true)
	end)
	if okH and type(hBody) == "string" then
		L(" game:HttpGet jpg: " .. #hBody .. " bytes")
		pcall(function() writefile("pe_t_hget.jpg", hBody) end)
	end

	-- 3) build custom assets (both call forms)
	local function assetOf(file)
		if type(getcustomasset) ~= "function" or not file then
			return nil
		end
		local okA, a = pcall(function()
			return getcustomasset({ filepath = file })
		end)
		if not okA or not a then
			okA, a = pcall(function() return getcustomasset(file) end)
		end
		if okA and type(a) == "string" then return a end
		L(" getcustomasset(" .. file .. ") FAILED: " .. tostring(a))
		return nil
	end
	tiles[3].Image = assetOf(jpgFile) or ""
	tiles[4].Image = assetOf(pngFile) or ""
	if okH and type(hBody) == "string" and #hBody > 500 then
		pcall(function() writefile("pe_t_hget2.jpg", hBody) end)
		tiles[3].Image = assetOf("pe_t_hget2.jpg") or tiles[3].Image
	end

	-- 4) report tile sizes after 3s (0,0 = empty asset)
	task.delay(3, function()
		for i = 1, 4 do
			pcall(function()
				local t = tiles[i]
				L(t.Name .. ": loaded=" .. tostring(t.IsLoaded)
					.. " rect=" .. tostring(t.ImageRectSize))
			end)
		end
		L("DONE - look at the 4 tiles on the right:")
		L(" which ones show the photo?")
		testing = false
	end)
end)
