class Bullet
  attr_accessor :x, :y, :type, :damage, :vx, :vy, :homing, :blooming, :bloom_distance, :bloom_target_x, :bloom_target_y, :bloom_timer, :bounce_count, :off_screen_timer, :width, :height

  def initialize(x, y, type, target_x = nil, target_y = nil, pattern_data = {})
    @x = x
    @y = y
    @type = type
    @target_x = target_x
    @target_y = target_y
    @image = (type == :pollen ? (Gosu::Image.new('media/pollen.png') rescue Gosu::Image.from_text('o',14)) :
                                (Gosu::Image.new('media/petal.png')  rescue Gosu::Image.from_text('~',14)))
    @damage = type == :pollen ? rand(2..5) : rand(8..15)
    
    @vx = 0
    @vy = 0
    @homing = pattern_data[:homing] || false
    @blooming = pattern_data[:blooming] || false
    @bloom_distance = pattern_data[:bloom_distance] || 200
    @bloom_target_x = target_x
    @bloom_target_y = target_y
    @bloom_timer = 0
    @angle = 0
    @time = 0
    @bounce_count = 0
    @max_bounces = 2
    @off_screen_timer = 0
    @width = @image.width
    @height = @image.height
    
    initialize_velocity(pattern_data)
  end

  def initialize_velocity(pattern_data)
    case @type
    when :pollen
      if @homing && !@blooming
        @vx = -BOSS_BULLET_SPEED * 0.7
        @vy = 0
      elsif @blooming
        @vx = -BOSS_BULLET_SPEED * 0.8
        @vy = 0
      else
        @vx = -BOSS_BULLET_SPEED
        @vy = 0
      end
    when :petal
      if pattern_data[:angle]
        angle = pattern_data[:angle]
        speed_variation = pattern_data[:speed_variation] || 1.0
        @vx = Math.cos(angle) * BOSS_BULLET_SPEED * speed_variation
        @vy = Math.sin(angle) * BOSS_BULLET_SPEED * speed_variation
      else
        @vx = -BOSS_BULLET_SPEED * rand(0.9..1.1)
        @vy = rand(-1.5..1.5)
      end
    end
  end

  def update
    @time += 1
    
    if @x < -50
      @off_screen_timer += 1
    else
      @off_screen_timer = 0
    end
    
    return if @off_screen_timer > 180
    
    case @type
    when :pollen
      if @homing && @target_x && @target_y
        if @blooming
          distance_to_target = distance(@x, @y, @target_x, @target_y)
          
          if distance_to_target > @bloom_distance && @bloom_timer == 0
            dx = @target_x - @x
            dy = @target_y - @y
            dist = Math.sqrt(dx**2 + dy**2)
            if dist > 0
              homing_strength = [1.5, 8.0 / dist].min
              @vx += (dx / dist) * 0.08 * homing_strength
              @vy += (dy / dist) * 0.08 * homing_strength
              
              speed = Math.sqrt(@vx**2 + @vy**2)
              if speed > BOSS_BULLET_SPEED * 1.3
                @vx = (@vx / speed) * BOSS_BULLET_SPEED * 1.3
                @vy = (@vy / speed) * BOSS_BULLET_SPEED * 1.3
              end
            end
          else
            @bloom_timer += 1
            if @bloom_timer == 1
              @bloom_target_x = @target_x
              @bloom_target_y = @target_y
              @vx += rand(-1.5..1.5)
              @vy += rand(-1.5..1.5)
            elsif @bloom_timer > 30
              dx = @bloom_target_x - @x
              dy = @bloom_target_y - @y
              dist = Math.sqrt(dx**2 + dy**2)
              if dist > 0
                @vx += (dx / dist) * 0.1
                @vy += (dy / dist) * 0.1
              end
            end
          end
        else
          dx = @target_x - @x
          dy = @target_y - @y
          dist = Math.sqrt(dx**2 + dy**2)
          if dist > 0
            homing_strength = [1.5, 8.0 / dist].min
            @vx += (dx / dist) * 0.08 * homing_strength
            @vy += (dy / dist) * 0.08 * homing_strength
            
            speed = Math.sqrt(@vx**2 + @vy**2)
            if speed > BOSS_BULLET_SPEED * 1.3
              @vx = (@vx / speed) * BOSS_BULLET_SPEED * 1.3
              @vy = (@vy / speed) * BOSS_BULLET_SPEED * 1.3
            end
          end
        end
      end
      
    when :petal
      # if @time < 120
      #   @vy += Math.sin(@time * 0.1) * 0.3
      # end
    end
    
    if @x > SCREEN_WIDTH - 20 && @vx > 0 && @bounce_count < @max_bounces
      @vx = -@vx * 0.8
      @bounce_count += 1
    end
    
    if (@y < 10 && @vy < 0) || (@y > SCREEN_HEIGHT - 10 && @vy > 0)
      @vy = -@vy * 0.8
    end
    
    @x += @vx
    @y += @vy
  end

  def draw
    @image.draw(@x, @y, 1)
  end

  def off_screen?
    @off_screen_timer > 180 || @x < -200 || @x > SCREEN_WIDTH + 200 || @y < -200 || @y > SCREEN_HEIGHT + 200
  end

  def distance(x1, y1, x2, y2)
    Math.sqrt((x1 - x2)**2 + (y1 - y2)**2)
  end
end