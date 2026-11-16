love.getWidth = love.graphics.getWidth
love.getHeight = love.graphics.getHeight

local ball = { x = 0, y = 0, vy = 0, r = 30 }
local costs = {50, 120, 250, 500, 1000, 2000, "MAX"};
local GRAVITY, JUMP = 1500, 1600
local SUPER, TIMING = 1.4, 0.6
local GOAL = 1500
local MAX_COMBO = { [0] = 1, 2, 3, 5, 7, 10, 15 }
local floorY = 0
local cam, following = 0, false
local clock, lastClick, landTime, tried = 0, -1, -1, false
local squish = { sx = 1, sy = 1 }
local drops = {}
local money, peak = 0, 0
local started = false
local won, winScreen = false, false
local bigFont = love.graphics.newFont(44)
local medFont = love.graphics.newFont(20)
local smallFont = love.graphics.newFont(16)
local upgrades = {
  { name = "SPEED", icon = "arrow.png", color = { 1, 0.3, 0.3 }, level = 0 },
  { name = "COMBO", icon = "fist.png", color = { 0.3, 0.6, 1 }, level = 0 },
  { name = "CASH", icon = "money.png", color = { 0.3, 0.9, 0.4 }, level = 0 },
}
local hover = nil
local combo = 0;
local windScroll = 0

local fx = { t = 99, freeze = 0, shake = 0, x = 0, y = 0, seed = 0 }
local FREEZE, STEP = 0.12, 1 / 12

local function gameW() return love.getWidth() / 2 end

local HILL_W, HILL_H = 1.1, 140

local function hillY(x)
  local ground = floorY + ball.r
  local u = (x - ball.x) / (gameW() * 0.5 * HILL_W)
  if math.abs(u) >= 1 then return ground + HILL_H end
  local curve = (1 - math.sqrt(1 - u * u)) * HILL_H
  local turn = math.sin(u * 9 + 0.6) * 10 * u * u
  return ground + curve + turn
end

local function squishLand(x, y)
  squish.sx, squish.sy = 1.4, 0.6
  for i = 1, 12 do
    local angle = math.pi + love.math.random() * math.pi
    local speed = love.math.random(100, 300)
    table.insert(drops, { x = x, y = y, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed, life = 1 })
  end
end

local function squishLaunch()
  squish.sx, squish.sy = 0.6, 1.5
  playWoosh()
end

local function launch(super)
  squishLaunch()
  if super then
    combo = math.min(combo + 1, MAX_COMBO[upgrades[2].level])
  else
    combo = 0
  end
  local v = JUMP * (1 + 0.2 * upgrades[1].level) * (1 + 0.05 * combo)
  if super then v = v * SUPER end
  ball.vy = -v
  tried = false
end

local function startImpact()
  fx.t, fx.freeze, fx.shake = 0, FREEZE, 18
  fx.x, fx.y = ball.x, floorY + ball.r
  fx.seed = love.math.random(1, 1000000)
  playImpact()
end

function love.load()
  ball.x = gameW() / 2
  floorY = love.getHeight() - ball.r - 100
  ball.y = floorY
  loadClouds()
  startMusic()
  loadImpactSound()
  loadWoosh()
  for _, u in ipairs(upgrades) do loadIcon(u.icon) end
end

local function pressJump()
  if not started then started = true return end
  if winScreen then winScreen = false return end
  if ball.y < floorY then
    if not tried then lastClick, tried = clock, true end
    return
  end
  launch(not tried and clock - landTime <= TIMING)
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  if started and not winScreen and x >= gameW() then
    local i = upgradeAt(x, y)
    if i then buy(i) end
    return
  end
  pressJump()
end

function love.keypressed(key)
  if key == "space" or key == "up" or key == "w" then pressJump() end
end

function love.mousemoved(x, y, dx, dy)
  hover = started and upgradeAt(x, y) or nil
end

function love.update(dt)
  if winScreen then return end
  fx.t = fx.t + dt
  fx.shake = math.max(0, fx.shake - dt * 40)
  if fx.freeze > 0 then fx.freeze = fx.freeze - dt return end

  clock = clock + dt
  ball.x = gameW() / 2
  floorY = love.getHeight() - ball.r - 100
  local wasInAir = ball.y < floorY
  ball.vy = ball.vy + GRAVITY * dt
  ball.y = ball.y + ball.vy * dt
  peak = math.max(peak, floorY - ball.y)
  windScroll = windScroll - ball.vy * dt
  if not won and floorY - ball.y >= GOAL * 10 then won, winScreen = true, true end
  if ball.y - ball.r < 0 then following = true end
  if ball.y >= floorY then
    ball.y, ball.vy = floorY, 0
    following = false
    if wasInAir then
      money = money + math.floor(peak / 50 *(1 + 0.5 * upgrades[3].level) * (1 + 0.2 * combo))
      peak = 0
      squishLand(ball.x, ball.y + ball.r)
      startImpact()
      landTime = clock
      if clock - lastClick <= TIMING then launch(true) end
    end
  end

  local st = math.min(0.5, math.abs(ball.vy) / 3000)
  squish.sx = squish.sx + ((1 - st * 0.5) - squish.sx) * 10 * dt
  squish.sy = squish.sy + ((1 + st) - squish.sy) * 10 * dt
  for i = #drops, 1, -1 do
    local d = drops[i]
    d.vy = d.vy + 800 * dt
    d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
    d.life = d.life - dt
    if d.life <= 0 then table.remove(drops, i) end
  end

  local target = following and math.min(0, ball.y - floorY) or 0
  cam = math.max(target, cam + (target - cam) * math.min(1, 5 * dt))
  cam = math.min(cam, ball.y - ball.r - 80)
  updateClouds(dt)
end

local function ballShape(ox, oy, k)
  ox, oy, k = ox or 0, oy or 0, k or 1
  love.graphics.ellipse("fill", ball.x + ox, ball.y + ball.r - ball.r * squish.sy + oy, ball.r * squish.sx * k, ball.r * squish.sy * k)
end

local function wedges(rng, count)
  for i = 1, count do
    local a = rng:random() * math.pi * 2
    local w = 0.015 + rng:random() * 0.05
    local inner = 45 + rng:random() * 120
    local outer = inner + 150 + rng:random() * 700
    local bend = (rng:random() - 0.5) * 0.08
    love.graphics.polygon("fill",
      fx.x + math.cos(a) * inner, fx.y + math.sin(a) * inner,
      fx.x + math.cos(a - w + bend) * outer, fx.y + math.sin(a - w + bend) * outer,
      fx.x + math.cos(a + w + bend) * outer, fx.y + math.sin(a + w + bend) * outer)
  end
end

local function jaggedRing(rng, r, width)
  local pts = {}
  for i = 0, 15 do
    local a = i / 16 * math.pi * 2 + (rng:random() - 0.5) * 0.25
    local rr = r * (0.8 + rng:random() * 0.4)
    pts[#pts + 1] = fx.x + math.cos(a) * rr
    pts[#pts + 1] = fx.y + math.sin(a) * rr * 0.45
  end
  pts[#pts + 1], pts[#pts + 2] = pts[1], pts[2]
  love.graphics.setLineWidth(width)
  love.graphics.line(pts)
  love.graphics.setLineWidth(1)
end

local CRACKS = {
  { 0, 0, -14, 3, -26, 1, -38, 7, -55, 6, -70, 12 },
  { -38, 7, -45, 16 },
  { 0, 0, -9, 8, -21, 10, -30, 19 },
  { 0, 0, 15, 2, 27, 8, 41, 6, 57, 11, 72, 9 },
  { 41, 6, 48, 15 },
  { 0, 0, 11, 7, 20, 14, 33, 16 },
}

local function cracks()
  love.graphics.setLineWidth(3)
  for _, c in ipairs(CRACKS) do
    local pts = {}
    for i = 1, #c, 2 do
      pts[i], pts[i + 1] = fx.x + c[i], fx.y + c[i + 1]
    end
    love.graphics.line(pts)
  end
  love.graphics.setLineWidth(1)
end

local INK, PAPER = { 0.1, 0.18, 0.14 }, { 0.96, 0.95, 0.87 }

function drawSpeedLines()
  local vel = ball.vy;
  local len = math.abs(vel) * 0.1;
  local gap = 10;
  local bottom = ball.y + ball.r;
  local top = bottom - 2 * ball.r * squish.sy;
  local y1, dir;
  if vel < 0 then
    y1, dir = bottom + gap, 1;
  else
    y1, dir = top - gap, -1;
  end

  local function streak(x, l, a)
    local y2 = y1 + dir * l;
    if dir == 1 then y2 = math.min(y2, floorY + ball.r) end
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.line(x, y1, x, y2)
  end

  streak(ball.x - 20, len * 0.7, 0.6);
  streak(ball.x, len, 0.9);
  streak(ball.x + 20, len * 0.7, 0.6);
  love.graphics.setColor(1, 1, 1, 1)
end

local function inkText(text, font, x, y, t, fill)
  love.graphics.setFont(font)
  love.graphics.setColor(INK)
  for ox = -t, t do
    for oy = -t, t do
      love.graphics.print(text, x + ox, y + oy)
    end
  end
  love.graphics.setColor(fill or PAPER)
  love.graphics.print(text, x, y)
end

local icons = {}

function loadIcon(file)
  if icons[file] ~= nil then return icons[file] end
  icons[file] = false
  if not love.filesystem.getInfo(file) then return false end
  local data = love.image.newImageData(file)
  local w, h = data:getDimensions()
  local x1, y1, x2, y2 = w, h, 0, 0
  for y = 0, h - 1, 8 do
    for x = 0, w - 1, 8 do
      local _, _, _, a = data:getPixel(x, y)
      if a > 0.1 then
        x1, y1 = math.min(x1, x), math.min(y1, y)
        x2, y2 = math.max(x2, x), math.max(y2, y)
      end
    end
  end
  if x2 < x1 then x1, y1, x2, y2 = 0, 0, w - 8, h - 8 end
  x1, y1 = math.max(0, x1 - 8), math.max(0, y1 - 8)
  local cw, ch = math.min(w, x2 + 16) - x1, math.min(h, y2 + 16) - y1
  local crop = love.image.newImageData(cw, ch)
  crop:paste(data, 0, 0, x1, y1, cw, ch)
  icons[file] = love.graphics.newImage(crop, { mipmaps = true })
  return icons[file]
end

local function drawIcon(file, x, y, bw, bh)
  local img = loadIcon(file)
  if not img then return end
  local s = math.min(bw / img:getWidth(), bh / img:getHeight())
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(img, x + (bw - img:getWidth() * s) / 2, y + (bh - img:getHeight() * s) / 2, 0, s, s)
end

local function drawHeight()
    local h = math.max(0, math.floor((floorY - ball.y) / 10))
    local text = h .. "m"
    love.graphics.push()
    love.graphics.translate(34, 30)
    love.graphics.rotate(-0.07)
    inkText("HEIGHT", smallFont, 4, 0, 2)
    inkText(text, bigFont, 0, 16, 3)
    local w = bigFont:getWidth(text)
    love.graphics.setLineWidth(7)
    love.graphics.setColor(INK)
    love.graphics.line(-2, 74, w * 0.5, 78, w + 6, 72)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(PAPER)
    love.graphics.line(0, 73, w * 0.5, 76, w + 4, 71)
    love.graphics.setLineWidth(1)
    inkText("SPEED " .. math.floor(math.abs(ball.vy)), smallFont, 4, 86, 2)
    inkText("COMBO " .. combo .. "/" .. MAX_COMBO[upgrades[2].level], smallFont, 4, 106, 2)
    love.graphics.pop()
end

local w = love.graphics.getWidth() / 2;
local H = love.graphics.getHeight();
local h = H / 4;

function drawTitle(startX, startY)
    local boxX = startX + (1 / 16) * w
    local boxW = w - (1 / 8) * w
    local centerX = boxX + boxW / 2

    local title = "UPGRADES"
    local textW = bigFont:getWidth(title)
    local textH = bigFont:getHeight()
    local textX = centerX - textW / 2
    local textY = startY + (1 / 2) * h - textH / 2
    inkText(title, bigFont, textX, textY, 3)

    local lineW = boxW * 0.85
    local lineX1 = centerX - lineW / 2
    local lineX2 = centerX + lineW / 2
    local lineY = startY + (5 / 6) * h

    love.graphics.setLineWidth(7)
    love.graphics.setColor(INK)
    love.graphics.line(lineX1 - 2, lineY, lineX2 + 2, lineY)

    love.graphics.setLineWidth(3)
    love.graphics.setColor(PAPER)
    love.graphics.line(lineX1, lineY, lineX2, lineY)
    love.graphics.setLineWidth(1)
end

function upgradeAt(x, y)
    for i = 1, #upgrades do
        local bx, by = w + w / 16, i * h
        if x >= bx and x <= bx + w * 7 / 8 and y >= by and y <= by + h * 3 / 4 then
            return i
        end
    end
    return nil
end

function buy(i)
    local u = upgrades[i]
    if u.level < 6 and spend(costs[u.level + 1]) then
        u.level = u.level + 1
    end
end

local function upgradeInfo(i, level)
    if i == 1 then return string.format("jump x%.1f", 1 + 0.2 * level) end
    if i == 2 then return "max combo " .. MAX_COMBO[level] end
    return string.format("cash x%.1f", 1 + 0.5 * level)
end

function drawUpgrade(startX, startY, i)
    local u = upgrades[i]
    local level = u.level
    local cost = costs[level + 1]
    if hover == i then
        love.graphics.setColor(0.35, 0.35, 0.38)
    else
        love.graphics.setColor(0, 0, 0)
    end
    love.graphics.rectangle("fill", startX + (1 / 16) * w, startY, w - (1 / 8) * w, (3 / 4) * h, 10, 10);
    love.graphics.setColor(0.5, 0.5, 0.5);
    love.graphics.rectangle("fill", startX + w/16 + h / 8, startY + h/8, h / 2, h / 2, 10, 10);
    drawIcon(u.icon, startX + w/16 + h / 8 + 6, startY + h/8 + 6, h / 2 - 12, h / 2 - 12)
    love.graphics.setColor(0.5, 0.5, 0.5);
    love.graphics.circle("fill", startX + 15 * w / 16 - 5 * h / 16, startY + 3 * h / 8, h / 4);
    love.graphics.setColor(u.color);
    for n = 1, level do
        love.graphics.arc("fill",
            startX + 15 * w / 16 - 5 * h / 16,
            startY + 3 * h / 8,
            h / 4,
            math.pi * 2 / 6 * (n - 1) - math.pi / 2,
            math.pi * 2 / 6 * n - math.pi / 2
        );
    end
    love.graphics.setColor(0, 0, 0);
    for n = 0, 5 do
        love.graphics.arc("line",
            startX + 15 * w / 16 - 5 * h / 16,
            startY + 3 * h / 8,
            h / 4,
            math.pi * 2 / 6 * n - math.pi / 2,
            math.pi * 2 / 6 * (n + 1) - math.pi / 2
        );
    end

    local tx = startX + h * 7 / 8
    inkText(u.name, medFont, tx, startY + 3 * h / 16, 2)
    inkText(upgradeInfo(i, level), smallFont, tx, startY + 3 * h / 16 + 28, 1)
    if level >= 6 then
        inkText("MAX", medFont, tx, startY + 3 * h / 16 + 50, 2, u.color)
    else
        drawIcon("money.png", tx, startY + 3 * h / 16 + 50, 14, 24)
        local fill = money >= cost and PAPER or { 1, 0.45, 0.4 }
        inkText(tostring(cost), medFont, tx + 18, startY + 3 * h / 16 + 50, 2, fill)
    end
end

local cloudImgs, clouds, cloudTop = {}, {}, 0

function loadClouds()
  for i = 1, 4 do
    local file = "cloud" .. i .. ".png"
    if love.filesystem.getInfo(file) then
      table.insert(cloudImgs, love.graphics.newImage(file))
    end
  end
  cloudTop = floorY - 120
end

local function addCloud(y)
  local img = cloudImgs[love.math.random(#cloudImgs)]
  local s = (80 + love.math.random() * 110) / img:getWidth()
  table.insert(clouds, {
    img = img, s = s, y = y,
    x = love.math.random() * gameW() - img:getWidth() * s / 2,
    speed = 8 + love.math.random() * 22,
  })
end

function updateClouds(dt)
  while #cloudImgs > 0 and cloudTop > cam - 300 do
    cloudTop = cloudTop - (140 + love.math.random() * 180)
    if cloudTop > floorY - 7000 then addCloud(cloudTop) end
  end
  for _, c in ipairs(clouds) do
    c.x = c.x + c.speed * dt
    if c.x > gameW() then c.x = -c.img:getWidth() * c.s end
  end
end

function drawClouds()
  love.graphics.setColor(1, 1, 1)
  for _, c in ipairs(clouds) do
    if c.y > cam - 300 and c.y < cam + love.getHeight() then
      love.graphics.draw(c.img, c.x, c.y, 0, c.s, c.s)
    end
  end
end

local function drawGoal(gw)
    local gy = floorY + ball.r - GOAL * 10
    if gy < cam - 60 or gy > cam + love.getHeight() + 60 then return end
    for x = 0, gw, 26 do
        love.graphics.setLineWidth(6)
        love.graphics.setColor(INK)
        love.graphics.line(x, gy, x + 16, gy)
        love.graphics.setLineWidth(3)
        love.graphics.setColor(PAPER)
        love.graphics.line(x + 1, gy, x + 15, gy)
    end
    love.graphics.setLineWidth(1)
    inkText("GOAL " .. GOAL .. "m", medFont, 12, gy - 32, 2)
end


function drawPanel(startX, startY)
    -- top is title + line
    drawTitle(startX, 0);

    drawUpgrade(startX, h, 1)
    drawUpgrade(startX, 2*h, 2)
    drawUpgrade(startX, 3*h, 3)
end

local titleFont = love.graphics.newFont(80)
local startFont = love.graphics.newFont(28)
local START_CLOUDS = {
  { 0.02, 120, 300, 1, 12 },
  { 0.55, 90, 360, 2, 8 },
  { 0.78, 230, 260, 3, 15 },
  { 0.25, 250, 220, 4, 10 },
}

local function startHillY(x, W, top)
  local u = (x - W / 2) / (W * 0.55)
  if math.abs(u) >= 1 then return top + 400 end
  return top + (1 - math.sqrt(1 - u * u)) * 280 + math.sin(u * 9 + 0.6) * 10 * u * u
end

function drawStart()
  local W, H = love.getWidth(), love.getHeight()
  local t = love.timer.getTime()
  love.graphics.clear(love.math.colorFromBytes(0x68, 0xb0, 0xab))

  love.graphics.setColor(1, 1, 1)
  for _, c in ipairs(START_CLOUDS) do
    local img = cloudImgs[c[4]]
    if img then
      local s = c[3] / img:getWidth()
      local x = (c[1] * W + t * c[5]) % (W + c[3]) - c[3]
      love.graphics.draw(img, x, c[2] - img:getHeight() * s / 2, 0, s, s)
    end
  end

  local top = H * 0.62
  love.graphics.setColor(love.math.colorFromBytes(0x4a, 0x7c, 0x59))
  for x = 0, W, 4 do
    love.graphics.polygon("fill", x, startHillY(x, W, top), x + 4, startHillY(x + 4, W, top), x + 4, H, x, H)
  end
  local still = love.math.newRandomGenerator(7)
  love.graphics.setColor(0, 0, 0, 0.18)
  local prev = 8 + still:random() * 6
  for x = 0, W, 20 do
    local nxt = 8 + still:random() * 6
    local a, b = startHillY(x, W, top), startHillY(x + 20, W, top)
    love.graphics.polygon("fill", x, a, x + 20, b, x + 20, b + nxt, x, a + prev)
    prev = nxt
  end
  love.graphics.setColor(0, 0, 0, 0.12)
  love.graphics.setLineWidth(2)
  for x = 8, W, 14 do
    local hx = x + still:random() * 6
    local hy = startHillY(hx, W, top) + 16 + still:random() * 10
    love.graphics.line(hx, hy, hx - 5 - still:random() * 4, hy + 6 + still:random() * 5)
  end
  love.graphics.setLineWidth(1)

  local r = 30
  local hop = math.abs(math.sin(t * 2.5)) * 40
  local bx, by = W / 2, top - r - hop
  local sh = math.max(0.4, 1 - hop / 80)
  love.graphics.setColor(0, 0, 0, 0.25 * sh)
  love.graphics.ellipse("fill", bx, top + 3, r * 1.2 * sh, 5 * sh)
  love.graphics.setColor(0.78, 0.8, 0.82)
  love.graphics.circle("fill", bx, by, r)
  love.graphics.setColor(1, 1, 1)
  love.graphics.circle("fill", bx - r * 0.12, by - r * 0.12, r * 0.85)

  local title = "BOUNCR"
  local R = 420
  local cx, cy = W / 2, 40 + R
  local a = -(titleFont:getWidth(title) + (#title - 1) * 6) / 2 / R
  for i = 1, #title do
    local ch = title:sub(i, i)
    local cw = titleFont:getWidth(ch)
    local mid = a + cw / 2 / R
    love.graphics.push()
    love.graphics.translate(cx + math.sin(mid) * R, cy - math.cos(mid) * R)
    love.graphics.rotate(mid)
    inkText(ch, titleFont, -cw / 2, 0, 4)
    love.graphics.pop()
    a = a + (cw + 6) / R
  end

  if t % 1.2 < 0.8 then
    local text = "click to start"
    love.graphics.push()
        love.graphics.translate(W / 2, 200)

    love.graphics.rotate(-0.03)
    inkText(text, startFont, -startFont:getWidth(text) / 2, 0, 2)
    love.graphics.pop()
  end
  local goalText = "get to " .. GOAL .. "m to win"
  inkText(goalText, startFont, W / 2 - startFont:getWidth(goalText) / 2, top + 70, 2)
  love.graphics.setColor(1, 1, 1)
end

local SKY_STOPS = {
  { 0, 0.41, 0.69, 0.67 },
  { 500, 0.41, 0.69, 0.67 },
  { 650, 0.58, 0.64, 0.86 },
  { 800, 0.47, 0.42, 0.70 },
  { 1200, 0.33, 0.28, 0.52 },
}
local STAR_COLORS = {
  { 1, 0.80, 0.90 }, { 0.75, 1, 0.90 }, { 1, 0.97, 0.75 }, { 0.85, 0.80, 1 }, { 1, 1, 1 },
}

local function skyColor(m)
  if m <= SKY_STOPS[1][1] then return SKY_STOPS[1][2], SKY_STOPS[1][3], SKY_STOPS[1][4] end
  for i = 2, #SKY_STOPS do
    local a, b = SKY_STOPS[i - 1], SKY_STOPS[i]
    if m <= b[1] then
      local t = (m - a[1]) / (b[1] - a[1])
      return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
    end
  end
  local last = SKY_STOPS[#SKY_STOPS]
  return last[2], last[3], last[4]
end

function drawSky(gw, H)
  for y = 0, H, 10 do
    love.graphics.setColor(skyColor((floorY - (cam + y)) / 10))
    love.graphics.rectangle("fill", 0, y, gw, 10)
  end
end

function drawStars(gw, H)
  local band = 200
  for b = math.floor(cam / band) - 1, math.floor((cam + H) / band) do
    local wy = b * band
    local m = (floorY - wy) / 10
    if m > 550 then
      local fade = math.min(1, (m - 550) / 250)
      local rng = love.math.newRandomGenerator(5000000 + b)
      for i = 1, 6 do
        local x = math.floor(rng:random() * gw / 4) * 4
        local y = wy + math.floor(rng:random() * band / 4) * 4
        local s = rng:random() < 0.7 and 4 or 8
        local twinkle = rng:random() < 0.25
        local c = STAR_COLORS[rng:random(#STAR_COLORS)]
        love.graphics.setColor(c[1], c[2], c[3], fade)
        if twinkle then
          love.graphics.rectangle("fill", x - 4, y, 12, 4)
          love.graphics.rectangle("fill", x, y - 4, 4, 12)
        else
          love.graphics.rectangle("fill", x, y, s, s)
        end
      end
    end
  end
end

local WIND = {
  { 14, 0.00, 120, 1.00, 2 },
  { 36, 0.40, 70, 1.30, 1.5 },
  { 24, 0.78, 160, 0.85, 2.5 },
  { 50, 0.22, 60, 1.15, 1 },
  { -14, 0.15, 100, 1.10, 2 },
  { -38, 0.58, 140, 0.90, 2.5 },
  { -24, 0.92, 80, 1.25, 1.5 },
  { -52, 0.35, 55, 1.05, 1 },
}

local function windStroke(x, y, len, width, alpha)
  love.graphics.setLineWidth(width)
  for i = 0, 7 do
    love.graphics.setColor(1, 1, 1, alpha * math.sin((i + 0.5) / 8 * math.pi))
    love.graphics.line(x, y + len * i / 8, x, y + len * (i + 1) / 8)
  end
end

function drawWind(gw, H)
  local speed = math.abs(ball.vy)
  local alpha = math.min(0.6, math.max(0, (speed - 300) / 2000))
  if alpha <= 0 then return end
  local stretch = 0.6 + 0.8 * math.min(1, speed / 3000)
  local span = H + 300
  for _, wnd in ipairs(WIND) do
    local x = wnd[1] >= 0 and wnd[1] or gw + wnd[1]
    local y = (wnd[2] * span + windScroll * 0.6 * wnd[4]) % span - 150
    windStroke(x, y, wnd[3] * stretch, wnd[5], alpha)
  end
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1)
end

function drawWin()
  local W, H = love.getWidth(), love.getHeight()
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, 0, W, H)
  local t1 = "YOU WIN!"
  inkText(t1, titleFont, W / 2 - titleFont:getWidth(t1) / 2, H * 0.28, 4)
  local t2 = "you reached " .. GOAL .. "m"
  inkText(t2, startFont, W / 2 - startFont:getWidth(t2) / 2, H * 0.28 + 110, 2)
  if love.timer.getTime() % 1.2 < 0.8 then
    local t3 = "click to keep bouncing"
    inkText(t3, smallFont, W / 2 - smallFont:getWidth(t3) / 2, H * 0.28 + 160, 2)
  end
  love.graphics.setColor(1, 1, 1)
end

function spend(cost)
  if money < cost then return false end
  money = money - cost
  return true
end

function drawMoney(gw)
  local text = tostring(money)
  local tx = gw - bigFont:getWidth(text) - 20
  inkText(text, bigFont, tx, 16, 3)
  drawIcon("money.png", tx - 30, 18, 26, bigFont:getHeight() * 0.85)
end
local music

function startMusic()
  for _, file in ipairs({ "music.mp3", "music.ogg", "music.wav" }) do
    if love.filesystem.getInfo(file) then
      music = love.audio.newSource(file, "stream")
      music:setLooping(true)
      music:setVolume(0.5)
      music:play()
      return
    end
  end
end

local impactSound

function loadImpactSound()
  if love.filesystem.getInfo("impact.mp3") then
    impactSound = love.audio.newSource("impact.mp3", "static")
  end
end

function playImpact()
  if impactSound then
    impactSound:stop()
    impactSound:seek(0.06)
    impactSound:play()
  end
end
local wooshSound

function loadWoosh()
  if love.filesystem.getInfo("woosh.mp3") then
    wooshSound = love.audio.newSource("woosh.mp3", "static")
  end
end

function playWoosh()
  if wooshSound then
    wooshSound:stop()
    wooshSound:seek(0.12)
    wooshSound:play()
  end
end
function love.draw()
    if not started then drawStart() return end
    local W, H = love.getWidth(), love.getHeight()
    local gw = gameW()
    local top = cam - 60

    local srng = love.math.newRandomGenerator(fx.seed + math.floor(fx.t * 24))
    local sx = (srng:random() * 2 - 1) * fx.shake
    local sy = (srng:random() * 2 - 1) * fx.shake

    love.graphics.clear(love.math.colorFromBytes(0x68, 0xb0, 0xab))
    love.graphics.setScissor(0, 0, gw, H)
    love.graphics.setLineJoin("bevel")
    drawSky(gw, H)
    love.graphics.translate(sx, sy - cam)
    drawStars(gw, H)
    drawClouds()
    drawGoal(gw)

    local ground = floorY + ball.r
    love.graphics.setColor(love.math.colorFromBytes(0x4a, 0x7c, 0x59))
    for x = -20, gw + 20, 4 do
        love.graphics.polygon("fill", x, hillY(x), x + 4, hillY(x + 4), x + 4, H + 200, x, H + 200)
    end
    local still = love.math.newRandomGenerator(7)
    love.graphics.setColor(0, 0, 0, 0.18)
    local prev = 8 + still:random() * 6
    for x = 0, gw, 20 do
        local nxt = 8 + still:random() * 6
        love.graphics.polygon("fill", x, hillY(x), x + 20, hillY(x + 20), x + 20, hillY(x + 20) + nxt, x, hillY(x) + prev)
        prev = nxt
    end
    love.graphics.setColor(0, 0, 0, 0.12)
    love.graphics.setLineWidth(2)
    for x = 8, gw, 14 do
        local hx = x + still:random() * 6
        local hy = hillY(hx) + 16 + still:random() * 10
        love.graphics.line(hx, hy, hx - 5 - still:random() * 4, hy + 6 + still:random() * 5)
    end
    love.graphics.setLineWidth(1)

    local s = math.max(0.15, 1 - (floorY - ball.y) / 600)
    local boil = love.math.newRandomGenerator(3)
    local function blob(rx, ry, ox)
        local pts = {}
        for i = 0, 13 do
            local a = i / 14 * math.pi * 2
            local j = 0.92 + boil:random() * 0.16
            pts[#pts + 1] = ball.x + ox + math.cos(a) * rx * j
            pts[#pts + 1] = ground + ry * 1.1 + math.sin(a) * ry * j
        end
        love.graphics.polygon("fill", pts)
    end
    love.graphics.setColor(0, 0, 0, 0.14 * s)
    blob(ball.r * 1.5 * s, 6 * s, 0)
    love.graphics.setColor(0, 0, 0, 0.3 * s)
    blob(ball.r * 0.9 * s, 4 * s, ball.r * 0.15 * s)

    if fx.t >= FREEZE and fx.t < FREEZE + 0.5 then
        love.graphics.setColor(0.03, 0.08, 0.2)
        cracks()
    end

    love.graphics.setColor(0.78, 0.8, 0.82)
    ballShape()
    love.graphics.setColor(1, 1, 1)
    ballShape(-ball.r * 0.12 * squish.sx, -ball.r * 0.12 * squish.sy, 0.85)
    for _, d in ipairs(drops) do
        love.graphics.setColor(1, 1, 1, d.life)
        love.graphics.circle("fill", d.x, d.y, 4)
    end
    love.graphics.setColor(1, 1, 1, 1)
    drawSpeedLines()

    local rng = love.math.newRandomGenerator(fx.seed + math.floor(fx.t / STEP))
    if fx.t < 0.04 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", -50, top, gw + 100, H + 120)
        love.graphics.setColor(0, 0, 0)
        wedges(rng, 22)
        ballShape()
    elseif fx.t < FREEZE then
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", -50, top, gw + 100, H + 120)
        love.graphics.setColor(1, 1, 1)
        wedges(rng, 28)
        ballShape()
        jaggedRing(rng, ball.r * 2.2, 4)
    elseif fx.t < FREEZE + STEP * 3 then
        local k = math.floor((fx.t - FREEZE) / STEP)
        love.graphics.setColor(1, 1, 1)
        jaggedRing(rng, 70 + k * 70, 6 - k * 2)
        if k == 0 then wedges(rng, 8) end
    end
    love.graphics.origin()
    drawWind(gw, H)
    love.graphics.setColor(1, 1, 1)
    drawHeight()
    drawMoney(gw)
    love.graphics.setScissor()
    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", gw, 0, W - gw, H)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.line(gw, 0, gw, H)
    love.graphics.setColor(1, 1, 1)
    drawPanel(w, 0);
    if winScreen then drawWin() end
end
