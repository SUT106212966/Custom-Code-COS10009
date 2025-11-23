class Boss
  attr_accessor :hp, :max_hp, :bullets, :x, :y, :width, :height, :current_pattern

  def initialize(settings)
    @x = SCREEN_WIDTH - 140
    @y = SCREEN_HEIGHT / 2
    @max_hp = 100
    @hp = @max_hp
    @image = Gosu::Image.new('media/flower.png') rescue Gosu::Image.from_text('F', 40)
    @bullets = []
    @shoot_timer = 0
    @animating = false
    @pattern_timer = 0
    @current_pattern = :circle
    @width = 80
    @height = 80
    
    @difficulty_type = settings[:type]
    @bullet_speed_multiplier = settings[:boss_bullet_speed_mult]
    @pattern_change_min = settings[:boss_change_pattern_range].min
    @pattern_change_max = settings[:boss_change_pattern_range].max
    @shoot_delay_min = settings[:boss_shoot_delay_range].min
    @shoot_delay_max = settings[:boss_shoot_delay_range].max
    @bullet_count_multiplier = settings[:boss_bullet_count_mult]
    @bullet_base_range = settings[:boss_base_bullet_range]
    @available_patterns = settings[:boss_patterns]
  end

  def update(player_x, player_y)
    @shoot_timer += 1
    @pattern_timer += 1
    
    # Pattern Logic
    hp_factor = @hp / @max_hp.to_f
    pattern_change_speed = if hp_factor < 0.3
                             (@pattern_change_min * 0.6).to_i..(@pattern_change_max * 0.6).to_i
                           else
                             @pattern_change_min..@pattern_change_max
                           end
    
    if @pattern_timer > rand(pattern_change_speed)
      @pattern_timer = 0
      @current_pattern = @available_patterns.sample
    end

    # Shooting Speed Logic
    speed_multiplier = 1 + (1 - hp_factor)
    delay = (@shoot_delay_min / speed_multiplier).to_i..(@shoot_delay_max / speed_multiplier).to_i
    
    if @shoot_timer > rand(delay)
      @shoot_timer = 0
      @animating = true
      generate_bullets(@current_pattern, player_x, player_y)
    end

    @bullets.each(&:update)
    @bullets.reject!(&:off_screen?)
  end

  def generate_bullets(pattern, player_x, player_y)
    base_count = rand(@bullet_base_range)
    
    case pattern
    when :circle
      bullet_count = (base_count * @bullet_count_multiplier).to_i
      bullet_count.times do |i|
        angle = i * (2 * Math::PI / bullet_count) # Perfect spacing
        bullet_type = [:pollen, :petal].sample
        speed = (BOSS_BULLET_SPEED * @bullet_speed_multiplier) 
        
        bullet = Bullet.new(@x, @y, bullet_type)
        bullet.vx = Math.cos(angle) * speed
        bullet.vy = Math.sin(angle) * speed
        @bullets << bullet
      end
      
    when :spiral
      bullet_count = (base_count * 0.7 * @bullet_count_multiplier).to_i
      base_angle = Gosu.milliseconds / 100.0 
      bullet_count.times do |i|
        angle = base_angle + (i * 0.5) 
        bullet = Bullet.new(@x, @y, :pollen)
        speed = (BOSS_BULLET_SPEED * @bullet_speed_multiplier)
        bullet.vx = Math.cos(angle) * speed
        bullet.vy = Math.sin(angle) * speed
        @bullets << bullet
      end
      
    when :wave
      bullet_count = (base_count * @bullet_count_multiplier).to_i
      vertical_spread = 40
      bullet_count.times do |i|
        offset_y = (i - bullet_count/2) * vertical_spread
        bullet = Bullet.new(@x, @y + offset_y, :petal)
        bullet.vx = -BOSS_BULLET_SPEED * @bullet_speed_multiplier
        bullet.vy = Math.sin(i) * 0.5 
        @bullets << bullet
      end

    when :homing
      bullet_count = (base_count * 0.5 * @bullet_count_multiplier).to_i
      bullet_count.times do
        offset_y = rand(-80..80)
        @bullets << Bullet.new(@x, @y + offset_y, :pollen, player_x, player_y, homing: true)
      end

    when :shotgun
      bullet_count = (base_count * 1.5 * @bullet_count_multiplier).to_i
      spread_angle = Math::PI / 3 
      bullet_count.times do
        angle = Math::PI + rand(-spread_angle/2..spread_angle/2) 
        speed = (BOSS_BULLET_SPEED * @bullet_speed_multiplier) * rand(1.0..1.5)
        bullet = Bullet.new(@x, @y, :petal)
        bullet.vx = Math.cos(angle) * speed
        bullet.vy = Math.sin(angle) * speed
        @bullets << bullet
      end

    when :random_spread
      bullet_count = (base_count * @bullet_count_multiplier).to_i
      bullet_count.times do
        angle = rand(0..2*Math::PI)
        speed = (BOSS_BULLET_SPEED * @bullet_speed_multiplier) * rand(0.8..1.2)
        bullet = Bullet.new(@x, @y, :pollen)
        bullet.vx = Math.cos(angle) * speed
        bullet.vy = Math.sin(angle) * speed
        @bullets << bullet
      end

    when :double_circle
      2.times do |circle|
        offset = circle * (Math::PI / base_count) 
        bullet_count = (base_count * @bullet_count_multiplier).to_i
        bullet_count.times do |i|
          angle = i * (2 * Math::PI / bullet_count) + offset
          bullet = Bullet.new(@x, @y, :pollen)
          speed = (BOSS_BULLET_SPEED * @bullet_speed_multiplier) * 0.8
          bullet.vx = Math.cos(angle) * speed
          bullet.vy = Math.sin(angle) * speed
          @bullets << bullet
        end
      end
      
    # For any other pattern, fallback to basic spiral/spread
    else 
        bullet_count = (base_count * @bullet_count_multiplier).to_i
        bullet_count.times do
            angle = rand(0..Math::PI*2)
            bullet = Bullet.new(@x, @y, :pollen)
            bullet.vx = Math.cos(angle) * 2
            bullet.vy = Math.sin(angle) * 2
            @bullets << bullet
        end
    end
  end

  def draw
    @image.draw(@x - @image.width / 2, @y - @image.height / 2, 1)
    bar_width = 120
    bar_height = 8
    Gosu.draw_rect(@x - bar_width / 2, @y - @image.height / 2 - 20, bar_width, bar_height, Gosu::Color::RED)
    Gosu.draw_rect(@x - bar_width / 2, @y - @image.height / 2 - 20, bar_width * (@hp / @max_hp.to_f), bar_height, Gosu::Color::GREEN)
  end

  def take_damage(amount = 2)
    @hp -= amount
    @hp = 0 if @hp < 0
  end
end