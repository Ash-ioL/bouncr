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
end

local GRAVITY, JUMP = 1500, 900
local floorY = love.getHeight() - ball.r
ball.y = floorY
ball.vy = 0

local yourMousepressed = love.mousepressed
function love.mousepressed(x, y, button)
  yourMousepressed(x, y, button)
  local dx, dy = x - ball.x, y - ball.y
  if button == 1 and dx * dx + dy * dy <= ball.r * ball.r then
    ball.vy = -JUMP
  end
end

function love.update(dt)
  local wasInAir = ball.y < floorY
  ball.vy = ball.vy + GRAVITY * dt
  ball.y = ball.y + ball.vy * dt
  if ball.y >= floorY then
    if wasInAir then squishLand(ball.x, ball.y + ball.r) end
    ball.y, ball.vy = floorY, 0
  end
  squishUpdate(dt)
end

function love.draw()
  squishDraw(ball)
end
