# frozen_string_literal: true

class AddOrderDetailsToOrderServices < ActiveRecord::Migration[8.1]
  def change
    add_column :order_services, :assignee_name, :string
    add_column :order_services, :priority_status, :string
  end
end
