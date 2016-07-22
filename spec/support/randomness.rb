module Randomness
  def rand_one(a)
    a[rand(a.length)]
  end
    
  def rand_times(i = 10)
    (1 + rand(i)).times
  end
  
  def rand_partition(a, n)
    i = rand(a.length / 3) + 1
    n == 1 ? [a] : [a.take(i).map(&:dup)] + rand_partition(a.drop(i), n - 1)
  end

  def rand_array(n = 10)
    rand_times(n).map { yield }
  end

  def rand_array_of_words(n = 10)
    rand_array(n) { Faker::Hipster.word }
  end

  def rand_array_of_uuids(n = 10)
    rand_array(n) { UUID.generate }
  end

  def rand_array_of_hexes(n = 10)
    rand_array(n) { Faker::Number.hexadecimal(6) }
  end

  def rand_array_of_urls(n = 10)
    rand_array(n) { Faker::Internet.url }
  end

  def rand_array_of_models(name, args = {}, n = 10)
    rand_array(n) { create(name, args) }
  end
end
