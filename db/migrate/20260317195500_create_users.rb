# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :name
      t.string :password_digest
      t.integer :role, default: 1, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :users, :deleted_at
  end
end
