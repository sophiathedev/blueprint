class AddGoogleSheetLinkAndCustomerDomainToOrderServices < ActiveRecord::Migration[8.1]
  def change
    add_column :order_services, :google_sheet_link, :string
    add_column :order_services, :customer_domain, :string
  end
end
