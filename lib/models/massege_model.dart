import 'package:webcam_doc/models/patient_model.dart';

class MassegeModel {
  String to;
  String from;
  String event;
  String data;
  PatientModel patient;

  MassegeModel({required this.to, required this.from, required this.event,required this.data, required this.patient});

  factory MassegeModel.fromJson(Map<String, dynamic> json) {
    return MassegeModel(
      from: json['to'],
      to: json['from'],
      event: json['event'],
      data: json['data'],
      patient: json['patient']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'from': from,
      'event': event,
      'data': data,
      'patient': patient.toJson()
    };
  }

  @override
  String toString() {
    // TODO: implement toString
    return 'MassegeModel{from: $from, to: $to, data: $data, event: $event, patient: $patient}';
  }
}