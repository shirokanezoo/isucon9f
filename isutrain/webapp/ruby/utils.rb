module Isutrain
  module Utils
    TRAIN_CLASS_MAP = {
      express: '最速',
      semi_express: '中間',
      local: '遅いやつ',
    }
    AVAILABLE_DAYS = 10
    AVAILABLE_SEATS_CACHE_TIME = 1000 * 30

    def check_available_date(date)
      t = Time.new(2020, 1, 1, 0, 0, 0, '+09:00')
      t += 60 * 60 * 24 * AVAILABLE_DAYS

      date < t
    end

    def get_usable_train_class_list(from_station, to_station)
      usable = TRAIN_CLASS_MAP.dup

      usable.delete(:express) unless from_station[:is_stop_express]
      usable.delete(:semi_express) unless from_station[:is_stop_semi_express]
      usable.delete(:local) unless from_station[:is_stop_local]

      usable.delete(:express) unless to_station[:is_stop_express]
      usable.delete(:semi_express) unless to_station[:is_stop_semi_express]
      usable.delete(:local) unless to_station[:is_stop_local]

      usable.values
    end

    def get_available_seats(train, from_station, to_station, seat_class, is_smoking_seat)
      # 指定種別の空き座席を返す
      key = "isutrain:#{train[:train_class]}/#{train[:is_nobori]}/#{seat_class}/#{is_smoking_seat}/#{from_station[:id]}/#{to_station[:id]}"
      cache = redis.get(key)
      return cache.to_i if cache

      puts key

      # 全ての座席を取得する
      seat_list = SEAT_MASTER_BY_CLASS["#{train[:train_class]}\0#{seat_class}\0#{is_smoking_seat}"] || []
      available_seat_map = {}
      seat_list.each do |seat|
        key = "#{seat[:car_number]}_#{seat[:seat_row]}_#{seat[:seat_column]}"
        available_seat_map[key] = seat
      end

      query = <<__EOF
        SELECT
          `sr`.`reservation_id`,
          `sr`.`car_number`,
          `sr`.`seat_row`,
          `sr`.`seat_column`
        FROM
          `seat_reservations` `sr`,
          `reservations` `r`,
          `seat_master` `s`,
          `station_master` `std`,
          `station_master` `sta`
        WHERE
          `r`.`reservation_id` = `sr`.`reservation_id` AND
          `s`.`train_class` = `r`.`train_class` AND
          `s`.`car_number` = `sr`.`car_number` AND
          `s`.`seat_column` = `sr`.`seat_column` AND
          `s`.`seat_row` = `sr`.`seat_row` AND
          `std`.`name` = `r`.`departure` AND
          `sta`.`name` = `r`.`arrival`
__EOF

      if train[:is_nobori]
        query = "#{query} AND (`sta`.`id` < ? AND ? <= `std`.`id`)\nUNION #{query} AND (`sta`.`id` < ? AND ? <= `std`.`id`)\nUNION #{query} AND (? < `sta`.`id` AND `std`.`id` < ?)"
      else
        query = "#{query} AND (`std`.`id` <= ? AND ? < `sta`.`id`)\nUNION #{query} AND (`std`.`id` <= ? AND ? < `sta`.`id`)\nUNION #{query} AND (`sta`.`id` < ? AND ? < `std`.`id`)"
      end

      seat_reservation_list = db.xquery(
        query,
        from_station[:id],
        from_station[:id],
        to_station[:id],
        to_station[:id],
        from_station[:id],
        to_station[:id],
      )

      seat_reservation_list.each do |seat_reservation|
        key = "#{seat_reservation[:car_number]}_#{seat_reservation[:seat_row]}_#{seat_reservation[:seat_column]}"
        available_seat_map.delete(key)
      end

      count = available_seat_map.values.length
      redis.psetex(key, AVAILABLE_SEATS_CACHE_TIME, count.to_s)
      count
    end
  end
end
__END__

SELECT
`sr`.`reservation_id`,
`sr`.`car_number`,
`sr`.`seat_row`,
`sr`.`seat_column`
FROM
`seat_reservations` `sr`,
`reservations` `r`,
`seat_master` `s`,
`station_master` `std`,
`station_master` `sta`
WHERE
`r`.`reservation_id` = `sr`.`reservation_id` AND
`s`.`train_class` = `r`.`train_class` AND
`s`.`car_number` = `sr`.`car_number` AND
`s`.`seat_column` = `sr`.`seat_column` AND
`s`.`seat_row` = `sr`.`seat_row` AND
`std`.`name` = `r`.`departure` AND
`sta`.`name` = `r`.`arrival`
AND (`std`.`id` <= '43' AND '43' < `sta`.`id`)

UNION

SELECT
`sr`.`reservation_id`,
`sr`.`car_number`,
`sr`.`seat_row`,
`sr`.`seat_column`
FROM
`seat_reservations` `sr`,
`reservations` `r`,
`seat_master` `s`,
`station_master` `std`,
`station_master` `sta`
WHERE
`r`.`reservation_id` = `sr`.`reservation_id` AND
`s`.`train_class` = `r`.`train_class` AND
`s`.`car_number` = `sr`.`car_number` AND
`s`.`seat_column` = `sr`.`seat_column` AND
`s`.`seat_row` = `sr`.`seat_row` AND
`std`.`name` = `r`.`departure` AND
`sta`.`name` = `r`.`arrival`
AND (`std`.`id` <= '55' AND '55' < `sta`.`id`)

UNION

SELECT
`sr`.`reservation_id`,
`sr`.`car_number`,
`sr`.`seat_row`,
`sr`.`seat_column`
FROM
`seat_reservations` `sr`,
`reservations` `r`,
`seat_master` `s`,
`station_master` `std`,
`station_master` `sta`
WHERE
`r`.`reservation_id` = `sr`.`reservation_id` AND
`s`.`train_class` = `r`.`train_class` AND
`s`.`car_number` = `sr`.`car_number` AND
`s`.`seat_column` = `sr`.`seat_column` AND
`s`.`seat_row` = `sr`.`seat_row` AND
`std`.`name` = `r`.`departure` AND
`sta`.`name` = `r`.`arrival`
AND (`sta`.`id` < '43' AND '55' < `std`.`id`);
