require 'gosu'
# Load all your other files here
require_relative 'config'
require_relative 'bullet'
require_relative 'player'
require_relative 'boss'
require_relative 'prop'

class GameWindow < Gosu::Window
  def initialize
    super(GameConfig::SCREEN_WIDTH, GameConfig::SCREEN_HEIGHT)
    self.caption = "Pollen Requiem"

    # --- 1. Game State Setup ---
    @game_state = :menu 
    @difficulty_settings = GameConfig.medium_settings 
    
    # Load all images into a Hash (Dictionary)
    @images = load_images
    
    # Fonts for text
    @font = Gosu::Font.new(20)
    @title_font = Gosu::Font.new(40)
    
    # Menu variables
    @menu_option = 0
    @victory_option = 0
    @hit_effect_timer = 0
    
    # Initialize the game objects
    reset_game
  end

  def load_images
    # Loading images safely. If a file is missing, it creates a text placeholder.
    {
      sky: (Gosu::Image.new('media/sky.png') rescue Gosu::Image.new(GameConfig::SCREEN_WIDTH, GameConfig::SCREEN_HEIGHT, Gosu::Color.new(0xFF87CEEB))),
      land: (Gosu::Image.new('media/land.png') rescue Gosu::Image.new(GameConfig::SCREEN_WIDTH, GameConfig::SCREEN_HEIGHT, Gosu::Color.new(0xFF228B22))),
      bee: (Gosu::Image.new('media/bee.png') rescue Gosu::Image.from_text('🐝', 28)),
      sting: (Gosu::Image.new('media/sting.png') rescue Gosu::Image.from_text('-', 14)),
      pollen: (Gosu::Image.new('media/fpollen.png') rescue Gosu::Image.from_text('o', 12)),
      petal: (Gosu::Image.new('media/petal.png') rescue Gosu::Image.from_text('~', 12)),
      flower: (Gosu::Image.new('media/flower.png') rescue Gosu::Image.from_text('F', 28)),
      bubble: (Gosu::Image.new('media/bubble.png') rescue nil),
      bubble_pop: (Gosu::Image.load_tiles('media/bubble_pop.png', 64, 64, tileable: false) rescue [])
    }
  end

  def reset_game
    # Create the Player and Boss objects
    @player = Player.new(100, GameConfig::SCREEN_HEIGHT / 2, @images, @difficulty_settings)
    @boss = Boss.new(@difficulty_settings)
    
    # Arrays to hold multiple objects
    @bee_stings = []
    @props = []
    
    @prop_spawn_rate = @difficulty_settings[:prop_spawn_rate]
    
    # Background scrolling variables
    @sky = @images[:sky]
    @land = @images[:land]
    @sky_x = 0

    @hit_effect_timer = 0
  end

  # This loop runs 60 times per second
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

  # --- MENU LOGIC ---
  def update_menu
    # Handle Up/Down keys to select difficulty
    if button_down?(Gosu::KB_DOWN) && @menu_option < 2
      @menu_option += 1
      sleep(0.15) # Small delay so it doesn't scroll too fast
    elsif button_down?(Gosu::KB_UP) && @menu_option > 0
      @menu_option -= 1
      sleep(0.15)
    end
    
    # Handle Enter key to start game
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

  # --- GAMEPLAY LOGIC ---
  def update_game
    # Update Player and Boss behavior
    @player.update(self, @bee_stings)
    @boss.update(@player.x, @player.y)

    # Move Player Bullets (Stings) and remove off-screen ones
    i = 0
    while i < @bee_stings.length
      @bee_stings[i].update
      if @bee_stings[i].off_screen?
        @bee_stings.delete_at(i)
      else
        i += 1
      end
    end

    # Move Props and remove off-screen ones
    i = 0
    while i < @props.length
      @props[i].update
      if @props[i].off_screen?
        @props.delete_at(i)
      else
        i += 1
      end
    end

    # Scroll the background
    @sky_x -= 1
    @sky_x = 0 if @sky_x <= -GameConfig::SCREEN_WIDTH

    # Randomly spawn Power-ups (Hearts/Shields)
    if rand < @prop_spawn_rate
      safe_x = rand(50..550)
      @props << Prop.new(safe_x, 0, [:heart, :shield].sample)
    end
    
    # --- COLLISION: Player vs Boss Bullets ---
    bullets_dup = @boss.bullets.dup
    i = 0
    while i < bullets_dup.length
      bullet = bullets_dup[i]
      
      # Using the Player's custom Circle Collision method
      if @player.collides_with_bullet?(bullet)
        if @player.take_damage(bullet.damage)
          @hit_effect_timer = 10 # Trigger blood effect
          if @player.hp <= 0
            @game_state = :game_over
          end
        end
        @boss.bullets.delete(bullet)
      end
      i += 1
    end

    # --- COLLISION: Player Bullets vs Boss ---
    stings_dup = @bee_stings.dup
    i = 0
    while i < stings_dup.length
      sting = stings_dup[i]
      
      # 1. Check if Sting hit a Boss Bullet (Destroy bullet)
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

      # 2. Check if Sting hit the Boss (Using Boss Circle Logic)
      if @boss.hit_by?(sting)
        @boss.take_damage
        @bee_stings.delete(sting)
        
        if @boss.hp <= 0
          @game_state = :victory
        end
      end
      i += 1
    end

    # --- COLLISION: Player vs Props ---
    props_dup = @props.dup
    i = 0
    while i < props_dup.length
      prop = props_dup[i]
      
      # Updated numbers (74, 32) to match your new Body Center!
      if collision_rect?(@player.x + 74, @player.y + 32, 40, 40,
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
    
    @title_font.draw_text("Pollen Requiem", GameConfig::SCREEN_WIDTH/2 - 130, 100, 1, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Choose Difficulty:", GameConfig::SCREEN_WIDTH/2 - 80, 180, 1, 1, 1, Gosu::Color::BLACK)
    
    difficulties = ["Easy", "Medium", "Hard"]
    i = 0
    while i < difficulties.length
      color = @menu_option == i ? Gosu::Color::YELLOW : Gosu::Color::BLACK
      y_pos = 230 + i * 50
      @font.draw_text("#{difficulties[i]}", GameConfig::SCREEN_WIDTH/2 - 30, y_pos, 1, 1, 1, color)
      i += 1
    end
    
    @font.draw_text("Use UP/DOWN to select, ENTER to start", GameConfig::SCREEN_WIDTH/2 - 150, 400, 1, 1, 1, Gosu::Color::BLACK)
    
    # Draw Instruction Box
    box_x = 20
    box_y = 150
    box_width = 180  
    box_height = 300 
    bg_color = Gosu::Color.new(200, 255, 255, 255) 
    text_color = Gosu::Color::BLACK

    draw_quad(box_x, box_y, bg_color,
              box_x + box_width, box_y, bg_color,
              box_x + box_width, box_y + box_height, bg_color,
              box_x, box_y + box_height, bg_color, 0)

    # Draw Instructions Text...
    padding = 15
    current_y = box_y + padding
    @font.draw_text("CONTROLS:", box_x + padding, current_y, 1, 1.0, 1.0, text_color)
    current_y += 40
    @font.draw_text("Move: Arrow Keys", box_x + padding, current_y, 1, 0.8, 0.8, text_color)
    current_y += 25
    @font.draw_text("<-  ^  v  ->", box_x + padding, current_y, 1, 0.8, 0.8, text_color)
    current_y += 40
    @font.draw_text("Shoot: Spacebar", box_x + padding, current_y, 1, 0.8, 0.8, text_color)
    current_y += 25
    @font.draw_text("Shoots bee stings in a", box_x + padding, current_y, 1, 0.7, 0.7, text_color)
    current_y += 20
    @font.draw_text("horizontal line.", box_x + padding, current_y, 1, 0.7, 0.7, text_color)
    current_y += 35
    @font.draw_text("NOTE:", box_x + padding, current_y, 1, 0.8, 0.8, Gosu::Color::RED)
    current_y += 25
    @font.draw_text("Bullets can destroy", box_x + padding, current_y, 1, 0.7, 0.7, text_color)
    current_y += 20
    @font.draw_text("enemy projectiles and", box_x + padding, current_y, 1, 0.7, 0.7, text_color)
    current_y += 20
    @font.draw_text("reduce Boss HP.", box_x + padding, current_y, 1, 0.7, 0.7, text_color)
  end

  def draw_game
    # Draw Background
    sky_scale_x = GameConfig::SCREEN_WIDTH / @sky.width.to_f
    sky_scale_y = GameConfig::SCREEN_WIDTH / @sky.height.to_f
    @sky.draw(@sky_x, 0, 0, sky_scale_x, sky_scale_y)
    @sky.draw(@sky_x + GameConfig::SCREEN_WIDTH, 0, 0, sky_scale_x, sky_scale_y)

    land_scale_x = GameConfig::SCREEN_WIDTH / @land.width.to_f
    land_scale_y = GameConfig::SCREEN_HEIGHT / @land.height.to_f
    @land.draw(0, 450, 1, land_scale_x, land_scale_y)

    # Draw Damage Effect (Blood)
    if @hit_effect_timer > 0
      i = 0
      while i < 12
        color = Gosu::Color.new(150, 255, 0, 0)
        # Using 94 and 52 to match the new body position!
        r_x = (@player.x + 94) + rand(-20..20)
        r_y = (@player.y + 52) + rand(-20..20)
        
        Gosu.draw_rect(r_x, r_y, 4, 4, color, 3)
        i += 1
      end
    end

    # Draw Entities
    @player.draw
    @boss.draw
    
    # Draw loops for bullets and props
    i = 0
    while i < @bee_stings.length
      @bee_stings[i].draw
      i += 1
    end
    
    i = 0
    while i < @boss.bullets.length
      @boss.bullets[i].draw
      i += 1
    end
    
    i = 0
    while i < @props.length
      @props[i].draw
      i += 1
    end

    # Draw UI (Health Bars and Text)
    @font.draw_text("HP: #{@player.hp}/#{@player.max_hp}", 10, 10, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Boss HP: #{@boss.hp}/#{@boss.max_hp}", 10, 32, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Difficulty: #{@difficulty_settings[:type].to_s.capitalize}", 10, 54, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Bullets: #{@boss.bullets.size}", 10, 76, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Pattern: #{@boss.current_pattern}", 10, 98, 3, 1, 1, Gosu::Color::BLACK) if @boss.current_pattern
  end

  # Draw Game Over Screen
  def draw_game_over
    Gosu.draw_rect(0, 0, GameConfig::SCREEN_WIDTH, GameConfig::SCREEN_HEIGHT, Gosu::Color.new(150, 0, 0, 0), 10)
    @title_font.draw_text("YOU LOSE!", GameConfig::SCREEN_WIDTH/2 - 100, 200, 11, 1, 1, Gosu::Color::RED)
    @font.draw_text("Press ESC to return to Main Menu", GameConfig::SCREEN_WIDTH/2 - 140, 400, 11)
  end

  # Draw Victory Screen
  def draw_victory
    Gosu.draw_rect(0, 0, GameConfig::SCREEN_WIDTH, GameConfig::SCREEN_HEIGHT, Gosu::Color.new(150, 0, 100, 0), 10)
    @title_font.draw_text("VICTORY!", GameConfig::SCREEN_WIDTH/2 - 90, 150, 11, 1, 1, Gosu::Color::GREEN)
    @font.draw_text("Press ENTER to Play Again", GameConfig::SCREEN_WIDTH/2 - 120, 350, 11, 1, 1, Gosu::Color::RED)
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

  # Helper method for simple rectangular collision (Used for Props and Bullet-on-Bullet)
  private
  def collision_rect?(x1, y1, w1, h1, x2, y2, w2, h2)
    (x1 < x2 + w2) && (x1 + w1 > x2) && (y1 < y2 + h2) && (y1 + h1 > y2)
  end
end

GameWindow.new.show