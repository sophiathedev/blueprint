# frozen_string_literal: true

class ChangePriorityStatusToIntegerOnOrderServices < ActiveRecord::Migration[8.1]
  PRIORITY_STATUS_SQL = <<~SQL.squish.freeze
    CASE priority_status
    WHEN 'low' THEN 0
    WHEN 'medium' THEN 1
    WHEN 'high' THEN 2
    WHEN 'urgent' THEN 3
    WHEN 'Thấp' THEN 0
    WHEN 'Trung Bình' THEN 1
    WHEN 'Cao' THEN 2
    WHEN 'Khẩn cấp' THEN 3
    ELSE NULL
    END
  SQL

  def up
    add_column :order_services, :priority_status_value, :integer

    execute <<~SQL.squish
      UPDATE order_services
      SET priority_status_value = #{PRIORITY_STATUS_SQL}
    SQL

    remove_column :order_services, :priority_status, :string
    rename_column :order_services, :priority_status_value, :priority_status
  end

  def down
    add_column :order_services, :priority_status_name, :string

    execute <<~SQL.squish
      UPDATE order_services
      SET priority_status_name = CASE priority_status
        WHEN 0 THEN 'low'
        WHEN 1 THEN 'medium'
        WHEN 2 THEN 'high'
        WHEN 3 THEN 'urgent'
        ELSE NULL
      END
    SQL

    remove_column :order_services, :priority_status, :integer
    rename_column :order_services, :priority_status_name, :priority_status
  end
end
