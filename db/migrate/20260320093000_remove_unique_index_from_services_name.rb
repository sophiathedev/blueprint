# frozen_string_literal: true

class RemoveUniqueIndexFromServicesName < ActiveRecord::Migration[8.1]
  def change
    remove_index :services, name: 'index_services_on_lower_name_active'
  end
end
