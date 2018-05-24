class CreateFanhaoAliases < ActiveRecord::Migration[5.2]
  def change
    create_table :fanhao_aliases do |t|
      t.string :keyword
      t.string :fanhao
      t.boolean :is_activated

      t.timestamps
    end
  end
end
