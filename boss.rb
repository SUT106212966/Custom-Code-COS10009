class Boss
  # Allow other files to access these variables (HP, x, y, etc.)
  attr_accessor :hp, :max_hp, :bullets, :x, :y, :width, :height, :current_pattern

  def initialize(settings)
    # --- 1. Position & Health ---
    @x = GameConfig::SCREEN_WIDTH - 140 # Position on right side
    @y = GameConfig::SCREEN_HEIGHT / 2  # Middle of screen vertically
    @max_hp = 100
    @hp = @max_hp
    
    # Load image (or use text 'F' if image is missing)
    @image = Gosu::Image.new('media/flower.png') rescue Gosu::Image.from_text('F', 40)
    
    # --- 2. Combat Variables ---
    @bullets = []           # Array to hold all active boss bullets
    @shoot_timer = 0        # Counts up to decide when to shoot
    @pattern_timer = 0      # Counts up to decide when to change attack
    @current_pattern = :circle # Starting move
    
    # Hitbox size (for logic, not visual)
    @width = 80
    @height = 80
    
    # --- 3. Unpack Settings (From Config File) ---
    # We take the rules from Easy/Medium/Hard and save them here.
    @difficulty_type = settings[:type]
    @bullet_speed_multiplier = settings[:boss_bullet_speed_mult]
    
    # .min and .max split the range (e.g., 300..500) into two numbers
    @pattern_change_min = settings[:boss_change_pattern_range].min
    @pattern_change_max = settings[:boss_change_pattern_range].max
    @shoot_delay_min = settings[:boss_shoot_delay_range].min
    @shoot_delay_max = settings[:boss_shoot_delay_range].max
    
    @bullet_count_multiplier = settings[:boss_bullet_count_mult]
    @bullet_base_range = settings[:boss_base_bullet_range]
    @available_patterns = settings[:boss_patterns] # List of moves allowed
  end

  def update(player_x, player_y)
    # Increase timers every frame (60 times/sec)
    @shoot_timer += 1
    @pattern_timer += 1
    
    # --- 1. Enrage Logic (Pattern Change) ---
    # Calculate HP percentage (0.0 to 1.0)
    hp_factor = @hp / @max_hp.to_f
    
    # If HP is below 30% (< 0.3), Boss gets angry!
    pattern_change_speed = if hp_factor < 0.3
        # Switch patterns 40% faster
        (@pattern_change_min * 0.6).to_i..(@pattern_change_max * 0.6).to_i
    else
        # Normal switching speed
        @pattern_change_min..@pattern_change_max
    end
    
    # Check if it's time to change attack pattern
    if @pattern_timer > rand(pattern_change_speed)
      @pattern_timer = 0
      # Pick a random move from the allowed list
      random_index = rand(@available_patterns.length)
      @current_pattern = @available_patterns[random_index]
    end

    # --- 2. Shooting Logic ---
    # As HP goes down, Speed goes UP. (1.0x -> 1.9x speed)
    speed_multiplier = 1 + (1 - hp_factor)
    
    # Calculate how long to wait before next shot
    delay = (@shoot_delay_min / speed_multiplier).to_i..(@shoot_delay_max / speed_multiplier).to_i
    
    if @shoot_timer > rand(delay)
      @shoot_timer = 0
      @animating = true
      # Create new bullets based on current pattern
      generate_bullets(@current_pattern, player_x, player_y)
    end

    # --- 3. Bullet Maintenance ---
    # Move every bullet and remove ones that went off-screen
    i = 0
    while i < @bullets.size
      @bullets[i].update
      if @bullets[i].off_screen?
        @bullets.delete_at(i)
      else
        i += 1
      end
    end
  end

  def generate_bullets(pattern, player_x, player_y)
    # Pick how many bullets to shoot (e.g., between 4 and 8)
    base_count = rand(@bullet_base_range)
    
    case pattern
    when :circle
      # --- PATTERN: Ring of Bullets ---
      bullet_count = (base_count * @bullet_count_multiplier).to_i
      i = 0
      while i < bullet_count
        # Divide 360 degrees (2*PI) by bullet count for even spacing
        angle = i * (2 * Math::PI / bullet_count)
        
        # Randomly pick Pollen (Low Dmg) or Petal (High Dmg)
        bullet_types = [:pollen, :petal]
        bullet_type = bullet_types[rand(bullet_types.length)]
        speed = (GameConfig::BOSS_BULLET_SPEED * @bullet_speed_multiplier) 
        
        # Create bullet and set velocity using Trig (Cos/Sin)
        bullet = Bullet.new(@x, @y, bullet_type)
        bullet.vx = Math.cos(angle) * speed
        bullet.vy = Math.sin(angle) * speed
        @bullets << bullet
        i += 1
      end
      
    when :spiral
      # --- PATTERN: Spinning Galaxy ---
      arm_count = 5
      # Add Time (milliseconds) to angle to make it spin
      spin_angle = Gosu.milliseconds / 200.0 
      
      i = 0
      while i < arm_count
        angle = (i * (2 * Math::PI / arm_count)) + spin_angle
        
        bullet = Bullet.new(@x, @y, :pollen)
        speed = GameConfig::BOSS_BULLET_SPEED * @bullet_speed_multiplier
        bullet.vx = Math.cos(angle) * speed
        bullet.vy = Math.sin(angle) * speed
        @bullets << bullet
        i += 1
      end
      
    when :wave
      # --- PATTERN: Wavy Wall ---
      bullet_count = (base_count * @bullet_count_multiplier).to_i
      vertical_spread = 40
      i = 0
      while i < bullet_count
        # Spread bullets vertically in a line
        offset_y = (i - bullet_count/2) * vertical_spread
        bullet = Bullet.new(@x, @y + offset_y, :petal)
        
        # Move Left, but use Sin(i) to create a wave shape
        bullet.vx = -GameConfig::BOSS_BULLET_SPEED * @bullet_speed_multiplier
        bullet.vy = Math.sin(i) * 0.5 
        @bullets << bullet
        i += 1
      end

    when :homing
      # --- PATTERN: Chasing Missiles ---
      bullet_count = (base_count * 0.5 * @bullet_count_multiplier).to_i
      i = 0
      while i < bullet_count
        offset_y = rand(-80..80)
        # Pass player position so bullet knows where to go
        @bullets << Bullet.new(@x, @y + offset_y, :pollen, player_x, player_y, homing: true)
        i += 1
      end

    when :shotgun
      # --- PATTERN: Cone Blast ---
      bullet_count = (base_count * 1.5 * @bullet_count_multiplier).to_i
      spread_angle = Math::PI / 3 # 60 degrees cone
      i = 0
      while i < bullet_count
        # Pick random angle inside the cone facing left
        angle = Math::PI + rand(-spread_angle/2..spread_angle/2) 
        speed = (GameConfig::BOSS_BULLET_SPEED * @bullet_speed_multiplier) * rand(1.0..1.5)
        
        bullet = Bullet.new(@x, @y, :petal)
        bullet.vx = Math.cos(angle) * speed
        bullet.vy = Math.sin(angle) * speed
        @bullets << bullet
        i += 1
      end

    when :random_spread
      # --- PATTERN: Messy Shooting ---
      bullet_count = (base_count * @bullet_count_multiplier).to_i
      i = 0
      while i < bullet_count
        # Completely random angle (0 to 360)
        angle = rand(0..2*Math::PI)
        speed = (GameConfig::BOSS_BULLET_SPEED * @bullet_speed_multiplier) * rand(0.8..1.2)
        
        bullet = Bullet.new(@x, @y, :pollen)
        bullet.vx = Math.cos(angle) * speed
        bullet.vy = Math.sin(angle) * speed
        @bullets << bullet
        i += 1
      end
      
    else 
      # --- SAFETY NET (Fallback) ---
      # If config asks for a missing pattern, shoot random bullets
      # so the game doesn't freeze.
      bullet_count = (base_count * @bullet_count_multiplier).to_i
      i = 0
      while i < bullet_count
          angle = rand(0..Math::PI*2)
          bullet = Bullet.new(@x, @y, :pollen)
          bullet.vx = Math.cos(angle) * 2
          bullet.vy = Math.sin(angle) * 2
          @bullets << bullet
          i += 1
      end
    end
  end

  def draw
    # 1. Draw Boss Image (Centered)
    @image.draw(@x - @image.width / 2, @y - @image.height / 2, 1)

    # 2. Draw Health Bar
    bar_width = 120
    bar_height = 8
    # Red Background
    Gosu.draw_rect(@x - bar_width / 2, @y - @image.height / 2 - 20, bar_width, bar_height, Gosu::Color::RED, 1)
    # Green Health (Shrinks as HP drops)
    Gosu.draw_rect(@x - bar_width / 2, @y - @image.height / 2 - 20, bar_width * (@hp / @max_hp.to_f), bar_height, Gosu::Color::GREEN, 1)
  end

  # --- HELPER FUNCTIONS ---
  
  # 1. Circle Collision Logic
  def hit_by?(sting)
    # Calculate Sting Center
    sx = sting.x + sting.width / 2
    sy = sting.y + sting.height / 2
    
    # Check distance between Boss Center (adjusted) and Sting Center
    # We use (+7, -20) to match the visual center of the flower
    dist = Math.sqrt(((@x + 7) - sx)**2 + ((@y - 20) - sy)**2)
    
    # Return TRUE if distance is less than combined radius
    return dist < (55 + 5) 
  end

  # 2. Helper to draw circles using lines
  def draw_debug_circle(cx, cy, r, color, z=100)
    points = 32
    step = 360.0 / points
    points.times do |i|
      angle1 = i * step
      angle2 = (i + 1) * step
      x1 = cx + Gosu.offset_x(angle1, r)
      y1 = cy + Gosu.offset_y(angle1, r)
      x2 = cx + Gosu.offset_x(angle2, r)
      y2 = cy + Gosu.offset_y(angle2, r)
      Gosu.draw_line(x1, y1, color, x2, y2, color, z)
    end
  end

  def take_damage(amount = 2)
    @hp -= amount
    @hp = 0 if @hp < 0
  end
end