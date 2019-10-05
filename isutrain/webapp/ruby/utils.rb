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

    def get_reserved_seats(train, date, from_station, to_station, car_number)
      query = <<~__EOF
      SELECT
        `seat_reservations`.`seat_row`
       ,`seat_reservations`.`seat_column`
      FROM
        `seat_reservations`
      INNER JOIN
        `reservations` ON `reservations`.`reservation_id` = `seat_reservations`.`reservation_id`
      WHERE
        `seat_reservations`.`car_number` = ? AND
        `seat_reservations`.`date` = ? AND
        `seat_reservations`.`train_class` = ? AND
        `seat_reservations`.`train_name` = ?
__EOF


      if train[:is_nobori]
        nobori_conditions = [
          '(`reservations`.`arrival_id` < ? AND ? <= `reservations`.`departure_id`)',
          '(`reservations`.`arrival_id` < ? AND ? <= `reservations`.`departure_id`)',
          '(? < `reservations`.`arrival_id` AND `reservations`.`departure_id` < ?)',
        ]
      else
        nobori_conditions = [
          '(`reservations`.`arrival_id` < ? AND ? <= `reservations`.`departure_id`)',
          '(`reservations`.`arrival_id` < ? AND ? <= `reservations`.`departure_id`)',
          '(? < `reservations`.`arrival_id` AND `reservations`.`departure_id` < ?)',
        ]
      end

      result = {}
      [
        [
          from_station[:id],
          from_station[:id],
        ],
        [
          to_station[:id],
          to_station[:id],
        ],
        [
          from_station[:id],
          to_station[:id],
        ],
      ].zip(nobori_conditions) do |(placeholders, condition)|
        db.xquery(
          "#{query} AND #{condition}",
          car_number,
          date.strftime('%Y/%m/%d'),
          train[:train_class],
          train[:train_name],
          *placeholders,
        ).each do |_|
          result["#{seat_reservation[:seat_row]}\0#{seat_reservation[:seat_column]}"] = true
        end
      end
      result
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
          `reservations` `r`
        WHERE
          `r`.`reservation_id` = `sr`.`reservation_id`
__EOF

      if train[:is_nobori]
        query = "#{query} AND (`r`.`arrival_id` < ? AND ? <= `r`.`departure_id`)\nUNION #{query} AND (`r`.`arrival_id` < ? AND ? <= `r`.`departure_id`)\nUNION #{query} AND (? < `r`.`arrival_id` AND `r`.`departure_id` < ?)"
      else
        query = "#{query} AND (`r`.`departure_id` <= ? AND ? < `r`.`arrival_id`)\nUNION #{query} AND (`r`.`departure_id` <= ? AND ? < `r`.`arrival_id`)\nUNION #{query} AND (`r`.`arrival_id` < ? AND ? < `r`.`departure_id`)"
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
