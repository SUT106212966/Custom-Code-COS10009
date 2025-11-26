class Prop
  attr_accessor :type, :x, :y, :width, :height

  def initialize(x, y, type)
    @x = x
    @y = y
    @type = type # Is it a :heart or a :shield?
    
    # --- 1. Load Graphics ---
    if type == :heart
      # Load multiple frames for animation (Sprite Sheet)
      @frames = Gosu::Image.load_tiles('media/love.png', 16, 16, tileable: true) rescue []
      @animation_frame = 0
      @width = 32
      @height = 32
    else
      # Load single image for shield
      @image = Gosu::Image.new('media/nshield.ng.png') rescue Gosu::Image.from_text('⬢', 24)
      @width = @image.width
      @height = @image.height
    end
    
    # Random number to make items sway differently from each other
    @float_offset = rand(100)
    @time = 0
  end

  def update
    @time += 1
    # Move Down
    @y += GameConfig::PROP_SPEED
    
    # Move Left/Right (Swaying motion using Sine Wave)
    @x += Math.sin((Gosu.milliseconds + @float_offset) * 0.005) * 0.3
  end

  def draw
    if @type == :heart
      # --- HEART ANIMATION ---
      if @frames.any?
        frame = @frames[@animation_frame]
        frame.draw(@x, @y, 1, 2, 2) # Draw at 2x size
        
        # Cycle through frames based on time (Animation Logic)
        @animation_frame = (Gosu.milliseconds / 150) % @frames.size
      else
        Gosu::Image.from_text('♥', 24).draw(@x, @y, 1)
      end
    else
      # --- SHIELD PULSE EFFECT ---
      # Make it grow and shrink slightly
      scale = 1.0 + Math.sin(Gosu.milliseconds * 0.005) * 0.05
      @image.draw(@x, @y, 1, scale, scale)
    end
  end

  # Delete if it falls off bottom or exists too long
  def off_screen?
    @y > GameConfig::SCREEN_HEIGHT + 20 || @time > 600
  end
end