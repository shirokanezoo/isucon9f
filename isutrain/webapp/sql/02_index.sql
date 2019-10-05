alter table train_timetable_master add index idx1(date, train_class, train_name, station);
alter table seat_reservations add index idx1(reservation_id);
alter table reservations add column arrival_id bigint;
alter table reservations add column departure_id bigint;

alter table seat_reservations add column `date` datetime;
alter table seat_reservations add column `train_class` varchar(100);
alter table seat_reservations add column `train_name` varchar(100);

alter table seat_reservations add index idx2(date,train_class,train_name,car_number);
