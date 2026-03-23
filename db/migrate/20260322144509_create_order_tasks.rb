# frozen_string_literal: true

class CreateOrderTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :order_tasks do |t|
      t.references :order_service, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.boolean :is_completed, null: false, default: false
      t.datetime :mark_completed_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :order_tasks, :deleted_at
    add_index :order_tasks, %i[order_service_id task_id], unique: true
  end
end
