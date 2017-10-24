class CreateImportGroups < ActiveRecord::Migration[5.1]
  def change
    create_table :import_groups do |t|
      t.string :group
      t.string :name
      t.string :desc
      t.string :var1
      t.string :var2
      t.string :var3
      t.string :var4
      t.string :var5
      t.string :colors
    end
    add_index :import_groups,:group
  end
end
