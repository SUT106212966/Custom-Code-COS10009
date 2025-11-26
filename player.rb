class Player
  # Allow other files to read these variables (Position, HP, Speed, etc.)
  attr_accessor :x, :y, :speed, :hp, :max_hp, :immune_until, :shield_until, :width, :height

  def initialize(x, y, images, settings)
    # --- 1. Position & Speed ---
    @x = x
    @y = y
    @speed = 8 # How many pixels the bee moves per frame
    
    # --- 2. Stats from Config ---
    @max_hp = settings[:player_hp]
    @shoot_delay = settings[:player_shoot_delay]
    
    @hp = @max_hp
    @immune_until = 0 # Timer for "Invincibility Frames" after getting hit
    @shield_until = 0 # Timer for how long the Bubble Shield lasts
    
    # --- 3. Graphics ---
    @image = images[:bee]
    @sting_animation = images[:sting_animation] || []
    
    # Bubble Shield Graphics
    @bubble_image = images[:bubble]
    @bubble_pop_frames = images[:bubble_pop] || []
    @bubble_pop_index = 0
    @bubble_animating = false 
    
    # Shooting Animation Variables
    @animating = false
    @animation_frame = 0
    @shoot_cooldown = 0
    
    @width = 60
    @height = 40
  end

  def update(window, global_bee_stings)
    # --- 1. Movement Logic ---
    # Check if arrow keys are pressed and move X/Y accordingly
    @x -= @speed if window.button_down?(Gosu::KB_LEFT)
    @x += @speed if window.button_down?(Gosu::KB_RIGHT)
    @y -= @speed if window.button_down?(Gosu::KB_UP)
    @y += @speed if window.button_down?(Gosu::KB_DOWN)

    # Keep player inside the screen (Boundary Check)
    # [min, max] logic prevents the bee from flying off-screen
    @x = [[@x, 0].max, GameConfig::SCREEN_WIDTH - @width].min
    @y = [[@y, 0].max, GameConfig::SCREEN_HEIGHT - @height].min

    # --- 2. Shooting Logic ---
    @shoot_cooldown -= 1 if @shoot_cooldown > 0
    
    # If SPACE is pressed and Cooldown is finished
    if Gosu.button_down?(Gosu::KB_SPACE) && @shoot_cooldown <= 0
      # Create a new BeeSting bullet at the bee's nose
      global_bee_stings << BeeSting.new(@x + 50, @y + 25)
      @shoot_cooldown = @shoot_delay
      @animating = true # Start the sparkle animation
    end

    # --- 3. Timers ---
    @immune_until -= 1 if @immune_until > 0
    
    # --- 4. Shield Animation Logic ---
    if @shield_until > 0
      @shield_until -= 1
      
      # If shield is almost gone (last 0.5 seconds), play POP animation
      if @shield_until < 30 && !@bubble_animating
        @bubble_animating = true
        @bubble_pop_index = 0
      end
      
      # Advance the "Pop" animation frame every 5 ticks
      if @bubble_animating
        if @shield_until % 5 == 0
          @bubble_pop_index += 1
        end
      end
    else
      @bubble_animating = false
    end

    # Shooting Animation (Sparkles)
    if @animating
      @animation_frame += 1
      @animating = false if @animation_frame >= @sting_animation.length
    end
  end

  def draw
    # --- 1. Draw Bubble Shield ---
    if @shield_until > 0
      if @bubble_animating
        # Draw the "POP" animation when shield breaks
        if @bubble_pop_index < @bubble_pop_frames.length
          img = @bubble_pop_frames[@bubble_pop_index]
          if img
             # Calculate center based on Image dimensions
             bee_center_x = @x + (@image.width / 2)
             bee_center_y = @y + (@image.height / 2)
             img.draw(bee_center_x - (img.width / 2), bee_center_y - (img.height / 2), 2)
          end
        end
      else
        # Draw the static "Floating" Bubble
        if @bubble_image
          # Make the bubble pulse (grow/shrink) using Math.sin
          pulse = 1.0 + Math.sin(Gosu.milliseconds / 200.0) * 0.05
          center_x = @x + (@image.width / 2)
          center_y = @y + (@image.height / 2)
          
          # Draw rotated/scaled bubble
          @bubble_image.draw_rot(center_x, center_y, 2, 0, 0.5, 0.5, pulse, pulse)
        else
          # Fallback (Red Box) if image fails to load
          c = Gosu::Color.new(100, 0, 0, 255) 
          Gosu.draw_rect(@x-5, @y-5, @width+10, @height+10, c, 2)
        end
      end
    end

    # --- 2. Draw Player Bee ---
    # Flash Yellow if immune (took damage recently)
    color = (@immune_until > 0 && (Gosu.milliseconds / 100) % 2 == 0) ? Gosu::Color::YELLOW : Gosu::Color::WHITE
    @image.draw(@x, @y, 1, 1, 1, color)
    
    # --- 3. Draw Shooting Sparkles ---
    if @animating
      i = 0
      while i < 8
        c = Gosu::Color.new(200, rand(255), rand(255), rand(255))
        
        # Sparkles appear at the STINGER position (New Hitbox Center)
        # We add 94 and 52 to align with the hitbox
        rx = (@x + 94) + rand(-18..18)
        ry = (@y + 52) + rand(-18..18)

        Gosu.draw_rect(rx, ry, 3, 3, c, 2)
        i += 1
      end
    end
  end

  # ==========================================
  # COLLISION LOGIC (The Important Math)
  # ==========================================
  def collides_with_bullet?(bullet)
    # Get the center and radius of the enemy bullet
    bx = bullet.x + bullet.width / 2
    by = bullet.y + bullet.height / 2
    br = bullet.width / 2

    # Check 3 separate circles to make a precise hitbox:
    
    # 1. Body Circle (The Main Body)
    if distance(@x + 94, @y + 52, bx, by) < (21 + br)
      return true
    end

    # 2. Left Wing Circle
    if distance(@x + 43, @y + 27, bx, by) < (10 + br)
      return true
    end

    # 3. Right Wing Circle
    if distance(@x + 68, @y + 20, bx, by) < (8 + br)
      return true
    end

    return false
  end

  def take_damage(amount)
    # Don't take damage if Shield is active OR if Immune
    return false if @immune_until > 0 || @shield_until > 0
    
    @hp -= amount
    @hp = 0 if @hp < 0
    @immune_until = 15 # Give brief invincibility
    true
  end

  def heal(amount)
    @hp += amount
    @hp = @max_hp if @hp > @max_hp # Don't go over Max HP
  end

  def activate_shield
    @shield_until = 180 # Shield lasts 3 seconds (60 frames * 3)
    @bubble_animating = false 
    @bubble_pop_index = 0
  end

  private

  # Helper: Pythagoras Theorem to calculate distance between two points
  def distance(x1, y1, x2, y2)
    Math.sqrt((x1 - x2)**2 + (y1 - y2)**2)
  end
end

# ==========================================
# BEE STING CLASS (Player Bullet)
# ==========================================
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
    # Move bullet to the Right
    @x += GameConfig::BULLET_SPEED
  end

  def draw
    @image.draw(@x, @y, 1)
  end

  # Check if bullet flew off the screen so we can delete it
  def off_screen?
    @x > GameConfig::SCREEN_WIDTH
  end
end