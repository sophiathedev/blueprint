# frozen_string_literal: true

class CreateOrderServices < ActiveRecord::Migration[8.1]
  def change
    create_table :order_services do |t|
      t.references :service, null: false, foreign_key: true
      t.datetime :completed_at, null: false
      t.text :notes
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :order_services, :deleted_at
  end
end
