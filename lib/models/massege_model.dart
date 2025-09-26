import 'package:webcam_doc/models/patient_model.dart';

class MassegeModel {
  String from;
  String to;
  String event;
  PatientModel data;

  MassegeModel({required this.from, required this.to, required this.event, required this.data});

  factory MassegeModel.fromJson(Map<String, dynamic> json) {
    return MassegeModel(
      from: json['from'],
      to: json['to'],
      event: json['event'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'event': event,
      'data': data,
    };
  }

  @override
  String toString() {
    // TODO: implement toString
    return 'MassegeModel{from: $from, to: $to, event: $event, data: $data}';
  }
}