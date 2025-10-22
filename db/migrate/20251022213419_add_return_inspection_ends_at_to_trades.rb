class AddReturnInspectionEndsAtToTrades < ActiveRecord::Migration[8.1]
  def change
    add_column :trades, :return_inspection_ends_at, :datetime
  end
end
