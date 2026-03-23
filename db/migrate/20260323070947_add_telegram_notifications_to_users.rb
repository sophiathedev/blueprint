class AddTelegramNotificationsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :telegram_chat_id, :bigint
    add_column :users, :telegram_connected_at, :datetime
    add_column :users, :telegram_connection_token_digest, :string
    add_column :users, :telegram_connection_token_generated_at, :datetime

    add_index :users, :telegram_chat_id, unique: true
    add_index :users, :telegram_connection_token_digest, unique: true
  end
end
