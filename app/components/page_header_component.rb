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
end
