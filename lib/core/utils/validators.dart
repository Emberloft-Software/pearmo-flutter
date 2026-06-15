/// Lightweight form validators shared across auth, onboarding and settings
/// screens. Keep these pure functions so they're trivial to unit test.
class Validators {
  Validators._();

  /// Requires E.164 format (e.g. +94771234567) as used by Supabase phone
  /// auth and the SMS OTP flow.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your phone number';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(trimmed)) {
      return 'Enter a valid phone number with country code, e.g. +94771234567';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter the code you received';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'The code should be 6 digits';
    }
    return null;
  }

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String label = 'This field'}) {
    if (value != null && value.length > max) {
      return '$label must be $max characters or fewer';
    }
    return null;
  }

  /// Onboarding requires users to be 18+.
  static String? dateOfBirthAdult(DateTime? dob) {
    if (dob == null) {
      return 'Select your date of birth';
    }
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    if (age < 18) {
      return 'You must be 18 or older to use Pearmo';
    }
    if (age > 100) {
      return 'Please enter a valid date of birth';
    }
    return null;
  }

  /// E.164 phone validation for the emergency contact on date check-ins.
  static String? emergencyContact(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter an emergency contact number';
    }
    return phone(value);
  }
}
