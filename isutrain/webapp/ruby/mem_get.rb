require './distance_fare_master'
require './fare_master'
require './seat_master'
require './train_master'

module Isutrain
  TRAIN_BY_DATE_CLASS_NAME = TRAIN_MASTER.map do |train|
    [
      "#{train[:date].strftime('%Y%m%d')}-#{train[:train_class]}-#{train[:train_name]}",
      train
    ]
  end.to_h

  SEAT_GROUP_BY_CLASS_AND_NUM = SEAT_MASTER
    .sort_by { |s| "#{s[:seat_row].to_s.rjust(4, '0')}-#{s[:seat_column]}" }
    .group_by { |s| "#{s[:train_class]}-#{s[:car_number]}" }

  class << self
    def get_train(date, klass, name)
      id = "#{date.strftime('%Y%m%d')}-#{klass}-#{name}"

      TRAIN_BY_DATE_CLASS_NAME[id].dup
    end

    def get_seats(klass, num)
      id = "#{klass}-#{num}"

      SEAT_GROUP_BY_CLASS_AND_NUM[id].dup
    end
  end
end
