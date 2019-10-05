alter table train_timetable_master add index idx1(date, train_class, train_name, station);
alter table seat_reservations add index idx1(reservation_id);