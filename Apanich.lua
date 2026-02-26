--// MOBILE-OPTIMIZED Universal Aimbot + ESP
--// Fixed: Touch input support, UI close button, mobile-specific optimizations

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

--// DETECT PLATFORM
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local IsController = UserInputService.GamepadEnabled

--// CONFIGURATION
local Config = {
    Aimbot = {
        Enabled = true,
        Mode = IsMobile and "Touch" or "Mouse", -- Auto-detect
        Key = Enum.UserInputType.MouseButton2,
        MobileButton = true, -- On-screen aim button for mobile
        FOV = 120,
        Smoothness = IsMobile and 0.15 or 0.08, -- Higher smoothness for mobile
        TargetPart = "Head",
        VisibilityCheck = true,
        TeamCheck = true,
        AutoFire = false -- Mobile tap-to-shoot
    },
    ESP = {
        Enabled = true,
        Box = true,
        BoxColor = Color3.fromRGB(255, 255, 255),
        Rainbow = true,
        HealthBar = true,
        NameTag = true,
        MaxDistance = 1000,
        TeamCheck = true
    },
    UI = {
        Keybind = Enum.KeyCode.Insert,
        CloseKey = Enum.KeyCode.Delete,
        Theme = {
            Background = Color3.fromRGB(25, 25, 25),
            Accent = Color3.fromRGB(0, 170, 255),
            Text = Color3.fromRGB(255, 255, 255),
            DarkText = Color3.fromRGB(180, 180, 180)
        }
    }
}

--// STATE MANAGEMENT
local State = {
    DrawingObjects = {},
    PlayerCache = {},
    IsAiming = false,
    ScreenSize = Camera.ViewportSize,
    FPS = 0,
    UIVisible = true,
    TouchObject = nil -- Track current touch
}

--// UTILITY FUNCTIONS
local Utility = {}

function Utility.CreateDrawing(type, properties)
    local drawing = Drawing.new(type)
    for prop, value in pairs(properties) do
        drawing[prop] = value
    end
    return drawing
end

function Utility.GetRainbowColor()
    return Color3.fromHSV((tick() * 0.5) % 1, 1, 1)
end

function Utility.IsTeammate(player)
    if not Config.Aimbot.TeamCheck and not Config.ESP.TeamCheck then return false end
    
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team == player.Team
    end
    
    local localChar = LocalPlayer.Character
    local playerChar = player.Character
    if localChar and playerChar then
        local localTeam = localChar:FindFirstChild("TeamColor")
        local playerTeam = playerChar:FindFirstChild("TeamColor")
        if localTeam and playerTeam then
            return localTeam.Value == playerTeam.Value
        end
    end
    
    return false
end

function Utility.IsVisible(targetPart)
    if not Config.Aimbot.VisibilityCheck then return true end
    
    local origin = Camera.CFrame.Position
    local destination = targetPart.Position
    local direction = (destination - origin).Unit * (destination - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    
    local filterList = {LocalPlayer.Character, targetPart.Parent}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filterList, player.Character)
        end
    end
    raycastParams.FilterDescendantsInstances = filterList
    
    local result = workspace:Raycast(origin, direction, raycastParams)
    return result == nil
end

function Utility.GetHealth(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.Health, humanoid.MaxHealth
    end
    return 0, 100
end

function Utility.IsAlive(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

--// ESP SYSTEM (Same as before, optimized)
local ESP = {}

function ESP.Create(player)
    if State.DrawingObjects[player] then return end
    
    local drawings = {
        Box = Utility.CreateDrawing("Square", {
            Thickness = 1,
            Filled = false,
            Visible = false,
            ZIndex = 1
        }),
        BoxOutline = Utility.CreateDrawing("Square", {
            Thickness = 3,
            Filled = false,
            Visible = false,
            Color = Color3.new(0, 0, 0),
            ZIndex = 0
        }),
        HealthBar = Utility.CreateDrawing("Square", {
            Thickness = 1,
            Filled = true,
            Visible = false,
            ZIndex = 2
        }),
        HealthBarBg = Utility.CreateDrawing("Square", {
            Thickness = 1,
            Filled = true,
            Visible = false,
            Color = Color3.new(0, 0, 0),
            Transparency = 0.5,
            ZIndex = 1
        }),
        Name = Utility.CreateDrawing("Text", {
            Size = IsMobile and 16 or 14, -- Larger text for mobile
            Center = true,
            Outline = true,
            Visible = false,
            ZIndex = 3
        }),
        Distance = Utility.CreateDrawing("Text", {
            Size = IsMobile and 14 or 12,
            Center = true,
            Outline = true,
            Visible = false,
            ZIndex = 3
        })
    }
    
    State.DrawingObjects[player] = drawings
end

function ESP.Remove(player)
    local drawings = State.DrawingObjects[player]
    if drawings then
        for _, drawing in pairs(drawings) do
            drawing:Remove()
        end
        State.DrawingObjects[player] = nil
    end
end

function ESP.Update()
    if not Config.ESP.Enabled then
        for player, drawings in pairs(State.DrawingObjects) do
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
        end
        return
    end
    
    local localCharacter = LocalPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    
    for player, drawings in pairs(State.DrawingObjects) do
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local head = character and character:FindFirstChild("Head")
        
        if player == LocalPlayer or 
           not character or 
           not Utility.IsAlive(character) or
           (Config.ESP.TeamCheck and Utility.IsTeammate(player)) or
           not head or not rootPart then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        local distance = localRoot and (rootPart.Position - localRoot.Position).Magnitude or 0
        if distance > Config.ESP.MaxDistance then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        local headPos, headVisible = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local rootPos, rootVisible = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
        
        if not headVisible or not rootVisible then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        local boxHeight = math.abs(rootPos.Y - headPos.Y)
        local boxWidth = boxHeight * 0.6
        local boxPosition = Vector2.new(
            math.floor(headPos.X - boxWidth / 2),
            math.floor(headPos.Y)
        )
        
        local color = Config.ESP.Rainbow and Utility.GetRainbowColor() or Config.ESP.BoxColor
        
        if Config.ESP.Box then
            drawings.BoxOutline.Size = Vector2.new(boxWidth, boxHeight)
            drawings.BoxOutline.Position = boxPosition
            drawings.BoxOutline.Visible = true
            
            drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
            drawings.Box.Position = boxPosition
            drawings.Box.Color = color
            drawings.Box.Visible = true
        else
            drawings.Box.Visible = false
            drawings.BoxOutline.Visible = false
        end
        
        if Config.ESP.HealthBar then
            local health, maxHealth = Utility.GetHealth(character)
            local healthPercent = math.clamp(health / maxHealth, 0, 1)
            
            local barWidth = 4
            local barHeight = boxHeight - 2
            local barX = boxPosition.X - barWidth - 3
            local barY = boxPosition.Y + 1
            
            drawings.HealthBarBg.Size = Vector2.new(barWidth, barHeight)
            drawings.HealthBarBg.Position = Vector2.new(barX, barY)
            drawings.HealthBarBg.Visible = true
            
            local fillHeight = barHeight * healthPercent
            drawings.HealthBar.Size = Vector2.new(barWidth, fillHeight)
            drawings.HealthBar.Position = Vector2.new(barX, barY + (barHeight - fillHeight))
            drawings.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
            drawings.HealthBar.Visible = true
        else
            drawings.HealthBar.Visible = false
            drawings.HealthBarBg.Visible = false
        end
        
        if Config.ESP.NameTag then
            drawings.Name.Text = string.format("%s [%dm]", player.Name, math.floor(distance))
            drawings.Name.Position = Vector2.new(headPos.X, boxPosition.Y - 18)
            drawings.Name.Color = color
            drawings.Name.Visible = true
        else
            drawings.Name.Visible = false
        end
    end
end

--// AIMBOT SYSTEM
local Aimbot = {}

function Aimbot.GetTarget()
    local closestTarget = nil
    local closestDistance = Config.Aimbot.FOV
    local screenCenter = State.ScreenSize / 2
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and Utility.IsTeammate(player) then continue end
        
        local character = player.Character
        if not Utility.IsAlive(character) then continue end
        
        local targetPart = character:FindFirstChild(Config.Aimbot.TargetPart)
        if not targetPart then continue end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        
        local distanceFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if distanceFromCenter > closestDistance then continue end
        
        if not Utility.IsVisible(targetPart) then continue end
        
        closestTarget = targetPart
        closestDistance = distanceFromCenter
    end
    
    return closestTarget
end

function Aimbot.Update()
    if not Config.Aimbot.Enabled then return end
    if not State.IsAiming and Config.Aimbot.Mode ~= "Auto" then return end
    
    local target = Aimbot.GetTarget()
    if not target then return end
    
    local targetPosition = target.Position
    local cameraPosition = Camera.CFrame.Position
    local targetDirection = (targetPosition - cameraPosition).Unit
    
    local targetCFrame = CFrame.new(cameraPosition, cameraPosition + targetDirection)
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Aimbot.Smoothness)
end

--// MOBILE UI COMPONENTS
local MobileUI = {}

function MobileUI.CreateAimButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MobileAimButton"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    local button = Instance.new("TextButton")
    button.Name = "AimButton"
    button.Size = UDim2.new(0, 80, 0, 80)
    button.Position = UDim2.new(1, -100, 1, -180)
    button.BackgroundColor3 = Config.UI.Theme.Accent
    button.Text = "AIM"
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 18
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = true
    button.Active = true
    button.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0) -- Circle
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 2
    stroke.Parent = button
    
    -- Touch handlers
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            State.IsAiming = true
            button.BackgroundColor3 = Color3.fromRGB(0, 255, 100) -- Green when active
        end
    end)
    
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            State.IsAiming = false
            button.BackgroundColor3 = Config.UI.Theme.Accent
        end
    end)
    
    -- Also support InputBegan/Ended for compatibility
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            State.IsAiming = true
        end
    end)
    
    return screenGui
end

--// CUSTOM UI SYSTEM
local UI = {}

function UI.Create()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimbotUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "Main"
    mainFrame.Size = UDim2.new(0, 320, 0, 450)
    mainFrame.Position = UDim2.new(0, 10, 0.5, -225)
    mainFrame.BackgroundColor3 = Config.UI.Theme.Background
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = screenGui
    
    -- Make draggable for both mouse and touch
    local dragInput, dragStart, startPos
    
    local function UpdateDrag(input)
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = mainFrame.Position
            
            local connection
            connection = UserInputService.InputChanged:Connect(function(input2)
                if input2 == input then
                    UpdateDrag(input2)
                end
            end)
            
            UserInputService.InputEnded:Connect(function(input2)
                if input2 == input then
                    connection:Disconnect()
                end
            end)
        end
    end)
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    shadow.Size = UDim2.new(1, 40, 1, 40)
    shadow.ZIndex = -1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.Parent = mainFrame
    
    -- Title Bar with Close Button
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "AIMBOT + ESP"
    title.TextColor3 = Config.UI.Theme.Accent
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- CLOSE BUTTON (X)
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0.5, -15)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        State.UIVisible = false
        mainFrame.Visible = false
        -- Show a small "Open" button when closed
        UI.CreateOpenButton(screenGui)
    end)
    
    -- Also support touch
    closeButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            State.UIVisible = false
            mainFrame.Visible = false
            UI.CreateOpenButton(screenGui)
        end
    end)
    
    -- Container
    local container = Instance.new("ScrollingFrame")
    container.Name = "Container"
    container.Size = UDim2.new(1, -20, 1, -50)
    container.Position = UDim2.new(0, 10, 0, 45)
    container.BackgroundTransparency = 1
    container.ScrollBarThickness = 6
    container.ScrollBarImageColor3 = Config.UI.Theme.Accent
    container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    container.Parent = mainFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.Parent = container
    
    -- Toggle Function
    local function CreateToggle(text, configTable, configKey)
        local toggleFrame = Instance.new("Frame")
        toggleFrame.Size = UDim2.new(1, 0, 0, 40)
        toggleFrame.BackgroundTransparency = 1
        toggleFrame.Parent = container
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -70, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Config.UI.Theme.Text
        label.TextSize = 14
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = toggleFrame
        
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 60, 0, 30)
        button.Position = UDim2.new(1, -60, 0.5, -15)
        button.BackgroundColor3 = configTable[configKey] and Config.UI.Theme.Accent or Color3.fromRGB(60, 60, 60)
        button.Text = configTable[configKey] and "ON" or "OFF"
        button.TextColor3 = Color3.new(1, 1, 1)
        button.TextSize = 14
        button.Font = Enum.Font.GothamBold
        button.AutoButtonColor = false
        button.Parent = toggleFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = button
        
        local function Toggle()
            configTable[configKey] = not configTable[configKey]
            button.BackgroundColor3 = configTable[configKey] and Config.UI.Theme.Accent or Color3.fromRGB(60, 60, 60)
            button.Text = configTable[configKey] and "ON" or "OFF"
        end
        
        button.MouseButton1Click:Connect(Toggle)
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                Toggle()
            end
        end)
    end
    
    -- Slider Function (Touch-compatible)
    local function CreateSlider(text, configTable, configKey, min, max, isFloat)
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, 0, 0, 60)
        sliderFrame.BackgroundTransparency = 1
        sliderFrame.Parent = container
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 25)
        label.BackgroundTransparency = 1
        label.Text = text .. ": " .. configTable[configKey]
        label.TextColor3 = Config.UI.Theme.Text
        label.TextSize = 14
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = sliderFrame
        
        local sliderBg = Instance.new("Frame")
        sliderBg.Name = "Background"
        sliderBg.Size = UDim2.new(1, 0, 0, 12)
        sliderBg.Position = UDim2.new(0, 0, 0, 38)
        sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = sliderFrame
        
        local bgCorner = Instance.new("UICorner")
        bgCorner.CornerRadius = UDim.new(0, 6)
        bgCorner.Parent = sliderBg
        
        local sliderFill = Instance.new("Frame")
        sliderFill.Name = "Fill"
        sliderFill.Size = UDim2.new((configTable[configKey] - min) / (max - min), 0, 1, 0)
        sliderFill.BackgroundColor3 = Config.UI.Theme.Accent
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBg
        
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 6)
        fillCorner.Parent = sliderFill
        
        local dragging = false
        
        local function UpdateSlider(input)
            local pos = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local value = min + (max - min) * pos
            if not isFloat then
                value = math.floor(value)
            else
                value = math.floor(value * 100) / 100
            end
            
            configTable[configKey] = value
            label.Text = text .. ": " .. value
            sliderFill.Size = UDim2.new(pos, 0, 1, 0)
        end
        
        -- Mouse support
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                UpdateSlider(input)
            end
        end)
        
        -- Touch support
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                UpdateSlider(input)
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateSlider(input)
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end
    
    -- Create UI Elements
    CreateToggle("Aimbot Enabled", Config.Aimbot, "Enabled")
    CreateToggle("Team Check (Aimbot)", Config.Aimbot, "TeamCheck")
    CreateToggle("Visibility Check", Config.Aimbot, "VisibilityCheck")
    CreateSlider("FOV", Config.Aimbot, "FOV", 30, 500, false)
    CreateSlider("Smoothness", Config.Aimbot, "Smoothness", 0.01, 1, true)
    
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -10, 0, 2)
    divider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    divider.BorderSizePixel = 0
    divider.Parent = container
    
    CreateToggle("ESP Enabled", Config.ESP, "Enabled")
    CreateToggle("ESP Boxes", Config.ESP, "Box")
    CreateToggle("Rainbow Mode", Config.ESP, "Rainbow")
    CreateToggle("Health Bar", Config.ESP, "HealthBar")
    CreateToggle("Name Tags", Config.ESP, "NameTag")
    CreateToggle("Team Check (ESP)", Config.ESP, "TeamCheck")
    CreateSlider("Max Distance", Config.ESP, "MaxDistance", 100, 5000, false)
    
    -- FOV Circle
    State.FOVCircle = Utility.CreateDrawing("Circle", {
        Thickness = 1.5,
        NumSides = 64,
        Radius = Config.Aimbot.FOV,
        Filled = false,
        Visible = true,
        Color = Config.UI.Theme.Accent
    })
    
    -- FPS Counter
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "FPS"
    fpsLabel.Size = UDim2.new(0, 100, 0, 20)
    fpsLabel.Position = UDim2.new(1, -110, 0, 10)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Text = "FPS: 60"
    fpsLabel.TextColor3 = Config.UI.Theme.DarkText
    fpsLabel.TextSize = 12
    fpsLabel.Font = Enum.Font.Gotham
    fpsLabel.Parent = mainFrame
    
    State.FPSLabel = fpsLabel
    State.UIMain = mainFrame
    State.ScreenGui = screenGui
    
    return screenGui
end

function UI.CreateOpenButton(parentGui)
    if State.OpenButton then State.OpenButton:Destroy() end
    
    local button = Instance.new("TextButton")
    button.Name = "OpenButton"
    button.Size = UDim2.new(0, 50, 0, 50)
    button.Position = UDim2.new(0, 10, 0, 10)
    button.BackgroundColor3 = Config.UI.Theme.Accent
    button.Text = "☰"
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 24
    button.Font = Enum.Font.GothamBold
    button.Parent = parentGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    
    local function Open()
        State.UIVisible = true
        State.UIMain.Visible = true
        button:Destroy()
        State.OpenButton = nil
    end
    
    button.MouseButton1Click:Connect(Open)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            Open()
        end
    end)
    
    State.OpenButton = button
end

--// CONNECTIONS
function Initialize()
    -- Create UI
    UI.Create()
    
    -- Create Mobile Aim Button if on mobile
    if IsMobile and Config.Aimbot.MobileButton then
        MobileUI.CreateAimButton()
    end
    
    -- Input handling (Desktop)
    if not IsMobile then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            
            if input.KeyCode == Config.UI.Keybind then
                State.UIVisible = not State.UIVisible
                State.UIMain.Visible = State.UIVisible
                if not State.UIVisible then
                    UI.CreateOpenButton(State.ScreenGui)
                elseif State.OpenButton then
                    State.OpenButton:Destroy()
                    State.OpenButton = nil
                end
            end
            
            if input.KeyCode == Config.UI.CloseKey then
                State.UIVisible = false
                State.UIMain.Visible = false
                UI.CreateOpenButton(State.ScreenGui)
            end
            
            if input.UserInputType == Config.Aimbot.Key then
                State.IsAiming = true
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Config.Aimbot.Key then
                State.IsAiming = false
            end
        end)
    else
        -- Mobile-specific input
        UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
            if gameProcessed then return end
            -- Optional: Tap to aim at target under finger
        end)
    end
    
    -- Player management
    Players.PlayerAdded:Connect(function(player)
        ESP.Create(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        ESP.Remove(player)
        State.PlayerCache[player] = nil
    end)
    
    -- Character respawn handling
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.1)
        State.IsAiming = false
    end)
    
    -- Initialize existing players
    for _, player in ipairs(Players:GetPlayers()) do
        ESP.Create(player)
    end
    
    -- Render loop
    local lastTime = tick()
    local frameCount = 0
    
    RunService.RenderStepped:Connect(function()
        local currentTime = tick()
        frameCount = frameCount + 1
        
        if currentTime - lastTime >= 1 then
            State.FPS = frameCount
            frameCount = 0
            lastTime = currentTime
            if State.FPSLabel then
                State.FPSLabel.Text = "FPS: " .. State.FPS
            end
        end
        
        State.ScreenSize = Camera.ViewportSize
        
        if State.FOVCircle then
            State.FOVCircle.Visible = Config.Aimbot.Enabled
            State.FOVCircle.Position = State.ScreenSize / 2
            State.FOVCircle.Radius = Config.Aimbot.FOV
            State.FOVCircle.Color = Config.ESP.Rainbow and Utility.GetRainbowColor() or Config.UI.Theme.Accent
        end
        
        ESP.Update()
        Aimbot.Update()
    end)
    
    -- Cleanup
    game:GetService("CoreGui").ChildRemoved:Connect(function(child)
        if child.Name == "AimbotUI" then
            for player, drawings in pairs(State.DrawingObjects) do
                for _, drawing in pairs(drawings) do
                    drawing:Remove()
                end
            end
            if State.FOVCircle then
                State.FOVCircle:Remove()
            end
        end
    end)
end

--// INITIALIZE
Initialize()
