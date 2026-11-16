love.getWidth = love.graphics.getWidth
love.getHeight = love.graphics.getHeight

local ball = { x = 0, y = 0, vy = 0, r = 30 }
local GRAVITY, JUMP = 1500, 1600
local SUPER, TIMING = JUMP * 1.4, 0.15
local floorY = 0
local cam, following = 0, false
local clock, lastClick, landTime, tried = 0, -1, -1, false
local squish = { sx = 1, sy = 1 }
local drops = {}
local bigFont = love.graphics.newFont(44)
local smallFont = love.graphics.newFont(16)

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
end

local function startImpact()
  fx.t, fx.freeze, fx.shake = 0, FREEZE, 18
  fx.x, fx.y = ball.x, floorY + ball.r
  fx.seed = love.math.random(1, 1000000)
end

function love.load()
  ball.x = gameW() / 2
  floorY = love.getHeight() - ball.r - 100
  ball.y = floorY
  loadClouds()
end

function love.mousepressed(x, y, button)
  if button ~= 1 or x >= gameW() then return end
  y = y + cam
  if ball.y < floorY then
    if not tried then lastClick, tried = clock, true end
    return
  end
  local dx, dy = x - ball.x, y - ball.y
  if dx * dx + dy * dy <= ball.r * ball.r then
    squishLaunch()
    local onTime = not tried and clock - landTime <= TIMING
    ball.vy = onTime and -SUPER or -JUMP
    tried = false
  end
end

function love.update(dt)
  fx.t = fx.t + dt
  fx.shake = math.max(0, fx.shake - dt * 40)
  if fx.freeze > 0 then fx.freeze = fx.freeze - dt return end

  clock = clock + dt
  ball.x = gameW() / 2
  floorY = love.getHeight() - ball.r - 100
  local wasInAir = ball.y < floorY
  ball.vy = ball.vy + GRAVITY * dt
  ball.y = ball.y + ball.vy * dt
  if ball.y - ball.r < 0 then following = true end
  if ball.y >= floorY then
    ball.y, ball.vy = floorY, 0
    following = false
    if wasInAir then
      squishLand(ball.x, ball.y + ball.r)
      startImpact()
      landTime = clock
      if clock - lastClick <= TIMING then
        squishLaunch()
        ball.vy = -SUPER
        tried = false
      end
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

local function inkText(text, font, x, y, t)
  love.graphics.setFont(font)
  love.graphics.setColor(INK)
  for ox = -t, t do
    for oy = -t, t do
      love.graphics.print(text, x + ox, y + oy)
    end
  end
  love.graphics.setColor(PAPER)
  love.graphics.print(text, x, y)
end

local function drawHeight()
  local h = math.max(0, math.floor((floorY - ball.y) / 10))
  local text = h .. "m"
  local hit = fx.t < 0.3 and 3 or 0
  love.graphics.push()
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

function drawUpgrade(startX, startY, cost)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", startX + (1 / 16) * w, startY, w - (1 / 8) * w, (3 / 4) * h, 10, 10);
    love.graphics.setColor(0.5, 0.5, 0.5);
    love.graphics.rectangle("fill", startX + w/16 + h / 8, startY + h/8, h / 2, h / 2, 10, 10);
    love.graphics.circle("fill", startX + 15 * w / 16 - 5 * h / 16, startY + 3 * h / 8, h / 4);

    love.graphics.print("Upgrade Name", smallFont, startX + w / 16 + h / 2 + 10, startY + h / 8 + 5);
    love.graphics.print("Cost: " .. cost, smallFont, startX + 15 * w / 16 - 5 * h / 16 - smallFont:getWidth("Cost: 100") / 2, startY + 3 * h / 8 + h / 4 + 5);
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
    addCloud(cloudTop)
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


function drawPanel(startX, startY)
    -- top is title + line
    drawTitle(startX, 0);
    -- top middle is velocity upgrades
    drawUpgrade(startX, h, 100);
    -- bottom middle is combo upgrades
    drawUpgrade(startX, 2 * h, 100);
    -- bottom is money upgrades
    drawUpgrade(startX, 3 * h, 100);
end



function love.draw()

    local W, H = love.getWidth(), love.getHeight()
    local gw = gameW()
    local top = cam - 60

    local srng = love.math.newRandomGenerator(fx.seed + math.floor(fx.t * 24))
    local sx = (srng:random() * 2 - 1) * fx.shake
    local sy = (srng:random() * 2 - 1) * fx.shake

    love.graphics.clear(love.math.colorFromBytes(0x68, 0xb0, 0xab))
    love.graphics.setScissor(0, 0, gw, H)
    love.graphics.setLineJoin("bevel")
    love.graphics.translate(sx, sy - cam)
    drawClouds()

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
    love.graphics.setColor(1, 1, 1)
    drawHeight()
    love.graphics.setScissor()
    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", gw, 0, W - gw, H)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.line(gw, 0, gw, H)
    love.graphics.setColor(1, 1, 1)
    drawPanel(w, 0);
end
