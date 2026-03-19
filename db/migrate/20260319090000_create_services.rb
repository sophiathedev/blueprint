# frozen_string_literal: true

class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :partner, null: false, foreign_key: true
      t.string :name, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :services, :deleted_at
    add_index :services, 'LOWER(name)', unique: true, where: 'deleted_at IS NULL', name: 'index_services_on_lower_name_active'
  end
end
