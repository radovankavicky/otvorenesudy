class CreateCourtStatisticalSummaries < ActiveRecord::Migration
  def change
    create_table :court_statistical_summaries do |t|
      t.string     :uri,    null: false
      t.references :source, null: false
      t.references :court,  null: false
      t.integer    :year,   null: false

      t.timestamps
    end

    add_index :court_statistical_summaries, :source_id
    add_index :court_statistical_summaries, :court_id
  end
end