# frozen_string_literal: true

class RenameAssigneeNameToPartnerAssigneeNameOnOrderServices < ActiveRecord::Migration[8.1]
  def change
    rename_column :order_services, :assignee_name, :partner_assignee_name
  end
end
