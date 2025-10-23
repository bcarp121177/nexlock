class PageHeaderComponent < JumpstartComponent
  renders_one :actions

  attr_reader :title, :subtitle

  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end

  def subtitle?
    subtitle.present?
  end

  # Override actions method to capture blocks
  def actions(&block)
    if block_given?
      capture_for(:actions, &block)
    else
      @actions
    end
  end
end
