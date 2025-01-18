import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsService {
  // Fetch contacts from the device
  Future<List<Contact>> getContacts() async {
    try {
      // Check for permissions
      if (await FlutterContacts.requestPermission()) {
        // Get all contacts from the device
        List<Contact> contacts = await FlutterContacts.getContacts();
        return contacts;
      } else {
        throw Exception("Permission denied to access contacts");
      }
    } catch (e) {
      print("Error fetching contacts: $e");
      return [];
    }
  }

  Future<String?> findContactNumber(String name) async {
    try {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      // Search for the contact by name
      Contact? contact = contacts.firstWhere(
        (c) => c.displayName.toLowerCase() == name.toLowerCase(),
        orElse: () => Contact(), // Provide a default Contact instance
      );

      if (contact != null && contact.phones.isNotEmpty) {
        // Return the first phone number
        return contact.phones.first.number;
      } else {
        print("Contact not found or no phone number available.");
        return null;
      }
    } catch (e) {
      print("Error finding contact: $e");
      return null;
    }
  }
}
