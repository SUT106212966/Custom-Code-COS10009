class Bullet
  # Allow other files to read/write these variables
  attr_accessor :x, :y, :type, :damage, :vx, :vy, :homing, :blooming, :bloom_distance, :bloom_target_x, :bloom_target_y, :bloom_timer, :bounce_count, :off_screen_timer, :width, :height

  def initialize(x, y, type, target_x = nil, target_y = nil, pattern_data = {})
    @x = x
    @y = y
    @type = type # :pollen or :petal
    @target_x = target_x # Player's X position (for homing)
    @target_y = target_y # Player's Y position (for homing)
    
    # --- 1. Load Image Based on Type ---
    # If type is :pollen, load pollen.png. Otherwise, load petal.png.
    @image = (type == :pollen ? (Gosu::Image.new('media/pollen.png') rescue Gosu::Image.from_text('o',14)) :
                                (Gosu::Image.new('media/petal.png')  rescue Gosu::Image.from_text('~',14)))
                                
    # --- 2. Set Damage ---
    # Pollen does low damage (2-5), Petal does high damage (8-15)
    @damage = type == :pollen ? rand(2..5) : rand(8..15)
    
    @vx = 0 # Velocity X (Horizontal speed)
    @vy = 0 # Velocity Y (Vertical speed)
    
    # --- 3. Special Behaviors ---
    @homing = pattern_data[:homing] || false     # Does it chase the player?
    @blooming = pattern_data[:blooming] || false # Does it stop and explode?
    
    # Timers and counters
    @bloom_timer = 0
    @time = 0
    @bounce_count = 0
    @max_bounces = 2 # Bullet can bounce off walls 2 times max
    @off_screen_timer = 0
    
    # Hitbox size
    @width = @image.width
    @height = @image.height
    
    # Calculate starting speed/direction
    initialize_velocity(pattern_data)
  end

  def initialize_velocity(pattern_data)
    case @type
    when :pollen
      # Pollen usually moves straight Left
      if @homing && !@blooming
        @vx = -GameConfig::BOSS_BULLET_SPEED * 0.7 # Homing bullets are slightly slower
        @vy = 0
      else
        @vx = -GameConfig::BOSS_BULLET_SPEED # Standard speed left
        @vy = 0
      end
      
    when :petal
      # Petals usually move at specific angles (Trigonometry)
      if pattern_data[:angle]
        angle = pattern_data[:angle]
        speed_variation = pattern_data[:speed_variation] || 1.0
        
        # Math.cos/sin converts an Angle (degrees) into X and Y movement
        @vx = Math.cos(angle) * GameConfig::BOSS_BULLET_SPEED * speed_variation
        @vy = Math.sin(angle) * GameConfig::BOSS_BULLET_SPEED * speed_variation
      else
        # If no angle given, just shoot randomly left
        @vx = -GameConfig::BOSS_BULLET_SPEED * rand(0.9..1.1)
        @vy = rand(-1.5..1.5)
      end
    end
  end

  # This runs every single frame (60 times a second)
  def update
    @time += 1
    
    # --- 1. Check if Bullet is Off Screen ---
    if @x < -50
      @off_screen_timer += 1
    else
      @off_screen_timer = 0
    end
    
    # If bullet has been off-screen for 3 seconds (180 frames), stop updating
    return if @off_screen_timer > 180
    
    # --- 2. Homing Logic (The Chasing Math) ---
    case @type
    when :pollen
      if @homing && @target_x && @target_y
        
        # Calculate distance to player (Pythagoras Theorem)
        dx = @target_x - @x
        dy = @target_y - @y
        dist = Math.sqrt(dx**2 + dy**2)
        
        if dist > 0
           # Calculate how hard to turn (Steering force)
           homing_strength = [1.5, 8.0 / dist].min
           
           # Adjust Velocity (Steer towards player)
           @vx += (dx / dist) * 0.08 * homing_strength
           @vy += (dy / dist) * 0.08 * homing_strength
           
           # Limit max speed so it doesn't accelerate forever
           speed = Math.sqrt(@vx**2 + @vy**2)
           if speed > GameConfig::BOSS_BULLET_SPEED * 1.3
             @vx = (@vx / speed) * GameConfig::BOSS_BULLET_SPEED * 1.3
             @vy = (@vy / speed) * GameConfig::BOSS_BULLET_SPEED * 1.3
           end
        end
      end
    end
    
    # --- 3. Wall Bouncing Logic ---
    # If it hits the Right Wall...
    if @x > GameConfig::SCREEN_WIDTH - 20 && @vx > 0 && @bounce_count < @max_bounces
      @vx = -@vx * 0.8 # Reverse direction and slow down
      @bounce_count += 1
    end
    
    # If it hits Top or Bottom Wall...
    if (@y < 10 && @vy < 0) || (@y > GameConfig::SCREEN_HEIGHT - 10 && @vy > 0)
      @vy = -@vy * 0.8 # Reverse direction and slow down
    end
    
    # --- 4. Apply Movement ---
    @x += @vx
    @y += @vy
  end

  def draw
    @image.draw(@x, @y, 1)
  end

  # Helper to check if bullet is too far away to matter
  def off_screen?
    @off_screen_timer > 180 || @x < -200 || @x > GameConfig::SCREEN_WIDTH + 200 || @y < -200 || @y > GameConfig::SCREEN_HEIGHT + 200
  end

  # Helper Math Function
  def distance(x1, y1, x2, y2)
    Math.sqrt((x1 - x2)**2 + (y1 - y2)**2)
  end
end