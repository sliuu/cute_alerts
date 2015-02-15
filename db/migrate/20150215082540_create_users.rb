class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
    end
    create_table :events do |t|
      t.string :summary
      t.integer :user_id
      t.datetime :time
    end
  end
end
