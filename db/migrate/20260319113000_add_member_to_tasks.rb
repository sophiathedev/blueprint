# frozen_string_literal: true

class AddMemberToTasks < ActiveRecord::Migration[8.1]
  def change
    add_reference :tasks, :member, foreign_key: { to_table: :users }
  end
end
