import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/auth/firebase_auth/auth_util.dart';

List<String> daysOfTheWeek() {
  return [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
}

List<String> getTimes() {
  List<String> singularTimes = [];
  for (int hour = 8; hour <= 17; hour++) {
    // Skip the times between 13:00 and 13:59
    if (hour == 13) continue;

    for (int minute = 0; minute < 60; minute += 30) {
      // Stop adding times after 17:00
      if (hour == 17 && minute == 30) continue;

      String hourStr = hour.toString().padLeft(2, '0');
      String minuteStr = minute.toString().padLeft(2, '0');
      singularTimes.add('$hourStr:$minuteStr');
    }
  }
  return singularTimes;
}

int calculateAge(DateTime dob) {
  final DateTime currentDate = DateTime.now();
  int age = currentDate.year - dob.year;
  if (dob.month > currentDate.month ||
      (dob.month == currentDate.month && dob.day > currentDate.day)) {
    age--;
  }
  return age;
}

String greeting(DateTime currentTime) {
  // Get the current hour
  int hour = currentTime.hour;

  String salutation = "Day";

  // Determine the time of day and print the appropriate greeting
  if (hour >= 5 && hour < 12) {
    salutation = "Morning";
  } else if (hour >= 12 && hour < 17) {
    salutation = "Afternoon";
  } else if (hour >= 17 && hour < 21) {
    salutation = "Evening";
  } else {
    salutation = "Night";
  }

  return salutation;
}

String createUniqueEmail(
  String name,
  DateTime dateOfBirth,
  String phoneNumber,
) {
  // Convert the name to lowercase and remove all spaces
  name = name.toLowerCase().replaceAll(' ', '');

  // Convert date of birth to string format
  String dobString =
      '${dateOfBirth.year}${dateOfBirth.month}${dateOfBirth.day}';

  // Concatenate date of birth string and phone number
  String uniqueString = dobString + phoneNumber;

  // Create a simple custom hash by summing the ASCII values of the characters
  int hash = uniqueString.runes.fold(0, (sum, value) => sum + value);

  // Convert the hash to a string in hexadecimal format
  String shortHash = hash.toRadixString(16);

  // Generate a unique email address using the name, short hash, and a domain name
  String email = '$name.$shortHash@mother.dawamom.com';

  return email;
}

String generateCustomPassword() {
  // Define the characters and symbols that can be used in the password
  const String chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()-_=+[]{}|;:,.<>?/';

  // Create a random number generator
  math.Random rnd = math.Random.secure();

  // Generate the random password
  String password = '';
  for (int i = 0; i < 10; i++) {
    password += chars[rnd.nextInt(chars.length)];
  }

  return password;
}

DateTime estimateDeliveryDate(DateTime lnmp) {
  // Pregnancy typically lasts about 40 weeks (280 days) from the LNMP
  return lnmp.add(Duration(days: 280));
}

int calculateGestationalAgeInWeeks(DateTime lnmp) {
  final currentDate = DateTime.now();
  final difference = currentDate.difference(lnmp);

  final weeks = (difference.inDays / 7).floor();

  return weeks;
}

int stringToInt(String string) {
  // converts a string to an int
  int num = int.parse(string);
  return num;
}

List<String>? getEndTimes(String startTime) {
  List<String> singularTimes = [];
  int startHour = int.parse(startTime.split(':')[0]);
  int startMinute = int.parse(startTime.split(':')[1]);

  for (int hour = startHour; hour <= 17; hour++) {
    // Start minute should be 0 for hours after the initial hour
    int loopStartMinute = hour == startHour ? startMinute : 0;

    // Skip the times between 13:00 and 14:00
    if (hour == 13) continue;

    for (int minute = loopStartMinute; minute < 60; minute += 30) {
      String hourStr = hour.toString().padLeft(2, '0');
      String minuteStr = minute.toString().padLeft(2, '0');
      singularTimes.add('$hourStr:$minuteStr');
    }
  }
  return singularTimes;
}
