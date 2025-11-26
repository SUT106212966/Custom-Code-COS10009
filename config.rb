module GameConfig

  # --- EASY MODE ---
  def self.easy_settings
    {
      type: :easy,
      player_hp: 200,                      
      player_shoot_delay: 10,              
      boss_bullet_speed_mult: 0.5,         
      boss_change_pattern_range: 300..500,
      boss_shoot_delay_range: 80..120,    
      boss_bullet_count_mult: 1.2,         
      boss_base_bullet_range: 4..8,        
      boss_patterns: [:circle, :wave, :spiral],     
      prop_spawn_rate: 0.003          
    }
  end

  # --- MEDIUM MODE ---
  def self.medium_settings
    {
      type: :medium,
      player_hp: 100,
      player_shoot_delay: 12,
      boss_bullet_speed_mult: 0.7,
      boss_change_pattern_range: 200..400,
      boss_shoot_delay_range: 50..90,
      boss_bullet_count_mult: 1.0,
      boss_base_bullet_range: 8..16,
      boss_patterns: [:circle, :spiral, :wave, :random_spread],
      prop_spawn_rate: 0.002
    }
  end

  # --- HARD MODE ---
  def self.hard_settings
    {
      type: :hard,
      player_hp: 100,
      player_shoot_delay: 20,
      boss_bullet_speed_mult: 1.0,
      boss_change_pattern_range: 150..300,
      boss_shoot_delay_range: 40..80,
      boss_bullet_count_mult: 1.2,
      boss_base_bullet_range: 12..20,
      boss_patterns: [:circle, :spiral, :homing, :wave, :random_spread, :shotgun],
      prop_spawn_rate: 0.001
    }
  end
end

# GLOBAL CONSTANTS
module GameConfig
  SCREEN_WIDTH = 800
  SCREEN_HEIGHT = 600
  BASE_BULLET_SPEED = 4                         # Standard speed for player bullets
  BASE_BOSS_BULLET_SPEED = 2                    # Standard speed for boss bullets
  PROP_SPEED = 0.5                              # How fast items fall down
  
  # Copying values to main variables
  BULLET_SPEED = BASE_BULLET_SPEED
  BOSS_BULLET_SPEED = BASE_BOSS_BULLET_SPEED
end