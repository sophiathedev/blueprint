# frozen_string_literal: true

class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :service, null: false, foreign_key: true
      t.string :name, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :tasks, :deleted_at
  end
end
