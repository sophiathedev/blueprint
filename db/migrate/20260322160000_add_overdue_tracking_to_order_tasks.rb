# frozen_string_literal: true

class AddOverdueTrackingToOrderTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :order_tasks, :is_overdue, :boolean, default: false, null: false
    add_column :order_services, :deadline_check_job_id, :string
    add_index :order_services, :deadline_check_job_id
  end
end
