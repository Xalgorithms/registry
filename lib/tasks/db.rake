namespace :db do
  task :clear_all, [] => :environment do |t, args|
    puts "# dropping SQL data"
    [Repository, Rule].map(&:destroy_all)

    puts "# dropping Mongo data"
    [RuleDocument].map(&:destroy_all)
  end
end
