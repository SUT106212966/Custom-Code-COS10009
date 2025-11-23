class Player
  attr_accessor :x, :y, :speed, :hp, :max_hp, :immune_until, :shield_until, :width, :height

  def initialize(x, y, images, settings)
    @x = x
    @y = y
    @speed = 8
    
    @max_hp = settings[:player_hp]
    @shoot_delay = settings[:player_shoot_delay]
    
    @hp = @max_hp
    @immune_until = 0
    @shield_until = 0
    
    @image = images[:bee]
    @sting_animation = images[:sting_animation] || []
    
    # --- NEW BUBBLE VARIABLES ---
    @bubble_image = images[:bubble]
    @bubble_pop_frames = images[:bubble_pop] || []
    @bubble_pop_index = 0
    @bubble_animating = false # Is the bubble currently popping?
    
    @animating = false
    @animation_frame = 0
    @shoot_cooldown = 0
    
    @width = 60
    @height = 40
  end

  def update(window, global_bee_stings)
    # Movement
    @x -= @speed if window.button_down?(Gosu::KB_LEFT)
    @x += @speed if window.button_down?(Gosu::KB_RIGHT)
    @y -= @speed if window.button_down?(Gosu::KB_UP)
    @y += @speed if window.button_down?(Gosu::KB_DOWN)

    @x = [[@x, 0].max, SCREEN_WIDTH - @width].min
    @y = [[@y, 0].max, SCREEN_HEIGHT - @height].min

    # Shooting
    @shoot_cooldown -= 1 if @shoot_cooldown > 0
    if Gosu.button_down?(Gosu::KB_SPACE) && @shoot_cooldown <= 0
      global_bee_stings << BeeSting.new(@x + 50, @y + 25)
      @shoot_cooldown = @shoot_delay
      @animating = true
    end

    # Timers
    @immune_until -= 1 if @immune_until > 0
    
    # --- SHIELD LOGIC ---
    if @shield_until > 0
      @shield_until -= 1
      
      # If shield is about to run out (last 30 frames / 0.5 seconds), start popping
      if @shield_until < 30 && !@bubble_animating
        @bubble_animating = true
        @bubble_pop_index = 0
      end
      
      # If popping, advance the animation frame
      if @bubble_animating
        # Change frame every 5 game ticks to make it visible
        if @shield_until % 5 == 0
          @bubble_pop_index += 1
        end
      end
    else
      # Reset bubble state when shield is gone
      @bubble_animating = false
    end

    # Shooting Animation
    if @animating
      @animation_frame += 1
      @animating = false if @animation_frame >= @sting_animation.size
    end
  end

  def draw
    # --- DRAW BUBBLE SHIELD ---
    if @shield_until > 0
      if @bubble_animating
        # Draw the POP animation
        if @bubble_pop_index < @bubble_pop_frames.size
          img = @bubble_pop_frames[@bubble_pop_index]
          # Center the pop over the bee (adjust -10 or +10 to align perfectly)
          img.draw(@x - 10, @y - 10, 2) if img
        end
      else
        # Draw the STATIC bubble wrapping the bee
        if @bubble_image
          # Draw it slightly larger than the bee, pulsing slightly
          pulse = 1.0 + Math.sin(Gosu.milliseconds / 200.0) * 0.05
          # Offset x/y to center the bubble on the bee
          @bubble_image.draw_rot(@x + @width/2, @y + @height/2, 2, 0, 0.5, 0.5, pulse, pulse)
        else
          # Fallback if image fails to load: Draw Blue Circle
          color = Gosu::Color.new(100, 0, 0, 255) # Transparent Blue
          Gosu.draw_rect(@x - 5, @y - 5, @width + 10, @height + 10, color, 2)
        end
      end
    end

    # Draw Player Bee
    color = if @immune_until > 0
              flash = (Gosu.milliseconds / 100) % 2 == 0
              flash ? Gosu::Color::YELLOW : Gosu::Color::WHITE
            else
              Gosu::Color::WHITE
            end
            
    @image.draw(@x, @y, 1, 1, 1, color)

    # Sparkle effect
    if @animating
      8.times do
        color = Gosu::Color.new(200, rand(255), rand(255), rand(255))
        Gosu.draw_rect(@x + rand(-18..18), @y + rand(-18..18), 3, 3, color, 2)
      end
    end
  end

  def take_damage(amount)
    return false if @immune_until > 0 || @shield_until > 0
    @hp -= amount
    @hp = 0 if @hp < 0
    @immune_until = 15
    true
  end

  def heal(amount)
    @hp += amount
    @hp = @max_hp if @hp > @max_hp
  end

  def activate_shield
    @shield_until = 180 # Shield lasts 3 seconds (60 frames * 3)
    @bubble_animating = false # Reset animation state
    @bubble_pop_index = 0
  end

  def collides_with_bullet?(bullet)
    body_collision = collision_rect?(@x + 20, @y + 10, 20, 20, bullet.x, bullet.y, bullet.width, bullet.height)
    left_wing_collision = collision_rect?(@x + 5, @y + 8, 15, 24, bullet.x, bullet.y, bullet.width, bullet.height)
    right_wing_collision = collision_rect?(@x + 40, @y + 8, 15, 24, bullet.x, bullet.y, bullet.width, bullet.height)
    body_collision || left_wing_collision || right_wing_collision
  end

  private
  def collision_rect?(x1, y1, w1, h1, x2, y2, w2, h2)
    (x1 < x2 + w2) && (x1 + w1 > x2) && (y1 < y2 + h2) && (y1 + h1 > y2)
  end
end

class BeeSting
  attr_accessor :x, :y, :width, :height

  def initialize(x, y)
    @x = x
    @y = y
    @image = Gosu::Image.new('media/sting.png') rescue Gosu::Image.from_text('*', 20)
    @width = 8
    @height = 8
  end

  def update
    @x += BULLET_SPEED
  end

  def draw
    @image.draw(@x, @y, 1)
  end

  def off_screen?
    @x > SCREEN_WIDTH
  end
end