local ball = { x = love.getWidth() / 2, y = love.getHeight(), r = 30 }
local jumpHeight = 200
local acceleration = -9.8
local prevTime = -1;
function love.mousepressed(x, y, button)
    local dx, dy = x - ball.x, y - ball.y                      -- how far the click is from the ball's centre
    local og = ball.y
    if button == 1 and dx * dx + dy * dy <= ball.r * ball.r then  -- is it inside the circle?
        while ball.y ~= og do
            ball.y = ball.y + acceleration
            acceleration = acceleration + 0.2
            if(ball.y <= love.getHeight()) then
                ball.y = love.getHeight()
            end
        end -- yes → launch the ball up
    end
end

function updateLoop()
    if (prevTime == -1) then
        prevTime = os.time();
    else
        -- Time loop thingie -- lkhk
        local curTime = os.time();
        local dt = prevTime - curTime;
        prevTime = curTime;
    end
end
