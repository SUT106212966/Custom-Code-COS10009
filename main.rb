require 'gosu'
# Load all your other files here
require_relative 'config'
require_relative 'bullet'
require_relative 'player'
require_relative 'boss'
require_relative 'prop'

class GameWindow < Gosu::Window
  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT)
    self.caption = "Pollen Requiem"
    
    @game_state = :menu 
    @difficulty_settings = GameConfig.medium_settings 
    @images = load_images
    @font = Gosu::Font.new(20)
    @title_font = Gosu::Font.new(40)
    @menu_option = 0
    @victory_option = 0
    @hit_effect_timer = 0
    
    reset_game
  end

  def load_images
    {
      # Added 'media/' in front of every file name
      sky: (Gosu::Image.new('media/sky.png') rescue Gosu::Image.new(SCREEN_WIDTH, SCREEN_HEIGHT, Gosu::Color.new(0xFF87CEEB))),
      land: (Gosu::Image.new('media/land.png') rescue Gosu::Image.new(SCREEN_WIDTH, SCREEN_HEIGHT, Gosu::Color.new(0xFF228B22))),
      bee: (Gosu::Image.new('media/bee.png') rescue Gosu::Image.from_text('🐝', 28)),
      sting: (Gosu::Image.new('media/sting.png') rescue Gosu::Image.from_text('-', 14)),
      pollen: (Gosu::Image.new('media/fpollen.png') rescue Gosu::Image.from_text('o', 12)),
      petal: (Gosu::Image.new('media/petal.png') rescue Gosu::Image.from_text('~', 12)),
      flower: (Gosu::Image.new('media/flower.png') rescue Gosu::Image.from_text('F', 28)),
      # REMOVED CLOUD HERE
      bubble: (Gosu::Image.new('media/bubble.png') rescue nil),
      bubble_pop: (Gosu::Image.load_tiles('media/bubble_pop.png', 64, 64, tileable: false) rescue [])
    }
  end

  def reset_game
    @player = Player.new(100, SCREEN_HEIGHT / 2, @images, @difficulty_settings)
    @boss = Boss.new(@difficulty_settings)
    @bee_stings = []
    @props = []
    
    @prop_spawn_rate = @difficulty_settings[:prop_spawn_rate]
    
    @sky = @images[:sky]
    @land = @images[:land]
    @sky_x = 0
    
    # REMOVED CLOUD SETUP LOOP HERE

    @hit_effect_timer = 0
  end

  def update
    case @game_state
    when :menu
      update_menu
    when :playing
      update_game
    when :game_over
      update_game_over
    when :victory
      update_victory
    end
  end

  def update_menu
    if button_down?(Gosu::KB_DOWN) && @menu_option < 2
      @menu_option += 1
      sleep(0.15)
    elsif button_down?(Gosu::KB_UP) && @menu_option > 0
      @menu_option -= 1
      sleep(0.15)
    end
    
    if button_down?(Gosu::KB_RETURN)
      case @menu_option
      when 0
        @difficulty_settings = GameConfig.easy_settings
        start_game
      when 1
        @difficulty_settings = GameConfig.medium_settings
        start_game
      when 2
        @difficulty_settings = GameConfig.hard_settings
        start_game
      end
    end
  end

  def update_game
    @player.update(self, @bee_stings)
    @boss.update(@player.x, @player.y)

    # Update bee stings with while loop
    i = 0
    while i < @bee_stings.length
      @bee_stings[i].update
      i += 1
    end
    
    # Remove off-screen bee stings with while loop
    i = 0
    while i < @bee_stings.length
      if @bee_stings[i].off_screen?
        @bee_stings.delete_at(i)
      else
        i += 1
      end
    end

    # Update props with while loop
    i = 0
    while i < @props.length
      @props[i].update
      i += 1
    end
    
    # Remove off-screen props with while loop
    i = 0
    while i < @props.length
      if @props[i].off_screen?
        @props.delete_at(i)
      else
        i += 1
      end
    end

    @sky_x -= 1
    @sky_x = 0 if @sky_x <= -SCREEN_WIDTH

    # REMOVED CLOUD MOVEMENT LOOP HERE

    if rand < @prop_spawn_rate
      safe_x = rand(50..550)
      @props << Prop.new(safe_x, 0, [:heart, :shield].sample)
    end
    
    # Boss bullets collision with while loop
    bullets_dup = @boss.bullets.dup
    i = 0
    while i < bullets_dup.length
      bullet = bullets_dup[i]
      if @player.collides_with_bullet?(bullet)
        if @player.take_damage(bullet.damage)
          @hit_effect_timer = 10
          if @player.hp <= 0
            @game_state = :game_over
          end
        end
        @boss.bullets.delete(bullet)
      end
      i += 1
    end

    # Bee stings vs boss bullets collision with while loop
    stings_dup = @bee_stings.dup
    i = 0
    while i < stings_dup.length
      sting = stings_dup[i]
      bullets_dup = @boss.bullets.dup
      j = 0
      while j < bullets_dup.length
        bullet = bullets_dup[j]
        if collision_rect?(sting.x, sting.y, sting.width, sting.height,
                           bullet.x, bullet.y, bullet.width, bullet.height)
          @boss.bullets.delete(bullet)
          @bee_stings.delete(sting)
          break
        end
        j += 1
      end

      if collision_rect?(sting.x, sting.y, sting.width, sting.height,
                         @boss.x - @boss.width/2, @boss.y - @boss.height/2, @boss.width, @boss.height)
        @boss.take_damage
        @bee_stings.delete(sting)
        
        if @boss.hp <= 0
          @game_state = :victory
        end
      end
      i += 1
    end

    # Props collision with while loop
    props_dup = @props.dup
    i = 0
    while i < props_dup.length
      prop = props_dup[i]
      if collision_rect?(@player.x + 5, @player.y + 5, @player.width - 10, @player.height - 5,
                         prop.x, prop.y, prop.width, prop.height)
        if prop.type == :heart
          @player.heal(20)
        else
          @player.activate_shield
        end
        @props.delete(prop)
      end
      i += 1
    end

    @hit_effect_timer -= 1 if @hit_effect_timer > 0
  end

  def update_game_over
    if button_down?(Gosu::KB_ESCAPE)
      @game_state = :menu
      @menu_option = 0
    end
  end

  def update_victory
    if button_down?(Gosu::KB_RETURN)
      start_game
      sleep(0.2)
    end
  end

  def start_game
    reset_game
    @game_state = :playing
  end

  def draw
    case @game_state
    when :menu
      draw_menu
    when :playing
      draw_game
    when :game_over
      draw_game_over
    when :victory
      draw_victory
    end
  end

  def draw_menu
    @sky.draw(0, 0, 0)
    
    @title_font.draw_text("Pollen Requiem", SCREEN_WIDTH/2 - 130, 100, 1, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Choose Difficulty:", SCREEN_WIDTH/2 - 80, 180, 1, 1, 1, Gosu::Color::BLACK)
    
    difficulties = ["Easy", "Medium", "Hard"]
    i = 0
    while i < difficulties.length
      color = @menu_option == i ? Gosu::Color::YELLOW : Gosu::Color::BLACK
      y_pos = 230 + i * 50
      @font.draw_text("#{difficulties[i]}", SCREEN_WIDTH/2 - 30, y_pos, 1, 1, 1, color)
      i += 1
    end
    
    @font.draw_text("Use UP/DOWN to select, ENTER to start", SCREEN_WIDTH/2 - 150, 400, 1, 1, 1, Gosu::Color::BLACK)
  end

  def draw_game
    sky_scale_x = SCREEN_WIDTH / @sky.width.to_f
    sky_scale_y = SCREEN_HEIGHT / @sky.height.to_f
    @sky.draw(@sky_x, 0, 0, sky_scale_x, sky_scale_y)
    @sky.draw(@sky_x + SCREEN_WIDTH, 0, 0, sky_scale_x, sky_scale_y)

    # REMOVED CLOUD DRAWING LOOP HERE

    land_scale_x = SCREEN_WIDTH / @land.width.to_f
    land_scale_y = SCREEN_HEIGHT / @land.height.to_f
    @land.draw(0, 450, 1, land_scale_x, land_scale_y)

    if @hit_effect_timer > 0
      i = 0
      while i < 12
        color = Gosu::Color.new(150, 255, 0, 0)
        Gosu.draw_rect(@player.x + rand(-30..30), @player.y + rand(-30..30), 4, 4, color, 3)
        i += 1
      end
    end

    @player.draw
    @boss.draw
    
    # Draw bee stings with while loop
    i = 0
    while i < @bee_stings.length
      @bee_stings[i].draw
      i += 1
    end
    
    # Draw boss bullets with while loop
    i = 0
    while i < @boss.bullets.length
      @boss.bullets[i].draw
      i += 1
    end
    
    # Draw props with while loop
    i = 0
    while i < @props.length
      @props[i].draw
      i += 1
    end

    # --- CHANGED TO BLACK FONT HERE ---
    # format: draw_text(text, x, y, z, scale_x, scale_y, color)
    @font.draw_text("HP: #{@player.hp}/#{@player.max_hp}", 10, 10, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Boss HP: #{@boss.hp}/#{@boss.max_hp}", 10, 32, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Difficulty: #{@difficulty_settings[:type].to_s.capitalize}", 10, 54, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Bullets: #{@boss.bullets.size}", 10, 76, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Pattern: #{@boss.current_pattern}", 10, 98, 3, 1, 1, Gosu::Color::BLACK) if @boss.current_pattern
  end

  def draw_game_over
    Gosu.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, Gosu::Color.new(150, 0, 0, 0), 10)
    
    @title_font.draw_text("YOU LOSE!", SCREEN_WIDTH/2 - 120, 200, 11, 1, 1, Gosu::Color::RED)
    @font.draw_text("Your bee couldn't survive the flower's attack!", SCREEN_WIDTH/2 - 180, 270, 11)
    @font.draw_text("Difficulty: #{@difficulty_settings[:type].to_s.capitalize}", SCREEN_WIDTH/2 - 70, 320, 11)
    
    @font.draw_text("Press ESC to return to Main Menu", SCREEN_WIDTH/2 - 140, 400, 11)
  end

  def draw_victory
    Gosu.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, Gosu::Color.new(150, 0, 100, 0), 10)
    
    @title_font.draw_text("VICTORY!", SCREEN_WIDTH/2 - 90, 150, 11, 1, 1, Gosu::Color::GREEN)
    @font.draw_text("Congratulations! You defeated the evil flower!", SCREEN_WIDTH/2 - 190, 220, 11)
    @font.draw_text("Your bee saved the day!", SCREEN_WIDTH/2 - 100, 260, 11)
    @font.draw_text("Difficulty: #{@difficulty_settings[:type].to_s.capitalize}", SCREEN_WIDTH/2 - 70, 300, 11)
    
    @font.draw_text("Press ENTER to Play Again", SCREEN_WIDTH/2 - 120, 350, 11, 1, 1, Gosu::Color::RED)
    @font.draw_text("Press ESC to return to Main Menu", SCREEN_WIDTH/2 - 140, 400, 11)
  end

  def button_down(id)
    case id
    when Gosu::KB_ESCAPE
      if @game_state == :playing || @game_state == :game_over || @game_state == :victory
        @game_state = :menu
        @menu_option = 0
      else
        close
      end
    end
  end

  private

  def collision_rect?(x1, y1, w1, h1, x2, y2, w2, h2)
    (x1 < x2 + w2) && (x1 + w1 > x2) && (y1 < y2 + h2) && (y1 + h1 > y2)
  end

  def distance(x1, y1, x2, y2)
    Math.sqrt((x1 - x2)**2 + (y1 - y2)**2)
  end
end

GameWindow.new.show