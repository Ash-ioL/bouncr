love.getWidth = love.graphics.getWidth
love.getHeight = love.graphics.getHeight

local ball = { x = love.getWidth() / 2, y = love.getHeight(), r = 30 }
local jumpHeight = 200
local acceleration = -9.8
local prevTime = -1;
function love.mousepressed(x, y, button)
    local dx, dy = x - ball.x, y - ball.y
    local og = ball.y
    if button == 1 and dx * dx + dy * dy <= ball.r * ball.r then
        squishLaunch()
        while ball.y ~= og do
            ball.y = ball.y + acceleration
            acceleration = acceleration + 0.2
            if(ball.y <= love.getHeight()) then
                ball.y = love.getHeight()
                squishLand()
            end
        end
    end
end

function updateLoop()
    if (prevTime == -1) then
        prevTime = os.time();
    else
        local curTime = os.time();
        local dt = prevTime - curTime;
        prevTime = curTime;
    end
    squishUpdate()
end

local squish = { sx = 1, sy = 1 }
local drops = {}

function squishLand(x, y)
  squish.sx, squish.sy = 1.4, 0.6
  for i = 1, 12 do
    local angle = math.pi + love.math.random() * math.pi
    local speed = love.math.random(100, 300)
    table.insert(drops, { x = x, y = y, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed, life = 1 })
  end
end

function squishLaunch()
  squish.sx, squish.sy = 0.7, 1.3
end

function squishUpdate(dt)
  squish.sx = squish.sx + (1 - squish.sx) * 10 * dt
  squish.sy = squish.sy + (1 - squish.sy) * 10 * dt
  for i = #drops, 1, -1 do
    local d = drops[i]
    d.vy = d.vy + 800 * dt
    d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
    d.life = d.life - dt
    if d.life <= 0 then table.remove(drops, i) end
  end
end

function drawSpeedLines()
    local vel = ball.vy;
    local fac = 0.1;
    love.graphics.setColor(1, 1, 1, 1)
    local x1 = ball.x - 20;
    local x2 = ball.x;
    local x3 = ball.x + 20;
    local y1 = ball.y - 10;
    local y2 = y1 - math.abs(vel) * fac;
    local floorY = love.getHeight() - ball.r - 50;
    if vel < 0 then
        y1 = ball.y + math.abs(ball.y - y1);
        y2 = ball.y + math.abs(ball.y - y2);
        y2 = math.min(floorY, y2);
    end

    love.graphics.print("Velocity: " .. math.floor(vel), 50, 50);

    love.graphics.line(x1, y1, x1, y2);
    love.graphics.line(x2, y1, x2, y2);
    love.graphics.line(x3, y1, x3, y2);
end

function squishDraw(ball)
    love.graphics.push()
    love.graphics.translate(ball.x, ball.y + ball.r)
    love.graphics.scale(squish.sx, squish.sy)
    love.graphics.circle("fill", 0, -ball.r, ball.r)
    love.graphics.pop()
    for _, d in ipairs(drops) do
        love.graphics.setColor(1, 1, 1, d.life)
        love.graphics.circle("fill", d.x, d.y, 4)
    end
    love.graphics.setColor(1, 1, 1, 1)
    drawSpeedLines()
end

local GRAVITY, JUMP = 1500, 1600
local floorY = love.getHeight() - ball.r
ball.y = floorY
ball.vy = 0
local cam = 0
local following = false
local SUPER, TIMING = JUMP * 1.4, 0.15
local clock, lastClick, landTime, tried = 0, -1, -1, false

local yourMousepressed = love.mousepressed
function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  y = y + cam
  if ball.y < floorY then
    if not tried then lastClick, tried = clock, true end
    return
  end
  local dx, dy = x - ball.x, y - ball.y
  if dx * dx + dy * dy <= ball.r * ball.r then
    yourMousepressed(x, y, button)
    local onTime = not tried and clock - landTime <= TIMING
    ball.vy = onTime and -SUPER or -JUMP
    tried = false
  end
end

function love.update(dt)
  clock = clock + dt
  ball.x = love.getWidth() / 2
  floorY = love.getHeight() - ball.r - 50
  local wasInAir = ball.y < floorY
  ball.vy = ball.vy + GRAVITY * dt
  ball.y = ball.y + ball.vy * dt
  if ball.y - ball.r < 0 then following = true end
  if ball.y >= floorY then
    ball.y, ball.vy = floorY, 0
    following = false
    if wasInAir then
      squishLand(ball.x, ball.y + ball.r)
      landTime = clock
      if clock - lastClick <= TIMING then
        squishLaunch()
        ball.vy = -SUPER
        tried = false
      end
    end
  end
  squishUpdate(dt)
  local target = following and math.min(0, ball.y - floorY) or 0
  cam = math.max(target, cam + (target - cam) * math.min(1, 5 * dt))
end

function love.draw()
  love.graphics.clear(0.08, 0.08, 0.14)
  love.graphics.translate(0, -cam)
  love.graphics.setColor(1, 1, 1, 0.15)
  for y = math.floor(cam / 100) * 100, cam + love.getHeight(), 100 do
    love.graphics.line(0, y, love.getWidth(), y)
  end
  love.graphics.setColor(0.2, 0.6, 1)
  love.graphics.rectangle("fill", 0, floorY + ball.r, love.getWidth(), love.getHeight())
  love.graphics.setColor(1, 1, 1)
  squishDraw(ball)
end

local font = love.graphics.newFont(28)

function love.draw()
  love.graphics.clear(0.08, 0.08, 0.14)
  love.graphics.translate(0, -cam)
  love.graphics.setColor(1, 1, 1, 0.15)
  for y = math.floor(cam / 100) * 100, cam + love.getHeight(), 100 do
    love.graphics.line(0, y, love.getWidth(), y)
  end
  love.graphics.setColor(0.2, 0.6, 1)
  love.graphics.rectangle("fill", 0, floorY + ball.r, love.getWidth(), love.getHeight())
  love.graphics.setColor(1, 1, 1)
  squishDraw(ball)

  love.graphics.origin()
  love.graphics.setFont(font)
  love.graphics.print("Height: " .. math.floor((floorY - ball.y) / 10) .. " m", 50, 100)
end
