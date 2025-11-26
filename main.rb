require 'gosu'
require_relative 'config'
require_relative 'bullet'
require_relative 'player'
require_relative 'boss'
require_relative 'prop'

class GameWindow < Gosu::Window
  def initialize
    # Set the screen size using our Config constants
    super(GameConfig::SCREEN_WIDTH, GameConfig::SCREEN_HEIGHT)
    self.caption = "Pollen Requiem"

    # --- 1. Setup Game State ---
    @game_state = :menu  # Start on the Menu screen
    @difficulty_settings = GameConfig.medium_settings 
    
    # Load all images into a Hash (Dictionary) for easy access
    @images = load_images
    
    # Create fonts for text display
    @font = Gosu::Font.new(20)
    @title_font = Gosu::Font.new(40)
    
    # Variables for menu selection and visual effects
    @menu_option = 0
    @victory_option = 0
    @hit_effect_timer = 0
    
    # Setup the actual game objects (Player, Boss, etc.)
    reset_game
  end

  def load_images
    # We use a Hash to store images. Key = Name, Value = Image File.
    # The 'rescue' part creates a backup image/text if the file is missing.
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
    # Create or Reset the main actors
    @player = Player.new(100, GameConfig::SCREEN_HEIGHT / 2, @images, @difficulty_settings)
    @boss = Boss.new(@difficulty_settings)
    
    # Clear all bullets and props (Empty Arrays)
    @bee_stings = []
    @props = []
    
    @prop_spawn_rate = @difficulty_settings[:prop_spawn_rate]
    
    # Reset background position
    @sky = @images[:sky]
    @land = @images[:land]
    @sky_x = 0

    @hit_effect_timer = 0
  end

  # --- MAIN GAME LOOP (Runs 60 times/second) ---
  def update
    # Check which screen we are on and run the correct logic
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
    # Navigate Menu (Up/Down)
    if button_down?(Gosu::KB_DOWN) && @menu_option < 2
      @menu_option += 1
      sleep(0.15) # Small delay to prevent fast scrolling
    elsif button_down?(Gosu::KB_UP) && @menu_option > 0
      @menu_option -= 1
      sleep(0.15)
    end
    
    # Select Difficulty (Enter)
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
    # 1. Update Entity Logic (Movement, AI)
    @player.update(self, @bee_stings)
    @boss.update(@player.x, @player.y)

    # 2. Update & Clean Up Player Bullets
    # We use a while loop so we can safely delete items while iterating
    i = 0
    while i < @bee_stings.length
      @bee_stings[i].update
      if @bee_stings[i].off_screen?
        @bee_stings.delete_at(i) # Remove if it flew away
      else
        i += 1
      end
    end
    
    # 3. Update & Clean Up Props (Hearts/Shields)
    i = 0
    while i < @props.length
      @props[i].update
      if @props[i].off_screen?
        @props.delete_at(i)
      else
        i += 1
      end
    end

    # 4. Scroll Background
    @sky_x -= 1
    @sky_x = 0 if @sky_x <= -GameConfig::SCREEN_WIDTH

    # 5. Randomly Spawn Power-ups
    if rand < @prop_spawn_rate
      safe_x = rand(50..550)
      @props << Prop.new(safe_x, 0, [:heart, :shield].sample)
    end
    
    # --- COLLISION A: Boss Bullets hitting Player ---
    bullets_dup = @boss.bullets.dup
    i = 0
    while i < bullets_dup.length
      bullet = bullets_dup[i]
      # Ask Player class: "Did this bullet hit you?" (Uses Circle Math)
      if @player.collides_with_bullet?(bullet)
        if @player.take_damage(bullet.damage)
          @hit_effect_timer = 10 # Start blood effect
          if @player.hp <= 0
            @game_state = :game_over
          end
        end
        @boss.bullets.delete(bullet) # Destroy the bullet that hit
      end
      i += 1
    end

    # --- COLLISION B: Player Stings hitting Boss/Bullets ---
    stings_dup = @bee_stings.dup
    i = 0
    while i < stings_dup.length
      sting = stings_dup[i]
      
      # Check if sting hit an enemy bullet (Defense)
      bullets_dup = @boss.bullets.dup
      j = 0
      while j < bullets_dup.length
        bullet = bullets_dup[j]
        # Simple Rectangle check for bullet-on-bullet collision
        if collision_rect?(sting.x, sting.y, sting.width, sting.height,
                           bullet.x, bullet.y, bullet.width, bullet.height)
          @boss.bullets.delete(bullet)
          @bee_stings.delete(sting)
          break
        end
        j += 1
      end

      # Check if sting hit the Boss (Offense)
      # Uses Boss's Circle Hitbox logic
      if @boss.hit_by?(sting)
        @boss.take_damage
        @bee_stings.delete(sting)
        
        if @boss.hp <= 0
          @game_state = :victory
        end
      end
      i += 1
    end

    # --- COLLISION C: Player hitting Props ---
    props_dup = @props.dup
    i = 0
    while i < props_dup.length
      prop = props_dup[i]
      # Check if player collected item (Using offset to match Body position)
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

    # Countdown for Blood Effect
    @hit_effect_timer -= 1 if @hit_effect_timer > 0
  end

  def update_game_over
    # Press ESC to restart
    if button_down?(Gosu::KB_ESCAPE)
      @game_state = :menu
      @menu_option = 0
    end
  end

  def update_victory
    # Press Enter to play again
    if button_down?(Gosu::KB_RETURN)
      start_game
      sleep(0.2)
    end
  end

  def start_game
    reset_game # Wipe variables clean
    @game_state = :playing # Switch screen
  end

  # --- DRAWING LOGIC ---
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
    
    # Draw Title
    @title_font.draw_text("Pollen Requiem", GameConfig::SCREEN_WIDTH/2 - 130, 100, 1, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Choose Difficulty:", GameConfig::SCREEN_WIDTH/2 - 80, 180, 1, 1, 1, Gosu::Color::BLACK)
    
    # Draw Difficulty Options (Highlight selected one Yellow)
    difficulties = ["Easy", "Medium", "Hard"]
    i = 0
    while i < difficulties.length
      color = @menu_option == i ? Gosu::Color::YELLOW : Gosu::Color::BLACK
      y_pos = 230 + i * 50
      @font.draw_text("#{difficulties[i]}", GameConfig::SCREEN_WIDTH/2 - 30, y_pos, 1, 1, 1, color)
      i += 1
    end
    
    @font.draw_text("Use UP/DOWN to select, ENTER to start", GameConfig::SCREEN_WIDTH/2 - 150, 400, 1, 1, 1, Gosu::Color::BLACK)
    
    # --- Draw Instructions Box (Left Side) ---
    box_x = 20
    box_y = 150
    box_width = 180  
    box_height = 300 
    
    bg_color = Gosu::Color.new(200, 255, 255, 255) # Semi-transparent white
    text_color = Gosu::Color::BLACK

    # Draw the white background box
    draw_quad(box_x, box_y, bg_color,
              box_x + box_width, box_y, bg_color,
              box_x + box_width, box_y + box_height, bg_color,
              box_x, box_y + box_height, bg_color,
              0)

    # Draw the instruction text inside the box
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
    # Draw Background (Sky + Land)
    sky_scale_x = GameConfig::SCREEN_WIDTH / @sky.width.to_f
    sky_scale_y = GameConfig::SCREEN_WIDTH / @sky.height.to_f
    @sky.draw(@sky_x, 0, 0, sky_scale_x, sky_scale_y)
    @sky.draw(@sky_x + GameConfig::SCREEN_WIDTH, 0, 0, sky_scale_x, sky_scale_y)

    land_scale_x = GameConfig::SCREEN_WIDTH / @land.width.to_f
    land_scale_y = GameConfig::SCREEN_HEIGHT / @land.height.to_f
    @land.draw(0, 450, 1, land_scale_x, land_scale_y)

    # Draw Blood Effect if player was hit recently
    if @hit_effect_timer > 0
      i = 0
      while i < 12
        color = Gosu::Color.new(150, 255, 0, 0)
        # Draw random red squares near the Player's Body
        r_x = (@player.x + 94) + rand(-20..20)
        r_y = (@player.y + 52) + rand(-20..20)
        
        Gosu.draw_rect(r_x, r_y, 4, 4, color, 3)
        i += 1
      end
    end

    # Draw the main actors
    @player.draw
    @boss.draw
    
    # Draw loops for all bullets and items
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

    # Draw UI (Heads Up Display)
    @font.draw_text("HP: #{@player.hp}/#{@player.max_hp}", 10, 10, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Boss HP: #{@boss.hp}/#{@boss.max_hp}", 10, 32, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Difficulty: #{@difficulty_settings[:type].to_s.capitalize}", 10, 54, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Bullets: #{@boss.bullets.size}", 10, 76, 3, 1, 1, Gosu::Color::BLACK)
    @font.draw_text("Pattern: #{@boss.current_pattern}", 10, 98, 3, 1, 1, Gosu::Color::BLACK) if @boss.current_pattern
  end

  # Game Over Screen
  def draw_game_over
    # Dark overlay
    Gosu.draw_rect(0, 0, GameConfig::SCREEN_WIDTH, GameConfig::SCREEN_HEIGHT, Gosu::Color.new(150, 0, 0, 0), 10)
    
    @title_font.draw_text("YOU LOSE!", GameConfig::SCREEN_WIDTH/2 - 100, 200, 11, 1, 1, Gosu::Color::RED)
    @font.draw_text("Your bee couldn't survive the flower's attack!", GameConfig::SCREEN_WIDTH/2 - 180, 270, 11)
    @font.draw_text("Difficulty: #{@difficulty_settings[:type].to_s.capitalize}", GameConfig::SCREEN_WIDTH/2 - 70, 320, 11)
    
    @font.draw_text("Press ESC to return to Main Menu", GameConfig::SCREEN_WIDTH/2 - 140, 400, 11)
  end

  # Victory Screen
  def draw_victory
    Gosu.draw_rect(0, 0, GameConfig::SCREEN_WIDTH, GameConfig::SCREEN_HEIGHT, Gosu::Color.new(150, 0, 100, 0), 10)
    
    @title_font.draw_text("VICTORY!", GameConfig::SCREEN_WIDTH/2 - 90, 150, 11, 1, 1, Gosu::Color::GREEN)
    @font.draw_text("Congratulations! You defeated the evil flower!", GameConfig::SCREEN_WIDTH/2 - 190, 220, 11)
    @font.draw_text("Your bee saved the day!", GameConfig::SCREEN_WIDTH/2 - 100, 260, 11)
    @font.draw_text("Difficulty: #{@difficulty_settings[:type].to_s.capitalize}", GameConfig::SCREEN_WIDTH/2 - 70, 300, 11)
    
    @font.draw_text("Press ENTER to Play Again", GameConfig::SCREEN_WIDTH/2 - 120, 350, 11, 1, 1, Gosu::Color::RED)
    @font.draw_text("Press ESC to return to Main Menu", GameConfig::SCREEN_WIDTH/2 - 140, 400, 11)
  end

  # Handle Input (Keyboard Presses)
  def button_down(id)
    case id
    when Gosu::KB_ESCAPE
      # If playing, return to Menu. If at Menu, Close game.
      if @game_state == :playing || @game_state == :game_over || @game_state == :victory
        @game_state = :menu
        @menu_option = 0
      else
        close
      end 
    end
  end

  private

  # Helper method for simple rectangular collision
  # Used for props and bullet-vs-bullet collision
  def collision_rect?(x1, y1, w1, h1, x2, y2, w2, h2)
    (x1 < x2 + w2) && (x1 + w1 > x2) && (y1 < y2 + h2) && (y1 + h1 > y2)
  end

  # Math Helper for Distance Formula
  def distance(x1, y1, x2, y2)
    Math.sqrt((x1 - x2)**2 + (y1 - y2)**2)
  end
end

GameWindow.new.show