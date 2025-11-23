class Prop
  attr_accessor :type, :x, :y, :width, :height

  def initialize(x, y, type)
    @x = x
    @y = y
    @type = type
    if type == :heart
      @frames = Gosu::Image.load_tiles('media/love.png', 16, 16, tileable: true) rescue []
      @animation_frame = 0
      @width = 32
      @height = 32
    else
      @image = Gosu::Image.new('media/nshield.ng.png') rescue Gosu::Image.from_text('⬢', 24)
      @width = @image.width
      @height = @image.height
    end
    @float_offset = rand(100)
    @time = 0
  end

  def update
    @time += 1
    @y += PROP_SPEED
    @x += Math.sin((Gosu.milliseconds + @float_offset) * 0.005) * 0.3
  end

  def draw
    if @type == :heart
      if @frames.any?
        frame = @frames[@animation_frame]
        frame.draw(@x, @y, 1, 2, 2) 
        @animation_frame = (Gosu.milliseconds / 150) % @frames.size
      else
        Gosu::Image.from_text('♥', 24).draw(@x, @y, 1)
      end
    else
      scale = 1.0 + Math.sin(Gosu.milliseconds * 0.005) * 0.05
      @image.draw(@x, @y, 1, scale, scale)
    end
  end

  def off_screen?
    @y > SCREEN_HEIGHT + 20 || @time > 600
  end
end