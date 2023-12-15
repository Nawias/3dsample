local baton = require"baton"

local input = baton.new {
    controls = {
        lookleft = {'key:left'},
        lookright = {'key:right'},
        lookup = {'key:up'},
        lookdown = {'key:down'},
        left = {'key:a'},
        right = {'key:d'},
        up = {'key:w'},
        down = {'key:s'},
    },
    pairs={
        move = {'left','right','up','down'},
        look = {'lookleft','lookright','lookup','lookdown'}
    },
    joystick = love.joystick.getJoysticks()[1],
}

function love.load()

end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    end

end


function love.update(dt)
    input:update()
end

function love.draw()
    -- Draw grid
    love.graphics.setColor(1,1,1,1)
end

