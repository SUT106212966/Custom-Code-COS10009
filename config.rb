module GameConfig
  # --- EASY MODE (Updated with more bullets) ---
  def self.easy_settings
    {
      type: :easy,
      player_hp: 200,                      # INCREASED: Give the player more health (was 150)
      player_shoot_delay: 6,               # DECREASED: Let player shoot faster (was 8)
      boss_bullet_speed_mult: 0.3,         # DECREASED: Make bullets even slower (was 0.5)
      boss_change_pattern_range: 300..500,
      boss_shoot_delay_range: 100..150,    # INCREASED: Boss waits longer between shots (was 80..120)
      boss_bullet_count_mult: 0.8,         # DECREASED: Boss fires fewer bullets overall (was 1.0)
      boss_base_bullet_range: 4..8,        # DECREASED: Base number of bullets per shot (was 6..12)
      boss_patterns: [:circle, :wave],     # SIMPLIFIED: Removed :random_spread and :shotgun for now
      prop_spawn_rate: 0.005               # INCREASED: More hearts/shields spawn (was 0.003)
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
      boss_patterns: [:circle, :spiral, :homing, :wave, :bloom, :random_spread, :cross, :shotgun],
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
      boss_patterns: [:circle, :spiral, :homing, :wave, :bloom, :random_spread,
                      :double_circle, :cross, :zigzag, :shotgun, :vortex, :random_aim],
      prop_spawn_rate: 0.001
    }
  end
end

# GLOBAL CONSTANTS
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600
BASE_BULLET_SPEED = 4
BASE_BOSS_BULLET_SPEED = 2
PROP_SPEED = 0.5
BULLET_SPEED = BASE_BULLET_SPEED
BOSS_BULLET_SPEED = BASE_BOSS_BULLET_SPEED