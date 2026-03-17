# frozen_string_literal: true

class CreatePartners < ActiveRecord::Migration[8.1]
  def change
    create_table :partners do |t|
      t.string :name, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :partners, :deleted_at
    add_index :partners, :name
  end
end
