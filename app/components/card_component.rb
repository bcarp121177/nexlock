class CardComponent < JumpstartComponent
  VARIANTS = [:default, :muted, :outline].freeze

  attr_reader :variant, :class_name

  def initialize(variant: :default, class_name: nil)
    @variant = VARIANTS.include?(variant) ? variant : :default
    @class_name = class_name
  end

  def card_classes
    classes = ["app-card"]
    classes << "app-card-muted" if variant == :muted
    classes << "app-card-outline" if variant == :outline
    classes << class_name if class_name.present?
    classes.join(" ")
  end
end
