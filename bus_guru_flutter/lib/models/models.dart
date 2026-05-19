class Bus {
  final int id;
  final String busName;
  final String routeName;
  final int totalSeats;
  final int fare;
  Bus({required this.id, required this.busName, required this.routeName, required this.totalSeats, required this.fare});
  factory Bus.fromJson(Map<String, dynamic> json) => Bus(id: json['id'], busName: json['bus_name'], routeName: json['route_name'], totalSeats: json['total_seats'], fare: json['fare']);
}

class Ticket {
  final int id;
  final int seats;
  final int price;
  final String busName;
  final String routeName;
  final String bookDate;
  Ticket({required this.id, required this.seats, required this.price, required this.busName, required this.routeName, required this.bookDate});
  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(id: json['id'], seats: json['seats_booked'], price: json['total_price'], busName: json['bus_name'], routeName: json['route_name'], bookDate: json['booking_date']);
}
