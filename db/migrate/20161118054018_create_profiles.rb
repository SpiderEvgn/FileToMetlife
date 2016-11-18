class CreateProfiles < ActiveRecord::Migration[5.0]
  def change
    create_table :profiles do |t|
      t.string :firstname
      t.string :lastname
      t.string :gender
      t.string :birthday
      t.string :id_num
      t.string :email
      t.string :cellphone
      t.string :employer
      t.string :occupation
      t.string :position
      t.string :province
      t.string :city
      t.string :address
      t.string :zipcode
      t.text :PC139
      t.text :PC150
      t.text :PC151
      t.text :PC167

      t.timestamps
    end
  end
end
