namespace :db do
  task :clear_all, [] => :environment do |t, args|
    puts "# dropping data"
    [Repository, Rule].map(&:destroy_all)
  end
end
